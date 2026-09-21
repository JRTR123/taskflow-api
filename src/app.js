const express = require('express');
const tasksRouter = require('./routes/tasks');

const app = express();

app.use(express.json());

app.get('/health', (req, res) => {
  if (process.env.FAIL_HEALTH === 'true' || process.env.FAIL_HEALTH === '1') {
    return res.status(500).json({ status: 'error' });
  }
  res.status(200).json({ status: 'ok', uptime: process.uptime() });
});

app.use('/api/tasks', tasksRouter);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  // eslint-disable-next-line no-console
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

module.exports = app;
