import test from 'node:test';
import assert from 'node:assert';
import request from 'supertest';
import app from '../src/app.js';

test('API Integration - Health Check', async (t) => {
  await t.test('GET /health returns 200 OK', async () => {
    const response = await request(app).get('/health');
    assert.strictEqual(response.status, 200);
    assert.deepStrictEqual(response.body, { status: 'ok', service: 'carecoins-backend' });
  });
});
