import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { findRetentionCandidates, deleteRetainedFamily } from '../src/services/retentionService.js';

function mockClient(responses) {
  let idx = 0;
  const calls = [];
  return {
    async query(sql, params) {
      calls.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
      if (idx >= responses.length) throw new Error(`Unexpected query #${idx}: ${sql.trim().slice(0, 60)}`);
      const resp = responses[idx++];
      if (resp instanceof Error) throw resp;
      return resp;
    },
    _calls: calls,
  };
}

const ok = (rows = []) => ({ rows, rowCount: rows.length });
const empty = () => ({ rows: [], rowCount: 0 });

const candidateRow = {
  id: '3', name: 'Quiet Family', last_active_at: '2025-01-01T00:00:00Z',
  noticed_by: '7', noticed_at: '2026-06-01T00:00:00Z',
};

describe('findRetentionCandidates', () => {
  test('requires both inactivity and an aged notice, and maps explicitly', async () => {
    const client = mockClient([ok([candidateRow])]);
    const rows = await findRetentionCandidates(client, { inactiveDays: 365, noticeDays: 30 });
    assert.deepEqual(rows, [{
      id: 3, name: 'Quiet Family', lastActiveAt: '2025-01-01T00:00:00Z',
      noticedBy: 7, noticedAt: '2026-06-01T00:00:00Z',
    }]);
    const call = client._calls[0];
    assert.ok(call.sql.includes(`action = 'family.notify_inactive'`));
    assert.deepEqual(call.params, [365, 30]);
  });
});

describe('deleteRetainedFamily', () => {
  const candidate = {
    id: 3, name: 'Quiet Family', lastActiveAt: '2025-01-01T00:00:00Z',
    noticedBy: 7, noticedAt: '2026-06-01T00:00:00Z',
  };

  test('re-verifies inactivity in the DELETE and audits as the noticing admin', async () => {
    const client = mockClient([{ rows: [], rowCount: 1 }, empty()]);
    const result = await deleteRetainedFamily(client, candidate);
    assert.equal(result.data.deleted, true);
    assert.ok(client._calls[0].sql.includes('last_active_at < NOW()'));
    const audit = client._calls[1];
    assert.ok(audit.sql.includes('INSERT INTO admin_audit_log'));
    assert.equal(audit.params[0], 7);
    assert.equal(audit.params[1], 'family.retention_delete');
    assert.equal(audit.params[3], '3');
  });

  test('skips (409, no audit) when the family became active again', async () => {
    const client = mockClient([empty()]);
    const result = await deleteRetainedFamily(client, candidate);
    assert.equal(result.error.code, 409);
    assert.equal(client._calls.length, 1);
  });
});
