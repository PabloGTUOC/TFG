/**
 * Activity lifecycle integration tests.
 *
 * These tests use mock DB clients — no running database required.
 * They verify the core coin accounting logic for:
 *   - runAutoCompleteSweep
 *   - validate.js rules
 *   - rbac.js assertMemberRole
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { runAutoCompleteSweep } from '../src/db/autoComplete.js';
import { required, string, positiveInt, email, isoDate } from '../src/middleware/validate.js';
import { assertMemberRole } from '../src/middleware/rbac.js';

// ─── Mock DB client helper ────────────────────────────────────────────────────

function mockClient(queryMap) {
  // queryMap: array of { match: string|RegExp, rows: [] }
  const log = [];
  return {
    log,
    query: async (sql, params = []) => {
      log.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
      const entry = queryMap.find(e =>
        typeof e.match === 'string' ? sql.includes(e.match) : e.match.test(sql)
      );
      const rows = entry?.rows ?? [];
      return { rows, rowCount: rows.length };
    }
  };
}

// ─── runAutoCompleteSweep ─────────────────────────────────────────────────────

describe('runAutoCompleteSweep', () => {
  it('completes expired activities and awards coins', async () => {
    const expired = [
      { id: 10, assigned_to: 42, coin_value: 100 },
      { id: 11, assigned_to: 43, coin_value: 50 }
    ];

    const client = mockClient([
      { match: 'SELECT id, assigned_to', rows: expired }
    ]);

    await runAutoCompleteSweep(client, 1);

    // One SELECT + 3 writes per activity = 7 queries total
    assert.equal(client.log.length, 7);

    // Both activities should be marked completed
    const completions = client.log.filter(q => q.sql.includes("status = 'completed'"));
    assert.equal(completions.length, 2);
    assert.deepEqual(completions.map(q => q.params[0]), [10, 11]);

    // Coin balances updated
    const coinUpdates = client.log.filter(q => q.sql.includes('coin_balance = coin_balance +'));
    assert.equal(coinUpdates.length, 2);
    assert.equal(coinUpdates[0].params[0], 100);
    assert.equal(coinUpdates[1].params[0], 50);

    // Ledger entries written
    const ledgerInserts = client.log.filter(q =>
      q.sql.includes('INSERT INTO coin_ledger') && q.sql.includes('activity_completed')
    );
    assert.equal(ledgerInserts.length, 2);
  });

  it('does nothing when no activities have expired', async () => {
    const client = mockClient([
      { match: 'SELECT id, assigned_to', rows: [] }
    ]);

    await runAutoCompleteSweep(client, 1);

    // Only the SELECT query should have run
    assert.equal(client.log.length, 1);
    assert.ok(client.log[0].sql.includes('SELECT id, assigned_to'));
  });

  it('passes the correct familyId to the SELECT query', async () => {
    const client = mockClient([{ match: 'SELECT id, assigned_to', rows: [] }]);

    await runAutoCompleteSweep(client, 99);

    assert.equal(client.log[0].params[0], 99);
  });
});

// ─── Validation rules ─────────────────────────────────────────────────────────

describe('validate rules', () => {
  describe('required()', () => {
    const rule = required();
    it('passes when value is present', () => assert.equal(rule('hello'), null));
    it('fails on empty string', () => assert.ok(rule('')));
    it('fails on null', () => assert.ok(rule(null)));
    it('fails on undefined', () => assert.ok(rule(undefined)));
  });

  describe('string(min, max)', () => {
    const rule = string(2, 5);
    it('passes within range', () => assert.equal(rule('abc'), null));
    it('passes at min boundary', () => assert.equal(rule('ab'), null));
    it('passes at max boundary', () => assert.equal(rule('abcde'), null));
    it('fails below min', () => assert.ok(rule('a')));
    it('fails above max', () => assert.ok(rule('abcdef')));
    it('skips null (let required() handle that)', () => assert.equal(rule(null), null));
    it('fails on non-string', () => assert.ok(rule(123)));
  });

  describe('positiveInt()', () => {
    const rule = positiveInt();
    it('passes on positive integer', () => assert.equal(rule(5), null));
    it('passes on string integer', () => assert.equal(rule('10'), null));
    it('fails on zero', () => assert.ok(rule(0)));
    it('fails on negative', () => assert.ok(rule(-1)));
    it('fails on float', () => assert.ok(rule(1.5)));
    it('skips null', () => assert.equal(rule(null), null));
  });

  describe('email()', () => {
    const rule = email();
    it('passes valid email', () => assert.equal(rule('user@example.com'), null));
    it('fails missing @', () => assert.ok(rule('notanemail')));
    it('fails missing domain', () => assert.ok(rule('user@')));
    it('skips falsy values', () => assert.equal(rule(null), null));
  });

  describe('isoDate()', () => {
    const rule = isoDate();
    it('passes valid ISO string', () => assert.equal(rule('2026-03-26T10:00:00Z'), null));
    it('passes date-only string', () => assert.equal(rule('2026-03-26'), null));
    it('fails on garbage string', () => assert.ok(rule('not-a-date')));
    it('skips falsy values', () => assert.equal(rule(null), null));
  });
});

// ─── assertMemberRole ─────────────────────────────────────────────────────────

describe('assertMemberRole', () => {
  it('returns null when user meets the required role', async () => {
    const client = mockClient([
      { match: 'SELECT role FROM family_members', rows: [{ role: 'main_caregiver' }] }
    ]);

    const result = await assertMemberRole(client, 1, 10, 'main_caregiver');
    assert.equal(result, null);
  });

  it('returns null when user has a higher role than required', async () => {
    const client = mockClient([
      { match: 'SELECT role FROM family_members', rows: [{ role: 'main_caregiver' }] }
    ]);

    const result = await assertMemberRole(client, 1, 10, 'caregiver');
    assert.equal(result, null);
  });

  it('returns 403 error when user role is too low', async () => {
    const client = mockClient([
      { match: 'SELECT role FROM family_members', rows: [{ role: 'member' }] }
    ]);

    const result = await assertMemberRole(client, 1, 10, 'main_caregiver');
    assert.ok(result?.error);
    assert.equal(result.error.code, 403);
  });

  it('returns 403 error when user is not a member', async () => {
    const client = mockClient([
      { match: 'SELECT role FROM family_members', rows: [] }
    ]);

    const result = await assertMemberRole(client, 1, 10, 'caregiver');
    assert.ok(result?.error);
    assert.equal(result.error.code, 403);
  });

  it('queries with correct familyId and userId', async () => {
    const client = mockClient([
      { match: 'SELECT role FROM family_members', rows: [{ role: 'caregiver' }] }
    ]);

    await assertMemberRole(client, 7, 42, 'member');
    assert.deepEqual(client.log[0].params, [42, 7]);
  });
});
