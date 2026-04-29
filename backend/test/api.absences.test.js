import test from 'node:test';
import assert from 'node:assert';
import request from 'supertest';
import app from '../src/app.js';
import { pool } from '../src/db/pool.js';

test('API Integration - Absences', async (t) => {
  let userId;
  let familyId;
  let absenceId;

  t.before(async () => {
    await pool.query('TRUNCATE TABLE absences, family_members, actors, families, users CASCADE');

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

  await t.test('POST /api/absences creates an absence', async () => {
    const res = await request(app)
      .post('/api/absences')
      .set('Authorization', 'Bearer test-token')
      .send({
        familyId,
        startTime: new Date().toISOString(),
        endTime: new Date(Date.now() + 86400000).toISOString(),
        title: 'Vacation'
      });

    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.absence.title, 'Vacation');
    absenceId = res.body.absence.id;
  });

  await t.test('GET /api/absences returns absences', async () => {
    const res = await request(app)
      .get(`/api/absences?familyId=${familyId}`)
      .set('Authorization', 'Bearer test-token');

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.absences.length, 1);
    assert.strictEqual(res.body.absences[0].id, absenceId);
  });

  await t.test('DELETE /api/absences/:id removes absence', async () => {
    const res = await request(app)
      .delete(`/api/absences/${absenceId}`)
      .set('Authorization', 'Bearer test-token');

    assert.strictEqual(res.status, 200);

    const getRes = await request(app)
      .get(`/api/absences?familyId=${familyId}`)
      .set('Authorization', 'Bearer test-token');
    
    assert.strictEqual(getRes.body.absences.length, 0);
  });
});
