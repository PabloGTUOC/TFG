<script setup>
import { ref, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { useFamilyStore } from '../stores/family';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';

const appStore = useAuthStore();
const familyStore = useFamilyStore();
const route = useRoute();
const router = useRouter();

const closeDailyView = () => {
  router.push('/dashboard');
};

// Extract the date param (e.g. '2026-03-24')
const targetDateStr = computed(() => route.params.date);
const targetDate = computed(() => {
  const [y, m, d] = targetDateStr.value.split('-');
  return new Date(y, m - 1, d);
});

const isToday = computed(() => new Date().toLocaleDateString() === targetDate.value.toLocaleDateString());
const scheduledTitle = computed(() => isToday.value ? 'Scheduled for Today' : `Schedule for ${targetDate.value.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`);

const familyActivities = ref([]);

const showScheduleModal = ref(false);
const scheduleForm = ref({ activityId: '', time: '' });

const scheduleHour = ref('06');
const scheduleMinute = ref('00');

const showRecurrenceModal = ref(false);
const recurrenceForm = ref({ activityId: '', title: '', frequency: 'daily', untilDate: '' });

const showDeleteModal = ref(false);
const deleteTarget = ref(null);

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

const getFamilyId = () => familyStore.families?.[0]?.family_id || familyStore.families?.[0]?.id;

const loadActivities = () => appStore.runAction(async () => {
  const fid = getFamilyId();
  if (!fid) return;
  const activitiesData = await appStore.request(`/api/activities?familyId=${fid}`, { headers: appStore.authHeaders() });
  familyActivities.value = activitiesData.activities || [];
}, 'Daily layout loaded.');

watch(() => targetDateStr.value, () => loadActivities(), { immediate: true });

// Column 1: Unscheduled Templates
const availableTemplates = computed(() => {
  return familyActivities.value.filter(a => a.is_template && a.status === 'approved');
});

const START_HOUR = 6;
const TOTAL_HOURS = 18;

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
    const endA = startA + (a.duration_minutes * 60000);

    let overlapCount = 0;
    for (let j = 0; j < i; j++) {
      const b = positionedActs[j];
      const startB = new Date(b.starts_at).getTime();
      const endB = startB + (b.duration_minutes * 60000);
      if (Math.max(startA, startB) < Math.min(endA, endB)) {
        overlapCount++;
      }
    }

    let d = new Date(a.starts_at);
    let hour = d.getHours() + d.getMinutes() / 60;
    let topP = ((Math.max(START_HOUR, hour) - START_HOUR) / TOTAL_HOURS) * 100;
    
    let visibleHours = Math.min(a.duration_minutes / 60, 24 - Math.max(START_HOUR, hour));
    let heightP = (visibleHours / TOTAL_HOURS) * 100;
    
    const indentMultiplier = Math.min(overlapCount, 4);
    const leftPx = 70 + (indentMultiplier * 30);
    const widthPx = `calc(100% - ${leftPx + 10}px)`;
    const shadowIntensity = 0.2 + (indentMultiplier * 0.1);

    positionedActs.push({
      ...a,
      overlapCount,
      _style: {
        position: 'absolute',
        top: `${topP}%`,
        height: `${Math.max(3, heightP)}%`,
        minHeight: '60px',
        left: `${leftPx}px`,
        width: widthPx,
        zIndex: 10 + overlapCount,
        boxShadow: overlapCount > 0 ? `-5px 5px 15px rgba(0,0,0,${shadowIntensity})` : '0 4px 15px rgba(0,0,0,0.2)'
      }
    });
  }
  
  return positionedActs;
});

// Column 3: Completed Today
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

// Drag & Drop Mechanics
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
  } catch(e) {}
};

const dropOnTimeline = (event) => {
  event.preventDefault();
  const j = event.dataTransfer.getData('text/plain');
  if (!j) return;
  
  try {
    const payload = JSON.parse(j);
    // Calc vertical drop %
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
  } catch(e) {}
};

