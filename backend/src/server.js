import './env.js';
import express from 'express';
import cors from 'cors';
import { requireAuth } from './middleware/auth.js';
import { logLoginHistory } from './middleware/audit.js';
import { familiesRouter } from './routes/families.js';
import { activitiesRouter } from './routes/activities.js';
import { meRouter } from './routes/me.js';
import { dashboardRouter } from './routes/dashboard.js';
import { marketplaceRouter } from './routes/marketplace.js';

const app = express();

const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim())
  : ['http://localhost:5173', 'http://127.0.0.1:5173'];

app.use(cors({
  origin: allowedOrigins,
  credentials: true
}));
app.use(express.json());

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok', service: 'carecoins-backend' });
});

app.use('/api/me', requireAuth, meRouter);
app.use('/api/families', requireAuth, familiesRouter);
app.use('/api/activities', requireAuth, activitiesRouter);
app.use('/api/dashboard', requireAuth, dashboardRouter);
app.use('/api/marketplace', requireAuth, marketplaceRouter);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error.' });
});

const port = Number(process.env.PORT || 3000);

app.listen(port, () => {
  console.log(`CareCoins backend running on port ${port}`);
});
