<script setup>
import { ref, onMounted, computed, watch } from 'vue';
import { useAppStore } from '../stores/app';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';

const appStore = useAppStore();
const dashboard = ref({ members: [], calendar: [], objectsOfCare: [] });
const familyActivities = ref([]);
const budgetInfo = ref(null);

// Modal state
const showScheduleModal = ref(false);
const scheduleForm = ref({ activityId: '', dateStr: '', time: '' });

const showBountyModal = ref(false);
const bountyForm = ref({ activity: null, amount: '' });

const showAcceptBountyModal = ref(false);
const acceptBountyForm = ref({ activity: null });

// Calendar state
const currentWeekOffset = ref(0);

const getFamilyId = () => appStore.families?.[0]?.family_id || appStore.families?.[0]?.id;

const loadDashboard = () => appStore.runAction(async () => {
  const fid = getFamilyId();
  if (!fid) return;
  dashboard.value = await appStore.request(`/api/dashboard/${fid}`, { headers: appStore.authHeaders() });
  
  const activitiesData = await appStore.request(`/api/activities?familyId=${fid}`, { headers: appStore.authHeaders() });
  familyActivities.value = activitiesData.activities || [];

  const bData = await appStore.request(`/api/families/${fid}/budget`, { headers: appStore.authHeaders() }).catch(()=>null);
  budgetInfo.value = bData;
}, 'Family dashboard loaded.');

// Watch for family ID changes to handle full page reloads properly
watch(() => getFamilyId(), (newFid) => {
  if (newFid) {
    loadDashboard();
  }
}, { immediate: true });

const daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const weekDays = computed(() => {
  const today = new Date();
  const startOfWeek = new Date(today);
  const currentDay = today.getDay() || 7; 
  startOfWeek.setDate(today.getDate() - currentDay + 1 + (currentWeekOffset.value * 7));
  startOfWeek.setHours(0, 0, 0, 0);

  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(startOfWeek);
    d.setDate(d.getDate() + i);
    return d;
  });
});

const weekLabel = computed(() => {
  if (!weekDays.value.length) return '';
  const first = weekDays.value[0];
  const last = weekDays.value[6];
  const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  if (first.getMonth() === last.getMonth()) {
    return `${monthNames[first.getMonth()]} ${first.getDate()} - ${last.getDate()}, ${first.getFullYear()}`;
  }
  return `${monthNames[first.getMonth()]} ${first.getDate()} - ${monthNames[last.getMonth()]} ${last.getDate()}, ${first.getFullYear()}`;
});

const prevWeek = () => currentWeekOffset.value--;
const nextWeek = () => currentWeekOffset.value++;
const resetWeek = () => currentWeekOffset.value = 0;

const timeOptions = [];
for(let h=0; h<24; h++) {
  const hh = String(h).padStart(2,'0');
  timeOptions.push(`${hh}:00`, `${hh}:30`);
} 

// Activities with no starts_at AND status approved = reusable templates
// Templates are shown in the sidebar and always remain there
const unscheduledActivities = computed(() => {
  return familyActivities.value.filter(a => a.is_template && a.status === 'approved');
});

// Instances = rows where is_template = false (cloned from a template, placed on calendar)
const scheduledInstances = computed(() => {
  return familyActivities.value.filter(a => !a.is_template && !!a.starts_at);
});

const getActivitiesForDay = (date) => {
  // Include instances that START on this day
  const starts = scheduledInstances.value.filter(a => {
    const d = new Date(a.starts_at);
    return d.getFullYear() === date.getFullYear() &&
           d.getMonth() === date.getMonth() &&
           d.getDate() === date.getDate();
  });

  // Also include instances that STARTED the previous day but overflow into this day
  const prevDate = new Date(date);
  prevDate.setDate(prevDate.getDate() - 1);
  const overflows = scheduledInstances.value.filter(a => {
    const s = new Date(a.starts_at);
    const e = new Date(a.ends_at);
    const sameDay = s.getFullYear() === prevDate.getFullYear() &&
                    s.getMonth() === prevDate.getMonth() &&
                    s.getDate() === prevDate.getDate();
    // ends after midnight of this day
    return sameDay && e > date;
  }).map(a => ({ ...a, _overflowDay: date }));

  return [...starts, ...overflows];
};

