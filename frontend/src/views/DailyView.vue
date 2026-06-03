<script setup>
import { ref, computed, watch, onMounted, onUnmounted, nextTick } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { useFamilyStore } from '../stores/family';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import { useCurrentFamily } from '../composables/useCurrentFamily';

const appStore = useAuthStore();
const familyStore = useFamilyStore();
const route = useRoute();
const router = useRouter();

const closeDailyView = () => {
  router.push('/dashboard');
};

const onKeyDown = (e) => { if (e.key === 'Escape') closeDailyView(); };
onMounted(() => window.addEventListener('keydown', onKeyDown));
onUnmounted(() => window.removeEventListener('keydown', onKeyDown));

const targetDateStr = computed(() => route.params.date);
const targetDate = computed(() => {
  const [y, m, d] = targetDateStr.value.split('-');
  return new Date(y, m - 1, d);
});

const isToday = computed(() => new Date().toLocaleDateString() === targetDate.value.toLocaleDateString());
const scheduledTitle = computed(() => isToday.value ? 'Scheduled for Today' : `Schedule for ${targetDate.value.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`);

const navigateDay = (offset) => {
  const d = new Date(targetDate.value);
  d.setDate(d.getDate() + offset);
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  router.push(`/daily/${yyyy}-${mm}-${dd}`);
};

// ── Day-navigation swipe (container) ────────────────────────
let touchStartX = 0;
let touchStartY = 0;
let daySwipeActive = false;
const onTouchStart = (e) => {
  touchStartX = e.touches[0].clientX;
  touchStartY = e.touches[0].clientY;
  daySwipeActive = true;
};
const onTouchEnd = (e) => {
  if (!daySwipeActive) return;
  daySwipeActive = false;
  const dx = e.changedTouches[0].clientX - touchStartX;
  const dy = e.changedTouches[0].clientY - touchStartY;
  if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy) * 1.5) {
    navigateDay(dx < 0 ? 1 : -1);
  }
};

// ── Card swipe-to-delete ─────────────────────────────────────
const swipingId   = ref(null);
const swipeDeltaX = ref(0);
const dismissingIds = ref(new Set());
let cardTouchStartX = 0;
let cardTouchStartY = 0;
let cardSwipeActive = false;

const onCardTouchStart = (e, activity) => {
  if (activity.status === 'completed') return;
  daySwipeActive = false; // cancel day-nav so it doesn't fire on lift
  cardTouchStartX = e.touches[0].clientX;
  cardTouchStartY = e.touches[0].clientY;
  swipingId.value = activity.id;
  swipeDeltaX.value = 0;
  cardSwipeActive = false;
};

const onCardTouchMove = (e, activity) => {
  if (swipingId.value !== activity.id) return;
  const dx = e.touches[0].clientX - cardTouchStartX;
  const dy = e.touches[0].clientY - cardTouchStartY;
  if (!cardSwipeActive) {
    if (dx < -8 && Math.abs(dx) > Math.abs(dy)) {
      cardSwipeActive = true;
    } else if (Math.abs(dy) > 8) {
      swipingId.value = null; // vertical scroll — abandon
      return;
    } else {
      return;
    }
  }
  swipeDeltaX.value = Math.min(0, dx);
};

const onCardTouchEnd = (e, activity) => {
  if (swipingId.value !== activity.id) return;
  cardSwipeActive = false;
  if (swipeDeltaX.value < -80) {
    dismissingIds.value = new Set([...dismissingIds.value, activity.id]);
    swipingId.value = null;
    swipeDeltaX.value = 0;
    setTimeout(() => removeMobile(activity), 260);
  } else {
    swipeDeltaX.value = 0;
    swipingId.value = null;
  }
};

const familyActivities = ref([]);

const showScheduleModal = ref(false);
const scheduleForm = ref({ activityId: '', time: '' });

const scheduleHour = ref('06');
const scheduleMinute = ref('00');

const showRecurrenceModal = ref(false);
const recurrenceForm = ref({ activityId: '', title: '', frequency: 'daily', untilDate: '' });

const showDeleteModal = ref(false);
const deleteTarget = ref(null);

const absences = ref([]);
const showAbsenceModal = ref(false);
const isSubmittingAbsence = ref(false);
const absenceForm = ref({ title: '', startDate: '', startTime: '', endDate: '', endTime: '' });
const showAbsenceDetailModal = ref(false);
const selectedAbsence = ref(null);

const openAbsenceModal = () => {
  absenceForm.value = {
    title: '',
    startDate: targetDateStr.value,
    startTime: '09:00',
    endDate: targetDateStr.value,
    endTime: '17:00'
  };
  showAbsenceModal.value = true;
};

const confirmAbsence = async () => {
  if (!absenceForm.value.title || !absenceForm.value.startDate || !absenceForm.value.startTime || !absenceForm.value.endDate || !absenceForm.value.endTime) {
    appStore.setError("Please fill in all fields.");
    return;
  }

  isSubmittingAbsence.value = true;
  await appStore.runAction(async () => {
    await appStore.request('/api/absences', {
      method: 'POST',
      headers: appStore.authHeaders(),
      body: JSON.stringify({
        familyId: Number(familyId.value),
        title: absenceForm.value.title,
        startTime: new Date(`${absenceForm.value.startDate}T${absenceForm.value.startTime}`).toISOString(),
        endTime: new Date(`${absenceForm.value.endDate}T${absenceForm.value.endTime}`).toISOString()
      })
    });
    showAbsenceModal.value = false;
    await loadAbsences();
  }, "Time off logged successfully!");
  isSubmittingAbsence.value = false;
};

const openAbsenceDetail = (absence) => {
  selectedAbsence.value = absence;
  showAbsenceDetailModal.value = true;
};

const removeAbsence = async () => {
  if (!selectedAbsence.value) return;
  await appStore.runAction(async () => {
    await appStore.request(`/api/absences/${selectedAbsence.value.id}`, {
      method: 'DELETE',
      headers: appStore.authHeaders()
    });
    showAbsenceDetailModal.value = false;
    selectedAbsence.value = null;
    await loadAbsences();
    appStore.setSuccess('Time off record removed.');
  });
};

const loadAbsences = () => appStore.runAction(async () => {
  const fid = familyId.value;
  if (!fid) return;
  const data = await appStore.request(`/api/absences?familyId=${fid}`, { headers: appStore.authHeaders() });
  absences.value = data.absences || [];
});

const absencesToday = computed(() => {
  return absences.value.filter(a => {
    const start = new Date(a.start_time);
    const end = new Date(a.end_time);
    const target = targetDate.value;
    
    const dayStart = new Date(target.getFullYear(), target.getMonth(), target.getDate(), 0, 0, 0);
    const dayEnd = new Date(target.getFullYear(), target.getMonth(), target.getDate(), 23, 59, 59);
    
    return start <= dayEnd && end >= dayStart;
  });
});

const confirmDeleteSingle = async () => {
  await unSchedule(deleteTarget.value.id, false);
  showDeleteModal.value = false;
};

const confirmDeleteSeries = async () => {
  await unSchedule(deleteTarget.value.id, true);
  showDeleteModal.value = false;
};

const openRecurrenceModal = (activity) => {
  recurrenceForm.value.activityId = activity.id;
  recurrenceForm.value.title = activity.title;
  recurrenceForm.value.frequency = 'daily';

  const tmrw = new Date();
  tmrw.setDate(tmrw.getDate() + 1);
  recurrenceForm.value.untilDate = tmrw.toISOString().split('T')[0];
  showRecurrenceModal.value = true;
};

const confirmRecurrence = async () => {
  if (!recurrenceForm.value.untilDate) return;
  await appStore.runAction(async () => {
    const res = await appStore.request(`/api/activities/${recurrenceForm.value.activityId}/recurrence`, {
      method: 'POST',
      headers: appStore.authHeaders(),
      body: JSON.stringify({
        frequency: recurrenceForm.value.frequency,
        untilDate: recurrenceForm.value.untilDate
      })
    });
    showRecurrenceModal.value = false;
    await loadActivities();
    appStore.setSuccess(`Created ${res.created} future instances!`);
  }, 'Propagating scheduled activities...');
};

const showBountyModal = ref(false);
const bountyForm = ref({ activityId: '', title: '', amount: '' });

const openBountyModal = (activity) => {
  bountyForm.value.activityId = activity.id;
  bountyForm.value.title = activity.title;
  bountyForm.value.amount = '';
  showBountyModal.value = true;
};

const confirmBounty = async () => {
  if (!bountyForm.value.amount || bountyForm.value.amount <= 0) return;
  await appStore.runAction(async () => {
    await appStore.request(`/api/activities/${bountyForm.value.activityId}/bounty`, {
      method: 'POST',
      headers: appStore.authHeaders(),
      body: JSON.stringify({ bountyAmount: Number(bountyForm.value.amount) })
    });
    showBountyModal.value = false;
    await loadActivities();
    appStore.setSuccess('Bounty added! Another caretaker can now take this task.');
  });
};

const showAcceptBountyModal = ref(false);
const acceptBountyTarget = ref(null);

const openAcceptBountyModal = (activity) => {
  acceptBountyTarget.value = activity;
  showAcceptBountyModal.value = true;
};

