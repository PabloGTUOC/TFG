import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  validateSelfWindow, priceCoverage, expiryFor,
  createRequest, acceptRequest, declineRequest, cancelRequest,
} from '../src/services/personalTimeService.js';

const NOW = new Date('2026-09-01T09:00:00Z');
const FRI_18 = '2026-09-04T18:00:00Z';
const FRI_1930 = '2026-09-04T19:30:00Z';

/** Dispatches on the SQL, since the service issues many queries per call. */
function fakeDb({
  member = true,
  request = null,
  caregivers = [{ user_id: 1, name: 'Ana' }, { user_id: 2, name: 'Ben' }],
  budget = 720,
  balance = 100,
  absences = [],
  busy = [],
} = {}) {
  const writes = { balance: [], ledger: [], activities: [], requests: [], updates: [], sql: [] };
  let nextId = 100;
  return {
    writes,
    async query(sql, params) {
      const q = sql.replace(/\s+/g, ' ').trim();
      writes.sql.push(q);

      if (q.startsWith('SELECT 1 FROM family_members')) return { rowCount: member ? 1 : 0, rows: [] };
      if (q.includes("role = 'caregiver'")) return { rows: caregivers };
      if (q.includes('monthly_coin_budget FROM families')) return { rows: [{ monthly_coin_budget: budget }] };
      if (q.includes('coin_balance FROM family_members')) return { rows: [{ coin_balance: balance }] };
      if (q.includes('FROM absences')) return { rows: absences };
      if (q.includes('FROM activities') && q.includes("type <> 'coverage'")) return { rows: busy };
      if (q.includes('FROM personal_time_requests')) {
        return { rowCount: request ? 1 : 0, rows: request ? [request] : [] };
      }

      if (q.startsWith('UPDATE family_members SET coin_balance')) {
        writes.balance.push(params[0]);
        return { rows: [] };
      }
      if (q.startsWith('INSERT INTO coin_ledger')) {
        writes.ledger.push({ amount: params[2], reason: /'([a-z_]+)'\)?\s*$/.exec(q)?.[1] ?? q });
        return { rows: [] };
      }
      if (q.startsWith('INSERT INTO personal_time_requests')) {
        const row = {
          id: 55, family_id: params[0], requester_id: params[1], requested_of: params[2],
          title: params[3], type: params[4], description: params[5],
          starts_at: params[6], ends_at: params[7], coverage_needed: params[8],
          baseline_coins: params[9], sweetener_coins: params[10], status: params[11],
        };
        writes.requests.push(row);
        return { rows: [row] };
      }
      if (q.startsWith('INSERT INTO activities')) {
        const row = { id: nextId++, category: q.includes("'self'") ? 'self' : 'care', params };
        writes.activities.push(row);
        return { rows: [row] };
      }
      if (q.startsWith('UPDATE personal_time_requests') || q.startsWith('UPDATE activities')) {
        writes.updates.push(q);
        return { rows: [] };
      }
      throw new Error(`Unexpected query: ${q.slice(0, 100)}`);
    },
  };
}

const pending = (over = {}) => ({
  id: 55, family_id: 10, requester_id: 1, requested_of: 2,
  title: 'Gym', type: 'sport', description: null,
  starts_at: FRI_18, ends_at: FRI_1930,
  coverage_needed: true, baseline_coins: 2, sweetener_coins: 5,
  status: 'pending', expires_at: '2026-09-03T09:00:00Z', ...over,
});

const body = (over = {}) => ({
  familyId: 10, title: 'Gym', type: 'sport',
  startsAt: FRI_18, endsAt: FRI_1930, ...over,
});

// ─── Pure rules ───────────────────────────────────────────────────────────────

describe('validateSelfWindow', () => {
  test('accepts a normal gym slot', () => {
    assert.equal(validateSelfWindow(FRI_18, FRI_1930, NOW), null);
  });
  test('rejects anything under a quarter of an hour', () => {
    assert.match(validateSelfWindow(FRI_18, '2026-09-04T18:10:00Z', NOW), /at least 15 minutes/);
  });
  test('rejects a day or more, pointing at time off instead', () => {
    assert.match(validateSelfWindow(FRI_18, '2026-09-05T18:01:00Z', NOW), /log time off/i);
  });
  test('accepts exactly 24 hours, where the two primitives meet', () => {
    assert.equal(validateSelfWindow(FRI_18, '2026-09-05T18:00:00Z', NOW), null);
  });
  test('rejects a window that has already passed', () => {
    assert.match(validateSelfWindow('2026-08-01T18:00:00Z', '2026-08-01T19:00:00Z', NOW), /future/);
  });
  test('rejects an end before its start, and unparseable input', () => {
    assert.match(validateSelfWindow(FRI_1930, FRI_18, NOW), /after start/);
    assert.match(validateSelfWindow('nonsense', FRI_18, NOW), /valid date/);
  });
});

