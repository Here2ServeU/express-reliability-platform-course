const express = require('express');
const axios = require('axios');
const app = express();
const PORT = process.env.PORT || 3000;
const FLASK_URL = process.env.FLASK_BASE_URL || 'http://localhost:5000';

// ── Routes from V1 (unchanged) ──────────────────────────────
app.get('/', (req, res) => {
  res.json({ service: 'node-api', version: 'v2', status: 'running' });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/api/status', (req, res) => {
  res.json({ message: 'API is operational', version: 'v2' });
});

// ── New V2 route: calls flask-api ──────────────────────────
app.get('/score', async (req, res) => {
  const input = req.query.input || 'default input';
  try {
    const response = await axios.get(`${FLASK_URL}/score`, {
      params: { input }
    });
    res.json({
      version: 'v2',
      source: 'node-api',
      flask: response.data
    });
  } catch (err) {
    res.status(500).json({ error: 'flask-api unavailable', detail: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`node-api running on port ${PORT}`);
  console.log(`flask-api URL: ${FLASK_URL}`);
});