const confirmAcceptBounty = async () => {
  if (!acceptBountyTarget.value) return;
  await appStore.runAction(async () => {
    await appStore.request(`/api/activities/${acceptBountyTarget.value.id}/accept-bounty`, {
      method: 'POST',
      headers: appStore.authHeaders()
    });
    await familyStore.fetchUserData();
    await loadActivities();
    appStore.setSuccess('Task taken! Coins added to your account.');
  });
  showAcceptBountyModal.value = false;
  acceptBountyTarget.value = null;
};

const removeMobile = (activity) => {
  if (activity.is_recurrent) {
    deleteTarget.value = activity;
    showDeleteModal.value = true;
  } else {
    unSchedule(activity.id, false);
  }
};

const { familyId, role } = useCurrentFamily();

const familyMembers = ref([]);
const loadMembers = () => appStore.runAction(async () => {
  const fid = familyId.value;
  if (!fid) return;
  const data = await appStore.request(`/api/families/${fid}/members`, {
    headers: appStore.authHeaders()
  });
  familyMembers.value = (data.members || []).sort((a, b) => b.coin_balance - a.coin_balance);
});

const getCardStyle = (activity) => {
  if (activity.status === 'rejected') {
    return { background: 'var(--danger-soft)', color: 'var(--danger)', border: '1px solid var(--danger-soft)' };
  }
  if (activity.status === 'completed') {
    return { background: activity.category === 'care' ? 'var(--success)' : 'var(--warning)', color: '#fff' };
  }
  return { background: 'var(--surface)', color: 'var(--text-primary)', border: '1px solid var(--border)' };
};

const getMemberAvatarStyle = (assigned_alias) => {
  const idx = familyMembers.value.findIndex(m => (m.alias || m.name) === assigned_alias);
  const bgs = ['var(--primary-soft)', 'var(--success-soft)', 'var(--warning-soft)', 'var(--danger-soft)'];
  const fgs = ['var(--primary)', 'var(--success)', 'var(--warning)', 'var(--danger)'];
  const i = idx === -1 ? 0 : idx % 4;
  return { background: bgs[i], color: fgs[i] };
};

const isLoadingActivities = ref(true);

const loadActivities = async () => {
  isLoadingActivities.value = true;
  await appStore.runAction(async () => {
    const fid = familyId.value;
    if (!fid) { isLoadingActivities.value = false; return; }
    const activitiesData = await appStore.request(`/api/activities?familyId=${fid}`, { headers: appStore.authHeaders() });
    familyActivities.value = activitiesData.activities || [];
  });
  isLoadingActivities.value = false;
};

onMounted(() => {
  loadMembers();
});

watch(() => targetDateStr.value, () => {
  loadActivities();
  loadAbsences();
}, { immediate: true });

watch(isLoadingActivities, (loading) => {
  if (!loading) nextTick(() => scrollToNow());
});

const searchQuery = ref('');
const categoryFilter = ref('all');

const availableTemplates = computed(() => {
  return familyActivities.value.filter(a => {
    if (!a.is_template || a.status !== 'approved') return false;
    if (categoryFilter.value !== 'all' && a.category !== categoryFilter.value) return false;
    if (searchQuery.value && !a.title.toLowerCase().includes(searchQuery.value.toLowerCase())) return false;
    return true;
  });
});

const START_HOUR = 6;
const TOTAL_HOURS = 18;

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

const formatGap = (minutes) => {
  if (minutes < 60) return `${minutes}min`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m > 0 ? `${h}h ${m}min` : `${h}h`;
};

const mobileTimelineRef = ref(null);

const scrollToNow = () => {
  if (!mobileTimelineRef.value) return;
  const divider = mobileTimelineRef.value.querySelector('.tl-now-divider');
  if (divider) {
    divider.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }
};

const showTaskSheet = ref(false);
const pendingScheduleHour = ref(null);
const pendingScheduleMinute = ref(null);

const openScheduleAtHour = (hour) => {
  pendingScheduleHour.value = String(Math.floor(hour)).padStart(2, '0');
  pendingScheduleMinute.value = hour % 1 === 0.5 ? '30' : '00';
  showTaskSheet.value = true;
};

const tapToScheduleFromSheet = (activity) => {
  scheduleForm.value.activityId = activity.id;
  scheduleHour.value = pendingScheduleHour.value ?? String(new Date().getHours()).padStart(2, '0');
  scheduleMinute.value = pendingScheduleMinute.value ?? (new Date().getMinutes() >= 30 ? '30' : '00');
  pendingScheduleHour.value = null;
  pendingScheduleMinute.value = null;
  showTaskSheet.value = false;
  showScheduleModal.value = true;
};

const scheduledToday = computed(() => {
  let acts = familyActivities.value.filter(a => {
    if (a.is_template || !a.starts_at) return false;
    const d = new Date(a.starts_at);
    return d.getFullYear() === targetDate.value.getFullYear() &&
           d.getMonth() === targetDate.value.getMonth() &&
           d.getDate() === targetDate.value.getDate();
  });
  
  // Sort by start time, then by duration (longest first)
  acts.sort((a, b) => {
    const timeA = new Date(a.starts_at).getTime();
    const timeB = new Date(b.starts_at).getTime();
    if (timeA !== timeB) return timeA - timeB;
    return (b.duration_minutes || 0) - (a.duration_minutes || 0);
  });

  const positionedActs = [];

  for (let i = 0; i < acts.length; i++) {
    const a = acts[i];
    const startA = new Date(a.starts_at).getTime();
    let overlapCount = 0;
    for (let j = 0; j < i; j++) {
      const b = positionedActs[j];
      const startB = new Date(b.starts_at).getTime();
      // Enforce minimum 60 min visual footprint to prevent physical overlapping of zero-duration chips
      const durA = Math.max((a.duration_minutes || a.durationMinutes || 0), 60);
      const durB = Math.max((b.duration_minutes || b.durationMinutes || 0), 60);
      const endA = startA + (durA * 60000);
      const endB = startB + (durB * 60000);
      
      if (Math.max(startA, startB) < Math.min(endA, endB)) {
        overlapCount++;
      }
    }

    let d = new Date(a.starts_at);
    let hour = d.getHours() + d.getMinutes() / 60;
    let topP = ((Math.max(START_HOUR, hour) - START_HOUR) / TOTAL_HOURS) * 100;
    
    let visibleHours = Math.min((a.duration_minutes || 60) / 60, 24 - Math.max(START_HOUR, hour));
    let heightP = (visibleHours / TOTAL_HOURS) * 100;
    
    const indentMultiplier = Math.min(overlapCount, 4);
    const leftPx = 70 + (indentMultiplier * 45); // increased indent to 45px for better visibility
    const widthPx = `calc(100% - ${leftPx + 10}px)`;
    const shadowIntensity = 0.2 + (indentMultiplier * 0.1);

    const prevEnd = i === 0
      ? new Date(d.getFullYear(), d.getMonth(), d.getDate(), START_HOUR, 0, 0).getTime()
      : new Date(positionedActs[i - 1].starts_at).getTime() + ((positionedActs[i - 1].duration_minutes || 0) * 60000);
    const gapBeforeMinutes = Math.max(0, Math.round((startA - prevEnd) / 60000));

    positionedActs.push({
      ...a,
      overlapCount,
      gapBeforeMinutes,
      _style: {
        position: 'absolute',
        top: `${topP}%`,
        left: `${leftPx}px`,
        width: widthPx,
        zIndex: 10 + overlapCount,
        boxShadow: overlapCount > 0 ? `-5px 5px 15px rgba(0,0,0,${shadowIntensity})` : '0 4px 15px rgba(0,0,0,0.2)'
      },
    });
  }
  
  return positionedActs;
});

const completedToday = computed(() => {
  return familyActivities.value.filter(a => {
    if (a.is_template || !a.starts_at || a.status !== 'completed') return false;
    const d = new Date(a.starts_at);
    return d.getFullYear() === targetDate.value.getFullYear() &&
           d.getMonth() === targetDate.value.getMonth() &&
           d.getDate() === targetDate.value.getDate();
  });
});

const todayCoins = computed(() => completedToday.value.reduce((sum, a) => sum + (a.coin_value||0), 0));

const dragStart = (event, activity) => {
  event.dataTransfer.effectAllowed = 'copyMove';
  event.dataTransfer.setData('text/plain', JSON.stringify({ type: 'template', activity }));
};

const dragStartScheduled = (event, activity) => {
  event.dataTransfer.effectAllowed = 'move';
  event.dataTransfer.setData('text/plain', JSON.stringify({ type: 'scheduled', activity }));
};

const dropOut = async (event) => {
  const j = event.dataTransfer.getData('text/plain');
  if (!j) return;
  try {
    const payload = JSON.parse(j);
    if (payload.type === 'scheduled') {
      if (payload.activity.is_recurrent) {
        deleteTarget.value = payload.activity;
        showDeleteModal.value = true;
      } else {
        await unSchedule(payload.activity.id, false);
      }
    }
  } catch(e) {
    console.error('dropOut: unexpected drag payload:', e);
  }
};

