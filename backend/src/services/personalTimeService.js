import { assertActiveMember } from '../db/users.js';

/**
 * Personal-time requests (docs/personal-time-plan.md §3.2, Phase 4).
 *
 * Booking time for yourself always carries a coverage offer to another
 * caretaker, and is only real once they accept — you cannot decline your
 * partner's business trip, but you can decline their gym session.
 *
 * Nothing is scheduled while a request is pending. On acceptance two ordinary
 * `activities` rows are materialized: the requester's self activity (worth
 * nothing) and the accepter's coverage shift (worth the family base rate, plus
 * whatever the requester put up from their own wallet). Every existing query
 * over `activities` therefore keeps working untouched.
 */

export const SELF_TYPES = ['sport', 'social', 'rest', 'appointment', 'other'];

export const MIN_MINUTES = 15;
export const MAX_HOURS = 24;
const DEFAULT_EXPIRY_HOURS = 48;
const MS_PER_MINUTE = 60_000;

// ─── Pure rules ───────────────────────────────────────────────────────────────

/**
 * Validates the window a self activity claims. Returns an error message, or
 * null when usable. Pure, so the rule is unit-testable without a database.
 */
export function validateSelfWindow(startsAt, endsAt, now = new Date()) {
  const start = new Date(startsAt);
  const end = new Date(endsAt);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    return 'Start and end must be valid date/time values.';
  }
  if (end.getTime() <= start.getTime()) return 'End time must be after start time.';
  const minutes = (end.getTime() - start.getTime()) / MS_PER_MINUTE;
  if (minutes < MIN_MINUTES) return `Personal time must last at least ${MIN_MINUTES} minutes.`;
  if (minutes > MAX_HOURS * 60) {
    return `Personal time cannot exceed ${MAX_HOURS} hours — log time off instead.`;
  }
  if (end.getTime() <= now.getTime()) return 'Personal time must be in the future.';
  return null;
}

/**
 * What covering that window is worth, using the same rule the activities screen
 * suggests for every other task: round(rate × hours), floored at 1.
 */
export function priceCoverage(baseRatePerHour, minutes) {
  return Math.max(1, Math.round((baseRatePerHour * minutes) / 60));
}

/** Requests go stale 48 h after asking, or when the window starts — whichever is sooner. */
export function expiryFor(startsAt, now = new Date()) {
  const cap = new Date(now.getTime() + DEFAULT_EXPIRY_HOURS * 60 * 60 * 1000);
  const start = new Date(startsAt);
  return start < cap ? start : cap;
}

// ─── Shared queries ───────────────────────────────────────────────────────────

async function activeCaregivers(client, familyId) {
  const { rows } = await client.query(
    `SELECT fm.user_id, COALESCE(fm.alias, u.display_name, u.email) AS name
     FROM family_members fm JOIN users u ON u.id = fm.user_id
     WHERE fm.family_id = $1 AND fm.role = 'caregiver' AND fm.status = 'active'
     ORDER BY fm.id`,
    [familyId]
  );
  return rows;
}

/**
 * Who to ask. Two caregivers is the common case and needs no picker — it is the
 * other one. With three or more, an unspecified counterparty means "ask anyone".
 */
function resolveCounterparty(caregivers, requesterId, requestedOf) {
  if (requestedOf) {
    const match = caregivers.find((c) => Number(c.user_id) === Number(requestedOf));
    if (!match) return { error: 'That person is not an active caregiver in this family.' };
    if (Number(requestedOf) === Number(requesterId)) {
      return { error: 'You cannot ask yourself to cover.' };
    }
    return { requestedOf: Number(requestedOf) };
  }
  const others = caregivers.filter((c) => Number(c.user_id) !== Number(requesterId));
  if (others.length === 1) return { requestedOf: Number(others[0].user_id) };
  if (others.length === 0) return { error: 'There is no one else to cover for you.' };
  return { requestedOf: null }; // ask anyone
}

/** What else sits in that window for a given person, ignoring coverage (§4.1). */
async function conflictsFor(client, familyId, userId, startsAt, endsAt) {
  const { rows: absences } = await client.query(
    `SELECT title FROM absences
     WHERE user_id = $1 AND family_id = $2 AND start_time < $4 AND end_time > $3`,
    [userId, familyId, startsAt, endsAt]
  );
  const { rows: busy } = await client.query(
    `SELECT title FROM activities
     WHERE assigned_to = $1 AND family_id = $2 AND is_template = false
       AND type <> 'coverage'
       AND status IN ('approved', 'pending_validation')
       AND starts_at < $4 AND ends_at > $3`,
    [userId, familyId, startsAt, endsAt]
  );
  return [...absences.map((a) => a.title), ...busy.map((b) => b.title)];
}