const confirmSchedule = async () => {
  const hh = scheduleHour.value;
  const mm = scheduleMinute.value;
  const d = new Date(targetDate.value);
  d.setHours(Number(hh), Number(mm), 0, 0);

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
  <div class="daily-fullscreen-overlay" @click.self="closeDailyView">
    <div class="daily-wrapper" @dragover.prevent @drop.prevent="dropOut($event)">
      <div style="display:flex; justify-content: space-between; align-items: center; margin-bottom: 2rem;">
      <h2 style="color: #fff; margin: 0;">Activities and Task Board</h2>
      <strong style="color: #e2e8f0;">{{ new Date(targetDate).toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' }) }}</strong>
    </div>

    <!-- 3 Column Layout -->
    <div class="daily-grid">
      
      <!-- COL 1: Available Activities -->
      <VCard title="Available Activities" class="col-card">
         <p class="text-sm" style="color: var(--text-secondary); margin-bottom: 1rem;">Drag items off the timeline to unschedule</p>
         <div class="template-grid">
           <div v-for="a in availableTemplates" :key="a.id" class="mock-gradient-pill" draggable="true" @dragstart="dragStart($event, a)">
              <strong class="text-lg" style="color: #1e293b; display: block; margin-bottom: 0.5rem;">{{ a.title }}</strong>
              <div class="text-xs" style="color: #475569; margin-bottom: 1rem; display: flex; align-items: center; justify-content: center; gap: 0.4rem;">
                <span>🕒 {{ a.duration_minutes || a.durationMinutes || 0 }}m</span>
                <span>•</span>
                <span>🪙 {{ a.coin_value }}cc</span>
              </div>
              <button class="mock-btn" style="background:#7c3aed; color:#fff;">Claim</button>
           </div>
         </div>
      </VCard>

      <!-- COL 2: Scheduled Timeline -->
      <VCard :title="scheduledTitle" class="col-card" style="padding: 0;">
         <div class="timeline-container" @dragover.prevent @drop.prevent.stop="dropOnTimeline($event)">
            <!-- Draw 18 hr lines -->
            <div class="hour-lines" style="position: absolute; width: 100%; height: 100%; display: flex; flex-direction: column;">
               <div v-for="h in 19" :key="h" class="h-line">
                 <span class="h-label">{{ (h+5) > 12 ? (h+5)-12 : (h+5) }}:00 {{ (h+5) >= 12 ? 'PM' : 'AM' }}</span>
                 <div class="h-border"></div>
               </div>
            </div>

            <!-- Absolute positioned chips -->
             <div v-for="a in scheduledToday" :key="a.id"
                  :style="[a._style, a.is_recurrent && a.status !== 'completed' ? { cursor: 'pointer' } : {}]"
                  :class="['scheduled-chip', a.status === 'pending_validation' ? 'gradient-orange' : (a.status === 'completed' ? 'gradient-green' : 'gradient-pink')]" 
                  :draggable="a.status !== 'completed'" @dragstart="a.status !== 'completed' ? dragStartScheduled($event, a) : null"
                  @click="a.is_recurrent && a.status !== 'completed' ? openRecurrenceModal(a) : null">
               <strong class="text-sm" style="display:block; margin-bottom: 2px; line-height: 1.2;">
                 {{ a.title }}
                 <span v-if="a.is_recurrent" title="Click to schedule future recurrences" style="font-size: 0.85rem; margin-left: 0.3rem;">🔁</span>
               </strong>
               
               <div style="display: flex; flex-wrap: wrap; justify-content: space-between; align-items: flex-end; width: 100%; margin-top: auto; padding-top: 4px; gap: 0.4rem;">
                <div class="text-xs" style="opacity: 0.9;">{{ a.assigned_alias || 'Unclaimed' }}</div>
                
                <div v-if="a.status === 'pending_validation'" style="display: flex; align-items: center; gap: 0.4rem;">
                  <span class="text-xs" style="font-weight: bold; color: #fef08a;">⏳ Pending Validation</span>
                  <button v-if="a.assigned_to !== familyStore.profile?.id && familyStore.profile?.actor_type === 'caregiver'" @click.stop="validateActivity(a.id)" class="validate-btn">✓ Validate</button>
                </div>
                <div v-else-if="a.status === 'completed'" class="text-xs" style="font-weight: bold; padding-bottom: 1px;">
                  ✓ Completed
                </div>
              </div>
            </div>
         </div>
      </VCard>

      <!-- COL 3: Completed -->
      <VCard title="Completed" class="col-card">
         <div v-for="a in completedToday" :key="a.id" class="completed-chip ui-gradient">
            <div>
              <strong class="text-base" style="color:#1e293b;">{{ a.title }}</strong>
              <div class="text-xs" style="color:#475569;">{{ a.duration_minutes || a.durationMinutes || 0 }}m - 🪙 {{ a.coin_value }}cc</div>
            </div>
            <div class="mock-check">✔</div>
         </div>

         <div v-if="completedToday.length === 0" class="empty-pill">
            Nothing finished yet today.
         </div>

         <div class="daily-tallies">
            <div class="text-sm" style="color: #94a3b8; margin-bottom: 0.3rem;">Great job everyone!</div>
            <div class="text-xl" style="font-weight: 700; color: #f8fafc;">Total coins earned this day: <span style="color: #fbbf24;">{{ todayCoins }}cc</span></div>
         </div>
      </VCard>

    </div>
    </div>
  </div>

  <!-- Recurrence Modal -->
  <div v-if="showRecurrenceModal" class="modal-overlay">
    <VCard title="Schedule Future Copies" style="max-width: 350px; width: 100%;">
      <p class="text-sm" style="color: var(--text-secondary); margin-bottom: 1.5rem; line-height: 1.4;">
        Repeat <strong>{{ recurrenceForm.title }}</strong> at this time into the future.
      </p>
      <div style="margin-bottom: 1.2rem;">
        <label style="display:block; margin-bottom: 0.5rem; color: #fff; font-size: 0.95rem;">Frequency:</label>
        <select v-model="recurrenceForm.frequency" style="width: 100%; padding: 0.75rem; border-radius: 8px; font-size: 1rem; background: #1e293b; color: #fff; border: 1px solid #334155; outline: none;">
          <option value="daily">Every Day</option>
          <option value="weekdays">Every Working Day (Mon-Fri)</option>
          <option value="weekly">Every Week (same day)</option>
        </select>
      </div>
      <div style="margin-bottom: 1.8rem;">
        <label style="display:block; margin-bottom: 0.5rem; color: #fff; font-size: 0.95rem;">Until Date:</label>
        <input type="date" v-model="recurrenceForm.untilDate" style="width: 100%; padding: 0.75rem; border-radius: 8px; font-size: 1rem; background: #1e293b; color: #fff; border: 1px solid #334155; outline: none; color-scheme: dark;" />
      </div>
      <div style="display:flex; justify-content: flex-end; gap: 1rem;">
        <VButton type="secondary" @click="showRecurrenceModal = false">Cancel</VButton>
        <VButton type="primary" @click="confirmRecurrence">Generate</VButton>
      </div>
    </VCard>
  </div>

  <!-- Time Modal -->
  <div v-if="showScheduleModal" class="modal-overlay">
    <VCard title="Confirm Time" style="max-width: 320px; width: 100%;">
      <div style="margin-bottom: 1.5rem;">
        <label style="display:block; margin-bottom: 0.75rem; color: #fff; font-size: 1.1rem; font-weight: 600;">Starting at...</label>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <select v-model="scheduleHour" style="flex: 1; padding: 0.75rem; border-radius: 8px; font-size: 1.2rem; background: #1e293b; color: #fff; border: 1px solid #334155; text-align: center; appearance: none; outline: none;">
            <option v-for="h in 24" :key="h-1" :value="String(h-1).padStart(2, '0')">{{ String(h-1).padStart(2, '0') }}</option>
          </select>
          <span style="font-size: 1.5rem; color: #fff; font-weight: bold;">:</span>
          <select v-model="scheduleMinute" style="flex: 1; padding: 0.75rem; border-radius: 8px; font-size: 1.2rem; background: #1e293b; color: #fff; border: 1px solid #334155; text-align: center; appearance: none; outline: none;">
            <option value="00">00</option>
            <option value="30">30</option>
          </select>
        </div>
      </div>
      <div style="display:flex; justify-content: flex-end; gap: 1rem;">
        <VButton type="secondary" @click="showScheduleModal = false">Nope</VButton>
        <VButton type="primary" @click="confirmSchedule">Yes I'll</VButton>
      </div>
    </VCard>
  </div>

  <!-- Delete Modal -->
  <div v-if="showDeleteModal" class="modal-overlay">
    <VCard title="Delete Recurring Activity" style="max-width: 350px; width: 100%;">
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

</template>

<style scoped>
.daily-fullscreen-overlay {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.85);
  backdrop-filter: blur(8px);
  z-index: 100;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 2rem;
  overflow-y: auto;
}

.daily-wrapper {
  background: #0f172a;
  border: 1px solid #1e293b;
  border-radius: 20px;
  width: 100%;
  max-width: 1400px;
  min-height: 80vh;
  padding: 2rem;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
}

.daily-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 1.5rem;
  align-items: stretch;
  min-height: 70vh;
}

.col-card {
  display: flex;
  flex-direction: column;
}

/* Template Grid (Col 1) */
.template-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}
.mock-gradient-pill {
  background: linear-gradient(135deg, #e0f2fe, #d8b4fe);
  border-radius: 12px;
  padding: 1rem;
  box-shadow: 0 4px 10px rgba(0,0,0,0.05);
  cursor: grab;
  transition: transform 0.1s;
  text-align: center;
}
.mock-gradient-pill:active { cursor: grabbing; transform: scale(0.95); }
.mock-btn {
  width: 100%; border:none; padding: 0.75rem; border-radius: 999px; font-weight:700; cursor:pointer; transition: opacity 0.2s;
}
.mock-btn:hover { opacity: 0.9; }

/* Timeline (Col 2) */
.timeline-container {
  flex: 1;
  position: relative;
  min-height: 800px;
  background: #f8fafc;
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
  color: #94a3b8;
  padding-left: 0.5rem;
  padding-top: 0.2rem;
}
.h-border {
  flex: 1;
  border-top: 1px dashed #e2e8f0;
}

.gradient-pink {
  background: linear-gradient(to right, #a855f7, #ec4899);
}
.gradient-orange {
  background: linear-gradient(to right, #f97316, #eab308);
}
.gradient-green {
  background: linear-gradient(to right, #10b981, #059669);
}
.scheduled-chip {
  border-radius: 8px;
  color: #fff;
  padding: 0.6rem 1rem;
  box-shadow: 0 4px 15px rgba(0,0,0,0.2);
  z-index: 10;
  display: flex;
  flex-direction: column;
  justify-content: flex-start;
  align-items: flex-start;
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
  background: rgba(255,255,255,0.25); border: none; color: #fff;
  border-radius: 4px; cursor: pointer; font-size: 0.7rem; font-weight: 600;
  padding: 4px 8px; transition: background 0.2s;
}
.validate-btn:hover { background: rgba(255,255,255,0.45); }

/* Completed (Col 3) */
.confetti-bg {
  background-image: radial-gradient(#bae6fd 1px, transparent 1px), radial-gradient(#d8b4fe 1px, transparent 1px);
  background-size: 20px 20px;
  background-position: 0 0, 10px 10px;
}
.completed-chip {
  background: linear-gradient(135deg, #e0f2fe, #d8b4fe);
  border-radius: 12px;
  padding: 1rem 1.2rem;
  margin-bottom: 1rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-shadow: 0 4px 10px rgba(0,0,0,0.05);
}
.mock-check {
  background: #10b981; color: white; width: 30px; height: 30px; border-radius: 50%; display: flex; align-items:center; justify-content:center; font-weight:bold; font-size:1.2rem;
}
.daily-tallies {
  margin-top: auto;
  text-align: center;
  background: #1e293b;
  padding: 1.25rem 1rem;
  border-radius: 16px;
  box-shadow: 0 10px 25px rgba(0,0,0,0.1);
}

.empty-pill {
  color: #fff; background: rgba(30, 41, 59, 0.8); backdrop-filter: blur(8px);
  padding: 0.8rem 1.5rem; border-radius: 999px; text-align: center; font-size: 1rem; margin: 2rem auto; font-weight: 500;
  width: max-content;
}

.modal-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 1000;
  display: flex; align-items: center; justify-content: center;
}
</style>
