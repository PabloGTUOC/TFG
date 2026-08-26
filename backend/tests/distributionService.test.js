import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  runMonthlyDistribution,
  presentHours,
  distributionShares,
} from '../src/services/distributionService.js';

/**
 * Dispatches on the SQL rather than on call order: the service loops once per
 * elapsed month, so a positional mock would encode the loop rather than the
 * behaviour.
 */
function fakeDb({ lastMonth, actors = [], explicit = {}, caretakers = [], absences = [] }) {
  const writes = { credits: [], ledger: [], clock: [], sql: [] };
  const client = {
    writes,
    async query(sql, params) {
      const q = sql.replace(/\s+/g, ' ').trim();
      writes.sql.push(q);
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
      if (q.includes('FROM absences')) return { rows: absences };
      if (q.startsWith('UPDATE family_members SET coin_balance')) {
        writes.credits.push({ amount: params[0], id: params[1] });
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
    assert.deepEqual(db.writes.credits, [
      { amount: 272, id: 11 },
      { amount: 272, id: 22 },
    ]); // (744-200)/2 each — nobody was away, so this is the old even split
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
    assert.equal(db.writes.credits[1].amount, 371);
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
    assert.deepEqual(db.writes.credits.map(c => c.amount), [360, 360, 372, 372]);
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

// ── Presence weighting (docs/personal-time-plan.md §3.1) ─────────────────────

const JUL_START = Date.UTC(2026, 6, 1);   // July 2026: 31 days = 744 h
const JUL_END = Date.UTC(2026, 7, 1);
const away = (from, to) => ({ start: Date.parse(from), end: Date.parse(to) });

describe('presentHours', () => {
  test('a caregiver who was never away was present all month', () => {
    assert.equal(presentHours(JUL_START, JUL_END, JUL_START, []), 744);
  });

  test('subtracts the hours spent away', () => {
    const hours = presentHours(JUL_START, JUL_END, JUL_START, [
      away('2026-07-10T00:00:00Z', '2026-07-13T00:00:00Z'), // 72 h
    ]);
    assert.equal(hours, 672);
  });

  test('merges overlapping absences instead of summing them', () => {
    // 1st-5th and 3rd-8th is seven days away, not nine.
    const hours = presentHours(JUL_START, JUL_END, JUL_START, [
      away('2026-07-01T00:00:00Z', '2026-07-05T00:00:00Z'),
      away('2026-07-03T00:00:00Z', '2026-07-08T00:00:00Z'),
    ]);
    assert.equal(hours, 744 - 168);
  });

  test('handles one absence entirely inside another', () => {
    const hours = presentHours(JUL_START, JUL_END, JUL_START, [
      away('2026-07-01T00:00:00Z', '2026-07-10T00:00:00Z'),
      away('2026-07-03T00:00:00Z', '2026-07-05T00:00:00Z'),
    ]);
    assert.equal(hours, 744 - 216);
  });

  test('clips an absence that straddles the month boundary', () => {
    const hours = presentHours(JUL_START, JUL_END, JUL_START, [
      away('2026-06-28T00:00:00Z', '2026-07-03T00:00:00Z'), // only 48 h fall in July
    ]);
    assert.equal(hours, 696);
  });

  test('ignores an absence in a different month', () => {
    const hours = presentHours(JUL_START, JUL_END, JUL_START, [
      away('2026-05-01T00:00:00Z', '2026-05-09T00:00:00Z'),
    ]);
    assert.equal(hours, 744);
  });

  test('counts a mid-month joiner only from the day they joined', () => {
    const joined = Date.parse('2026-07-16T00:00:00Z');
    assert.equal(presentHours(JUL_START, JUL_END, joined, []), 384);
  });

  test('a caregiver who joined after the month was never present', () => {
    const joined = Date.parse('2026-08-20T00:00:00Z');
    assert.equal(presentHours(JUL_START, JUL_END, joined, []), 0);
  });

  test('away for the whole month is zero, never negative', () => {
    const hours = presentHours(JUL_START, JUL_END, JUL_START, [
      away('2026-06-01T00:00:00Z', '2026-09-01T00:00:00Z'),
    ]);
    assert.equal(hours, 0);
  });
});

describe('distributionShares', () => {
  test('equal presence reproduces the even split exactly', () => {
    assert.deepEqual(distributionShares(544, [744, 744]), [272, 272]);
  });

  test('never hands out more than there is', () => {
    for (const unclaimed of [0, 1, 7, 543, 544, 1000]) {
      for (const weights of [[744, 744], [672, 744], [1, 2, 3], [744]]) {
        const shares = distributionShares(unclaimed, weights);
        const total = shares.reduce((a, b) => a + b, 0);
        assert.ok(total <= unclaimed, `${total} > ${unclaimed}`);
        assert.ok(unclaimed - total < weights.length, 'lost more than rounding');
      }
    }
  });

  test('falls back to an even split when nobody was present', () => {
    assert.deepEqual(distributionShares(544, [0, 0]), [272, 272]);
  });

  test('a lone caregiver takes the whole remainder', () => {
    assert.deepEqual(distributionShares(700, [744]), [700]);
  });

  test('a caregiver present for none of the month gets nothing', () => {
    assert.deepEqual(distributionShares(544, [0, 744]), [0, 544]);
  });

  test('nothing to split means nothing is written', () => {
    assert.deepEqual(distributionShares(0, [744, 744]), [0, 0]);
    assert.deepEqual(distributionShares(544, []), []);
  });
});

describe('runMonthlyDistribution with absences', () => {
  test("the traveller's share goes to whoever was home", async () => {
    const db = fakeDb({
      lastMonth: '2026-07',
      actors: fullTime,
      explicit: { '2026-07': 200 },   // unclaimed 544
      caretakers: twoCaregivers,
      absences: [
        { user_id: 1, start_time: '2026-07-10T00:00:00Z', end_time: '2026-07-13T00:00:00Z' },
      ],
    });
    await runMonthlyDistribution(db, 1, AUG);

    const [traveller, home] = db.writes.credits;
    assert.equal(traveller.amount, 258, 'three days away costs the traveller 14 coins');
    assert.equal(home.amount, 285, 'and the caretaker who stayed gains them');
    assert.ok(traveller.amount + home.amount <= 544, 'no coin is invented');
    assert.deepEqual(db.writes.ledger.map(l => l.reason),
      ['monthly_distribution', 'monthly_distribution']);
  });

  test('a caregiver away all month is skipped entirely', async () => {
    const db = fakeDb({
      lastMonth: '2026-07',
      actors: fullTime,
      explicit: { '2026-07': 200 },
      caretakers: twoCaregivers,
      absences: [
        { user_id: 1, start_time: '2026-06-20T00:00:00Z', end_time: '2026-08-05T00:00:00Z' },
      ],
    });
    await runMonthlyDistribution(db, 1, AUG);

    assert.deepEqual(db.writes.credits, [{ amount: 544, id: 22 }]);
    assert.deepEqual(db.writes.ledger.map(l => l.userId), [2],
      'no zero-coin ledger row for the absent caregiver');
  });

  test('the whole family away falls back to the even split', async () => {
    const db = fakeDb({
      lastMonth: '2026-07',
      actors: fullTime,
      explicit: { '2026-07': 200 },
      caretakers: twoCaregivers,
      absences: [
        { user_id: 1, start_time: '2026-06-20T00:00:00Z', end_time: '2026-08-05T00:00:00Z' },
        { user_id: 2, start_time: '2026-06-20T00:00:00Z', end_time: '2026-08-05T00:00:00Z' },
      ],
    });
    await runMonthlyDistribution(db, 1, AUG);
    assert.deepEqual(db.writes.credits.map(c => c.amount), [272, 272],
      'the residual must not vanish because everyone happened to be away');
  });
});

describe('activity subclasses', () => {
  test('personal time is excluded from the claimed total', async () => {
    // A self activity is worth 0 coins, so it cannot move SUM(coin_value) — the
    // filter is what stops it being counted as work anywhere the row appears.
    const db = fakeDb({
      lastMonth: '2026-07',
      actors: fullTime,
      explicit: { '2026-07': 200 },
      caretakers: twoCaregivers,
    });
    await runMonthlyDistribution(db, 1, AUG);

    const claimed = db.writes.sql.find(q => q.includes('SUM(coin_value)'));
    assert.ok(claimed, 'the claimed-coins query should have run');
    assert.match(claimed, /category = 'care'/,
      'the GDP residual must count care work only, never personal time');
  });
});