async function baseRateFor(client, familyId) {
  const { rows } = await client.query(
    'SELECT monthly_coin_budget FROM families WHERE id = $1',
    [familyId]
  );
  return rows.length ? rows[0].monthly_coin_budget / 720 : 0;
}

/** Returns the requester's escrowed sweetener, crediting it back. */
async function refundSweetener(client, req) {
  if (!req.sweetener_coins) return;
  await client.query(
    'UPDATE family_members SET coin_balance = coin_balance + $1 WHERE family_id = $2 AND user_id = $3',
    [req.sweetener_coins, req.family_id, req.requester_id]
  );
  await client.query(
    `INSERT INTO coin_ledger (family_id, user_id, amount, reason)
     VALUES ($1, $2, $3, 'coverage_sweetener_refunded')`,
    [req.family_id, req.requester_id, req.sweetener_coins]
  );
}

// ─── Operations ───────────────────────────────────────────────────────────────

export async function quoteRequest(client, userId, { familyId, startsAt, endsAt, requestedOf, coverageNeeded = true }, now = new Date()) {
  if (!await assertActiveMember(client, familyId, userId)) {
    return { error: { code: 403, message: 'Not a family member.' } };
  }
  const windowError = validateSelfWindow(startsAt, endsAt, now);
  if (windowError) return { error: { code: 400, message: windowError } };

  const minutes = (new Date(endsAt) - new Date(startsAt)) / MS_PER_MINUTE;
  const caregivers = await activeCaregivers(client, familyId);
  const resolved = resolveCounterparty(caregivers, userId, requestedOf);
  if (resolved.error) return { error: { code: 400, message: resolved.error } };

  const baseline = coverageNeeded ? priceCoverage(await baseRateFor(client, familyId), minutes) : 0;

  const { rows: balanceRows } = await client.query(
    'SELECT coin_balance FROM family_members WHERE family_id = $1 AND user_id = $2',
    [familyId, userId]
  );

  // Their conflicts are a warning, never a refusal — they may rearrange.
  const theirConflicts = resolved.requestedOf
    ? await conflictsFor(client, familyId, resolved.requestedOf, startsAt, endsAt)
    : [];

  return {
    data: {
      baselineCoins: baseline,
      minutes,
      requestedOf: resolved.requestedOf,
      candidates: caregivers.filter((c) => Number(c.user_id) !== Number(userId)),
      yourBalance: balanceRows[0]?.coin_balance ?? 0,
      theirConflicts,
      expiresAt: expiryFor(startsAt, now).toISOString(),
    },
  };
}

export async function listRequests(client, userId, familyId) {
  if (!await assertActiveMember(client, familyId, userId)) {
    return { error: { code: 403, message: 'Not a family member.' } };
  }
  const { rows } = await client.query(
    `SELECT r.*,
            COALESCE(rm.alias, ru.display_name) AS requester_name,
            COALESCE(om.alias, ou.display_name) AS requested_of_name
     FROM personal_time_requests r
     JOIN users ru ON ru.id = r.requester_id
     LEFT JOIN family_members rm ON rm.user_id = r.requester_id AND rm.family_id = r.family_id
     LEFT JOIN users ou ON ou.id = r.requested_of
     LEFT JOIN family_members om ON om.user_id = r.requested_of AND om.family_id = r.family_id
     WHERE r.family_id = $1
     ORDER BY r.starts_at ASC`,
    [familyId]
  );
  return { data: { requests: rows } };
}