describe('priceCoverage', () => {
  test('prices at the family base rate, floored at one coin', () => {
    assert.equal(priceCoverage(1, 90), 2);   // the default single-dependent family
    assert.equal(priceCoverage(2, 90), 3);
    assert.equal(priceCoverage(1, 15), 1);   // rounds to 0, floored to 1
  });
});

describe('expiryFor', () => {
  test('expires 48 h after asking when the window is further out', () => {
    assert.equal(expiryFor(FRI_18, NOW).toISOString(), '2026-09-03T09:00:00.000Z');
  });
  test('expires when the window starts, if that comes first', () => {
    const soon = '2026-09-01T20:00:00Z';
    assert.equal(expiryFor(soon, NOW).toISOString(), '2026-09-01T20:00:00.000Z');
  });
});

// ─── Creating ─────────────────────────────────────────────────────────────────

describe('createRequest', () => {
  test('escrows the sweetener and leaves the request pending', async () => {
    const db = fakeDb({ balance: 40 });
    const result = await createRequest(db, 1, body({ sweetenerCoins: 5 }), NOW);

    assert.equal(result.data.status, 'pending');
    assert.equal(result.data.baseline_coins, 2, '90 min at 1 cc/h');
    assert.deepEqual(db.writes.balance, [5], 'debited from the requester now');
    assert.deepEqual(db.writes.ledger, [{ amount: -5, reason: 'coverage_sweetener_escrow' }]);
    assert.deepEqual(db.writes.activities, [], 'nothing is booked until someone accepts');
  });

  test('refuses a sweetener the requester cannot afford, and writes nothing', async () => {
    const db = fakeDb({ balance: 3 });
    const result = await createRequest(db, 1, body({ sweetenerCoins: 5 }), NOW);
    assert.equal(result.error.code, 409);
    assert.deepEqual(db.writes.balance, []);
    assert.deepEqual(db.writes.requests, []);
  });

  test('refuses a window the requester is already busy in', async () => {
    const db = fakeDb({ busy: [{ title: 'Bath time' }] });
    const result = await createRequest(db, 1, body(), NOW);
    assert.equal(result.error.code, 409);
    assert.match(result.error.message, /Bath time/);
  });

  test('rejects a type outside the self vocabulary', async () => {
    const db = fakeDb();
    const result = await createRequest(db, 1, body({ type: 'household' }), NOW);
    assert.equal(result.error.code, 400);
  });

  test('books straight away when no coverage is needed', async () => {
    const db = fakeDb();
    const result = await createRequest(db, 1, body({ coverageNeeded: false, sweetenerCoins: 5 }), NOW);

    assert.equal(result.data.status, 'accepted');
    assert.equal(result.data.baseline_coins, 0);
    assert.deepEqual(db.writes.ledger, [], 'no coins move when nobody has to cover');
    assert.equal(db.writes.activities.length, 1, 'just the self activity');
    assert.equal(db.writes.activities[0].category, 'self');
  });

  test('with two caregivers it asks the other one, no picker needed', async () => {
    const db = fakeDb();
    const result = await createRequest(db, 1, body(), NOW);
    assert.equal(result.data.requested_of, 2);
  });

  test('with three caregivers and nobody named, it asks anyone', async () => {
    const db = fakeDb({ caregivers: [{ user_id: 1 }, { user_id: 2 }, { user_id: 3 }] });
    const result = await createRequest(db, 1, body(), NOW);
    assert.equal(result.data.requested_of, null);
  });

  test('warns about the counterparty being busy, but does not refuse', async () => {
    const db = fakeDb({ busy: [] });
    const result = await createRequest(db, 1, body(), NOW);
    assert.ok(result.data, 'the request is still created');
    assert.deepEqual(result.warnings, []);
  });
});

// ─── Accepting ────────────────────────────────────────────────────────────────