const dropOnTimeline = (event) => {
  event.preventDefault();
  const j = event.dataTransfer.getData('text/plain');
  if (!j) return;
  
  try {
    const payload = JSON.parse(j);
    const rect = event.currentTarget.getBoundingClientRect();
    const y = Math.max(0, event.clientY - rect.top);
    const percentage = y / rect.height;
    
    let droppedHour = 6 + (percentage * 18);
    droppedHour = Math.round(droppedHour * 2) / 2; // 30-min snap
    droppedHour = Math.max(6, Math.min(23.5, droppedHour));
    
    let hh = Math.floor(droppedHour);
    let mm = (droppedHour % 1 === 0.5) ? '30' : '00';
    
    scheduleForm.value.activityId = payload.activity.id;
    scheduleHour.value = String(hh).padStart(2, '0');
    scheduleMinute.value = mm;
    showScheduleModal.value = true;
  } catch(e) {
    console.error('dropOnTimeline: unexpected drag payload:', e);
  }
};

const tapToSchedule = (activity) => {
  if (window.innerWidth <= 768) {
    scheduleForm.value.activityId = activity.id;
    const now = new Date();
    scheduleHour.value = String(now.getHours()).padStart(2, '0');
    scheduleMinute.value = now.getMinutes() >= 30 ? '30' : '00';
    showScheduleModal.value = true;
  }
};

const confirmSchedule = async () => {
  if (!scheduleForm.value.activityId) {
    appStore.setError("Select a task first.");
    return;
  }
  const hh = scheduleHour.value;
  const mm = scheduleMinute.value;
  const d = new Date(targetDate.value);
  d.setHours(Number(hh), Number(mm), 0, 0);

  const activityEnd = new Date(d.getTime() + 60 * 60000);
  const hasOverlap = absencesToday.value.some(a => {
    const aStart = new Date(a.start_time);
    const aEnd = new Date(a.end_time);
    return String(a.user_id) === String(familyStore.profile?.id) && aStart < activityEnd && aEnd > d;
  });

  if (hasOverlap) {
    appStore.setError("You cannot schedule activities during a logged absence.");
    return;
  }

  await appStore.runAction(async () => {
    const res = await appStore.request(`/api/activities/${scheduleForm.value.activityId}/schedule`, {
      method: 'POST',
      headers: appStore.authHeaders(),
      body: JSON.stringify({ startsAt: d.toISOString() })
    });
    showScheduleModal.value = false;
    await loadActivities();
    appStore.setSuccess('Activity successfully scheduled!');
  });
};

const unSchedule = (aid, series = false) => appStore.runAction(async () => {
  await appStore.request(`/api/activities/${aid}${series ? '?series=true' : ''}`, {
    method: 'DELETE',
    headers: appStore.authHeaders()
  });
  await loadActivities();
  appStore.setSuccess(series ? 'Entire recurring series removed.' : 'Activity removed from schedule.');
});

const validateActivity = (aid) => appStore.runAction(async () => {
  await appStore.request(`/api/activities/${aid}/validate`, {
    method: 'POST',
    headers: appStore.authHeaders()
  });
  await loadActivities();
  appStore.setSuccess('Activity validated! Coins awarded to the user.');
});

</script>

