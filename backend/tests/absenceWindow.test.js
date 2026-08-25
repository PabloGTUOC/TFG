import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { validateAbsenceWindow, MIN_ABSENCE_HOURS } from '../src/services/absenceService.js';

const HOUR = 60 * 60 * 1000;
const base = Date.parse('2026-09-04T00:00:00.000Z');
const iso = (ms) => new Date(ms).toISOString();

describe('validateAbsenceWindow', () => {
  test('accepts exactly the minimum duration', () => {
    assert.equal(
      validateAbsenceWindow(iso(base), iso(base + MIN_ABSENCE_HOURS * HOUR)),
      null
    );
  });

  test('accepts a multi-day window', () => {
    assert.equal(validateAbsenceWindow(iso(base), iso(base + 72 * HOUR)), null);
  });

  test('rejects one minute under the minimum', () => {
    const err = validateAbsenceWindow(
      iso(base),
      iso(base + MIN_ABSENCE_HOURS * HOUR - 60 * 1000)
    );
    assert.match(err, /at least 24 hours/);
  });

  test('rejects the old default 09:00-17:00 window', () => {
    const err = validateAbsenceWindow('2026-09-04T09:00:00.000Z', '2026-09-04T17:00:00.000Z');
    assert.match(err, /whole days/);
  });

  test('rejects an end at or before the start, before checking duration', () => {
    assert.equal(
      validateAbsenceWindow(iso(base), iso(base)),
      'End time must be after start time.'
    );
    assert.equal(
      validateAbsenceWindow(iso(base), iso(base - HOUR)),
      'End time must be after start time.'
    );
  });

  test('rejects unparseable timestamps', () => {
    assert.match(validateAbsenceWindow('not-a-date', iso(base)), /valid date/);
    assert.match(validateAbsenceWindow(iso(base), undefined), /valid date/);
  });

  test('measures elapsed time, so a DST-shifted local day still passes', () => {
    // Europe/Madrid springs forward on 2026-03-29: local midnight to local
    // midnight is 23 h, but the client sends UTC instants a full 24 h apart.
    assert.equal(
      validateAbsenceWindow('2026-03-28T23:00:00.000Z', '2026-03-29T23:00:00.000Z'),
      null
    );
  });
});
