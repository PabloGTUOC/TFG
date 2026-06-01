import test from 'node:test';
import assert from 'node:assert';
import admin from 'firebase-admin';
import { pool } from './src/db/pool.js';
import { notifyUser, notifyFamilyCaregivers, notifyFamilyAll } from './src/utils/notify.js';

test('Notification Service - notifyUser', async (t) => {
  // Save originals
  const originalQuery = pool.query;
  const originalAppsDescriptor = Object.getOwnPropertyDescriptor(admin, 'apps');
  const originalMessagingDescriptor = Object.getOwnPropertyDescriptor(admin, 'messaging');

  t.after(() => {
    // Restore
    pool.query = originalQuery;
    if (originalAppsDescriptor) {
      Object.defineProperty(admin, 'apps', originalAppsDescriptor);
    }
    if (originalMessagingDescriptor) {
      Object.defineProperty(admin, 'messaging', originalMessagingDescriptor);
    }
  });

  // Mock admin.apps using defineProperty
  Object.defineProperty(admin, 'apps', {
    get: () => [{ name: 'mock-app' }],
    configurable: true
  });

  // Mocks
  let queryCount = 0;
  let queryParams = [];
  let deleteParams = [];
  let sentPayload = null;

  pool.query = async (text, params) => {
    queryCount++;
    queryParams.push({ text, params });
    if (text.includes('SELECT token')) {
      return { rows: [{ token: 'token-active' }, { token: 'token-stale' }] };
    }
    if (text.includes('DELETE FROM fcm_tokens')) {
      deleteParams = params[0];
      return { rowCount: 1 };
    }
    return { rows: [] };
  };

  // Mock admin.messaging using defineProperty
  Object.defineProperty(admin, 'messaging', {
    value: () => ({
      sendEachForMulticast: async (payload) => {
        sentPayload = payload;
        return {
          responses: [
            { success: true, messageId: '1' },
            { success: false, error: { code: 'messaging/invalid-registration-token' } }
          ]
        };
      }
    }),
    configurable: true
  });

  // Execute
  await notifyUser(42, { title: 'Test Title', body: 'Test Body' });

  // Assertions
  assert.strictEqual(queryCount, 2, 'Should execute select and delete queries');
  assert.deepEqual(queryParams[0].params, [42], 'Select query should target user 42');
  assert.deepEqual(sentPayload.tokens, ['token-active', 'token-stale'], 'Should send to both retrieved tokens');
  assert.strictEqual(sentPayload.notification.title, 'Test Title');
  assert.strictEqual(sentPayload.notification.body, 'Test Body');
  assert.deepEqual(deleteParams, ['token-stale'], 'Should prune the stale token');
});

test('Notification Service - notifyFamilyCaregivers', async (t) => {
  const originalQuery = pool.query;
  const originalAppsDescriptor = Object.getOwnPropertyDescriptor(admin, 'apps');
  const originalMessagingDescriptor = Object.getOwnPropertyDescriptor(admin, 'messaging');

  t.after(() => {
    pool.query = originalQuery;
    if (originalAppsDescriptor) {
      Object.defineProperty(admin, 'apps', originalAppsDescriptor);
    }
    if (originalMessagingDescriptor) {
      Object.defineProperty(admin, 'messaging', originalMessagingDescriptor);
    }
  });

  Object.defineProperty(admin, 'apps', {
    get: () => [{ name: 'mock-app' }],
    configurable: true
  });

  let queryParams = [];
  let sentTokens = [];

  pool.query = async (text, params) => {
    queryParams.push({ text, params });
    if (text.includes('SELECT DISTINCT')) {
      return { rows: [{ token: 'token-caregiver1' }, { token: 'token-caregiver2' }] };
    }
    return { rows: [] };
  };

  Object.defineProperty(admin, 'messaging', {
    value: () => ({
      sendEachForMulticast: async (payload) => {
        sentTokens = payload.tokens;
        return { responses: [{ success: true }, { success: true }] };
      }
    }),
    configurable: true
  });

  await notifyFamilyCaregivers(10, 42, { title: 'Alert', body: 'Caregiver action required' });

  assert.deepEqual(queryParams[0].params, [10, 42], 'Query parameters should match familyId and excluded user_id');
  assert.deepEqual(sentTokens, ['token-caregiver1', 'token-caregiver2'], 'Should send to fetched caregiver tokens');
});

test('Notification Service - notifyFamilyAll', async (t) => {
  const originalQuery = pool.query;
  const originalAppsDescriptor = Object.getOwnPropertyDescriptor(admin, 'apps');
  const originalMessagingDescriptor = Object.getOwnPropertyDescriptor(admin, 'messaging');

  t.after(() => {
    pool.query = originalQuery;
    if (originalAppsDescriptor) {
      Object.defineProperty(admin, 'apps', originalAppsDescriptor);
    }
    if (originalMessagingDescriptor) {
      Object.defineProperty(admin, 'messaging', originalMessagingDescriptor);
    }
  });

  Object.defineProperty(admin, 'apps', {
    get: () => [{ name: 'mock-app' }],
    configurable: true
  });

  let queryParams = [];
  let sentTokens = [];

  pool.query = async (text, params) => {
    queryParams.push({ text, params });
    if (text.includes('SELECT DISTINCT')) {
      return { rows: [{ token: 'token-member1' }, { token: 'token-member2' }] };
    }
    return { rows: [] };
  };

  Object.defineProperty(admin, 'messaging', {
    value: () => ({
      sendEachForMulticast: async (payload) => {
        sentTokens = payload.tokens;
        return { responses: [{ success: true }, { success: true }] };
      }
    }),
    configurable: true
  });

  await notifyFamilyAll(15, 99, { title: 'Broadcast', body: 'Important announcement' });

  assert.deepEqual(queryParams[0].params, [15, 99], 'Query parameters should match familyId and excluded user_id');
  assert.deepEqual(sentTokens, ['token-member1', 'token-member2'], 'Should send to fetched member tokens');
});