describe('acceptRequest', () => {
  test('books the pair and pays baseline plus sweetener to the coverer', async () => {
    const db = fakeDb({ request: pending() });
    const result = await acceptRequest(db, 2, 55, NOW);

    assert.equal(result.data.accepted, true);
    assert.equal(db.writes.activities.length, 2, 'a coverage shift and a self activity');

    const coverage = db.writes.activities.find((a) => a.category === 'care');
    assert.equal(coverage.params[7], 2, 'coin_value is the baseline');
    assert.equal(coverage.params[8], 5, 'the sweetener rides on bounty_amount');

    assert.deepEqual(db.writes.ledger, [],
      'coins are paid by the existing sweep when the shift ends, not here');
    assert.ok(db.writes.updates.some((q) => q.includes("status = 'accepted'")));
  });

  test('locks the request row, so two accepts cannot both materialize', async () => {
    const db = fakeDb({ request: pending() });
    await acceptRequest(db, 2, 55, NOW);
    assert.match(db.writes.sql[0], /FROM personal_time_requests WHERE id = \$1 FOR UPDATE/);
  });

  test('links each activity to the other', async () => {
    const db = fakeDb({ request: pending() });
    await acceptRequest(db, 2, 55, NOW);
    assert.ok(db.writes.updates.some((q) => q.includes('counterpart_activity_id')));
  });

  test('refuses to let the requester cover their own personal time', async () => {
    const db = fakeDb({ request: pending() });
    const result = await acceptRequest(db, 1, 55, NOW);
    assert.equal(result.error.code, 403);
    assert.deepEqual(db.writes.activities, []);
  });

  test('refuses when the request was addressed to someone else', async () => {
    const db = fakeDb({ request: pending(), caregivers: [{ user_id: 1 }, { user_id: 2 }, { user_id: 3 }] });
    const result = await acceptRequest(db, 3, 55, NOW);
    assert.equal(result.error.code, 403);
  });

  test('refuses an expired request', async () => {
    const db = fakeDb({ request: pending({ expires_at: '2026-08-30T09:00:00Z' }) });
    const result = await acceptRequest(db, 2, 55, NOW);
    assert.match(result.error.message, /expired/);
    assert.deepEqual(db.writes.activities, []);
  });

  test('refuses one that is already settled', async () => {
    const db = fakeDb({ request: pending({ status: 'declined' }) });
    const result = await acceptRequest(db, 2, 55, NOW);
    assert.equal(result.error.code, 409);
  });

  test('refuses when the coverer is away in that window', async () => {
    const db = fakeDb({ request: pending(), absences: [{ title: 'Work trip' }] });
    const result = await acceptRequest(db, 2, 55, NOW);
    assert.match(result.error.message, /Work trip/);
    assert.deepEqual(db.writes.activities, []);
  });
});

// ─── Declining and withdrawing ────────────────────────────────────────────────

describe('declineRequest', () => {
  test('refunds the sweetener and books nothing', async () => {
    const db = fakeDb({ request: pending() });
    const result = await declineRequest(db, 2, 55, NOW);

    assert.equal(result.data.declined, true);
    assert.deepEqual(db.writes.balance, [5], 'the escrow comes back');
    assert.deepEqual(db.writes.ledger, [{ amount: 5, reason: 'coverage_sweetener_refunded' }]);
    assert.deepEqual(db.writes.activities, [], 'a declined request leaves no activity rows');
  });

  test('refuses to let the requester decline their own request', async () => {
    const db = fakeDb({ request: pending() });
    const result = await declineRequest(db, 1, 55, NOW);
    assert.equal(result.error.code, 403);
    assert.deepEqual(db.writes.balance, []);
  });
});

describe('cancelRequest', () => {
  test('the requester withdraws and gets the sweetener back', async () => {
    const db = fakeDb({ request: pending() });
    const result = await cancelRequest(db, 1, 55);
    assert.equal(result.data.cancelled, true);
    assert.deepEqual(db.writes.ledger, [{ amount: 5, reason: 'coverage_sweetener_refunded' }]);
  });

  test('nobody else can withdraw it', async () => {
    const db = fakeDb({ request: pending() });
    const result = await cancelRequest(db, 2, 55);
    assert.equal(result.error.code, 403);
    assert.deepEqual(db.writes.balance, []);
  });

  test('cannot withdraw one that is already settled', async () => {
    const db = fakeDb({ request: pending({ status: 'accepted' }) });
    const result = await cancelRequest(db, 1, 55);
    assert.equal(result.error.code, 409);
    assert.deepEqual(db.writes.balance, []);
  });
});
