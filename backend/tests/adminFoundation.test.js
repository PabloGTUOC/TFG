import { test, describe, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import app from '../src/app.js';
import { pool } from '../src/db/pool.js';
import { checkPlatformAdmin, requireAdmin } from '../src/middleware/rbac.js';
import { logAdminAction } from '../src/services/adminService.js';

function mockClient(responses) {
  let idx = 0;
  const calls = [];
  return {
    async query(sql, params) {
      calls.push({ sql: sql.replace(/\s+/g, ' ').trim().slice(0, 80), params });
      if (idx >= responses.length) throw new Error(`Unexpected query #${idx}: ${sql.trim().slice(0, 60)}`);
      const resp = responses[idx++];
      if (resp instanceof Error) throw resp;
      return resp;
    },
    release() {},
    _calls: calls,
  };
}

const ok = (rows = []) => ({ rows, rowCount: rows.length });
const empty = () => ({ rows: [], rowCount: 0 });

const auth = { uid: 'fb-uid-1', email: 'admin@test.com', name: 'Admin' };
const userRow = { id: 1, firebase_uid: 'fb-uid-1', email: 'admin@test.com', display_name: 'Admin', avatar_url: null };

// ─── checkPlatformAdmin ─────────────────────────────────────────────────────

describe('checkPlatformAdmin', () => {
  test('returns user when platform_role is admin', async () => {
    const client = mockClient([
      ok([userRow]),                       // upsertUserFromAuth (UPDATE path)
      ok([{ platform_role: 'admin' }]),    // SELECT platform_role
    ]);
    const result = await checkPlatformAdmin(client, auth);
    assert.equal(result.error, undefined);
    assert.equal(result.user.id, 1);
  });

  test('returns 403 for a regular user', async () => {
    const client = mockClient([
      ok([userRow]),
      ok([{ platform_role: 'user' }]),
    ]);
    const result = await checkPlatformAdmin(client, auth);
    assert.equal(result.error.code, 403);
  });

  test('returns 403 when the user row is deleted/missing', async () => {
    const client = mockClient([
      ok([userRow]),
      empty(),                             // is_deleted = true filters the row out
    ]);
    const result = await checkPlatformAdmin(client, auth);
    assert.equal(result.error.code, 403);
  });
});

// ─── requireAdmin middleware ────────────────────────────────────────────────

describe('requireAdmin', () => {
  const realConnect = pool.connect;
  afterEach(() => { pool.connect = realConnect; });

  function run(client) {
    return new Promise((resolve) => {
      pool.connect = async () => client;
      const req = { auth };
      const res = {
        statusCode: 200,
        status(code) { this.statusCode = code; return this; },
        json(body) { resolve({ req, statusCode: this.statusCode, body, nextCalled: false }); },
      };
      requireAdmin(req, res, () => resolve({ req, statusCode: 200, body: null, nextCalled: true }));
    });
  }

  test('calls next and sets req.adminUser for an admin', async () => {
    const client = mockClient([ok([userRow]), ok([{ platform_role: 'admin' }])]);
    const result = await run(client);
    assert.equal(result.nextCalled, true);
    assert.equal(result.req.adminUser.id, 1);
  });

  test('responds 403 for a non-admin without calling next', async () => {
    const client = mockClient([ok([userRow]), ok([{ platform_role: 'user' }])]);
    const result = await run(client);
    assert.equal(result.nextCalled, false);
    assert.equal(result.statusCode, 403);
    assert.equal(result.body.error, 'Requires platform admin.');
  });

  test('responds 500 when the authorization query fails', async () => {
    const client = mockClient([new Error('db down')]);
    const result = await run(client);
    assert.equal(result.nextCalled, false);
    assert.equal(result.statusCode, 500);
  });
});

// ─── /api/admin over HTTP ───────────────────────────────────────────────────

describe('/api/admin routes', () => {
  test('rejects unauthenticated requests with 401 before any DB access', async () => {
    const res = await request(app).get('/api/admin/status');
    assert.equal(res.status, 401);
  });
});

// ─── logAdminAction ─────────────────────────────────────────────────────────

describe('logAdminAction', () => {
  test('writes one audit row with stringified target and payload', async () => {
    const client = mockClient([empty()]);
    await logAdminAction(client, 1, 'family.suspend', {
      targetType: 'family', targetId: 42, payload: { reason: 'test' },
    });
    assert.equal(client._calls.length, 1);
    assert.ok(client._calls[0].sql.includes('INSERT INTO admin_audit_log'));
    assert.deepEqual(client._calls[0].params, [1, 'family.suspend', 'family', '42', '{"reason":"test"}']);
  });

  test('defaults target and payload when omitted', async () => {
    const client = mockClient([empty()]);
    await logAdminAction(client, 1, 'plans.list');
    assert.deepEqual(client._calls[0].params, [1, 'plans.list', 'none', null, null]);
  });
});
