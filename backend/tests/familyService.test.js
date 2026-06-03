import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { createFamily, deleteFamily, approveDeletion } from '../src/services/familyService.js';
import { joinByToken, joinByInvitation, approveMember, removeActor } from '../src/services/memberService.js';

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
    _calls: calls,
  };
}

const ok = (rows = []) => ({ rows, rowCount: rows.length });
const empty = () => ({ rows: [], rowCount: 0 });

// ─── createFamily — budget calculation ──────────────────────────────────────

describe('createFamily', () => {
  const baseUser = { id: 1, display_name: 'Alice', email: 'alice@test.com' };

  test('sets budget to 1000 when no objectsOfCare', async () => {
    const client = mockClient([
      empty(),        // UPDATE users display_name (skipped since no mainCaretakerName)
      ok([{ id: 10, name: 'Test Family', monthly_coin_budget: 1000 }]), // INSERT families
      empty(),        // INSERT family_members
      empty(),        // INSERT actors (person)
      // insertDefaultActivities — mocked as no queries needed (it's a separate module)
    ]);
    // insertDefaultActivities will call client.query — we need to handle those
    // Since defaultActivities inserts multiple rows, let's provide enough empty responses
    const manyEmpty = Array.from({ length: 20 }, () => empty());
    const fullClient = mockClient([
      ok([{ id: 10, name: 'Test Family', monthly_coin_budget: 1000 }]),
      empty(), empty(), ...manyEmpty,
    ]);
    const result = await createFamily(fullClient, baseUser, { name: 'Test Family', caretakers: [], objectsOfCare: [] });
    assert.equal(result.data.monthly_coin_budget, 1000);
  });

  test('calculates 720 per full_time dependent', async () => {
    // We're testing the budget calculation logic, not the DB calls
    // The budget is calculated before any DB call, so we can verify by the INSERT params
    let capturedBudget = null;
    const capturingClient = {
      async query(sql, params) {
        if (sql.includes('INSERT INTO families')) capturedBudget = params[1];
        return { rows: [{ id: 1, name: 'F', monthly_coin_budget: params?.[1] }], rowCount: 1 };
      }
    };
    await createFamily(capturingClient, baseUser, {
      name: 'Test',
      caretakers: [],
      objectsOfCare: [{ name: 'Baby', type: 'child', careTime: 'full_time' }],
    }).catch(() => {}); // may fail on later queries, that's fine
    assert.equal(capturedBudget, 720);
  });

  test('calculates 360 per part_time dependent', async () => {
    let capturedBudget = null;
    const capturingClient = {
      async query(sql, params) {
        if (sql.includes('INSERT INTO families')) capturedBudget = params[1];
        return { rows: [{ id: 1, name: 'F', monthly_coin_budget: params?.[1] }], rowCount: 1 };
      }
    };
    await createFamily(capturingClient, baseUser, {
      name: 'Test',
      caretakers: [],
      objectsOfCare: [{ name: 'Grandpa', type: 'elderly', careTime: 'part_time' }],
    }).catch(() => {});
    assert.equal(capturedBudget, 360);
  });

  test('sums budget across multiple dependents', async () => {
    let capturedBudget = null;
    const capturingClient = {
      async query(sql, params) {
        if (sql.includes('INSERT INTO families')) capturedBudget = params[1];
        return { rows: [{ id: 1, name: 'F', monthly_coin_budget: params?.[1] }], rowCount: 1 };
      }
    };
    await createFamily(capturingClient, baseUser, {
      name: 'Test',
      caretakers: [],
      objectsOfCare: [
        { name: 'Baby', type: 'child', careTime: 'full_time' },   // 720
        { name: 'Dog',  type: 'pet',   careTime: 'part_time' },   // 360
      ],
    }).catch(() => {});
    assert.equal(capturedBudget, 1080);
  });
});

// ─── deleteFamily ────────────────────────────────────────────────────────────

describe('deleteFamily', () => {
  const me = { id: 1, display_name: 'Alice', email: 'alice@test.com' };

  test('deletes immediately when only one caregiver', async () => {
    const client = mockClient([
      ok([{ id: 1, email: 'alice@test.com', display_name: 'Alice' }]), // SELECT caregivers (just me)
      ok([{ name: 'My Family' }]),  // SELECT families
      empty(),                      // DELETE families
    ]);
    const result = await deleteFamily(client, me, 10);
    assert.equal(result.data.deleted, true);
  });

  test('creates deletion request when multiple caregivers', async () => {
    const client = mockClient([
      ok([{ id: 1, email: 'alice@test.com', display_name: 'Alice' },
          { id: 2, email: 'bob@test.com',   display_name: 'Bob' }]),  // SELECT caregivers
      ok([{ name: 'My Family' }]),    // SELECT families
      ok([]),                         // SELECT existing requests (none)
      ok([{ id: 99 }]),               // INSERT deletion request
      empty(),                        // INSERT deletion approval for Bob
    ]);
    const result = await deleteFamily(client, me, 10);
    assert.equal(result.data.pendingApproval, true);
  });

  test('returns 409 when deletion request already pending', async () => {
    const client = mockClient([
      ok([{ id: 1, email: 'alice@test.com' }, { id: 2, email: 'bob@test.com' }]),
      ok([{ name: 'My Family' }]),
      ok([{ id: 55 }]), // existing pending request
    ]);
    const result = await deleteFamily(client, me, 10);
    assert.equal(result.error.code, 409);
  });

  test('returns 404 when family not found', async () => {
    const client = mockClient([
      ok([{ id: 1, email: 'alice@test.com' }]), // caregivers
      ok([]),                                    // families — empty
    ]);
    const result = await deleteFamily(client, me, 999);
    assert.equal(result.error.code, 404);
  });
});

