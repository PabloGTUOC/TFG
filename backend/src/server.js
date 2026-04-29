import app from './app.js';

const port = Number(process.env.PORT || 3000);

app.listen(port, '0.0.0.0', () => {
  console.log(`CareCoins backend running on port ${port} and bound to 0.0.0.0`);
});
