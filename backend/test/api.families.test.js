import test from 'node:test';
import assert from 'node:assert';
import request from 'supertest';
import app from '../src/app.js';
import { pool } from '../src/db/pool.js';

test('API Integration - Families', async (t) => {
  let userId;
  let familyId;

  t.before(async () => {
    await pool.query('TRUNCATE TABLE family_invitations, actors, family_members, families, users CASCADE');

    const userRes = await pool.query(`
      INSERT INTO users (firebase_uid, email, display_name) 
      VALUES ($1, $2, $3) RETURNING id
    `, ['test-user-123', 'test@example.com', 'Test User']);
    userId = userRes.rows[0].id;
  });

  t.after(async () => {
    await pool.end();
  });

  await t.test('POST /api/families creates a family', async () => {
    const newFamily = {
      name: 'Integration Family',
      mainCaretakerName: 'Super Caretaker',
      alias: 'Boss',
      objectsOfCare: [
        { name: 'Grandpa', type: 'elderly', careTime: 'part_time' }
      ]
    };

    const res = await request(app)
      .post('/api/families')
      .set('Authorization', 'Bearer test-token')
      .send(newFamily);

    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.family.name, 'Integration Family');
    assert.ok(res.body.family.id);
    familyId = res.body.family.id;
  });

  await t.test('GET /api/families returns my families', async () => {
    const res = await request(app)
      .get('/api/families')
      .set('Authorization', 'Bearer test-token');

    assert.strictEqual(res.status, 200);
    assert.ok(res.body.families.find(f => f.id === familyId));
  });

  await t.test('GET /api/families/search finds the new family', async () => {
    const res = await request(app)
      .get('/api/families/search?query=Integration')
      .set('Authorization', 'Bearer test-token');

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body[0].id, familyId);
  });

  await t.test('GET /api/families/:familyId/members returns members', async () => {
    const res = await request(app)
      .get(`/api/families/${familyId}/members`)
      .set('Authorization', 'Bearer test-token');

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.members[0].role, 'main_caregiver');
  });

  await t.test('POST /api/families/:familyId/actors adds an object of care', async () => {
    const res = await request(app)
      .post(`/api/families/${familyId}/actors`)
      .set('Authorization', 'Bearer test-token')
      .send({ name: 'Fluffy', actorType: 'pet', careTime: 'part_time' });

    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.name, 'Fluffy');
  });
});