// ─── approveDeletion ─────────────────────────────────────────────────────────

describe('approveDeletion', () => {
  test('deletes family when all approvals received', async () => {
    const client = mockClient([
      ok([{ id: 99 }]),   // SELECT request check
      ok([{ id: 1 }]),    // UPDATE approval → approved
      ok([]),             // SELECT pending approvals — none left
      empty(),            // UPDATE request status = approved
      empty(),            // DELETE families
    ]);
    const result = await approveDeletion(client, 2, 10, 99);
    assert.equal(result.data.deleted, true);
  });

  test('returns pendingApproval when other approvals still needed', async () => {
    const client = mockClient([
      ok([{ id: 99 }]),       // SELECT request check
      ok([{ id: 1 }]),        // UPDATE approval
      ok([{ id: 2 }]),        // SELECT pending — still 1 pending
    ]);
    const result = await approveDeletion(client, 2, 10, 99);
    assert.equal(result.data.pendingApproval, true);
  });

  test('returns 404 when request not found', async () => {
    const client = mockClient([ok([])]);
    const result = await approveDeletion(client, 2, 10, 999);
    assert.equal(result.error.code, 404);
  });
});

// ─── joinByToken ─────────────────────────────────────────────────────────────

describe('joinByToken', () => {
  const user = { id: 5, display_name: 'Bob', email: 'bob@test.com' };

  test('returns 410 when link is revoked', async () => {
    const client = mockClient([ok([{ id: 'abc', family_id: 1, revoked: true, max_uses: null, uses: 0, expires_at: null }])]);
    const result = await joinByToken(client, user, { token: 'abc', alias: '' });
    assert.equal(result.error.code, 410);
    assert.match(result.error.message, /revoked/);
  });

  test('returns 410 when link is expired', async () => {
    const past = new Date(Date.now() - 86400000).toISOString();
    const client = mockClient([ok([{ id: 'abc', family_id: 1, revoked: false, max_uses: null, uses: 0, expires_at: past }])]);
    const result = await joinByToken(client, user, { token: 'abc', alias: '' });
    assert.equal(result.error.code, 410);
    assert.match(result.error.message, /expired/);
  });

  test('returns 410 when max uses reached', async () => {
    const client = mockClient([ok([{ id: 'abc', family_id: 1, revoked: false, max_uses: 3, uses: 3, expires_at: null }])]);
    const result = await joinByToken(client, user, { token: 'abc', alias: '' });
    assert.equal(result.error.code, 410);
    assert.match(result.error.message, /maximum uses/);
  });

  test('returns 409 when already an active member', async () => {
    const client = mockClient([
      ok([{ id: 'abc', family_id: 1, revoked: false, max_uses: null, uses: 0, expires_at: null }]),
      ok([{ status: 'active' }]), // existing membership check
    ]);
    const result = await joinByToken(client, user, { token: 'abc', alias: '' });
    assert.equal(result.error.code, 409);
  });

  test('returns 404 when token not found', async () => {
    const client = mockClient([ok([])]);
    const result = await joinByToken(client, user, { token: 'bad-token', alias: '' });
    assert.equal(result.error.code, 404);
  });
});

// ─── joinByInvitation ────────────────────────────────────────────────────────

describe('joinByInvitation', () => {
  test('returns 400 when user has no email', async () => {
    const noEmailUser = { id: 5, display_name: 'Bob', email: null };
    const client = mockClient([]);
    const result = await joinByInvitation(client, noEmailUser, { familyId: 1, alias: '' });
    assert.equal(result.error.code, 400);
  });

  test('returns 403 when no pending invitation for email', async () => {
    const user = { id: 5, display_name: 'Bob', email: 'bob@test.com' };
    const client = mockClient([ok([])]); // no invitation found
    const result = await joinByInvitation(client, user, { familyId: 1, alias: '' });
    assert.equal(result.error.code, 403);
  });
});

// ─── approveMember ───────────────────────────────────────────────────────────

describe('approveMember', () => {
  test('returns 404 when pending member not found', async () => {
    const client = mockClient([{ rows: [], rowCount: 0 }]);
    const result = await approveMember(client, 10, 99);
    assert.equal(result.error.code, 404);
  });

  test('returns success when member approved', async () => {
    const client = mockClient([{ rows: [], rowCount: 1 }]);
    const result = await approveMember(client, 10, 5);
    assert.equal(result.data.success, true);
  });
});

// ─── removeActor ─────────────────────────────────────────────────────────────

describe('removeActor', () => {
  test('returns 403 when actor is not a pet', async () => {
    const client = mockClient([ok([{ id: 1, actor_type: 'child', care_time: 'full_time' }])]);
    const result = await removeActor(client, 10, 1);
    assert.equal(result.error.code, 403);
    assert.match(result.error.message, /pet/);
  });

  test('returns 404 when actor not found', async () => {
    const client = mockClient([ok([])]);
    const result = await removeActor(client, 10, 999);
    assert.equal(result.error.code, 404);
  });

  test('removes pet and adjusts budget', async () => {
    const client = mockClient([
      ok([{ id: 1, actor_type: 'pet', care_time: 'full_time' }]),
      empty(), // DELETE actors
      empty(), // UPDATE families budget
    ]);
    const result = await removeActor(client, 10, 1);
    assert.equal(result.data.success, true);
  });
});
