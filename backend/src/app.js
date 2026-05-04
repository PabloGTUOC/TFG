import './env.js';
import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { requireAuth } from './middleware/auth.js';
import { logLoginHistory } from './middleware/audit.js';
import { familiesRouter } from './routes/families.js';
import { activitiesRouter } from './routes/activities.js';
import { meRouter } from './routes/me.js';
import { dashboardRouter } from './routes/dashboard.js';
import { marketplaceRouter } from './routes/marketplace.js';
import { statsRouter } from './routes/stats.js';
import { absencesRouter } from './routes/absences.js';
import { inviteLinksRouter } from './routes/inviteLinks.js';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

app.use(cors({
  origin: function (origin, callback) {
    // Allow all origins in development (solves network IP blocking)
    callback(null, true);
  },
  credentials: true
}));
app.use(express.json());

app.use(rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 1000,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests. Please try again later.' },
  keyGenerator: (req) => req.auth?.uid || req.ip,
}));

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok', service: 'carecoins-backend' });
});

app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

app.use('/api/me', requireAuth, meRouter);
app.use('/api/families', requireAuth, familiesRouter);
app.use('/api/activities', requireAuth, activitiesRouter);
app.use('/api/dashboard', requireAuth, dashboardRouter);
app.use('/api/marketplace', requireAuth, marketplaceRouter);
app.use('/api/stats', requireAuth, statsRouter);
app.use('/api/absences', requireAuth, absencesRouter);
app.use('/api/families', requireAuth, inviteLinksRouter);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error.' });
});

export default app;