<template>
  <div class="daily-fullscreen-overlay" @click.self="closeDailyView" @dragover.prevent @drop.prevent="dropOut($event)">
    <div class="daily-wrapper" @dragover.prevent @drop.prevent="dropOut($event)">
      <div class="daily-header-row">
        <div class="daily-header-left">
          <h2 style="margin: 0;">Daily Schedule</h2>
          <button @click="openAbsenceModal" class="log-off-btn">+ Log Time Off</button>
        </div>
        <div class="daily-header-right" style="display: flex; flex-direction: column; align-items: flex-end;">
          <div style="display: flex; align-items: center; gap: 0.5rem;">
            <button @click="navigateDay(-1)" class="date-nav-btn">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"></polyline></svg>
            </button>
            <strong class="date-display">{{ new Date(targetDate).toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' }) }}</strong>
            <button @click="navigateDay(1)" class="date-nav-btn">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg>
            </button>
          </div>
          <div class="day-progress">
            <div class="day-progress-bar">
              <div class="day-progress-fill"
                   :style="{ width: scheduledToday.length ? (completedToday.length / scheduledToday.length * 100) + '%' : '0%' }">
              </div>
            </div>
            <span class="day-progress-label">
              {{ completedToday.length }} / {{ scheduledToday.length }} done
              <span v-if="todayCoins > 0" style="margin-left: 0.4rem;">· 🪙 {{ todayCoins }}cc</span>
            </span>
          </div>
        </div>
      </div>

    <div class="daily-grid">
      
      <VCard title="Task Library" class="col-card" style="box-shadow: none; border: none; background: transparent;">
         <p class="text-sm" style="color: var(--text-secondary); margin-bottom: 1rem; flex-shrink: 0;">Drag icons to the timeline to schedule your day.</p>
         
         <!-- Search and Filter -->
         <div style="display: flex; flex-direction: column; gap: 0.6rem; margin-bottom: 1rem; flex-shrink: 0; padding-right: 0.5rem;">
           <input type="text" v-model="searchQuery" placeholder="Search tasks..." style="width: 100%; box-sizing: border-box; padding: 0.6rem 1rem; border-radius: var(--r-sm); border: 1px solid var(--border); background: var(--surface); color: var(--text-primary); font-size: 0.9rem; outline: none; box-shadow: inset 0 1px 3px rgba(0,0,0,0.05);" />
           <div style="display: flex; gap: 0.4rem; overflow-x: auto; padding-bottom: 4px; scrollbar-width: none;">
             <button @click="categoryFilter = 'all'" :style="{ background: categoryFilter === 'all' ? 'var(--primary)' : 'var(--surface)', color: categoryFilter === 'all' ? 'white' : 'var(--text-secondary)', border: '1px solid ' + (categoryFilter === 'all' ? 'var(--primary)' : 'var(--border)'), padding: '0.4rem 0.8rem', borderRadius: '999px', fontSize: '0.8rem', fontWeight: 'bold', cursor: 'pointer', flexShrink: 0, transition: 'all 0.2s' }">All</button>
             <button @click="categoryFilter = 'care'" :style="{ background: categoryFilter === 'care' ? 'var(--primary)' : 'var(--surface)', color: categoryFilter === 'care' ? 'white' : 'var(--text-secondary)', border: '1px solid ' + (categoryFilter === 'care' ? 'var(--primary)' : 'var(--border)'), padding: '0.4rem 0.8rem', borderRadius: '999px', fontSize: '0.8rem', fontWeight: 'bold', cursor: 'pointer', flexShrink: 0, transition: 'all 0.2s' }">Care</button>
             <button @click="categoryFilter = 'household'" :style="{ background: categoryFilter === 'household' ? 'var(--primary)' : 'var(--surface)', color: categoryFilter === 'household' ? 'white' : 'var(--text-secondary)', border: '1px solid ' + (categoryFilter === 'household' ? 'var(--primary)' : 'var(--border)'), padding: '0.4rem 0.8rem', borderRadius: '999px', fontSize: '0.8rem', fontWeight: 'bold', cursor: 'pointer', flexShrink: 0, transition: 'all 0.2s' }">Household</button>
           </div>
         </div>

         <div class="template-grid">
           
           <template v-for="category in ['care', 'household']" :key="category">
             <div v-if="availableTemplates.some(a => a.category === category)" class="category-divider">
               <span class="category-pip" :style="{ background: category === 'care' ? 'var(--success)' : 'var(--warning)' }"></span>
               <span>{{ category === 'care' ? 'Care & Wellness' : 'Household' }}</span>
             </div>
             
             <div v-for="a in availableTemplates.filter(t => t.category === category)" :key="a.id" class="task-template-row" draggable="true" @dragstart="dragStart($event, a)" @click="tapToSchedule(a)">
                <div style="width: 40px; height: 40px; background: var(--primary-soft); color: var(--primary); border-radius: 50%; display:flex; align-items:center; justify-content:center; flex-shrink:0;">
                  <span style="font-size: 1.2rem;">{{ category === 'care' ? '❤️' : '🧹' }}</span>
                </div>
                <div style="flex:1;">
                  <strong class="text-base" style="color: var(--text-primary); display: block; margin-bottom: 0.1rem; line-height:1.2; font-weight: 800;">{{ a.title }}</strong>
                  <div class="text-xs" style="color: var(--text-secondary); display: flex; align-items: center; gap: 0.4rem;">
                    <span>{{ category === 'care' ? 'Care' : 'Cleaning' }}</span>
                    <span>•</span>
                    <span>🪙 {{ a.coin_value }}cc</span>
                  </div>
                </div>
             </div>
           </template>
           <!-- Empty state for search -->
           <div v-if="availableTemplates.length === 0" style="text-align: center; padding: 2rem 1rem; color: var(--text-secondary); font-size: 0.9rem; font-weight: 600;">
             No tasks found matching your filters.
           </div>
           
         </div>
      </VCard>

      <div class="timeline-col">
        
        <VCard :title="scheduledTitle" class="agenda-card" style="padding: 0; flex: 1; display: flex; flex-direction: column;">
           <div v-if="absencesToday.length > 0" class="absence-banner-row">
             <div v-for="a in absencesToday" :key="a.id"
                  style="background: var(--danger-soft); border: 1px solid var(--danger-soft); border-radius: var(--r-sm); padding: 0.6rem 1rem; font-size: 0.85rem; color: var(--danger); display: flex; align-items: center; gap: 0.6rem; cursor: pointer;"
                  @click="openAbsenceDetail(a)">
               <span style="font-size: 1rem; flex-shrink: 0;">✈️</span>
               <div style="display: flex; flex-direction: column; gap: 0.1rem;">
                 <div style="font-weight: 800; line-height: 1.2;">{{ a.user_alias || a.user_name }}</div>
                 <div style="font-size: 0.75rem; font-weight: 600; opacity: 0.75;">{{ a.title }}</div>
               </div>
             </div>
           </div>

           <div class="timeline-container desktop-only" @dragover.prevent @drop.prevent.stop="dropOnTimeline($event)">
             <div class="timeline-inner">
              <div class="hour-lines" style="position: absolute; width: 100%; height: 100%; display: flex; flex-direction: column;">
                 <div v-for="h in 19" :key="h" class="h-line">
                   <span class="h-label">{{ (h+5) > 12 ? (h+5)-12 : (h+5) }}:00 {{ (h+5) >= 12 ? 'PM' : 'AM' }}</span>
                   <div class="h-border"></div>
                 </div>
              </div>

               <div v-if="nowLineTop !== null" :style="{ position: 'absolute', top: nowLineTop + '%', left: '60px', right: '10px', zIndex: 50, pointerEvents: 'none', display: 'flex', alignItems: 'center', gap: '0' }">
                 <div style="width: 8px; height: 8px; border-radius: 50%; background: var(--danger); flex-shrink: 0;"></div>
                 <div style="flex: 1; height: 2px; background: var(--danger);"></div>
               </div>

               <div v-for="a in scheduledToday" :key="a.id"
                    class="scheduled-chip"
                    :style="[
                      a._style,
                      getCardStyle(a),
                      a.is_recurrent && a.status !== 'completed' ? { cursor: 'pointer' } : {}
                    ]"
                    :draggable="a.status !== 'completed'" @dragstart="a.status !== 'completed' ? dragStartScheduled($event, a) : null"
                    @click="a.is_recurrent && a.status !== 'completed' ? openRecurrenceModal(a) : null">
                 <div style="display:flex; align-items:center; gap: 0.8rem;">
                   <span style="font-size: 1.4rem;">{{ a.category === 'care' ? '❤️' : '🍽️' }}</span>
                   <strong class="text-base" style="display:block; line-height: 1.2; font-weight:800;">
                     <span v-if="a.status === 'rejected'" title="Rejected" style="margin-right:4px;">⚠️</span>
                     {{ a.title }}
                     <span v-if="a.is_recurrent" title="Click to schedule future recurrences" style="font-size: 0.85rem; margin-left: 0.3rem;">🔁</span>
                   </strong>
                 </div>
                 
                 <div style="display: flex; align-items: center; gap: 0.5rem;">
                  <div class="text-xs" style="font-weight:800; background: var(--bg); border: 1px solid var(--border); padding: 4px 10px; border-radius: 999px; color: var(--text-secondary);">
                    {{ new Date(a.starts_at).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }) }}
                  </div>

                  <div v-if="a.status === 'pending_validation'" style="display: flex; align-items: center; gap: 0.4rem;">
                    <button v-if="a.assigned_to !== familyStore.profile?.id && role === 'caregiver'" @click.stop="validateActivity(a.id)" class="validate-btn">✓ Validate</button>
                  </div>
                  <div v-else-if="a.status === 'completed'" class="text-xs" style="font-weight: bold; background: rgba(0,0,0,0.15); padding: 2px 6px; border-radius: 999px; color: #fff;">
                    ✓ Done
                  </div>
                  <div v-else-if="['pending', 'approved'].includes(a.status)" style="display: flex; align-items: center; gap: 0.4rem;">
                    <!-- My Task -> I can offer Bribe -->
                    <button v-if="a.assigned_to === familyStore.profile?.id && !a.bounty_amount && role === 'caregiver'"
                            @click.stop="openBountyModal(a)" class="validate-btn" style="background: var(--warning-soft); border: 1px solid var(--warning); color: var(--warning);">
                      Delegate (-cc)
                    </button>
                    <!-- My Task with Bribe already offered -->
                    <span v-else-if="a.assigned_to === familyStore.profile?.id && a.bounty_amount" class="text-xs" style="background: var(--warning-soft); padding: 4px 8px; border-radius: 999px; font-weight:800; border: 1px solid var(--warning); color: var(--warning);">
                      Offering: {{ a.bounty_amount }}cc
                    </span>
                    <!-- Other User's Task with Bribe -> I can ACCEPT Bribe -->
                    <button v-else-if="a.assigned_to !== familyStore.profile?.id && a.bounty_amount && role === 'caregiver'"
                            @click.stop="openAcceptBountyModal(a)" class="validate-btn" style="background: var(--success-soft); border: 1px solid var(--success); color: var(--success);">
                      Take Over (+{{a.bounty_amount}}cc)
                    </button>
                    <!-- Other User's Task with NO bribe -->
                    <span v-else-if="a.assigned_to !== familyStore.profile?.id && !a.bounty_amount" class="text-xs" style="background: var(--bg); border: 1px solid var(--border); padding: 4px 8px; border-radius: 999px; font-weight: 800; color: var(--text-secondary);">
                      Assigned to {{ a.assigned_alias || 'Caregiver' }}
                    </span>
                  </div>
                </div>
              </div>
             </div>
           </div>
         
         <div class="mobile-timeline mobile-only" ref="mobileTimelineRef"
              @touchstart.passive="onTouchStart" @touchend.passive="onTouchEnd">
           <template v-if="isLoadingActivities">
             <div v-for="i in 3" :key="i" class="skeleton-card" style="margin: 8px 12px;"></div>
           </template>

           <div v-else-if="scheduledToday.length === 0" class="mobile-empty-state" @click="showTaskSheet = true">
             <div class="empty-state-icon">
               <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                    stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                 <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
                 <line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/>
                 <line x1="3" y1="10" x2="21" y2="10"/>
               </svg>
             </div>
             <strong class="empty-state-title">Your day is wide open.</strong>
             <span class="empty-state-sub">Tap here to schedule a task.</span>
           </div>

           <div v-else class="tl-list">
             <template v-for="(a, index) in scheduledToday" :key="a.id">

               <!-- NOW divider before the first future task -->
               <div v-if="nowIndex === index" class="tl-now-divider">
                 <div class="tl-now-divider-line"></div>
                 <span class="tl-now-divider-label">Now</span>
                 <div class="tl-now-divider-line"></div>
               </div>

               <!-- Gap indicator (only when gap > 30 min and not at start of day) -->
               <div v-if="a.gapBeforeMinutes > 30 && index > 0" class="tl-gap">
                 {{ formatGap(a.gapBeforeMinutes) }} free
               </div>

               <!-- Task row: time axis + card -->
               <div class="tl-row"
                    :class="{
                      'tl-row--swiping': swipingId === a.id,
                      'tl-row--dismissing': dismissingIds.has(a.id)
                    }"
                    @touchstart.stop="onCardTouchStart($event, a)"
                    @touchmove="onCardTouchMove($event, a)"
                    @touchend.stop="onCardTouchEnd($event, a)">
                 <div class="tl-row-time">
                   {{ new Date(a.starts_at).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }) }}
                 </div>
                 <div class="tl-card"
                      :class="[{ 'tl-card--dismiss': dismissingIds.has(a.id) }, a.status === 'completed' ? 'tl-card--colored' : 'tl-card--on-surface']"
                      :style="[
                        getCardStyle(a),
                        {
                          transform: swipingId === a.id ? `translateX(${swipeDeltaX}px)` : undefined,
                          transition: swipingId === a.id ? 'none' : 'transform 0.25s ease-out',
                        }
                      ]">
                   <div class="tl-card-header">
                     <span class="tl-card-emoji">{{ a.category === 'care' ? '❤️' : '🍽️' }}</span>
                     <div class="tl-card-title-block">
                       <div class="tl-card-title">
                         <span v-if="a.status === 'rejected'">⚠️ </span>{{ a.title }}
                         <span v-if="a.is_recurrent" style="font-size:0.8rem;margin-left:2px;">🔁</span>
                       </div>
                       <div class="tl-card-meta">
                         <span>🪙 {{ a.coin_value }}cc</span>
                         <span v-if="a.bounty_amount" class="tl-bounty-chip">+{{ a.bounty_amount }}cc</span>
                       </div>
                     </div>
                   </div>

                   <div class="tl-card-footer">
                     <span class="tl-card-assignee">{{ a.assigned_alias || 'Caregiver' }}</span>
                     <div class="tl-card-actions">
                       <button v-if="a.status === 'pending_validation' && a.assigned_to !== familyStore.profile?.id && role === 'caregiver'"
                               @click.stop="validateActivity(a.id)" class="validate-btn" style="padding:0.35rem 0.9rem;">
                         ✓ Validate
                       </button>
                       <div v-else-if="a.status === 'completed'"
                            style="background:rgba(0,0,0,0.2);padding:3px 10px;border-radius:999px;font-size:0.78rem;font-weight:800;">
                         ✓ Done
                       </div>
                       <button v-else-if="a.assigned_to === familyStore.profile?.id && !a.bounty_amount && role === 'caregiver'"
                               @click.stop="openBountyModal(a)" class="validate-btn"
                               style="background:var(--warning-soft);border:1px solid var(--warning);color:var(--warning);padding:0.35rem 0.9rem;">
                         Delegate
                       </button>
                       <button v-else-if="a.assigned_to !== familyStore.profile?.id && a.bounty_amount && role === 'caregiver'"
                               @click.stop="openAcceptBountyModal(a)" class="validate-btn"
                               style="background:var(--success-soft);color:var(--success);border:none;padding:0.35rem 0.9rem;">
                         Take Over
                       </button>
                       <span v-else-if="a.assigned_to !== familyStore.profile?.id && !a.bounty_amount"
                             style="font-size:0.72rem;background:rgba(0,0,0,0.15);padding:3px 8px;border-radius:999px;font-weight:700;">
                         {{ a.assigned_alias || 'Caregiver' }}
                       </span>
                     </div>
                   </div>
                 </div>
               </div>

             </template>

             <!-- NOW divider at the end when all tasks are in the past -->
             <div v-if="nowIndex === -1" class="tl-now-divider">
               <div class="tl-now-divider-line"></div>
               <span class="tl-now-divider-label">Now</span>
               <div class="tl-now-divider-line"></div>
             </div>

           </div>
         </div>

        </VCard>

        <!-- Horizontal Completed Bar -->
        <div class="completed-bar" style="background: var(--surface); color: var(--text-primary); padding: 0.8rem 1.2rem; border-radius: var(--r-lg); display: flex; align-items: center; justify-content: space-between; border: 1px solid var(--border); box-shadow: 0 1px 2px rgba(14,23,38,0.04);">
           <div style="display: flex; gap: 0.6rem; align-items: center; flex-wrap: wrap; flex: 1;">
             <span class="completed-bar-label">Done today</span>

             <div v-if="completedToday.length === 0" style="font-weight: 600; font-size: 0.9rem; color: var(--text-secondary);">
               Nothing finished yet today.
             </div>

             <div v-for="a in completedToday.slice(0, 5)" :key="a.id"
                  :style="{ background: a.category === 'care' ? 'var(--success)' : 'var(--warning)', color: 'white' }"
                  style="display: flex; align-items: center; gap: 0.5rem; padding: 0.4rem 1rem; border-radius: var(--r-pill); font-size: 0.85rem;">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink:0;"><path d="M20 6L9 17l-5-5"/></svg>
                <strong style="font-weight: 800;">{{ a.title }}</strong>
             </div>
             <div v-if="completedToday.length > 5"
                  style="background: var(--bg); border: 1px solid var(--border); padding: 0.4rem 0.8rem; border-radius: var(--r-pill); font-size: 0.8rem; font-weight: 800; color: var(--text-secondary);">
               +{{ completedToday.length - 5 }} more
             </div>
           </div>

           <!-- Totals at the end -->
           <div v-if="todayCoins > 0" style="margin-left: 1rem; display: flex; align-items: center; gap: 0.5rem; background: var(--bg); color: var(--text-primary); padding: 0.4rem 1rem; border-radius: var(--r-pill); border: 1px solid var(--border); flex-shrink: 0;">
              <span style="font-size: 11px; font-weight: 800; text-transform: uppercase; color: var(--text-secondary);">Earned</span>
              <strong style="font-size: 1.1rem; font-weight: 800; color: var(--primary);">{{ todayCoins }}cc</strong>
           </div>
        </div>
        
      </div>
    
    </div> <!-- end daily-grid -->
    </div> <!-- end daily-wrapper -->

    <button class="daily-back-fab" @click="closeDailyView" aria-label="Back to Family Hub">
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
        <path d="M19 12H5M12 19l-7-7 7-7"/>
      </svg>
    </button>

    <div class="mobile-bottom-bar mobile-only">
      <button class="mobile-bottom-back" @click="closeDailyView" aria-label="Back to Family Hub">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"
             stroke-linecap="round" stroke-linejoin="round">
          <path d="M19 12H5M12 19l-7-7 7-7"/>
        </svg>
      </button>
      <div style="flex: 1;"></div>
      <button class="mobile-bottom-add" @click="showTaskSheet = true" aria-label="Add task to schedule">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"
             stroke-linecap="round" stroke-linejoin="round">
          <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
        </svg>
      </button>
    </div>

  </div> <!-- end daily-fullscreen-overlay -->

  <div v-if="showTaskSheet" class="task-sheet-backdrop" @click.self="showTaskSheet = false; pendingScheduleHour = null; pendingScheduleMinute = null;">
    <div class="task-sheet">
      <div class="task-sheet-handle"></div>
      <div class="task-sheet-header">
        <strong style="font-size: 1rem; color: var(--text-primary);">Add a task</strong>
        <span v-if="pendingScheduleHour" style="color: var(--primary); font-size: 0.9rem; font-weight: 700;">
          at {{ pendingScheduleHour }}:{{ pendingScheduleMinute }}
        </span>
        <button @click="showTaskSheet = false; pendingScheduleHour = null; pendingScheduleMinute = null;"
                style="background:none; border:none; cursor:pointer; color:var(--text-secondary); padding:4px; line-height:0;">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
      </div>

      <div style="padding: 0 1rem 0.5rem; flex-shrink: 0;">
        <input type="text" v-model="searchQuery" placeholder="Search tasks..."
               style="width:100%; box-sizing:border-box; padding:0.6rem 1rem; border-radius:var(--r-sm); border:1px solid var(--border); background:var(--surface); color:var(--text-primary); font-size:0.9rem; outline:none;" />
        <div style="display:flex; gap:0.4rem; overflow-x:auto; padding:0.5rem 0 0.25rem; scrollbar-width:none;">
          <button @click="categoryFilter = 'all'" :style="{ background: categoryFilter === 'all' ? 'var(--primary)' : 'var(--surface)', color: categoryFilter === 'all' ? 'white' : 'var(--text-secondary)', border: '1px solid ' + (categoryFilter === 'all' ? 'var(--primary)' : 'var(--border)'), padding: '0.35rem 0.8rem', borderRadius: '999px', fontSize: '0.8rem', fontWeight: 'bold', cursor: 'pointer', flexShrink: 0 }">All</button>
          <button @click="categoryFilter = 'care'" :style="{ background: categoryFilter === 'care' ? 'var(--primary)' : 'var(--surface)', color: categoryFilter === 'care' ? 'white' : 'var(--text-secondary)', border: '1px solid ' + (categoryFilter === 'care' ? 'var(--primary)' : 'var(--border)'), padding: '0.35rem 0.8rem', borderRadius: '999px', fontSize: '0.8rem', fontWeight: 'bold', cursor: 'pointer', flexShrink: 0 }">Care</button>
          <button @click="categoryFilter = 'household'" :style="{ background: categoryFilter === 'household' ? 'var(--primary)' : 'var(--surface)', color: categoryFilter === 'household' ? 'white' : 'var(--text-secondary)', border: '1px solid ' + (categoryFilter === 'household' ? 'var(--primary)' : 'var(--border)'), padding: '0.35rem 0.8rem', borderRadius: '999px', fontSize: '0.8rem', fontWeight: 'bold', cursor: 'pointer', flexShrink: 0 }">Household</button>
        </div>
      </div>

      <div class="task-sheet-list">
        <template v-for="category in ['care', 'household']" :key="category">
          <div v-if="availableTemplates.some(a => a.category === category)" class="category-divider" style="padding: 0.5rem 1rem 0.25rem;">
            <span class="category-pip" :style="{ background: category === 'care' ? 'var(--success)' : 'var(--warning)' }"></span>
            <span>{{ category === 'care' ? 'Care & Wellness' : 'Household' }}</span>
          </div>
          <div v-for="a in availableTemplates.filter(t => t.category === category)" :key="a.id"
               class="task-template-row" style="margin: 0 1rem 0.5rem;"
               @click="tapToScheduleFromSheet(a)">
            <div style="width:40px; height:40px; background:var(--primary-soft); color:var(--primary); border-radius:50%; display:flex; align-items:center; justify-content:center; flex-shrink:0;">
              <span style="font-size:1.2rem;">{{ category === 'care' ? '❤️' : '🧹' }}</span>
            </div>
            <div style="flex:1;">
              <strong style="color:var(--text-primary); display:block; margin-bottom:0.1rem; line-height:1.2; font-weight:800;">{{ a.title }}</strong>
              <div style="color:var(--text-secondary); font-size:0.78rem; display:flex; align-items:center; gap:0.4rem;">
                <span>{{ category === 'care' ? 'Care' : 'Cleaning' }}</span>
                <span>•</span>
                <span>🪙 {{ a.coin_value }}cc</span>
              </div>
            </div>
          </div>
        </template>
        <div v-if="availableTemplates.length === 0"
             style="text-align:center; padding:2rem 1rem; color:var(--text-secondary); font-size:0.9rem; font-weight:600;">
          No tasks found.
        </div>
      </div>
    </div>
  </div>

  <div v-if="showRecurrenceModal" class="modal-overlay">
    <VCard title="Schedule Future Copies" style="max-width: 350px; width: 100%;">
      <p class="text-sm" style="color: var(--text-secondary); margin-bottom: 1.5rem; line-height: 1.4;">
        Repeat <strong>{{ recurrenceForm.title }}</strong> at this time into the future.
      </p>
      <div style="margin-bottom: 1.2rem;">
        <label style="display:block; margin-bottom: 0.5rem; color: var(--text-primary); font-size: 0.95rem; font-weight:600;">Frequency:</label>
        <select v-model="recurrenceForm.frequency" style="width: 100%; padding: 0.75rem; border-radius: var(--radius-button); font-size: 1rem; background: var(--input-bg); color: var(--text-primary); border: 1px solid var(--input-border); outline: none;">
          <option value="daily">Every Day</option>
          <option value="weekdays">Every Working Day (Mon-Fri)</option>
          <option value="weekly">Every Week (same day)</option>
        </select>
      </div>
      <div style="margin-bottom: 1.8rem;">
        <label style="display:block; margin-bottom: 0.5rem; color: var(--text-primary); font-size: 0.95rem; font-weight:600;">Until Date:</label>
        <input type="date" v-model="recurrenceForm.untilDate" style="width: 100%; padding: 0.75rem; border-radius: var(--radius-button); font-size: 1rem; background: var(--input-bg); color: var(--text-primary); border: 1px solid var(--input-border); outline: none;" />
      </div>
      <div style="display:flex; justify-content: flex-end; gap: 1rem;">
        <VButton type="secondary" @click="showRecurrenceModal = false">Cancel</VButton>
        <VButton type="primary" @click="confirmRecurrence">Create schedule</VButton>
      </div>
    </VCard>
  </div>

  <div v-if="showScheduleModal" class="modal-overlay bs-overlay">
    <VCard title="Confirm Time" style="max-width: 320px; width: 100%;">
      <div class="sheet-handle-bar"></div>
      <div style="margin-bottom: 1.5rem;">
        <label style="display:block; margin-bottom: 0.75rem; color: var(--text-primary); font-size: 1.1rem; font-weight: 800;">Starting at...</label>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <select v-model="scheduleHour" style="flex: 1; padding: 0.75rem; border-radius: var(--radius-button); font-size: 1.2rem; background: var(--input-bg); color: var(--text-primary); border: 1px solid var(--input-border); text-align: center; appearance: none; outline: none;">
            <option v-for="h in 24" :key="h-1" :value="String(h-1).padStart(2, '0')">{{ String(h-1).padStart(2, '0') }}</option>
          </select>
          <span style="font-size: 1.5rem; color: var(--text-primary); font-weight: bold;">:</span>
          <select v-model="scheduleMinute" style="flex: 1; padding: 0.75rem; border-radius: var(--radius-button); font-size: 1.2rem; background: var(--input-bg); color: var(--text-primary); border: 1px solid var(--input-border); text-align: center; appearance: none; outline: none;">
            <option value="00">00</option>
            <option value="30">30</option>
          </select>
          <span style="font-size: 0.9rem; font-weight: 800; color: var(--text-secondary); min-width: 2.5rem; text-align: center;">
            {{ Number(scheduleHour) < 12 ? 'AM' : 'PM' }}
          </span>
        </div>
      </div>
      <div style="display:flex; justify-content: flex-end; gap: 1rem;">
        <VButton type="secondary" @click="showScheduleModal = false">Cancel</VButton>
        <VButton type="primary" @click="confirmSchedule">Schedule</VButton>
      </div>
    </VCard>
  </div>

  <div v-if="showBountyModal" class="modal-overlay">
    <VCard title="Delegate Task (Bribe)" style="max-width: 350px; width: 100%;">
      <p class="text-sm" style="color: var(--text-secondary); margin-bottom: 1.5rem; line-height: 1.4;">
        Add a coin bounty to <strong>{{ bountyForm.title }}</strong>! If another caregiver takes it over, these coins will instantly be deducted from your personal balance and given to them.
      </p>
      
      <div style="margin-bottom: 1.8rem;">
        <label style="display:block; margin-bottom: 0.5rem; color: var(--text-primary); font-size: 0.95rem; font-weight:600;">Offer amount (cc):</label>
        <div style="display: flex; align-items: center; gap: 0.5rem;">
          <span style="font-size: 1.4rem;">🪙</span>
          <input type="number" v-model="bountyForm.amount" placeholder="e.g. 50" min="1"
                 style="width: 100%; padding: 0.75rem; border-radius: var(--radius-button); font-size: 1.1rem; font-weight: 800; background: var(--input-bg); color: var(--text-primary); border: 1px solid var(--input-border); outline: none;" />
        </div>
      </div>
      <div style="display:flex; justify-content: flex-end; gap: 1rem;">
        <VButton type="secondary" @click="showBountyModal = false">Nevermind</VButton>
        <VButton type="primary" @click="confirmBounty">Offer Bounty</VButton>
      </div>
    </VCard>
  </div>

  <div v-if="showDeleteModal" class="modal-overlay bs-overlay">
    <VCard title="Delete Recurring Activity" style="max-width: 350px; width: 100%;">
      <div class="sheet-handle-bar"></div>
      <p class="text-sm" style="color: var(--text-secondary); margin-bottom: 1.5rem; line-height: 1.4;">
        <strong>{{ deleteTarget?.title }}</strong> is a recurring activity. Do you want to delete just this specific instance, or everything from this date onward?
      </p>
      
      <div style="display:flex; flex-direction: column; gap: 0.8rem;">
        <VButton type="primary" block @click="confirmDeleteSingle">Delete just this one</VButton>
        <VButton type="danger" block @click="confirmDeleteSeries">Delete this and all future</VButton>
        <VButton type="secondary" block style="margin-top: 0.2rem;" @click="showDeleteModal = false">Cancel</VButton>
      </div>
    </VCard>
  </div>

  <div v-if="showAbsenceModal" class="modal-overlay">
    <VCard title="Log Time Off" style="max-width: 400px; width: 100%;">
      <p class="text-sm" style="color: var(--text-secondary); margin-bottom: 1.5rem;">
        Record when you'll be unavailable. Coins for tasks during this time will be fairly distributed to caregivers who cover for you.
      </p>
      
      <div style="margin-bottom: 1rem;">
        <label class="modal-label">Title (e.g., Business Trip)</label>
        <input type="text" v-model="absenceForm.title" class="modal-input" placeholder="Enter reason..." />
      </div>
      
      <div style="display: flex; flex-direction: column; gap: 1rem; margin-bottom: 1.8rem;">
        <div>
          <label class="modal-label">Start</label>
          <div style="display: flex; gap: 0.5rem;">
            <input type="date" v-model="absenceForm.startDate" class="modal-input" style="flex: 1;" />
            <input type="time" v-model="absenceForm.startTime" class="modal-input" style="flex: 0 0 auto; width: 7rem;" />
          </div>
        </div>
        <div>
          <label class="modal-label">End</label>
          <div style="display: flex; gap: 0.5rem;">
            <input type="date" v-model="absenceForm.endDate" class="modal-input" style="flex: 1;" />
            <input type="time" v-model="absenceForm.endTime" class="modal-input" style="flex: 0 0 auto; width: 7rem;" />
          </div>
        </div>
      </div>

      <div style="display:flex; justify-content: flex-end; gap: 1rem;">
        <VButton type="secondary" @click="showAbsenceModal = false" :disabled="isSubmittingAbsence">Cancel</VButton>
        <VButton type="primary" @click="confirmAbsence" :disabled="isSubmittingAbsence">
          {{ isSubmittingAbsence ? 'Logging...' : 'Log Absence' }}
        </VButton>
      </div>
    </VCard>
  </div>

  <div v-if="showAbsenceDetailModal" class="modal-overlay">
    <VCard title="Absence Details" style="max-width: 350px; width: 100%;">
      <div style="margin-bottom: 1.5rem;">
        <div style="font-size: 1.1rem; font-weight: 800; margin-bottom: 0.5rem; color: var(--primary);">
          {{ selectedAbsence?.title }}
        </div>
        <div class="text-sm" style="color: var(--text-secondary); margin-bottom: 1rem;">
          Caregiver: <strong>{{ selectedAbsence?.user_alias || selectedAbsence?.user_name }}</strong>
        </div>
        
        <div style="background: var(--bg-color); padding: 0.8rem; border-radius: 12px; border: 1px solid var(--card-border);">
          <div class="text-xs" style="text-transform: uppercase; color: var(--text-secondary); margin-bottom: 0.4rem;">Timeframe</div>
          <div style="font-weight: 600; font-size: 0.9rem;">
            {{ new Date(selectedAbsence?.start_time).toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) }}
            <br/>to<br/>
            {{ new Date(selectedAbsence?.end_time).toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) }}
          </div>
        </div>
      </div>

      <div style="display:flex; flex-direction: column; gap: 0.8rem;">
        <VButton v-if="selectedAbsence?.user_id == familyStore.profile?.id || role === 'caregiver'"
                 type="danger" block @click="removeAbsence">Remove Absence</VButton>
        <VButton type="secondary" block @click="showAbsenceDetailModal = false">Close</VButton>
      </div>
    </VCard>
  </div>

  <div v-if="showAcceptBountyModal" class="modal-overlay">
    <VCard title="Claim task" style="max-width: 350px; width: 100%;">
      <p class="text-sm" style="color: var(--text-secondary); margin-bottom: 1.5rem; line-height: 1.4;">
        Take over <strong>{{ acceptBountyTarget?.title }}</strong> and earn
        <strong>🪙 {{ acceptBountyTarget?.bounty_amount }}cc</strong>. These coins transfer from the original caregiver to you immediately.
      </p>
      <div style="display:flex; justify-content: flex-end; gap: 1rem;">
        <VButton type="secondary" @click="showAcceptBountyModal = false; acceptBountyTarget = null">Cancel</VButton>
        <VButton type="primary" @click="confirmAcceptBounty">Claim task</VButton>
      </div>
    </VCard>
  </div>