export async function createRequest(client, userId, body, now = new Date()) {
  const {
    familyId, title, type, description = null,
    startsAt, endsAt, requestedOf = null,
    coverageNeeded = true, sweetenerCoins = 0,
  } = body;

  if (!await assertActiveMember(client, familyId, userId)) {
    return { error: { code: 403, message: 'Not a family member.' } };
  }
  if (!SELF_TYPES.includes(type)) {
    return { error: { code: 400, message: `type must be one of: ${SELF_TYPES.join(', ')}.` } };
  }
  const windowError = validateSelfWindow(startsAt, endsAt, now);
  if (windowError) return { error: { code: 400, message: windowError } };

  const yourConflicts = await conflictsFor(client, familyId, userId, startsAt, endsAt);
  if (yourConflicts.length) {
    return { error: { code: 409, message: `You already have "${yourConflicts[0]}" during this time.` } };
  }

  const caregivers = await activeCaregivers(client, familyId);
  const resolved = resolveCounterparty(caregivers, userId, requestedOf);
  if (resolved.error) return { error: { code: 400, message: resolved.error } };

  const minutes = (new Date(endsAt) - new Date(startsAt)) / MS_PER_MINUTE;
  const baseline = coverageNeeded ? priceCoverage(await baseRateFor(client, familyId), minutes) : 0;
  const sweetener = coverageNeeded ? Math.max(0, Math.trunc(Number(sweetenerCoins) || 0)) : 0;

  if (sweetener > 0) {
    const { rows } = await client.query(
      `SELECT coin_balance FROM family_members
       WHERE family_id = $1 AND user_id = $2 AND status = 'active' FOR UPDATE`,
      [familyId, userId]
    );
    if (!rows.length || rows[0].coin_balance < sweetener) {
      return { error: { code: 409, message: 'You do not have enough coins to sweeten this offer.' } };
    }
    // Escrowed now, exactly as offerBounty does, so the coins cannot be spent
    // twice while the request is outstanding.
    await client.query(
      'UPDATE family_members SET coin_balance = coin_balance - $1 WHERE family_id = $2 AND user_id = $3',
      [sweetener, familyId, userId]
    );
    await client.query(
      `INSERT INTO coin_ledger (family_id, user_id, amount, reason)
       VALUES ($1, $2, $3, 'coverage_sweetener_escrow')`,
      [familyId, userId, -sweetener]
    );
  }

  // Nobody has to answer a request that needs no coverage; it is recorded as
  // already settled, with responded_by NULL to show no one was asked to decide.
  const status = coverageNeeded ? 'pending' : 'accepted';

  const { rows } = await client.query(
    `INSERT INTO personal_time_requests
       (family_id, requester_id, requested_of, title, type, description,
        starts_at, ends_at, coverage_needed, baseline_coins, sweetener_coins,
        status, responded_at, expires_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7::timestamptz,$8::timestamptz,$9,$10,$11,$12,$13,$14::timestamptz)
     RETURNING *`,
    [
      familyId, userId, resolved.requestedOf, title.trim(), type, description,
      startsAt, endsAt, coverageNeeded, baseline, sweetener,
      status, coverageNeeded ? null : now.toISOString(),
      expiryFor(startsAt, now).toISOString(),
    ]
  );
  const request = rows[0];

  // With no coverage to negotiate the self activity is booked straight away.
  if (!coverageNeeded) {
    await insertSelfActivity(client, request);
  }

  const theirConflicts = resolved.requestedOf
    ? await conflictsFor(client, familyId, resolved.requestedOf, startsAt, endsAt)
    : [];

  return { data: request, warnings: theirConflicts };
}

async function insertSelfActivity(client, request, counterpartId = null) {
  const { rows } = await client.query(
    `INSERT INTO activities
       (family_id, created_by, assigned_to, title, category, type, description,
        starts_at, ends_at, duration_minutes, coin_value, status, is_template,
        personal_time_request_id, counterpart_activity_id)
     VALUES ($1,$2,$2,$3,'self',$4,$5,$6::timestamptz,$7::timestamptz,
             EXTRACT(EPOCH FROM ($7::timestamptz - $6::timestamptz))/60, 0, 'approved', false, $8, $9)
     RETURNING *`,
    [request.family_id, request.requester_id, request.title, request.type,
     request.description, request.starts_at, request.ends_at, request.id, counterpartId]
  );
  return rows[0];
}