const processedWeekDays = computed(() => {
  return weekDays.value.map(date => {
     let acts = getActivitiesForDay(date);
     const START_HOUR = 6;
     const TOTAL_HOURS = 18;
     
     const getRange = (act) => {
       let st = new Date(act.starts_at).getTime();
       let en = new Date(act.ends_at).getTime();
       if (act._overflowDay) {
         const d = new Date(act._overflowDay); d.setHours(START_HOUR,0,0,0);
         st = d.getTime();
       }
       return { st, en };
     };
     
     acts.sort((x,y) => getRange(x).st - getRange(y).st);
     
     // Find disjoint clusters
     let clusters = [];
     for(let a of acts) {
        const range = getRange(a);
        let added = false;
        for(let c of clusters) {
           if (range.st < c.maxEnd) {
              c.acts.push(a);
              c.maxEnd = Math.max(c.maxEnd, range.en);
              added = true;
              break;
           }
        }
        if(!added) {
           clusters.push({ acts: [a], maxEnd: range.en });
        }
     }
     
     // Calculate layout metrics
     for(let c of clusters) {
        let columns = [];
        for(let a of c.acts) {
           const range = getRange(a);
           let colIdx = columns.findIndex(endTime => endTime <= range.st);
           if (colIdx === -1) colIdx = columns.length;
           columns[colIdx] = range.en;
           a._colIdx = colIdx;
        }
        c.numCols = columns.length;
        
        for(let a of c.acts) {
           let topP = 0, heightP=0;
           if (a._overflowDay) {
             let endsAt = new Date(a.ends_at);
             let endHour = endsAt.getHours() + endsAt.getMinutes() / 60;
             let clampedEnd = Math.min(24, endHour);
             if (clampedEnd > START_HOUR) {
               heightP = ((clampedEnd - START_HOUR) / TOTAL_HOURS) * 100;
             }
             topP = 0;
           } else {
             let d = new Date(a.starts_at);
             let hour = d.getHours() + d.getMinutes() / 60;
             let clampedStart = Math.max(START_HOUR, hour);
             topP = ((clampedStart - START_HOUR) / TOTAL_HOURS) * 100;
             let visibleHours = Math.min(a.duration_minutes / 60, 24 - clampedStart);
             heightP = (visibleHours / TOTAL_HOURS) * 100;
           }
           
           a._style = {
             position: 'absolute',
             top: `${topP}%`,
             height: `${Math.max(2, heightP)}%`,
             width: `${100 / c.numCols}%`,
             left: `${(a._colIdx / c.numCols) * 100}%`
           };
        }
     }
     
     return { date, acts: acts.filter(a => a._style && a._style.height !== '0%') };
  });
});

const getMemberName = (userId) => {
  const m = dashboard.value.members.find(memb => memb.user_id === userId);
  return m ? m.name : `User ${userId}`;
};

const dragStart = (event, activity) => {
  event.dataTransfer.effectAllowed = 'copyMove';
  event.dataTransfer.setData('text/plain', JSON.stringify({
    type: activity.is_template ? 'template' : 'existing_activity',
    activity
  }));
};

const dropOnDay = (event, date) => {
  event.preventDefault();
  const j = event.dataTransfer.getData('text/plain');
  if (!j) return;
  try {
    const payload = JSON.parse(j);
    
    const rect = event.currentTarget.getBoundingClientRect();
    const y = Math.max(0, event.clientY - rect.top);
    const percentage = y / rect.height;
    
    // 18 hours layout window (06:00 to 24:00)
    let droppedHour = 6 + (percentage * 18);
    droppedHour = Math.round(droppedHour * 2) / 2; // Snap 30-min
    droppedHour = Math.max(6, Math.min(23.5, droppedHour));
    
    let hh = Math.floor(droppedHour);
    let mm = (droppedHour % 1 === 0.5) ? '30' : '00';
    
    const d = new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    
    scheduleForm.value.activityId = payload.activity.id;
    scheduleForm.value.dateStr = `${year}-${month}-${day}`;
    scheduleForm.value.time = `${String(hh).padStart(2,'0')}:${mm}`;
    
    showScheduleModal.value = true;
  } catch(e) {}
};

