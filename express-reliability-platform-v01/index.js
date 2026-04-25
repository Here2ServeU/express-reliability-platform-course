const express = require('express');
const app = express();
const PORT = 3000;

app.use(express.static('public'));

app.get('/', (req, res) => {
  res.send('<h1>Welcome to the Express Reliability Platform!</h1>');
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'web-service', version: 'v1' });
});

app.listen(PORT, () => {
  console.log('Server running on port ' + PORT);
  console.log('Visit: http://localhost:' + PORT);
});
