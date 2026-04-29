import test from 'node:test';
import assert from 'node:assert';
import request from 'supertest';
import app from '../src/app.js';
import { pool } from '../src/db/pool.js';

test('API Integration - Marketplace', async (t) => {
  let userId;
  let familyId;
  let rewardId;

  t.before(async () => {
    await pool.query('TRUNCATE TABLE reward_redemptions, marketplace_rewards, family_members, families, users CASCADE');

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
      INSERT INTO family_members (family_id, user_id, role, status, coin_balance) 
      VALUES ($1, $2, 'main_caregiver', 'active', 500)
    `, [familyId, userId]);
  });

  t.after(async () => {
    await pool.end();
  });

  await t.test('POST /api/marketplace/rewards creates a reward', async () => {
    const res = await request(app)
      .post('/api/marketplace/rewards')
      .set('Authorization', 'Bearer test-token')
      .send({
        familyId,
        title: 'Movie Night',
        cost: 200,
        maxUses: 1
      });

    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.reward.title, 'Movie Night');
    rewardId = res.body.reward.id;
  });

  await t.test('GET /api/marketplace/rewards/:familyId returns active rewards', async () => {
    const res = await request(app)
      .get(`/api/marketplace/rewards/${familyId}`)
      .set('Authorization', 'Bearer test-token');

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.rewards.length, 1);
    assert.strictEqual(res.body.rewards[0].id, rewardId);
  });

  await t.test('POST /api/marketplace/rewards/:rewardId/redeem redeems a reward', async () => {
    const res = await request(app)
      .post(`/api/marketplace/rewards/${rewardId}/redeem`)
      .set('Authorization', 'Bearer test-token');

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.redeemed, true);
  });

  await t.test('POST /api/marketplace/rewards/:rewardId/redeem fails if sold out', async () => {
    const res = await request(app)
      .post(`/api/marketplace/rewards/${rewardId}/redeem`)
      .set('Authorization', 'Bearer test-token');

    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.error, 'Reward is sold out.');
  });
});
