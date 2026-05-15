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
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

// Trust the nginx reverse proxy sitting in front of this service
app.set('trust proxy', 1);

const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || 'http://localhost:5173')
  .split(',')
  .map(o => o.trim());

app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (e.g. mobile apps, curl) only in development
    if (!origin) {
      return callback(null, process.env.NODE_ENV !== 'production');
    }
    if (ALLOWED_ORIGINS.includes(origin)) {
      return callback(null, true);
    }
    callback(new Error(`Origin ${origin} not allowed by CORS policy.`));
  },
  credentials: true
}));
app.use(express.json());

// 1. Keep a loose global limiter as a DoS shield
app.use(rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 1000,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests. Please try again later.' },
}));

// 2. Add a tighter per-user limiter applied after auth
const perUserLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests. Please try again later.' },
  keyGenerator: (req) => req.auth.uid, // auth is guaranteed set by this point
});

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok', service: 'carecoins-backend' });
});

app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

app.use('/api/me', requireAuth, perUserLimiter, meRouter);
app.use('/api/families', requireAuth, perUserLimiter, familiesRouter);
app.use('/api/activities', requireAuth, perUserLimiter, activitiesRouter);
app.use('/api/dashboard', requireAuth, perUserLimiter, dashboardRouter);
app.use('/api/marketplace', requireAuth, perUserLimiter, marketplaceRouter);
app.use('/api/stats', requireAuth, perUserLimiter, statsRouter);
app.use('/api/absences', requireAuth, perUserLimiter, absencesRouter);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error.' });
});

export default app;
