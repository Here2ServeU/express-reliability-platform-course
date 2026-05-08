const express = require('express');
const axios   = require('axios');
const client  = require('prom-client');

const app  = express();
const PORT = 3000;
const FLASK_URL = process.env.FLASK_BASE_URL || 'http://localhost:5000';

const register = new client.Registry();

client.collectDefaultMetrics({ register });

const httpRequests = new client.Counter({
  name:       'http_requests_total',
  help:       'Total number of HTTP requests received',
  labelNames: ['method', 'route', 'status'],
  registers:  [register]
});

const httpDuration = new client.Histogram({
  name:       'http_request_duration_seconds',
  help:       'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets:    [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers:  [register]
});

app.use((req, res, next) => {
  const endTimer = httpDuration.startTimer();
  res.on('finish', () => {
    const labels = { method: req.method, route: req.path, status: res.statusCode };
    httpRequests.inc(labels);
    endTimer(labels);
  });
  next();
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'node-api', version: 'v7' });
});

app.get('/score', async (req, res) => {
  try {
    const input    = req.query.input || 'default';
    const response = await axios.get(`${FLASK_URL}/score`, { params: { input } });
    res.json({
      version: 'v7',
      source:  'node-api',
      flask:    response.data
    });
  } catch (err) {
    res.status(500).json({ error: 'Flask unavailable', detail: err.message });
  }
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(PORT, () => {
  console.log(`Node API listening on port ${PORT}`);
  console.log(`Flask URL configured as: ${FLASK_URL}`);
});
