# CareCoins Monorepo

This repository is split into:

- `backend/`: Node.js + Express API and PostgreSQL schema.
- `frontend/`: Vue 3 + Vite client for backend integration flows.

## Backend

```bash
cd backend
npm install
npm run dev
```

## Frontend

```bash
cd frontend
npm install
npm run dev
```

Default frontend API base URL is `http://localhost:3000`.

## Frontend implemented flows

The Vue frontend currently supports all implemented backend routes:

- `GET /health`
- `GET /api/families`
- `POST /api/families`
- `POST /api/families/:familyId/join`
- `GET /api/activities?familyId=...`
- `POST /api/activities`
- `POST /api/activities/:activityId/approve`
