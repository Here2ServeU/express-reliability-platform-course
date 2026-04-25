const express = require('express');
const axios   = require('axios');

const app  = express();
const PORT = 3000;
const FLASK_URL = process.env.FLASK_BASE_URL || 'http://localhost:5000';

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'node-api', version: 'v2' });
});

app.get('/score', async (req, res) => {
  try {
    const input    = req.query.input || 'default';
    const response = await axios.get(`${FLASK_URL}/score`, { params: { input } });
    res.json({
      version: 'v2',
      source:  'node-api',
      flask:    response.data
    });
  } catch (err) {
    res.status(500).json({ error: 'Flask unavailable', detail: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`Node API listening on port ${PORT}`);
  console.log(`Flask URL configured as: ${FLASK_URL}`);
});
