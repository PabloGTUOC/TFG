import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  validateStarterTasks,
  insertStarterTasks,
} from '../src/db/defaultActivities.js';
import { createFamily } from '../src/services/familyService.js';

function capturingClient() {
  const calls = [];
  return {
    calls,
    async query(sql, params) {
      calls.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
      if (sql.includes('INSERT INTO families')) {
        return { rows: [{ id: 10, name: 'F', monthly_coin_budget: params?.[1] }], rowCount: 1 };
      }
      return { rows: [], rowCount: 0 };
    },
  };
}

const task = (over = {}) =>
  ({ title: 'Breakfast prep', type: 'household', durationMinutes: 30, isRecurrent: true, ...over });

// ─── validateStarterTasks ───────────────────────────────────────────────────

describe('validateStarterTasks', () => {
  test('accepts a well-formed list and an empty list', () => {
    assert.equal(validateStarterTasks([task(), task({ type: 'care' })]), null);
    assert.equal(validateStarterTasks([]), null);
  });

  test('isRecurrent is optional but must be boolean when present', () => {
    const { isRecurrent, ...noFlag } = task();
    assert.equal(validateStarterTasks([noFlag]), null);
    assert.match(validateStarterTasks([task({ isRecurrent: 'yes' })]), /isRecurrent/);
  });

  test('rejects non-arrays and oversized lists', () => {
    assert.match(validateStarterTasks('nope'), /must be an array/);
    assert.match(validateStarterTasks(Array.from({ length: 41 }, () => task())), /at most 40/);
  });

  test('rejects bad titles, categories and durations', () => {
    assert.match(validateStarterTasks([task({ title: '   ' })]), /title/);
    assert.match(validateStarterTasks([task({ title: 'x'.repeat(101) })]), /title/);
    assert.match(validateStarterTasks([task({ type: 'chores' })]), /type/);
    // The activities table requires duration_minutes >= 15.
    assert.match(validateStarterTasks([task({ durationMinutes: 10 })]), /durationMinutes/);
    assert.match(validateStarterTasks([task({ durationMinutes: 30.5 })]), /durationMinutes/);
    assert.match(validateStarterTasks([null]), /must be an object/);
  });

  test('reports the offending index', () => {
    assert.match(validateStarterTasks([task(), task({ type: 'bogus' })]), /starterTasks\[1\]/);
  });
});

// ─── insertStarterTasks ─────────────────────────────────────────────────────

describe('insertStarterTasks', () => {
  test('prices tasks with the same rule as user-created ones', async () => {
    const client = capturingClient();
    // budget 1440 → 2 coins/hour: 30 min → 1, 60 min → 2, 90 min → 3.
    await insertStarterTasks(client, 10, 1, [
      task({ durationMinutes: 30 }),
      task({ durationMinutes: 60 }),
      task({ durationMinutes: 90 }),
    ], 1440);
    const { params } = client.calls[0];
    assert.equal(params[5], 1);
    assert.equal(params[12], 2);
    assert.equal(params[19], 3);
  });

  test('floors coin value at 1 for tiny budgets', async () => {
    const client = capturingClient();
    await insertStarterTasks(client, 10, 1, [task({ durationMinutes: 15 })], 60);
    assert.equal(client.calls[0].params[5], 1);
  });

  test('seeds approved templates and defaults isRecurrent to false', async () => {
    const client = capturingClient();
    const { isRecurrent, ...noFlag } = task();
    await insertStarterTasks(client, 10, 7, [noFlag], 1000);
    const call = client.calls[0];
    assert.ok(call.sql.includes("'approved', true"));
    assert.equal(call.params[0], 10);          // family
    assert.equal(call.params[1], 7);           // creator
    assert.equal(call.params[2], 'Breakfast prep');
    assert.equal(call.params[6], false);       // isRecurrent default
  });

  test('writes nothing for an empty list', async () => {
    const client = capturingClient();
    await insertStarterTasks(client, 10, 1, [], 1000);
    assert.equal(client.calls.length, 0);
  });
});

// ─── createFamily branching ─────────────────────────────────────────────────

describe('createFamily starterTasks branching', () => {
  const user = { id: 1, display_name: 'Alice', email: 'alice@test.com' };
  const base = { name: 'Casa', caretakers: [], objectsOfCare: [] };
  const seeded = (client) =>
    client.calls.filter(c => c.sql.includes('INSERT INTO activities'));

  test('uses the client catalogue when starterTasks is provided', async () => {
    const client = capturingClient();
    await createFamily(client, user, { ...base, starterTasks: [task()] });
    const inserts = seeded(client);
    assert.equal(inserts.length, 1);
    assert.equal(inserts[0].params[2], 'Breakfast prep');
  });

  test('an empty array means start empty — no seeding at all', async () => {
    const client = capturingClient();
    await createFamily(client, user, { ...base, starterTasks: [] });
    assert.equal(seeded(client).length, 0);
  });

  test('omitting the field keeps the legacy English defaults', async () => {
    const client = capturingClient();
    await createFamily(client, user, base);
    const inserts = seeded(client);
    assert.equal(inserts.length, 1);
    assert.ok(inserts[0].params.includes('Breakfast prep')); // legacy catalogue
    assert.ok(inserts[0].params.length > 7 * 5);             // many rows
  });

  test('rejects an invalid catalogue with 400 before writing anything', async () => {
    const client = capturingClient();
    const result = await createFamily(client, user, {
      ...base, starterTasks: [task({ type: 'bogus' })],
    });
    assert.equal(result.error.code, 400);
    assert.equal(client.calls.length, 0);
  });
});