</template>

<style scoped>
.modal-overlay {
  z-index: 10000 !important;
}

.daily-fullscreen-overlay {
  position: fixed;
  inset: 0;
  background: var(--bg-color); /* fully opaque solid background to cover dashboard */
  z-index: 9999;
  display: flex;
  justify-content: center;
  align-items: flex-start; /* THIS IS THE KEY FIX: prevent vertical centering from pushing content off the top of the monitor */
  padding: 4rem 2rem;
  overflow-y: auto;
}

.daily-wrapper {
  background: transparent;
  border: none;
  width: 100%;
  max-width: 1080px;
  min-height: 80vh;
  margin: 0 auto;
}

.daily-grid {
  display: grid;
  grid-template-columns: 320px 1fr;
  gap: 2rem;
  align-items: stretch;
  min-height: 70vh;
}

.log-off-btn {
  background: rgba(var(--primary-rgb), 0.1);
  color: var(--primary);
  border: 1px solid var(--primary);
  padding: 0.4rem 1rem;
  border-radius: 999px;
  font-size: 0.85rem;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.2s;
}
.log-off-btn:hover {
  background: var(--primary);
  color: white;
}

.absence-banner-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  padding: 0.8rem 1rem;
  background: var(--bg);
  border-bottom: 1px solid var(--border);
}

