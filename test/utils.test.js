import test from 'node:test';
import assert from 'node:assert/strict';
import { computeDurationMinutes } from '../src/utils.js';

test('computeDurationMinutes returns duration in minutes', () => {
  const mins = computeDurationMinutes('2026-01-01T10:00:00.000Z', '2026-01-01T11:30:00.000Z');
  assert.equal(mins, 90);
});

test('computeDurationMinutes returns null for invalid date values', () => {
  const mins = computeDurationMinutes('invalid', '2026-01-01T11:30:00.000Z');
  assert.equal(mins, null);
});
