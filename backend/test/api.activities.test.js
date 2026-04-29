import test from 'node:test';
import assert from 'node:assert';
import request from 'supertest';
import admin from 'firebase-admin';
import app from '../src/app.js';
import { pool } from '../src/db/pool.js';

test('API Integration - Activities', async (t) => {
  let familyId;
  let userId;

  t.before(async () => {
    // Clear test DB and set up test data
    await pool.query('TRUNCATE TABLE activities, actors, families, users CASCADE');

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

  await t.test('POST /api/activities creates an activity', async () => {
    const newActivity = {
      familyId,
      actorId: userId,
      category: 'care',
      title: 'Test Activity',
      description: 'Doing a test',
      durationMinutes: 60
    };

    const response = await request(app)
      .post('/api/activities')
      .set('Authorization', 'Bearer test-token')
      .send(newActivity);

    assert.strictEqual(response.status, 201, `Expected 201, got ${response.status}: ${JSON.stringify(response.body)}`);
    assert.strictEqual(response.body.activity.title, 'Test Activity');
    assert.strictEqual(response.body.activity.category, 'care');
    assert.ok(response.body.activity.id);
  });
});
