import dotenv from 'dotenv';
import express from 'express';
import { requireAuth } from './middleware/auth.js';
import { familiesRouter } from './routes/families.js';
import { activitiesRouter } from './routes/activities.js';

dotenv.config();

const app = express();

app.use(express.json());

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok', service: 'carecoins-backend' });
});

app.use('/api/families', requireAuth, familiesRouter);
app.use('/api/activities', requireAuth, activitiesRouter);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error.' });
});

const port = Number(process.env.PORT || 3000);

app.listen(port, () => {
  console.log(`CareCoins backend running on port ${port}`);
});
