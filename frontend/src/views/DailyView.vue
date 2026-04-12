<script setup>
import { ref, computed, watch, onMounted } from 'vue';
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

// --- Bounty Feature ---
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

const acceptBounty = async (activityId) => {
  if (!confirm('Are you sure you want to take over this task and claim the bounty?')) return;
  await appStore.runAction(async () => {
    await appStore.request(`/api/activities/${activityId}/accept-bounty`, {
      method: 'POST',
      headers: appStore.authHeaders()
    });
    await familyStore.fetchUserData(); // To update personal coin balance
    await loadActivities();
    appStore.setSuccess('Task taken! Coins added to your account.');
  });
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

const gradients = [
  'linear-gradient(to right, #3b82f6, #2563eb)', // Blue
  'linear-gradient(to right, #10b981, #059669)', // Green
  'linear-gradient(to right, #eab308, #ca8a04)', // Yellow
  'linear-gradient(to right, #ef4444, #dc2626)'  // Red
];
const getAssigneeGradient = (assigned_to, category) => {
  if (!assigned_to) return category === 'care' ? 'linear-gradient(to right, #ec4899, #db2777)' : 'linear-gradient(to right, #f97316, #ea580c)';
  const idx = familyMembers.value.findIndex(m => m.id === assigned_to);
  if (idx === -1) return category === 'care' ? 'linear-gradient(to right, #ec4899, #db2777)' : 'linear-gradient(to right, #f97316, #ea580c)';
  return gradients[idx % gradients.length];
};

const loadActivities = () => appStore.runAction(async () => {
  const fid = familyId.value;
  if (!fid) return;
  const activitiesData = await appStore.request(`/api/activities?familyId=${fid}`, { headers: appStore.authHeaders() });
  familyActivities.value = activitiesData.activities || [];
}, 'Daily layout loaded.');

onMounted(async () => {
  await loadMembers();
  loadActivities();
});

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

    positionedActs.push({
      ...a,
      overlapCount,
      _style: {
        position: 'absolute',
        top: `${topP}%`,
        /* height removed to ensure the element acts as a fixed-height Pill rather than a distorted oval */
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
      <h2 style="margin: 0;">Daily Schedule</h2>
      <div style="text-align: right;">
        <strong style="color: var(--primary); font-size: 1.5rem; display:block; line-height:1.2;">{{ new Date(targetDate).toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' }) }}</strong>
        <span style="color: var(--accent-primary); font-weight: 800;">{{ scheduledToday.filter(a => a.status !== 'completed').length }} Tasks Remaining</span>
      </div>
    </div>

    <!-- 3 Column Layout -->
    <div class="daily-grid">
      
      <!-- COL 1: Task Library -->
      <VCard title="Task Library" class="col-card" style="box-shadow: none; border: none; background: transparent;">
         <p class="text-sm" style="color: var(--text-secondary); margin-bottom: 1rem;">Drag icons to the timeline to schedule your day.</p>
         <div class="template-grid">
           
           <template v-for="category in ['care', 'household']" :key="category">
             <div v-if="availableTemplates.some(a => a.category === category)" style="text-transform: uppercase; font-size: 0.75rem; font-weight: 800; color: var(--text-secondary); margin-top: 1rem; letter-spacing: 1px;">
               {{ category === 'care' ? 'CARE & WELLNESS' : 'HOUSEHOLD' }}
             </div>
             
             <div v-for="a in availableTemplates.filter(t => t.category === category)" :key="a.id" class="mock-gradient-pill" draggable="true" @dragstart="dragStart($event, a)">
                <div style="width: 40px; height: 40px; background: #e0e7ff; color: #3730a3; border-radius: 50%; display:flex; align-items:center; justify-content:center; flex-shrink:0;">
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
           
         </div>
      </VCard>

      <!-- Right Column: Timeline & Completed Bar -->
      <div style="display: flex; flex-direction: column; gap: 1.5rem; flex: 1;">
        
        <!-- COL 2: Scheduled Timeline -->
        <VCard :title="scheduledTitle" style="padding: 0; flex: 1; min-height: 600px; display: flex; flex-direction: column;">
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
                    class="scheduled-chip"
                    :style="[a._style, { background: getAssigneeGradient(a.assigned_to, a.category) }, a.is_recurrent && a.status !== 'completed' ? { cursor: 'pointer' } : {}]"
                    :draggable="a.status !== 'completed'" @dragstart="a.status !== 'completed' ? dragStartScheduled($event, a) : null"
                    @click="a.is_recurrent && a.status !== 'completed' ? openRecurrenceModal(a) : null">
                 <div style="display:flex; align-items:center; gap: 0.8rem;">
                   <span style="font-size: 1.4rem;">{{ a.category === 'care' ? '❤️' : '🍽️' }}</span>
                   <strong class="text-base" style="display:block; line-height: 1.2; font-weight:800;">
                     {{ a.title }}
                     <span v-if="a.is_recurrent" title="Click to schedule future recurrences" style="font-size: 0.85rem; margin-left: 0.3rem;">🔁</span>
                   </strong>
                 </div>
                 
                 <div style="display: flex; align-items: center; gap: 0.5rem;">
                  <div class="text-xs" style="font-weight:800; background: rgba(0,0,0,0.1); padding: 4px 10px; border-radius: 999px;">
                    {{ new Date(a.starts_at).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }) }}
                  </div>
                  
                  <div v-if="a.status === 'pending_validation'" style="display: flex; align-items: center; gap: 0.4rem;">
                    <button v-if="a.assigned_to !== familyStore.profile?.id && familyStore.profile?.actor_type === 'caregiver'" @click.stop="validateActivity(a.id)" class="validate-btn">✓ Validate</button>
                  </div>
                  <div v-else-if="a.status === 'completed'" class="text-xs" style="font-weight: bold; background: rgba(0,0,0,0.15); padding: 2px 6px; border-radius: 999px;">
                    ✓ Done
                  </div>
                  <div v-else-if="['pending', 'approved'].includes(a.status)" style="display: flex; align-items: center; gap: 0.4rem;">
                    <!-- My Task -> I can offer Bribe -->
                    <button v-if="a.assigned_to === familyStore.profile?.id && !a.bounty_amount && ['main_caregiver', 'caregiver'].includes(role)" 
                            @click.stop="openBountyModal(a)" class="validate-btn" style="background: rgba(0,0,0,0.15); border: 2px solid rgba(255,165,0,0.5); color: #fff;">
                      💸 Delegate (-cc)
                    </button>
                    <!-- My Task with Bribe already offered -->
                    <span v-else-if="a.assigned_to === familyStore.profile?.id && a.bounty_amount" class="text-xs" style="background: rgba(255, 165, 0, 0.2); padding: 4px 8px; border-radius: 999px; font-weight:800; border: 1px solid rgba(255,165,0,0.8);">
                      Offering: {{ a.bounty_amount }}cc
                    </span>
                    <!-- Other User's Task with Bribe -> I can ACCEPT Bribe -->
                    <button v-else-if="a.assigned_to !== familyStore.profile?.id && a.bounty_amount && ['main_caregiver', 'caregiver'].includes(role)" 
                            @click.stop="acceptBounty(a.id)" class="validate-btn" style="background: rgba(16, 185, 129, 0.4); border: 2px solid #10b981;">
                      🤑 Take Over (+{{a.bounty_amount}}cc)
                    </button>
                    <!-- Other User's Task with NO bribe -->
                    <span v-else-if="a.assigned_to !== familyStore.profile?.id && !a.bounty_amount" class="text-xs" style="background: rgba(0,0,0,0.1); padding: 4px 8px; border-radius: 999px; font-weight: 800;">
                      Assigned to {{ a.assigned_alias || 'Caregiver' }}
                    </span>
                  </div>
                </div>
              </div>
           </div>
        </VCard>

        <!-- Horizontal Completed Bar -->
        <div style="background: var(--card-bg); color: var(--text-primary); padding: 1.2rem 2rem; border-radius: 32px; display: flex; align-items: center; justify-content: space-between; border: 1px solid var(--card-border); margin-top: 0.5rem; box-shadow: 0 4px 15px rgba(0,0,0,0.05);">
           <div style="display: flex; gap: 1rem; align-items: center; flex-wrap: wrap; flex: 1;">
             
             <div v-if="completedToday.length === 0" style="font-weight: 600; font-size: 0.95rem; color: var(--text-secondary);">
               Nothing finished yet today. Get to work!
             </div>

             <div v-for="a in completedToday" :key="a.id" :class="[a.category === 'care' ? 'gradient-pink' : 'gradient-orange']" style="display: flex; align-items: center; gap: 0.6rem; padding: 0.5rem 1.2rem; border-radius: 9999px; font-size: 0.95rem; color: white;">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="color: white; flex-shrink: 0;"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><path d="M22 4L12 14.01l-3-3"/></svg>
                <strong style="line-height: 1; font-weight: 800;">{{ a.title }}</strong>
             </div>
           </div>

           <!-- Totals at the end -->
           <div v-if="todayCoins > 0" style="margin-left: 1rem; display: flex; align-items: center; gap: 0.6rem; background: var(--bg-color); color: var(--text-primary); padding: 0.5rem 1.2rem; border-radius: 9999px; border: 1px solid var(--input-border);">
              <span style="font-size: 0.85rem; font-weight: 800; text-transform: uppercase;">Total Earned</span>
              <strong style="font-size: 1.3rem; font-weight: 800; color: var(--accent-primary);">{{ todayCoins }}cc</strong>
           </div>
        </div>
        
      </div>
    
    </div> <!-- end daily-grid -->
    </div> <!-- end daily-wrapper -->
  </div> <!-- end daily-fullscreen-overlay -->

  <!-- Recurrence Modal -->
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
        <VButton type="primary" @click="confirmRecurrence">Generate</VButton>
      </div>
    </VCard>
  </div>

  <!-- Time Modal -->
  <div v-if="showScheduleModal" class="modal-overlay">
    <VCard title="Confirm Time" style="max-width: 320px; width: 100%;">
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
        </div>
      </div>
      <div style="display:flex; justify-content: flex-end; gap: 1rem;">
        <VButton type="secondary" @click="showScheduleModal = false">Nope</VButton>
        <VButton type="primary" @click="confirmSchedule">Yes I'll</VButton>
      </div>
    </VCard>
  </div>

  <!-- Bounty Modal -->
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
  max-width: 1400px;
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

.col-card {
  display: flex;
  flex-direction: column;
}

/* Template Grid (Col 1) */
.template-grid {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}
.mock-gradient-pill {
  background: #ffffff;
  border: 1px solid var(--card-border);
  border-radius: 9999px; /* Re-applied Pill Radius since they are now horizontal */
  padding: 0.8rem 1.2rem;
  box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05);
  cursor: grab;
  transition: transform 0.1s;
  display: flex;
  align-items: center;
  gap: 1rem;
  text-align: left;
}
.mock-gradient-pill:active { cursor: grabbing; transform: scale(0.98); }

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
  border-radius: 9999px; /* Real Pill radius without oval distortion */
  color: #fff;
  padding: 0.6rem 1.2rem;
  box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1);
  z-index: 10;
  display: flex;
  flex-direction: row; /* Horizontal alignment */
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
  background: var(--card-bg);
  border-radius: 16px;
  padding: 1rem 1.2rem;
  margin-bottom: 1rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border: 1px solid var(--card-border);
  box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05);
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
  color: var(--text-primary); background: var(--input-bg); border: 1px solid var(--input-border);
  padding: 0.8rem 1.5rem; border-radius: 999px; text-align: center; font-size: 1rem; margin: 1rem auto; font-weight: 600;
  width: max-content;
}

</style>