const confirmSchedule = async () => {
  const [hh, mm] = scheduleForm.value.time.split(':');
  const targetDate = new Date(`${scheduleForm.value.dateStr}T00:00:00`);
  targetDate.setHours(Number(hh), Number(mm), 0, 0);

  await appStore.runAction(async () => {
    // POST creates a NEW instance from the approved template
    const res = await appStore.request(`/api/activities/${scheduleForm.value.activityId}/schedule`, {
      method: 'POST',
      headers: appStore.authHeaders(),
      body: JSON.stringify({ startsAt: targetDate.toISOString() })
    });
    showScheduleModal.value = false;
    await loadDashboard();
    
    if (res.warning === 'budget_exceeded') {
      appStore.setSuccess('Scheduled! Note: Monthly coin budget exceeded (coins may be deferred).');
    } else {
      appStore.setSuccess('Activity successfully placed on the calendar.');
    }
  });
};

const dropOutsideCalendar = async (e) => {
  e.preventDefault();
  const j = e.dataTransfer.getData('text/plain');
  if (!j) return;
  try {
    const payload = JSON.parse(j);
    if (payload.type === 'existing_activity' && payload.activity.status === 'approved') {
      // Instantly delete without confirm popup
      await appStore.runAction(async () => {
        await appStore.request(`/api/activities/${payload.activity.id}`, { 
          method: 'DELETE', 
          headers: appStore.authHeaders() 
        });
        await loadDashboard();
        appStore.setSuccess('Activity unscheduled.');
      });
    }
  } catch(err) {
    console.error("Drop Parse Error", err);
  }
};

const handleActivityClick = (a) => {
  if (a.status === 'completed' || a._overflowDay) return;
  // If no one is logged in profile yet, skip gracefully
  if (!appStore.profile?.id) return;
  
  if (a.assigned_to === appStore.profile.id) {
    if (a.bounty_amount > 0) return; // already offered
    // Open offer bounty modal
    bountyForm.value.activity = a;
    bountyForm.value.amount = '';
    showBountyModal.value = true;
  } else if (a.bounty_amount > 0) {
    // Another person has a bounty, I can accept it
    acceptBountyForm.value.activity = a;
    showAcceptBountyModal.value = true;
  }
};

const submitBounty = async () => {
  await appStore.runAction(async () => {
    await appStore.request(`/api/activities/${bountyForm.value.activity.id}/bounty`, {
      method: 'POST',
      headers: appStore.authHeaders(),
      body: JSON.stringify({ bountyAmount: Number(bountyForm.value.amount) })
    });
    showBountyModal.value = false;
    await loadDashboard();
    appStore.setSuccess("Bounty successfully offered!");
  });
};

const cancelBounty = () => { showBountyModal.value = false; };

const acceptBounty = async () => {
  await appStore.runAction(async () => {
    await appStore.request(`/api/activities/${acceptBountyForm.value.activity.id}/accept-bounty`, {
      method: 'POST',
      headers: appStore.authHeaders()
    });
    showAcceptBountyModal.value = false;
    appStore.setSuccess(`Shift stolen! You instantly earned ${acceptBountyForm.value.activity.bounty_amount} cc!`);
    await appStore.fetchUserData(); // Refresh local balance
    await loadDashboard();
  });
};

const cancelAcceptBounty = () => { showAcceptBountyModal.value = false; };

const cancelSchedule = () => {
  showScheduleModal.value = false;
};
</script>

