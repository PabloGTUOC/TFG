import test from 'node:test';
import assert from 'node:assert';
import request from 'supertest';
import app from '../src/app.js';
import { pool } from '../src/db/pool.js';

test('API Integration - Me', async (t) => {
  let userId;
  let familyId;

  t.before(async () => {
    await pool.query('TRUNCATE TABLE coin_ledger, login_history, activities, family_members, actors, families, users CASCADE');

    const userRes = await pool.query(`
      INSERT INTO users (firebase_uid, email, display_name) 
      VALUES ($1, $2, $3) RETURNING id
    `, ['test-user-123', 'test@example.com', 'Test User']);
    userId = userRes.rows[0].id;

    const famRes = await pool.query(`
      INSERT INTO families (name, created_by) 
      VALUES ($1, $2) RETURNING id
    `, ['Test Family', userId]);
    familyId = famRes.rows[0].id;

    await pool.query(`
      INSERT INTO family_members (family_id, user_id, role, status) 
      VALUES ($1, $2, 'main_caregiver', 'active')
    `, [familyId, userId]);
  });

  t.after(async () => {
    await pool.end();
  });

  await t.test('GET /api/me returns user profile and families', async () => {
    const res = await request(app)
      .get('/api/me')
      .set('Authorization', 'Bearer test-token');

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.user.email, 'test@example.com');
    assert.strictEqual(res.body.families.length, 1);
    assert.strictEqual(res.body.families[0].family_id, familyId);
  });

  await t.test('PATCH /api/me/profile updates the user display name', async () => {
    const res = await request(app)
      .patch('/api/me/profile')
      .set('Authorization', 'Bearer test-token')
      .send({ displayName: 'Updated Name' });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.user.display_name, 'Updated Name');
  });

  await t.test('POST /api/me/login-event records a login', async () => {
    const res = await request(app)
      .post('/api/me/login-event')
      .set('Authorization', 'Bearer test-token');

    assert.strictEqual(res.status, 200);
    assert.ok(res.body.eventId);
  });

  await t.test('GET /api/me/login-history returns recorded logins', async () => {
    const res = await request(app)
      .get('/api/me/login-history')
      .set('Authorization', 'Bearer test-token');

    assert.strictEqual(res.status, 200);
    assert.ok(res.body.loginHistory.length >= 1);
  });
});
