const express = require('express');
const app = express();
const PORT = 3000;

// Serve any files inside the public/ folder automatically
app.use(express.static('public'));

// Homepage: what happens when someone visits the main URL /
app.get('/', (req, res) => {
  res.send('<h1>Welcome to the Express Reliability Platform!</h1>');
});

// Health check: a standard route used by monitoring systems
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'web-service', version: 'v1' });
});

// Start the server and begin listening for visitors
app.listen(PORT, () => {
  console.log('Server running on port ' + PORT);
  console.log('Visit: http://localhost:' + PORT);
});
