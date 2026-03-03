const express = require("express");
const axios = require("axios");

const app = express();
const PORT = 3000;

const FLASK_BASE_URL = "http://localhost:5000";

app.get("/health", (req, res) => {
  res.json({ status: "node-api healthy" });
});

app.get("/score", async (req, res) => {
  try {
    const input = req.query.input || "default";
    const response = await axios.get(`${FLASK_BASE_URL}/score`, {
      params: { input }
    });
    res.json({
      version: "v2",
      flask_response: response.data
    });
  } catch (err) {
    res.status(500).json({ error: "Flask service unavailable" });
  }
});

app.listen(PORT, () => {
  console.log(`Node API running on port ${PORT}`);
});
