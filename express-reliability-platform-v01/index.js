const express = require('express');
const path = require('path');
const app = express();
const PORT = 3000;

app.use(express.static('public'));

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'web-service', version: 'v1' });
});

app.listen(PORT, () => {
  console.log('Server running on port ' + PORT);
  console.log('Visit: http://localhost:' + PORT);
});