.absence-indicator {
  background: var(--surface);
  border: 1px solid var(--border);
  padding: 0.3rem 0.8rem;
  border-radius: var(--r-pill);
  font-size: 0.8rem;
  color: var(--text-primary);
  cursor: pointer;
  box-shadow: 0 1px 3px rgba(14,23,38,0.05);
  transition: transform 0.1s;
}
.absence-indicator:hover {
  transform: translateY(-1px);
  border-color: var(--primary);
}

.modal-label {
  display: block;
  margin-bottom: 0.4rem;
  color: var(--text-primary);
  font-size: 0.9rem;
  font-weight: 600;
}

.modal-input {
  width: 100%;
  padding: 0.75rem;
  border-radius: var(--radius-button);
  font-size: 1rem;
  background: var(--input-bg);
  color: var(--text-primary);
  border: 1px solid var(--input-border);
  outline: none;
}

.col-card {
  display: flex;
  flex-direction: column;
  position: sticky;
  top: 2rem;
  height: calc(100vh - 4rem); /* Occupy full viewport height minus padding */
}

.col-card :deep(.v-card-body) {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-height: 0;
}

.template-grid {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  flex: 1;
  overflow-y: auto;
  padding-right: 0.5rem;
  padding-bottom: 1rem;
}
.template-grid::-webkit-scrollbar {
  width: 6px;
}
.template-grid::-webkit-scrollbar-track {
  background: transparent;
}
.template-grid::-webkit-scrollbar-thumb {
  background-color: var(--border);
  border-radius: 10px;
}
.task-template-row {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r-md);
  padding: 0.8rem 1rem;
  cursor: grab;
  transition: transform 0.1s, box-shadow 0.15s;
  display: flex;
  align-items: center;
  gap: 0.8rem;
  text-align: left;
}
.task-template-row:hover { box-shadow: 0 4px 12px rgba(14,23,38,0.08); }
.task-template-row:active {
  cursor: grabbing;
  transform: scale(0.98);
  background: var(--primary-soft);
  border-color: var(--primary);
}

