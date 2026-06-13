const express = require('express');
const axios = require('axios');
const client = require('prom-client'); // NEW

const app = express();
const PORT = process.env.PORT || 3000;
const FLASK_URL = process.env.FLASK_BASE_URL || 'http://localhost:5000';

// NEW: collect default Node.js metrics (memory, CPU, event loop)
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// NEW: a counter for requests to this service
const httpRequestsTotal = new client.Counter({
  name: 'node_api_requests_total',
  help: 'Total number of requests to node-api',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

// NEW: the /metrics door
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// All V3 routes stay exactly the same:
app.get('/', (req, res) => {
  httpRequestsTotal.labels('GET', '/', '200').inc();
  res.json({ service: 'node-api', version: 'v4', status: 'running' });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/score', async (req, res) => {
  const input = req.query.input || 'default input';
  try {
    const response = await axios.get(`${FLASK_URL}/score`, { params: { input } });
    httpRequestsTotal.labels('GET', '/score', '200').inc();
    res.json({ version: 'v4', source: 'node-api', flask: response.data });
  } catch (err) {
    httpRequestsTotal.labels('GET', '/score', '500').inc();
    res.status(500).json({ error: 'flask-api unavailable', detail: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`node-api running on port ${PORT}`);
});