<template>
  <div class="dashboard-layout" @dragover.prevent @drop="dropOutsideCalendar($event)">

    <div style="display: flex; flex-direction: column; gap: 2rem;">
      <!-- Main Family Overview -->
      <VCard :title="appStore.families?.[0]?.name || 'Family Home'">
        <div v-if="!appStore.families?.length">
          <p>You are not in a family yet. Create or join one first.</p>
        </div>
        <div v-else>
          <!-- Objects of Care Section -->
          <div v-if="dashboard.objectsOfCare && dashboard.objectsOfCare.length > 0">
            <h4 class="section-heading">Object of Care</h4>
            <div class="grid three" style="margin-bottom: 1rem;">
              <div v-for="obj in dashboard.objectsOfCare" :key="obj.id" class="care-object-card">
                <div class="emoji-avatar">{{ obj.actor_type === 'elderly' ? '🧓' : obj.actor_type === 'pet' ? '🐾' : '👶' }}</div>
                <div class="user-name">{{ obj.name }}</div>
                <div class="role-badge">{{ obj.actor_type.toUpperCase() }} · {{ obj.care_time.replace('_', ' ') }}</div>
              </div>
            </div>

            <div v-if="budgetInfo && dashboard.objectsOfCare.length > 0" class="budget-message">
              <strong>{{ dashboard.objectsOfCare.map(o => o.name).join(' and ') }}</strong> has a remaining pool of <strong>{{ budgetInfo.remainingBudget }}</strong> coins this month.<br/>
              If no further activities are claimed, {{ dashboard.objectsOfCare.map(o => o.name).join(' and ') }} will give approximately <b>{{ Math.floor(budgetInfo.remainingBudget / Math.max(1, dashboard.members.length)) }} coins</b> to each caregiver at month's end!
            </div>
          </div>

          <!-- Caregivers Section -->
          <h4 class="section-heading">Caregivers</h4>
          <div v-if="dashboard.members.length > 0">
            <div class="grid three">
              <div v-for="m in dashboard.members" :key="m.user_id" class="balance-card">
                <div class="user-name">{{ m.name || `User ${m.user_id}` }}</div>
                <div class="role-badge">{{ m.role.replace('_', ' ') }}</div>
                <div style="font-size: 0.70rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 0.2rem;">Lifetime Bank Balance</div>
                <div class="coin-amount">{{ m.coin_balance }} <small>cc</small></div>
              </div>
            </div>
          </div>
        </div>
      </VCard>

      <!-- Calendar View -->
      <VCard title="Family times">
        <p style="color:var(--text-secondary); margin-bottom: 1.5rem; font-size: 0.9rem;">
          Drag activities onto a specific hour slot to schedule. Accrued coins will be processed once activities are completed in their scheduled month.
        </p>

        <div class="family-times-layout">
          <!-- Calendar Area -->
          <div class="calendar-wrapper">
            
            <!-- Top Horizontal Available Activities Tray -->
            <div class="available-tray" title="Drag activities into the calendar to plan them, or drop back here to un-schedule.">
              <h4 style="margin: 0; padding-right: 1.5rem; border-right: 1px solid var(--input-border); white-space: nowrap; font-size: 0.95rem; color: var(--text-secondary); text-transform: uppercase;">Activities</h4>
              <div v-if="unscheduledActivities.length > 0" class="unscheduled-tray-list">
                <div v-for="a in unscheduledActivities" :key="a.id" class="activity-chip draggable-chip" draggable="true" @dragstart="dragStart($event, a)">
                  <div style="font-weight: 600;">{{ a.title }}</div>
                  <div style="display:flex; justify-content:space-between; align-items:flex-end; margin-top:0.4rem;">
                    <div style="font-size: 0.75rem; color: #b49af9;">
                      {{ Math.floor(a.duration_minutes / 60) > 0 ? Math.floor(a.duration_minutes / 60) + 'h ' : '' }}{{ a.duration_minutes % 60 > 0 ? (a.duration_minutes % 60) + 'm' : '' }}
                    </div>
                    <div style="font-size: 0.75rem; color: var(--success);">{{ a.coin_value }}cc</div>
                  </div>
                </div>
              </div>
              <div v-else style="color:var(--text-secondary); font-size: 0.85rem; padding-left: 1.5rem;">
                No approved activities available. Create from top menu.
              </div>
            </div>
            <div class="calendar-toolbar">
              <VButton type="secondary" @click="prevWeek">&laquo; Prev</VButton>
              <div class="calendar-date-display" @click="resetWeek" title="Back to current week" style="cursor: pointer;">
                {{ weekLabel }}
              </div>
              <VButton type="secondary" @click="nextWeek">Next &raquo;</VButton>
            </div>

            <div class="weekly-calendar">
              <!-- Days Columns -->
              <div v-for="dayObj in processedWeekDays" :key="dayObj.date.toISOString()" class="day-col" style="flex: 1; border-right: 1px solid var(--card-border); display: flex; flex-direction: column;">
                <div class="day-header" :class="{ 'is-today': dayObj.date.toDateString() === new Date().toDateString() }">
                  {{ daysOfWeek[(dayObj.date.getDay() - 1 + 7) % 7] }} {{ dayObj.date.getDate() }}
                </div>
                <!-- 3 colored zones painted over a 650px responsive tall block for mapping percentage times cleanly -->
                <div class="day-body" @dragover.prevent.stop @drop.prevent.stop="dropOnDay($event, dayObj.date)" 
                     style="flex: 1; position: relative; min-height: 550px; background: linear-gradient(to bottom, 
                      rgba(234, 179, 8, 0.05) 0%, rgba(234, 179, 8, 0.05) 33.3%, 
                      rgba(249, 115, 22, 0.04) 33.3%, rgba(249, 115, 22, 0.04) 66.6%, 
                      rgba(99, 102, 241, 0.05) 66.6%, rgba(99, 102, 241, 0.05) 100%);">
                  
                    <div v-for="a in dayObj.acts" :key="a._overflowDay ? `overflow-${a.id}` : a.id" 
                         class="activity-chip scheduled-chip" :style="a._style"
                         :class="{ 'is-completed': a.status === 'completed', 'is-overflow': !!a._overflowDay, 'has-bounty': a.bounty_amount > 0 }"
                         :draggable="a.status !== 'completed' && !a._overflowDay" 
                         @dragstart="a.status !== 'completed' && !a._overflowDay ? dragStart($event, a) : null"
                         @click.stop="handleActivityClick(a)">
                      <div class="scheduled-content" style="display:flex; flex-direction:column; justify-content: space-between; height: 100%;">
                        <div>
                          <strong style="font-size: 0.85rem;">{{ a.title }}</strong><br/>
                          <span class="caregiver-badge" style="margin-top: 2px;">{{ getMemberName(a.assigned_to) }}</span>
                          <div v-if="a.bounty_amount > 0" class="bounty-badge">🔥 {{ a.bounty_amount }} cc</div>
                        </div>
                        <div class="scheduled-footer" style="opacity: 0.8;">
                          <span>{{ new Date(a.starts_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) }}</span>
                        </div>
                      </div>
                    </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </VCard>
    </div>

    <!-- Confirm Schedule Modal -->
    <div v-if="showScheduleModal" class="modal-overlay" @click.self="cancelSchedule">
      <div class="modal-content">
        <VCard title="Confirm Start Time">
          <p style="margin-bottom: 1rem; color: var(--text-secondary); font-size: 0.9rem;">
            Please confirm the exact start time for this activity on <strong>{{ scheduleForm.dateStr }}</strong>.
          </p>
          <select v-model="scheduleForm.time" class="time-select" style="width: 100%; padding: 0.8rem; background: var(--input-bg); border: 1px solid var(--input-border); color: #fff; border-radius: 8px;">
            <option v-for="t in timeOptions" :key="t" :value="t">{{ t }}</option>
          </select>
          
          <div style="margin-top: 1.5rem; display: flex; gap: 1rem; justify-content: flex-end;">
            <VButton type="secondary" @click="cancelSchedule">Cancel</VButton>
            <VButton type="primary" @click="confirmSchedule">Confirm</VButton>
          </div>
        </VCard>
      </div>
    </div>

    <!-- Offer Bounty Modal -->
    <div v-if="showBountyModal" class="modal-overlay" @click.self="cancelBounty">
      <div class="modal-content">
        <VCard title="Offer a Shift Bribe">
          <p style="margin-bottom: 1rem; color: var(--text-secondary); font-size: 0.9rem;">
            Don't want to work <strong>{{ bountyForm.activity?.title }}</strong>? Attach coins from your personal bank to incentivize someone to steal it from you.
          </p>
          <VInput type="number" v-model="bountyForm.amount" label="Bribe Amount (cc)" placeholder="e.g. 15" />
          
          <div style="margin-top: 1.5rem; display: flex; gap: 1rem; justify-content: flex-end;">
            <VButton type="secondary" @click="cancelBounty">Cancel</VButton>
            <VButton type="primary" @click="submitBounty">Offer Bribe</VButton>
          </div>
        </VCard>
      </div>
    </div>

    <!-- Accept Bounty Modal -->
    <div v-if="showAcceptBountyModal" class="modal-overlay" @click.self="cancelAcceptBounty">
      <div class="modal-content">
        <VCard title="Steal this Shift!">
          <p style="margin-bottom: 1rem; font-size: 0.95rem;">
            Take over <strong>{{ acceptBountyForm.activity?.title }}</strong> and instantly earn 
            <span style="color:var(--accent-primary); font-weight:bold;">{{ acceptBountyForm.activity?.bounty_amount }} extra cc</span> 
            from their personal stash!
          </p>
          <p style="color: var(--text-secondary); font-size: 0.8rem;">
            (You will still earn the baseline system coins when you complete it later.)
          </p>
          
          <div style="margin-top: 1.5rem; display: flex; gap: 1rem; justify-content: flex-end;">
            <VButton type="secondary" @click="cancelAcceptBounty">Cancel</VButton>
            <VButton type="primary" @click="acceptBounty">Steal & Collect Coins</VButton>
          </div>
        </VCard>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dashboard-layout {
  display: flex;
  flex-direction: column;
}

