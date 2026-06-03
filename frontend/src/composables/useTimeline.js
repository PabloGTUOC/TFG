import { ref, computed, nextTick } from 'vue';

export const START_HOUR  = 6;
export const TOTAL_HOURS = 18;

export function formatGap(minutes) {
  if (minutes < 60) return `${minutes}min`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m > 0 ? `${h}h ${m}min` : `${h}h`;
}

export function getCardStyle(activity) {
  if (activity.status === 'rejected') {
    return { background: 'var(--danger-soft)', color: 'var(--danger)', border: '1px solid var(--danger-soft)' };
  }
  if (activity.status === 'completed') {
    return { background: activity.category === 'care' ? 'var(--success)' : 'var(--warning)', color: '#fff' };
  }
  return { background: 'var(--surface)', color: 'var(--text-primary)', border: '1px solid var(--border)' };
}

export function useTimeline({ familyActivities, targetDate }) {
  const mobileTimelineRef = ref(null);

  const scheduledToday = computed(() => {
    let acts = familyActivities.value.filter(a => {
      if (a.is_template || !a.starts_at) return false;
      const d = new Date(a.starts_at);
      return d.getFullYear() === targetDate.value.getFullYear() &&
             d.getMonth()    === targetDate.value.getMonth() &&
             d.getDate()     === targetDate.value.getDate();
    });

    acts.sort((a, b) => {
      const tA = new Date(a.starts_at).getTime();
      const tB = new Date(b.starts_at).getTime();
      if (tA !== tB) return tA - tB;
      return (b.duration_minutes || 0) - (a.duration_minutes || 0);
    });

    const positioned = [];
    for (let i = 0; i < acts.length; i++) {
      const a = acts[i];
      const startA = new Date(a.starts_at).getTime();
      let overlapCount = 0;

      for (let j = 0; j < i; j++) {
        const b = positioned[j];
        const startB = new Date(b.starts_at).getTime();
        const durA = Math.max(a.duration_minutes || 0, 60);
        const durB = Math.max(b.duration_minutes || 0, 60);
        if (Math.max(startA, startB) < Math.min(startA + durA * 60000, startB + durB * 60000)) {
          overlapCount++;
        }
      }

      const d = new Date(a.starts_at);
      const hour = d.getHours() + d.getMinutes() / 60;
      const topP = ((Math.max(START_HOUR, hour) - START_HOUR) / TOTAL_HOURS) * 100;
      const visibleHours = Math.min((a.duration_minutes || 60) / 60, 24 - Math.max(START_HOUR, hour));
      const leftPx = 70 + (Math.min(overlapCount, 4) * 45);
      const shadowIntensity = 0.2 + (Math.min(overlapCount, 4) * 0.1);

      const prevEnd = i === 0
        ? new Date(d.getFullYear(), d.getMonth(), d.getDate(), START_HOUR, 0, 0).getTime()
        : new Date(positioned[i - 1].starts_at).getTime() + ((positioned[i - 1].duration_minutes || 0) * 60000);
      const gapBeforeMinutes = Math.max(0, Math.round((startA - prevEnd) / 60000));

      positioned.push({
        ...a,
        overlapCount,
        gapBeforeMinutes,
        _style: {
          position: 'absolute',
          top: `${topP}%`,
          left: `${leftPx}px`,
          width: `calc(100% - ${leftPx + 10}px)`,
          zIndex: 10 + overlapCount,
          boxShadow: overlapCount > 0
            ? `-5px 5px 15px rgba(0,0,0,${shadowIntensity})`
            : '0 4px 15px rgba(0,0,0,0.2)',
        },
      });
    }
    return positioned;
  });

  const completedToday = computed(() =>
    familyActivities.value.filter(a => {
      if (a.is_template || !a.starts_at || a.status !== 'completed') return false;
      const d = new Date(a.starts_at);
      return d.getFullYear() === targetDate.value.getFullYear() &&
             d.getMonth()    === targetDate.value.getMonth() &&
             d.getDate()     === targetDate.value.getDate();
    })
  );

  const todayCoins = computed(() =>
    completedToday.value.reduce((sum, a) => sum + (a.coin_value || 0), 0)
  );

  const nowLineTop = computed(() => {
    const now = new Date();
    const hour = now.getHours() + now.getMinutes() / 60;
    if (hour < START_HOUR || hour > START_HOUR + TOTAL_HOURS) return null;
    return ((hour - START_HOUR) / TOTAL_HOURS) * 100;
  });

  const nowIndex = computed(() => {
    const now = Date.now();
    return scheduledToday.value.findIndex(a => new Date(a.starts_at).getTime() > now);
  });

  const scrollToNow = () => {
    if (!mobileTimelineRef.value) return;
    const divider = mobileTimelineRef.value.querySelector('.tl-now-divider');
    if (divider) divider.scrollIntoView({ behavior: 'smooth', block: 'center' });
  };

  return { scheduledToday, completedToday, todayCoins, nowLineTop, nowIndex, mobileTimelineRef, scrollToNow };
}
