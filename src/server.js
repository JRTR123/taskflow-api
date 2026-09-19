const app = require('./app');

const PORT = process.env.PORT || 8080;

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`taskflow-api listening on port ${PORT}`);
});