export async function acceptRequest(client, userId, requestId, now = new Date()) {
  const { rows } = await client.query(
    'SELECT * FROM personal_time_requests WHERE id = $1 FOR UPDATE',
    [requestId]
  );
  if (!rows.length) return { error: { code: 404, message: 'Request not found.' } };
  const request = rows[0];

  if (!await assertActiveMember(client, request.family_id, userId)) {
    return { error: { code: 403, message: 'Not a family member.' } };
  }
  if (request.status !== 'pending') {
    return { error: { code: 409, message: `This request is already ${request.status}.` } };
  }
  if (new Date(request.expires_at) <= now) {
    return { error: { code: 409, message: 'This request has expired.' } };
  }
  if (Number(request.requester_id) === Number(userId)) {
    return { error: { code: 403, message: 'You cannot cover your own personal time.' } };
  }
  if (request.requested_of && Number(request.requested_of) !== Number(userId)) {
    return { error: { code: 403, message: 'This request was addressed to someone else.' } };
  }
  const caregivers = await activeCaregivers(client, request.family_id);
  if (!caregivers.some((c) => Number(c.user_id) === Number(userId))) {
    return { error: { code: 403, message: 'Only caregivers can cover.' } };
  }

  // Being away is the one thing that makes covering impossible; anything else in
  // their calendar is fine, because coverage nests (§4.1).
  const { rows: away } = await client.query(
    `SELECT title FROM absences
     WHERE user_id = $1 AND family_id = $2 AND start_time < $4 AND end_time > $3`,
    [userId, request.family_id, request.starts_at, request.ends_at]
  );
  if (away.length) {
    return { error: { code: 409, message: `You are away ("${away[0].title}") during this time.` } };
  }

  // The coverage shift is inserted directly rather than through
  // scheduleActivity: it is allowed to overlap whatever else they have on.
  const minutes = `EXTRACT(EPOCH FROM ($6::timestamptz - $5::timestamptz))/60`;
  const { rows: coverRows } = await client.query(
    `INSERT INTO activities
       (family_id, created_by, assigned_to, title, category, type, description,
        starts_at, ends_at, duration_minutes, coin_value, status, is_template,
        bounty_amount, bounty_offered_by, personal_time_request_id)
     VALUES ($1,$2,$3,$4,'care','coverage',$7,$5::timestamptz,$6::timestamptz,
             ${minutes}, $8, 'approved', false, $9, $2, $10)
     RETURNING *`,
    [request.family_id, request.requester_id, userId,
     `Covering for ${request.title}`, request.starts_at, request.ends_at,
     request.description, request.baseline_coins, request.sweetener_coins, request.id]
  );
  const coverage = coverRows[0];

  const self = await insertSelfActivity(client, request, coverage.id);
  await client.query(
    'UPDATE activities SET counterpart_activity_id = $1 WHERE id = $2',
    [self.id, coverage.id]
  );

  await client.query(
    `UPDATE personal_time_requests
     SET status = 'accepted', responded_by = $1, responded_at = $2::timestamptz
     WHERE id = $3`,
    [userId, now.toISOString(), request.id]
  );

  return { data: { accepted: true, selfActivityId: self.id, coverageActivityId: coverage.id }, request };
}

export async function declineRequest(client, userId, requestId, now = new Date()) {
  const { rows } = await client.query(
    'SELECT * FROM personal_time_requests WHERE id = $1 FOR UPDATE',
    [requestId]
  );
  if (!rows.length) return { error: { code: 404, message: 'Request not found.' } };
  const request = rows[0];

  if (!await assertActiveMember(client, request.family_id, userId)) {
    return { error: { code: 403, message: 'Not a family member.' } };
  }
  if (request.status !== 'pending') {
    return { error: { code: 409, message: `This request is already ${request.status}.` } };
  }
  if (Number(request.requester_id) === Number(userId)) {
    return { error: { code: 403, message: 'Withdraw your own request instead of declining it.' } };
  }
  if (request.requested_of && Number(request.requested_of) !== Number(userId)) {
    return { error: { code: 403, message: 'This request was addressed to someone else.' } };
  }

  await refundSweetener(client, request);
  await client.query(
    `UPDATE personal_time_requests
     SET status = 'declined', responded_by = $1, responded_at = $2::timestamptz
     WHERE id = $3`,
    [userId, now.toISOString(), request.id]
  );
  return { data: { declined: true }, request };
}

export async function cancelRequest(client, userId, requestId) {
  const { rows } = await client.query(
    'SELECT * FROM personal_time_requests WHERE id = $1 FOR UPDATE',
    [requestId]
  );
  if (!rows.length) return { error: { code: 404, message: 'Request not found.' } };
  const request = rows[0];

  if (Number(request.requester_id) !== Number(userId)) {
    return { error: { code: 403, message: 'Only the person who asked can withdraw a request.' } };
  }
  if (request.status !== 'pending') {
    return { error: { code: 409, message: `This request is already ${request.status}.` } };
  }

  await refundSweetener(client, request);
  await client.query(
    `UPDATE personal_time_requests SET status = 'cancelled' WHERE id = $1`,
    [request.id]
  );
  return { data: { cancelled: true }, request };
}
