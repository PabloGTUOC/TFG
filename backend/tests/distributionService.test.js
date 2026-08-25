import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { runMonthlyDistribution } from '../src/services/distributionService.js';

/**
 * Dispatches on the SQL rather than on call order: the service loops once per
 * elapsed month, so a positional mock would encode the loop rather than the
 * behaviour.
 */
function fakeDb({ lastMonth, actors = [], explicit = {}, caretakers = [] }) {
  const writes = { credits: [], ledger: [], clock: [] };
  const client = {
    writes,
    async query(sql, params) {
      const q = sql.replace(/\s+/g, ' ').trim();
      if (q.startsWith('SELECT last_coin_distribution_month')) {
        return lastMonth === undefined
          ? { rowCount: 0, rows: [] }
          : { rowCount: 1, rows: [{ last_coin_distribution_month: lastMonth }] };
      }
      if (q.startsWith('UPDATE families SET last_coin_distribution_month')) {
        writes.clock.push(params[0]);
        return { rows: [] };
      }
      if (q.includes('FROM actors')) return { rows: actors };
      if (q.includes('SUM(coin_value)')) {
        return { rows: [{ total: explicit[params[1]] ?? 0 }] };
      }
      if (q.includes('FROM family_members WHERE family_id')) return { rows: caretakers };
      if (q.startsWith('UPDATE family_members SET coin_balance')) {
        writes.credits.push({ amount: params[0], ids: params[1] });
        return { rows: [] };
      }
      if (q.startsWith('INSERT INTO coin_ledger')) {
        writes.ledger.push({ userId: params[1], amount: params[2], reason: 'monthly_distribution' });
        return { rows: [] };
      }
      throw new Error(`Unexpected query: ${q.slice(0, 90)}`);
    },
  };
  return client;
}

const AUG = new Date('2026-08-15T10:00:00Z');
const fullTime = [{ care_time: 'full_time' }];
const twoCaregivers = [{ id: 11, user_id: 1 }, { id: 22, user_id: 2 }];

describe('runMonthlyDistribution', () => {
  test('returns false when the family does not exist', async () => {
    const db = fakeDb({ lastMonth: undefined });
    assert.equal(await runMonthlyDistribution(db, 1, AUG), false);
    assert.deepEqual(db.writes.ledger, []);
  });

  test('a family that never distributed just starts its clock', async () => {
    const db = fakeDb({ lastMonth: null, actors: fullTime, caretakers: twoCaregivers });
    assert.equal(await runMonthlyDistribution(db, 1, AUG), true);
    assert.deepEqual(db.writes.clock, ['2026-08']);
    assert.deepEqual(db.writes.ledger, [], 'must not back-pay every month since creation');
  });

  test('does nothing when already up to date', async () => {
    const db = fakeDb({ lastMonth: '2026-08', actors: fullTime, caretakers: twoCaregivers });
    assert.equal(await runMonthlyDistribution(db, 1, AUG), true);
    assert.deepEqual(db.writes.clock, []);
    assert.deepEqual(db.writes.ledger, []);
  });

  test('splits the unclaimed remainder evenly between caregivers', async () => {
    // July 2026 has 31 days → 744 h of GDP for one full-time dependent.
    const db = fakeDb({
      lastMonth: '2026-07',
      actors: fullTime,
      explicit: { '2026-07': 200 },
      caretakers: twoCaregivers,
    });
    await runMonthlyDistribution(db, 1, AUG);
    assert.deepEqual(db.writes.credits, [{ amount: 272, ids: [11, 22] }]); // (744-200)/2
    assert.deepEqual(db.writes.ledger.map(l => l.amount), [272, 272]);
    assert.deepEqual(db.writes.ledger.map(l => l.userId), [1, 2]);
  });

  test('a part-time dependent is worth half a month', async () => {
    const db = fakeDb({
      lastMonth: '2026-07',
      actors: [{ care_time: 'part_time' }],
      caretakers: twoCaregivers,
    });
    await runMonthlyDistribution(db, 1, AUG);
    assert.equal(db.writes.credits[0].amount, 186); // floor(744/2)/2
  });

  test('flooring leaves the rounding remainder unspent', async () => {
    const db = fakeDb({
      lastMonth: '2026-07',
      actors: fullTime,
      explicit: { '2026-07': 1 }, // unclaimed 743, odd
      caretakers: twoCaregivers,
    });
    await runMonthlyDistribution(db, 1, AUG);
    assert.equal(db.writes.credits[0].amount, 371);
    assert.equal(371 * 2, 742, 'one coin stays unspent rather than being invented');
  });

  test('credits nothing when activities claimed the whole month', async () => {
    const db = fakeDb({
      lastMonth: '2026-07',
      actors: fullTime,
      explicit: { '2026-07': 5000 },
      caretakers: twoCaregivers,
    });
    await runMonthlyDistribution(db, 1, AUG);
    assert.deepEqual(db.writes.ledger, []);
    assert.deepEqual(db.writes.clock, ['2026-08'], 'the clock still advances');
  });

  test('credits nothing when the family has no dependents', async () => {
    const db = fakeDb({ lastMonth: '2026-07', actors: [], caretakers: twoCaregivers });
    await runMonthlyDistribution(db, 1, AUG);
    assert.deepEqual(db.writes.ledger, []);
  });

  test('settles every elapsed month, in order, then advances the clock once', async () => {
    const db = fakeDb({
      lastMonth: '2026-05',
      actors: fullTime,
      explicit: { '2026-05': 744, '2026-06': 0, '2026-07': 0 },
      caretakers: twoCaregivers,
    });
    await runMonthlyDistribution(db, 1, AUG);
    // May fully claimed → nothing. June 30 d → 720/2 = 360. July 31 d → 744/2 = 372.
    assert.deepEqual(db.writes.credits.map(c => c.amount), [360, 372]);
    assert.deepEqual(db.writes.clock, ['2026-08']);
  });

  test('a lone caregiver takes the whole remainder', async () => {
    const db = fakeDb({
      lastMonth: '2026-07',
      actors: fullTime,
      explicit: { '2026-07': 44 },
      caretakers: [{ id: 11, user_id: 1 }],
    });
    await runMonthlyDistribution(db, 1, AUG);
    assert.equal(db.writes.credits[0].amount, 700);
  });
});
