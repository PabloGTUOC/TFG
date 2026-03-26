<script setup>
import { ref, computed, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { useFamilyStore } from '../stores/family';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';

const appStore = useAuthStore();
const familyStore = useFamilyStore();
const route = useRoute();

// Extract the date param (e.g. '2026-03-24')
const targetDateStr = computed(() => route.params.date);
const targetDate = computed(() => {
  const [y, m, d] = targetDateStr.value.split('-');
  return new Date(y, m - 1, d);
});

const familyActivities = ref([]);

const showScheduleModal = ref(false);
const scheduleForm = ref({ activityId: '', time: '' });

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

// Column 2: Scheduled on this date (06:00 to 24:00 math)
const START_HOUR = 6;
const TOTAL_HOURS = 18;

const scheduledToday = computed(() => {
  const acts = familyActivities.value.filter(a => {
    if (a.is_template || !a.starts_at || a.status === 'completed') return false;
    const d = new Date(a.starts_at);
    return d.getFullYear() === targetDate.value.getFullYear() &&
           d.getMonth() === targetDate.value.getMonth() &&
           d.getDate() === targetDate.value.getDate();
  });
  
  // Compute absolute vertical CSS
  return acts.map(a => {
    let d = new Date(a.starts_at);
    let hour = d.getHours() + d.getMinutes() / 60;
    let topP = ((Math.max(START_HOUR, hour) - START_HOUR) / TOTAL_HOURS) * 100;
    
    let visibleHours = Math.min(a.duration_minutes / 60, 24 - Math.max(START_HOUR, hour));
    let heightP = (visibleHours / TOTAL_HOURS) * 100;
    
    return {
      ...a,
      _style: {
        position: 'absolute',
        top: `${topP}%`,
        height: `${Math.max(3, heightP)}%`,
        left: '5%',
        width: '90%'
      }
    };
  });
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
    scheduleForm.value.time = `${String(hh).padStart(2,'0')}:${mm}`;
    showScheduleModal.value = true;
  } catch(e) {}
};

const confirmSchedule = async () => {
  const [hh, mm] = scheduleForm.value.time.split(':');
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

const markCompleted = (aid) => appStore.runAction(async () => {
  await appStore.request(`/api/activities/${aid}`, {
    method: 'PATCH',
    headers: appStore.authHeaders(),
    body: JSON.stringify({ status: 'completed' })
  });
  await loadActivities();
  appStore.setSuccess('Activity marked as completed! Coins awarded!');
});

</script>

<template>
  <div class="daily-wrapper">
    <div style="display:flex; justify-content: space-between; align-items: center; margin-bottom: 2rem;">
      <h2 style="color: #fff; margin: 0;">Activities and Task Board</h2>
      <strong style="color: #e2e8f0;">{{ new Date(targetDate).toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' }) }}</strong>
    </div>

    <!-- 3 Column Layout -->
    <div class="daily-grid">
      
      <!-- COL 1: Available Activities -->
      <VCard title="Available Activities" class="col-card">
         <p style="font-size: 0.85rem; color: var(--text-secondary); margin-bottom: 1rem;">Drag to schedule</p>
         <div class="template-grid">
           <div v-for="a in availableTemplates" :key="a.id" class="mock-gradient-pill" draggable="true" @dragstart="dragStart($event, a)">
              <strong style="font-size: 1.1rem; color: #1e293b; display: block; margin-bottom: 0.5rem;">{{ a.title }}</strong>
              <div style="font-size: 0.8rem; color: #475569; margin-bottom: 1rem;">
                🕒 {{ a.durationMinutes }}m • 🪙 {{ a.coin_value }}cc
              </div>
              <button class="mock-btn disable-pointer" style="background:#7c3aed; color:#fff;">Claim</button>
           </div>
         </div>
      </VCard>

      <!-- COL 2: Scheduled Timeline -->
      <VCard title="Scheduled for Today" class="col-card" style="padding: 0;">
         <div class="timeline-container" @dragover.prevent @drop.prevent.stop="dropOnTimeline($event)">
            <!-- Draw 18 hr lines -->
            <div class="hour-lines" style="position: absolute; width: 100%; height: 100%; display: flex; flex-direction: column;">
               <div v-for="h in 19" :key="h" class="h-line">
                 <span class="h-label">{{ (h+5) > 12 ? (h+5)-12 : (h+5) }}:00 {{ (h+5) >= 12 ? 'PM' : 'AM' }}</span>
                 <div class="h-border"></div>
               </div>
            </div>

            <!-- Absolute positioned chips -->
            <div v-for="a in scheduledToday" :key="a.id" :style="a._style" class="scheduled-chip gradient-pink">
              <strong style="font-size: 0.9rem;">{{ a.title }}</strong>
              <div style="font-size: 0.75rem; opacity: 0.8;">Assigned: {{ a.assigned_to ? `User ${a.assigned_to}` : 'Unclaimed' }}</div>
              <button class="complete-shorthand" @click="markCompleted(a.id)">✓ Finish</button>
            </div>
         </div>
      </VCard>

      <!-- COL 3: Completed -->
      <VCard title="Completed" class="col-card confetti-bg">
         <div v-for="a in completedToday" :key="a.id" class="completed-chip ui-gradient">
            <div>
              <strong style="font-size: 1rem; color:#1e293b;">{{ a.title }}</strong>
              <div style="font-size:0.75rem; color:#475569;">{{ a.durationMinutes }}m - 🪙 {{ a.coin_value }}cc</div>
            </div>
            <div class="mock-check">✔</div>
         </div>

         <div v-if="completedToday.length === 0" style="color: #64748b; font-size: 0.9rem; text-align: center; margin-top:2rem;">
            Nothing finished yet today.
         </div>

         <div class="daily-tallies">
            <div>Great job everyone!</div>
            <div style="font-weight: 700; font-size: 1.1rem; color: #1e293b;">Total coins earned today: {{ todayCoins }}cc</div>
         </div>
      </VCard>

    </div>
  </div>

  <!-- Time Modal -->
  <div v-if="showScheduleModal" class="modal-overlay">
    <VCard title="Confirm Time" style="max-width: 400px; width: 100%;">
      <p>Schedule this activity at {{ scheduleForm.time }}?</p>
      <div style="margin-top: 1.5rem; display:flex; justify-content: flex-end; gap: 1rem;">
        <VButton type="secondary" @click="showScheduleModal = false">Cancel</VButton>
        <VButton type="primary" @click="confirmSchedule">Confirm Layout</VButton>
      </div>
    </VCard>
  </div>
</template>

<style scoped>
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
  width: 100%; border:none; padding: 0.5rem; border-radius: 999px; font-weight:700; cursor:pointer;
}

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
  font-size: 0.70rem;
  color: #94a3b8;
  padding-left: 0.5rem;
  padding-top: 0.2rem;
}
.h-border {
  flex: 1;
  border-top: 1px dashed #e2e8f0;
}

.scheduled-chip {
  background: linear-gradient(to right, #a855f7, #ec4899);
  border-radius: 8px;
  color: #fff;
  padding: 0.5rem 1rem;
  box-shadow: 0 4px 15px rgba(236,72,153,0.3);
  z-index: 10;
  display: flex;
  flex-direction: column;
  justify-content: center;
}
.complete-shorthand {
  position: absolute; right: 10px; top: 10px;
  background: rgba(255,255,255,0.2); border:none; color:#fff; border-radius:4px; cursor:pointer; font-size:0.7rem; padding: 3px 6px;
}
.complete-shorthand:hover { background: rgba(255,255,255,0.4); }

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
  background: rgba(255,255,255,0.5);
  padding: 1rem;
  border-radius: 12px;
}

.modal-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 1000;
  display: flex; align-items: center; justify-content: center;
}
</style>