.balance-card {
  background: var(--input-bg);
  border: 1px solid var(--input-border);
  padding: 1.2rem;
  border-radius: 12px;
  text-align: center;
  position: relative;
  overflow: hidden;
}
.balance-card::before {
  content: '';
  position: absolute;
  top: 0; left: 0; right: 0; height: 3px;
  background: var(--accent-gradient);
}
.user-name {
  font-weight: 600;
  color: #fff;
  font-size: 1.1rem;
  margin-bottom: 0.2rem;
}
.role-badge {
  font-size: 0.75rem;
  background: rgba(139, 92, 246, 0.2);
  color: #c4b5fd;
  padding: 2px 8px;
  border-radius: 999px;
  display: inline-block;
  margin-bottom: 1rem;
}
.coin-amount {
  font-size: 2rem;
  font-weight: 700;
  color: var(--accent-primary);
  line-height: 1;
}
.coin-amount small {
  font-size: 1rem;
  color: var(--text-secondary);
}

.section-heading {
  font-size: 0.9rem;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 1px;
  margin-bottom: 1rem;
  border-bottom: 1px solid var(--input-border);
  padding-bottom: 0.5rem;
}

.care-object-card {
  background: rgba(255, 255, 255, 0.02);
  border: 1px solid var(--input-border);
  padding: 1.2rem;
  border-radius: 12px;
  text-align: center;
}
.emoji-avatar {
  font-size: 2.5rem;
  margin-bottom: 0.5rem;
}

