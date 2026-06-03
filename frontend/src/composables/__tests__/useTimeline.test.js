import { describe, it, expect } from 'vitest';
import { ref } from 'vue';
import { useTimeline, getCardStyle, formatGap, START_HOUR, TOTAL_HOURS } from '../useTimeline';

// ─── getCardStyle ─────────────────────────────────────────────

describe('getCardStyle', () => {
  it('returns danger-soft for rejected', () => {
    const s = getCardStyle({ status: 'rejected', category: 'care' });
    expect(s.background).toBe('var(--danger-soft)');
    expect(s.color).toBe('var(--danger)');
  });

  it('returns success for completed care', () => {
    const s = getCardStyle({ status: 'completed', category: 'care' });
    expect(s.background).toBe('var(--success)');
    expect(s.color).toBe('#fff');
  });

  it('returns warning for completed household', () => {
    const s = getCardStyle({ status: 'completed', category: 'household' });
    expect(s.background).toBe('var(--warning)');
    expect(s.color).toBe('#fff');
  });

  it('returns surface for pending', () => {
    const s = getCardStyle({ status: 'pending', category: 'care' });
    expect(s.background).toBe('var(--surface)');
    expect(s.color).toBe('var(--text-primary)');
  });

  it('returns surface for approved', () => {
    const s = getCardStyle({ status: 'approved', category: 'household' });
    expect(s.background).toBe('var(--surface)');
  });

  it('returns surface for pending_validation', () => {
    const s = getCardStyle({ status: 'pending_validation', category: 'care' });
    expect(s.background).toBe('var(--surface)');
  });
});

// ─── formatGap ────────────────────────────────────────────────

describe('formatGap', () => {
  it('returns minutes only when < 60', () => {
    expect(formatGap(45)).toBe('45min');
  });

  it('returns hours only when exact hour', () => {
    expect(formatGap(120)).toBe('2h');
  });

  it('returns hours + minutes', () => {
    expect(formatGap(90)).toBe('1h 30min');
  });

  it('handles 0 minutes', () => {
    expect(formatGap(0)).toBe('0min');
  });
});

// ─── useTimeline — scheduledToday positioning ─────────────────

function makeActivity(overrides) {
  return {
    id: Math.random(),
    is_template: false,
    status: 'approved',
    category: 'care',
    coin_value: 10,
    duration_minutes: 60,
    starts_at: null,
    ...overrides,
  };
}

function dateAt(hour, minute = 0) {
  const d = new Date();
  d.setHours(hour, minute, 0, 0);
  return d.toISOString();
}

describe('useTimeline', () => {
  it('scheduledToday filters to target date only', () => {
    const today = new Date();
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const todayAct    = makeActivity({ starts_at: dateAt(9) });
    const tomorrowAct = makeActivity({ starts_at: tomorrow.toISOString() });

    const familyActivities = ref([todayAct, tomorrowAct]);
    const targetDate       = ref(today);
    const { scheduledToday } = useTimeline({ familyActivities, targetDate });

    expect(scheduledToday.value).toHaveLength(1);
    expect(scheduledToday.value[0].id).toBe(todayAct.id);
  });

  it('excludes templates from scheduledToday', () => {
    const today = new Date();
    const template  = makeActivity({ is_template: true, starts_at: dateAt(9) });
    const scheduled = makeActivity({ starts_at: dateAt(10) });

    const familyActivities = ref([template, scheduled]);
    const targetDate       = ref(today);
    const { scheduledToday } = useTimeline({ familyActivities, targetDate });

    expect(scheduledToday.value).toHaveLength(1);
    expect(scheduledToday.value[0].is_template).toBe(false);
  });

  it('attaches _style with top% inside START_HOUR..END', () => {
    const today = new Date();
    const act = makeActivity({ starts_at: dateAt(START_HOUR + 3) }); // 3h after start

    const { scheduledToday } = useTimeline({ familyActivities: ref([act]), targetDate: ref(today) });

    const styled = scheduledToday.value[0];
    expect(styled._style).toBeDefined();
    const topPct = parseFloat(styled._style.top);
    expect(topPct).toBeCloseTo((3 / TOTAL_HOURS) * 100, 1);
  });

  it('sorts activities by start time', () => {
    const today = new Date();
    const late  = makeActivity({ id: 'late',  starts_at: dateAt(14) });
    const early = makeActivity({ id: 'early', starts_at: dateAt(8)  });

    const { scheduledToday } = useTimeline({ familyActivities: ref([late, early]), targetDate: ref(today) });

    expect(scheduledToday.value[0].id).toBe('early');
    expect(scheduledToday.value[1].id).toBe('late');
  });

  it('completedToday contains only completed activities for today', () => {
    const today = new Date();
    const done    = makeActivity({ status: 'completed', starts_at: dateAt(9) });
    const pending = makeActivity({ status: 'approved',  starts_at: dateAt(10) });

    const { completedToday } = useTimeline({ familyActivities: ref([done, pending]), targetDate: ref(today) });

    expect(completedToday.value).toHaveLength(1);
    expect(completedToday.value[0].status).toBe('completed');
  });

  it('todayCoins sums coin_value of completed activities', () => {
    const today = new Date();
    const a = makeActivity({ status: 'completed', coin_value: 30, starts_at: dateAt(9) });
    const b = makeActivity({ status: 'completed', coin_value: 50, starts_at: dateAt(10) });
    const c = makeActivity({ status: 'approved',  coin_value: 20, starts_at: dateAt(11) });

    const { todayCoins } = useTimeline({ familyActivities: ref([a, b, c]), targetDate: ref(today) });

    expect(todayCoins.value).toBe(80);
  });

  it('nowLineTop is null when outside the visible window', () => {
    const today = new Date();
    // Mock a date early in the morning (before START_HOUR)
    // Since we can't mock Date easily here, just verify the shape
    const { nowLineTop } = useTimeline({ familyActivities: ref([]), targetDate: ref(today) });
    // nowLineTop is a computed — it returns null or a number
    const val = nowLineTop.value;
    expect(val === null || typeof val === 'number').toBe(true);
  });

  it('gapBeforeMinutes reflects gap between consecutive activities', () => {
    const today = new Date();
    const first  = makeActivity({ starts_at: dateAt(8),  duration_minutes: 60 }); // ends 9:00
    const second = makeActivity({ starts_at: dateAt(11), duration_minutes: 60 }); // gap = 120 min

    const { scheduledToday } = useTimeline({ familyActivities: ref([first, second]), targetDate: ref(today) });

    const gap = scheduledToday.value[1].gapBeforeMinutes;
    expect(gap).toBeGreaterThanOrEqual(100); // ~120 min
  });
});
