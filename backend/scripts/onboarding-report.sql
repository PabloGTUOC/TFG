-- Onboarding effectiveness report (docs/onboarding-help-plan.md Phase 4).
-- Run with:
--   docker exec -i tfg-postgres-1 psql -U carecoins -d carecoins \
--     < backend/scripts/onboarding-report.sql

-- ── 1. Activation ────────────────────────────────────────────────────
-- Definition: a user is "activated" when their family validates its first
-- task (first positive coin_ledger entry) within 7 days of the user's
-- signup. Compare cohorts before/after the onboarding release to judge
-- whether the help system moved the needle.
SELECT
  date_trunc('week', u.created_at)::date          AS signup_week,
  COUNT(*)                                        AS signups,
  COUNT(*) FILTER (WHERE fe.first_earn IS NOT NULL
    AND fe.first_earn <= u.created_at + INTERVAL '7 days')
                                                  AS activated_7d,
  ROUND(100.0 * COUNT(*) FILTER (WHERE fe.first_earn IS NOT NULL
    AND fe.first_earn <= u.created_at + INTERVAL '7 days') / COUNT(*), 1)
                                                  AS activation_pct
FROM users u
LEFT JOIN LATERAL (
  SELECT MIN(cl.created_at) AS first_earn
  FROM coin_ledger cl
  WHERE cl.user_id = u.id AND cl.amount > 0
) fe ON true
GROUP BY 1
ORDER BY 1 DESC;

-- ── 2. Welcome dialog funnel ─────────────────────────────────────────
SELECT detail->>'choice' AS choice, COUNT(*) AS users
FROM onboarding_events
WHERE event = 'welcome_choice'
GROUP BY 1;

-- ── 3. Tour completion by surface ────────────────────────────────────
SELECT
  detail->>'tour'                                   AS tour,
  COUNT(*) FILTER (WHERE event = 'tour_completed')  AS completed,
  COUNT(*) FILTER (WHERE event = 'tour_skipped')    AS skipped
FROM onboarding_events
WHERE event IN ('tour_completed', 'tour_skipped')
GROUP BY 1
ORDER BY completed DESC;

-- ── 4. Checklist engagement ──────────────────────────────────────────
SELECT event, COUNT(*) AS n, COUNT(DISTINCT user_id) AS users
FROM onboarding_events
WHERE event IN ('checklist_step_tapped', 'checklist_dismissed',
                'checklist_completed')
GROUP BY event;

-- Which checklist steps get tapped (where people need the shortcut):
SELECT detail->>'step' AS step, COUNT(*) AS taps
FROM onboarding_events
WHERE event = 'checklist_step_tapped'
GROUP BY 1
ORDER BY taps DESC;