.budget-message {
  text-align: center;
  color: var(--text-secondary);
  background: rgba(139, 92, 246, 0.05);
  border: 1px dashed rgba(139, 92, 246, 0.3);
  padding: 1.2rem;
  border-radius: 8px;
  line-height: 1.6;
  margin-bottom: 2rem;
}
.budget-message strong, .budget-message b {
  color: #c4b5fd;
}

.family-times-layout {
  display: flex;
  gap: 1.5rem;
  align-items: flex-start;
}
@media (max-width: 950px) {
  .family-times-layout {
    flex-direction: column;
  }
}

.calendar-wrapper {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.calendar-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: var(--input-bg);
  padding: 0.5rem 1rem;
  border-radius: 8px;
  border: 1px solid var(--input-border);
}
.calendar-date-display {
  font-weight: 600;
  color: #fff;
}
.calendar-date-display:hover {
  color: #b49af9;
}

.weekly-calendar {
  display: flex;
  border: 1px solid var(--input-border);
  border-radius: 8px;
  background: var(--bg-surface);
  overflow-x: auto;
}
.day-col {
  flex: 1;
  min-width: 100px;
  border-right: 1px solid var(--input-border);
}
.day-col:last-child {
  border-right: none;
}
.day-header {
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 0.85rem;
  border-bottom: 1px solid var(--input-border);
  background: var(--input-bg);
  color: var(--text-secondary);
}
.day-header.is-today {
  color: #fff;
  background: rgba(139, 92, 246, 0.15);
  border-bottom-color: rgba(139, 92, 246, 0.3);
}