.agenda-card {
  min-height: 600px;
}

.timeline-container {
  flex: 1;
  position: relative;
  min-height: 800px;
  background: var(--bg);
  overflow: hidden;
}
.h-line {
  flex: 1;
  display: flex;
  align-items: flex-start;
}
.h-label {
  width: 60px;
  font-size: 0.75rem;
  color: var(--text-secondary);
  padding-left: 0.5rem;
  padding-top: 0.2rem;
}
.h-border {
  flex: 1;
  border-top: 1px dashed var(--border);
}

.scheduled-chip {
  border-radius: var(--r-md);
  padding: 0.6rem 1.2rem;
  box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1);
  z-index: 10;
  display: flex;
  flex-direction: row;
  justify-content: space-between;
  align-items: center;
  overflow: hidden;
  box-sizing: border-box;
  cursor: grab;
  transition: transform 0.1s, box-shadow 0.2s;
}
.scheduled-chip:hover {
  z-index: 50 !important;
}
.scheduled-chip:active {
  cursor: grabbing;
  transform: scale(0.98);
}
.validate-btn {
  background: var(--primary-soft); border: 1px solid var(--primary); color: var(--primary);
  border-radius: var(--r-sm); cursor: pointer; font-size: 0.7rem; font-weight: 700;
  padding: 4px 8px; transition: background 0.2s, color 0.2s;
}
.validate-btn:hover { background: var(--primary); color: #fff; }

.confetti-bg {
  background-image: radial-gradient(var(--primary-soft) 1px, transparent 1px), radial-gradient(var(--success-soft) 1px, transparent 1px);
  background-size: 20px 20px;
  background-position: 0 0, 10px 10px;
}
.completed-chip {
  background: var(--surface);
  border-radius: var(--r-md);
  padding: 1rem 1.2rem;
  margin-bottom: 1rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border: 1px solid var(--border);
  box-shadow: 0 1px 2px rgba(14,23,38,0.04);
}
.mock-check {
  background: var(--success); color: white; width: 30px; height: 30px; border-radius: 50%; display: flex; align-items:center; justify-content:center; font-weight:bold; font-size:1.2rem;
}
.daily-tallies {
  margin-top: auto;
  text-align: center;
  background: var(--text-primary);
  padding: 1.25rem 1rem;
  border-radius: var(--r-md);
  box-shadow: 0 4px 12px rgba(14,23,38,0.12);
}

.empty-pill {
  color: var(--text-primary); background: var(--input-bg); border: 1px solid var(--input-border);
  padding: 0.8rem 1.5rem; border-radius: 999px; text-align: center; font-size: 1rem; margin: 1rem auto; font-weight: 600;
  width: max-content;
}

.date-display {
  color: var(--primary);
  font-size: 1.5rem;
  display: block;
  line-height: 1.2;
  min-width: 160px;
  text-align: center;
}

@keyframes skeleton-shimmer {
  0%   { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

.skeleton-card {
  height: 100px;
  border-radius: 16px;
  background: linear-gradient(90deg, var(--border) 25%, var(--bg) 50%, var(--border) 75%);
  background-size: 200% 100%;
  animation: skeleton-shimmer 1.4s ease-in-out infinite;
  margin-bottom: 1rem;
  flex-shrink: 0;
}

@media (prefers-reduced-motion: reduce) {
  .skeleton-card {
    animation: none;
    background: var(--border);
  }
  .scheduled-chip,
  .task-template-row,
  .daily-back-fab,
  .mobile-remove-btn,
  .log-off-btn,
  .date-nav-btn {
    transition: none;
  }
  .daily-back-fab:hover,
  .task-template-row:active,
  .daily-back-fab:active {
    transform: none;
  }
}

@media (max-width: 768px) {
  .date-display {
    min-width: 0;
    font-size: 1.2rem;
  }
}

.mobile-timeline {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  padding: 0.75rem 1rem calc(56px + env(safe-area-inset-bottom, 0px) + 1rem);
  display: flex;
  flex-direction: column;
}
.tl-list {
  display: flex;
  flex-direction: column;
  gap: 0;
  width: 100%;
}
.tl-row {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
  width: 100%;
}
.tl-row-time {
  width: 52px;
  flex-shrink: 0;
  font-size: 0.72rem;
  font-weight: 700;
  color: var(--text-secondary);
  padding-top: 0.6rem;
  text-align: right;
  line-height: 1.2;
}
.tl-card {
  flex: 1;
  border-radius: var(--r-md);
  padding: 0.65rem 0.85rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.12);
  box-sizing: border-box;
  -webkit-tap-highlight-color: transparent;
}
.tl-card-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  min-width: 0;
}
.tl-card-emoji { font-size: 1.1rem; flex-shrink: 0; }
.tl-card-title-block { flex: 1; min-width: 0; }
.tl-card-title {
  font-weight: 800;
  font-size: 0.9rem;
  line-height: 1.3;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.tl-card-meta {
  font-size: 0.72rem;
  font-weight: 700;
  opacity: 0.85;
  display: flex;
  align-items: center;
  gap: 0.3rem;
  margin-top: 0.15rem;
}
.tl-bounty-chip {
  background: rgba(255,255,255,0.2);
  padding: 1px 5px;
  border-radius: 999px;
}
.tl-card--on-surface .tl-bounty-chip {
  background: var(--primary-soft);
  color: var(--primary);
}
.tl-card--on-surface .tl-card-footer {
  border-top: 1px solid var(--border);
}
.tl-card-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 0.4rem;
  border-top: 1px solid rgba(255,255,255,0.15);
}
.tl-card-assignee {
  font-size: 0.75rem;
  font-weight: 700;
  opacity: 0.85;
}
.tl-card-actions {
  display: flex;
  align-items: center;
  gap: 0.4rem;
}
.tl-gap {
  text-align: center;
  font-size: 0.72rem;
  font-weight: 700;
  color: var(--text-secondary);
  padding: 0.4rem 0;
  padding-left: calc(52px + 0.75rem);
  opacity: 0.7;
}
.tl-now-divider {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  margin: 0.5rem 0 0.75rem;
  width: 100%;
  padding-left: calc(52px + 0.75rem); /* align with card left edge */
  box-sizing: border-box;
}
.tl-now-divider-line {
  flex: 1;
  height: 2px;
  background: var(--danger);
  border-radius: 999px;
  opacity: 0.7;
}
.tl-now-divider-label {
  font-size: 0.7rem;
  font-weight: 800;
  color: var(--danger);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  flex-shrink: 0;
}

/* ---- Mobile bottom bar ---- */
.mobile-bottom-bar {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  height: calc(56px + env(safe-area-inset-bottom, 0px));
  padding-bottom: env(safe-area-inset-bottom, 0px);
  background: var(--surface);
  border-top: 1px solid var(--border);
  box-shadow: 0 -4px 16px rgba(14,23,38,0.06);
  z-index: 9998;
  align-items: center;
  gap: 0.75rem;
  padding-left: 1rem;
  padding-right: 0.75rem;
  box-sizing: border-box;
}
.mobile-bottom-back {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: var(--primary);
  border: none;
  color: #fff;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  box-shadow: 0 2px 8px rgba(37,99,235,0.3);
  transition: transform 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}
.mobile-bottom-back:active { transform: scale(0.92); }

.mobile-bottom-add {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: var(--success);
  color: #fff;
  border: none;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  box-shadow: 0 2px 8px rgba(0,0,0,0.15);
  transition: transform 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}
.mobile-bottom-add:active { transform: scale(0.92); }
@media (prefers-reduced-motion: reduce) {
  .mobile-bottom-add, .mobile-bottom-back { transition: none; }
  .mobile-bottom-back:active { transform: none; }
}

/* ---- Task Bottom Sheet ---- */
.task-sheet-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.45);
  z-index: 10001;
  display: flex;
  align-items: flex-end;
}
.task-sheet {
  width: 100%;
  max-height: 65vh;
  background: var(--surface);
  border-radius: var(--r-lg) var(--r-lg) 0 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  padding-bottom: env(safe-area-inset-bottom, 0px);
  animation: sheet-slide-up 0.22s ease-out;
}
.task-sheet-handle {
  width: 36px;
  height: 4px;
  background: var(--border);
  border-radius: 999px;
  margin: 0.75rem auto 0;
  flex-shrink: 0;
}
.task-sheet-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.6rem 1rem 0.4rem;
  flex-shrink: 0;
}
.task-sheet-list {
  flex: 1;
  overflow-y: auto;
  padding: 0 0 1rem;
}
@keyframes sheet-slide-up {
  from { transform: translateY(100%); }
  to   { transform: translateY(0); }
}
@media (prefers-reduced-motion: reduce) {
  .task-sheet { animation: none; }
  .tl-hour-label { transition: none; }
  .task-sheet-fab { transition: none; }
  .task-sheet-fab:hover, .task-sheet-fab:active { transform: none; }
  .bs-overlay :deep(.v-card) { animation: none; }
}