.available-tray {
  display: flex;
  align-items: center;
  background: var(--input-bg);
  border: 1px solid var(--input-border);
  border-radius: 8px;
  padding: 1rem;
  overflow-x: auto;
  margin-bottom: 1rem;
}
.unscheduled-tray-list {
  display: flex;
  gap: 1rem;
  padding-left: 1.5rem;
  flex: 1;
}
.draggable-chip {
  flex: 0 0 200px;
  cursor: grab;
  user-select: none;
  background: rgba(139, 92, 246, 0.05);
  border-color: rgba(139, 92, 246, 0.3);
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
  transition: transform 0.1s, box-shadow 0.1s, background 0.2s;
}
.draggable-chip:hover {
  background: rgba(139, 92, 246, 0.15);
  box-shadow: 0 6px 10px rgba(0,0,0,0.15);
  transform: translateY(-2px);
}
.draggable-chip:active {
  cursor: grabbing;
}

.scheduled-chip {
  margin: 0;
  padding: 0;
  font-size: 0.70rem;
  border-radius: 4px;
  background: rgba(16, 185, 129, 0.15);
  color: #a7f3d0;
  border: 1px solid rgba(16, 185, 129, 0.5);
  cursor: grab;
  box-sizing: border-box;
  overflow: hidden;
  position: relative;
}
.scheduled-content {
  padding: 0.2rem 0.4rem;
}
.scheduled-chip:hover {
  background: rgba(16, 185, 129, 0.3);
  z-index: 15;
}

.caregiver-badge {
  font-size:0.6rem; 
  padding: 2px 4px; 
  background: rgba(0,0,0,0.25); 
  border-radius: 4px; 
  margin-top:2px; 
  display:inline-block;
  color: #fff;
  text-overflow: ellipsis;
  overflow: hidden;
  white-space: nowrap;
  max-width: 100%;
}

.scheduled-footer {
  margin-top:auto; 
  font-size: 0.65rem; 
  display:flex; 
  justify-content:space-between; 
  align-items:center;
}

.scheduled-chip.is-completed {
  background: rgba(255, 255, 255, 0.05);
  border: 1px dashed rgba(255, 255, 255, 0.2);
  color: var(--text-secondary);
  cursor: default;
}
.scheduled-chip.is-completed:hover {
  background: rgba(255, 255, 255, 0.08);
  z-index: 10;
}
.scheduled-chip.is-completed .caregiver-badge {
  background: transparent;
  padding: 0;
  opacity: 0.7;
}

.scheduled-chip.is-overflow {
  background: rgba(139, 92, 246, 0.12);
  border: 1px solid rgba(139, 92, 246, 0.4);
  border-top: 2px dashed rgba(139, 92, 246, 0.7);
  color: #c4b5fd;
  cursor: default;
}
.scheduled-chip.is-overflow:hover {
  background: rgba(139, 92, 246, 0.2);
}

.modal-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}
.modal-content {
  width: 90%;
  max-width: 350px;
  animation: popIn 0.2s ease-out forwards;
}
@keyframes popIn {
  0% { transform: scale(0.95); opacity: 0; }
  100% { transform: scale(1); opacity: 1; }
}

.scheduled-chip.has-bounty {
  border: 1px solid #f59e0b;
  box-shadow: 0 0 10px rgba(245, 158, 11, 0.4);
  background: rgba(245, 158, 11, 0.2);
}
.scheduled-chip.has-bounty:hover {
  background: rgba(245, 158, 11, 0.3);
  box-shadow: 0 0 15px rgba(245, 158, 11, 0.6);
  z-index: 20;
}
.bounty-badge {
  display: inline-block;
  background: #f59e0b;
  color: #fff;
  font-weight: bold;
  font-size: 0.65rem;
  padding: 2px 6px;
  border-radius: 4px;
  margin-top: 4px;
}

</style>