/* ── Card swipe-to-delete ───────────────────────────────── */
.tl-row {
  overflow: hidden;
  border-radius: var(--r-md);
  transition: background 0.15s;
}
.tl-row--swiping {
  background: var(--danger-soft);
}
.tl-row--dismissing {
  background: var(--danger-soft);
}
.tl-card--dismiss {
  transform: translateX(-110%) !important;
  opacity: 0 !important;
  transition: transform 0.26s ease-out, opacity 0.2s ease-out !important;
}
@media (prefers-reduced-motion: reduce) {
  .tl-card--dismiss { transition: opacity 0.2s ease-out !important; transform: none !important; }
  .tl-row { transition: none; }
}

/* ── Bottom-sheet modals (mobile only) ──────────────────── */
.sheet-handle-bar { display: none; }

@media (max-width: 768px) {
  .bs-overlay {
    align-items: flex-end !important;
    padding: 0 !important;
  }
  .bs-overlay :deep(.v-card) {
    width: 100% !important;
    max-width: 100% !important;
    border-radius: 20px 20px 0 0 !important;
    padding-bottom: env(safe-area-inset-bottom, 0px) !important;
    animation: sheet-slide-up 0.22s ease-out;
  }
  .sheet-handle-bar {
    display: block;
    width: 36px;
    height: 4px;
    background: var(--border);
    border-radius: 999px;
    margin: 0 auto 1.25rem;
  }
}

.mobile-empty-state {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 1.5rem;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.mobile-empty-state:active .empty-state-icon {
  background: var(--primary-soft);
  opacity: 0.7;
}
.empty-state-icon {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  background: var(--primary-soft);
  color: var(--primary);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 1.25rem;
  transition: opacity 0.15s;
}
.empty-state-title {
  font-size: 1.05rem;
  font-weight: 800;
  color: var(--text-primary);
  display: block;
  margin-bottom: 0.35rem;
}
.empty-state-sub {
  font-size: 0.85rem;
  color: var(--text-secondary);
  font-weight: 500;
}

.completed-bar-label {
  display: none;
  font-size: 0.7rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--text-secondary);
  flex-basis: 100%;
  margin-bottom: 0.25rem;
}

.category-divider {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-top: 1rem;
  font-size: 0.8rem;
  font-weight: 700;
  color: var(--text-secondary);
}

.category-pip {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

@media (max-width: 768px) {
  .completed-bar-label {
    display: block;
  }
  .completed-bar {
    flex-wrap: wrap;
    align-items: flex-start;
  }
}

.mobile-remove-btn {
  background: rgba(0,0,0,0.2);
  border: none;
  color: #fff;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  flex-shrink: 0;
  transition: background 0.15s;
  -webkit-tap-highlight-color: transparent;
}
.mobile-remove-btn:active {
  background: rgba(0,0,0,0.4);
}

.daily-back-fab {
  position: fixed;
  bottom: calc(2rem + env(safe-area-inset-bottom, 0px));
  left: 2rem;
  z-index: 9998;
  width: 52px;
  height: 52px;
  border-radius: 50%;
  background: var(--primary);
  color: #fff;
  border: none;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.daily-back-fab:hover {
  transform: scale(1.1);
  box-shadow: 0 6px 28px rgba(0, 0, 0, 0.32);
}
.daily-back-fab:active {
  transform: scale(0.95);
}

.date-nav-btn {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 50%;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  color: var(--text-primary);
  transition: all 0.2s;
}
.date-nav-btn:hover {
  background: var(--border);
}

.day-progress {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.3rem;
  margin-top: 0.25rem;
}
.day-progress-bar {
  width: 120px;
  height: 6px;
  background: var(--border);
  border-radius: var(--r-pill);
  overflow: hidden;
}
.day-progress-fill {
  height: 100%;
  background: var(--success);
  border-radius: var(--r-pill);
  transition: width 0.4s ease;
}
.day-progress-label {
  font-size: 0.8rem;
  font-weight: 700;
  color: var(--text-secondary);
}
@media (prefers-reduced-motion: reduce) {
  .day-progress-fill { transition: none; }
}

.daily-header-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
}
.daily-header-left {
  display: flex;
  align-items: center;
  gap: 1.5rem;
}
.daily-header-right {
  text-align: right;
}

.timeline-col {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
  flex: 1;
}

@media (max-width: 768px) {
  .daily-header-row {
    flex-direction: column;
    align-items: flex-start;
    gap: 1rem;
  }
  .daily-header-left {
    flex-wrap: wrap;
    gap: 1rem;
  }
  .daily-header-right {
    text-align: left;
  }
  .daily-grid {
    grid-template-columns: 1fr;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  .timeline-col {
    gap: 0.8rem;
  }
  .col-card {
    display: none;
  }
  .completed-bar {
    flex-wrap: nowrap;
    overflow-x: auto;
    scrollbar-width: none;
  }
  .completed-bar::-webkit-scrollbar { display: none; }
  .agenda-card {
    min-height: auto;
    margin-bottom: 0 !important;
  }
  .agenda-card :deep(.v-card-title) {
    display: none;
  }
  .timeline-container {
    overflow-x: auto;
  }
  .timeline-inner {
    min-width: 600px;
    height: 100%;
    position: relative;
  }
  .daily-fullscreen-overlay {
    padding: 1rem 0.5rem calc(56px + env(safe-area-inset-bottom, 0px) + 1rem);
  }
  .daily-back-fab {
    display: none;
  }
}
</style>
