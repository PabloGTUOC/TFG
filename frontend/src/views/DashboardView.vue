<script setup>
import { ref, computed, watch } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useFamilyStore } from '../stores/family';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';
import VSelect from '../components/VSelect.vue';
import { useRoute, useRouter } from 'vue-router';
import { useCurrentFamily } from '../composables/useCurrentFamily';

const appStore = useAuthStore();
const familyStore = useFamilyStore();
const route = useRoute();
const router = useRouter();
const { familyId, role } = useCurrentFamily();

const dashboard = ref({ members: [], calendar: [], objectsOfCare: [] });
const familyActivities = ref([]);
const claimedRewards = ref([]);
const currentWeekOffset = ref(0);
const absences = ref([]);
const showAbsenceModal = ref(false);
const absenceForm = ref({ title: '', startTime: '', endTime: '' });
const isSubmittingAbsence = ref(false);

const isCaregiver = computed(() => role.value === 'caregiver');

const loadDashboard = () => appStore.runAction(async () => {
  const fid = familyId.value;
  if (!fid) return;
  dashboard.value = await appStore.request(`/api/dashboard/${fid}`, { headers: appStore.authHeaders() });
  const activitiesData = await appStore.request(`/api/activities?familyId=${fid}`, { headers: appStore.authHeaders() });
  familyActivities.value = activitiesData.activities || [];
  
  try {
    const rewardsData = await appStore.request(`/api/marketplace/rewards/${fid}`, { headers: appStore.authHeaders() });
    claimedRewards.value = rewardsData.claimed || [];
  } catch(e) {}
  
  await loadAbsences();
}, 'Family dashboard loaded.');

const loadAbsences = () => appStore.runAction(async () => {
  const fid = familyId.value;
  if (!fid) return;
  const data = await appStore.request(`/api/absences?familyId=${fid}`, { headers: appStore.authHeaders() });
  absences.value = data.absences || [];
});

const openAbsenceModal = () => {
  const today = new Date();
  const dateStr = today.toISOString().split('T')[0];
  absenceForm.value = { 
    title: '', 
    startTime: `${dateStr}T09:00`, 
    endTime: `${dateStr}T17:00` 
  };
  showAbsenceModal.value = true;
};

const confirmAbsence = async () => {
  if (!absenceForm.value.title || !absenceForm.value.startTime || !absenceForm.value.endTime) {
    appStore.setError('Please fill in all fields.');
    return;
  }
  
  isSubmittingAbsence.value = true;
  await appStore.runAction(async () => {
    const payload = {
      familyId: Number(familyId.value),
      title: absenceForm.value.title,
      startTime: new Date(absenceForm.value.startTime).toISOString(),
      endTime: new Date(absenceForm.value.endTime).toISOString()
    };
    
    await appStore.request('/api/absences', {
      method: 'POST',
      headers: appStore.authHeaders(),
      body: JSON.stringify(payload)
    });
    
    showAbsenceModal.value = false;
    await loadAbsences();
  }, 'Time off logged successfully!');
  isSubmittingAbsence.value = false;
};

watch(familyId, (newFid) => {
  if (newFid) loadDashboard();
}, { immediate: true });

watch(() => route.path, (newPath) => {
  if (newPath === '/dashboard') loadDashboard();
});

const activeMembers = computed(() => dashboard.value.members.filter(m => m.status !== 'pending'));
const pendingMembers = computed(() => dashboard.value.members.filter(m => m.status === 'pending'));

// --- Pending Approval Logic ---
const approveMember = (userId) => appStore.runAction(async () => {
   const fid = familyId.value;
   await appStore.request(`/api/families/${fid}/members/${userId}/approve`, {
     method: 'POST',
     headers: appStore.authHeaders()
   });
   await loadDashboard();
}, 'Member approved!');

// --- Avatar Upload Logic Moved To Profile View ---

// --- Care Object Modal ---
const showCareObjectModal = ref(false);
const careObjectForm = ref({ name: '', actorType: 'child', careTime: 'full_time' });
const typeOptions = [
  { value: 'child', label: 'Child / Baby' },
  { value: 'pet', label: 'Pet' },
  { value: 'elderly', label: 'Elderly' }
];
const timeOptions = [
  { value: 'full_time', label: 'Full Time' },
  { value: 'part_time', label: 'Part Time' }
];

const createCareObject = () => appStore.runAction(async () => {
  const fid = familyId.value;
  if (!careObjectForm.value.name.trim()) throw new Error("Name is required");
  
  await appStore.request(`/api/families/${fid}/actors`, {
    method: 'POST',
    headers: appStore.authHeaders(),
    body: JSON.stringify(careObjectForm.value)
  });
  showCareObjectModal.value = false;
  careObjectForm.value = { name: '', actorType: 'child', careTime: 'full_time' };
  await loadDashboard();
}, 'Care dependent added!');


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

const scheduledInstances = computed(() => familyActivities.value.filter(a => !a.is_template && !!a.starts_at));

const processedWeekDays = computed(() => {
  return weekDays.value.map(date => {
     let acts = scheduledInstances.value.filter(a => {
        const d = new Date(a.starts_at);
        return d.getFullYear() === date.getFullYear() &&
               d.getMonth() === date.getMonth() &&
               d.getDate() === date.getDate();
     });
     // Simple start time sort
     acts.sort((a,b) => new Date(a.starts_at).getTime() - new Date(b.starts_at).getTime());
     return { 
       date, 
       dateStr: `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`,
       acts,
       hasAbsence: absences.value.some(a => {
         const start = new Date(a.start_time);
         const end = new Date(a.end_time);
         const dayStart = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0);
         const dayEnd = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 23, 59, 59);
         return start <= dayEnd && end >= dayStart;
       }),
       dayAbsences: absences.value.filter(a => {
         const start = new Date(a.start_time);
         const end = new Date(a.end_time);
         const dayStart = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0);
         const dayEnd = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 23, 59, 59);
         return start <= dayEnd && end >= dayStart;
       })
     };
  });
});

const navigateToDaily = (dateStr) => {
  router.push(`/daily/${dateStr}`);
};

const navigateToStats = () => {
  router.push('/stats');
};

// --- NEW HIGH FIDELITY COMPUTED DATA ---
const completedToday = computed(() => {
  return familyActivities.value.filter(a => {
    if (a.is_template || !a.starts_at || a.status !== 'completed') return false;
    const d = new Date(a.starts_at);
    const today = new Date();
    return d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate();
  });
});

const todayCoins = computed(() => {
   return dashboard.value.members.reduce((acc, current) => acc + (current.coin_balance || 0), 0);
});

const todayPendingTasks = computed(() => {
   return (familyActivities.value || []).filter(a => a.status === 'pending_validation' || a.status === 'pending').length;
});

const availableOffers = computed(() => {
   return (familyActivities.value || []).filter(a => a.bounty_amount && a.bounty_amount > 0 && a.status !== 'completed');
});

const recentActivitiesList = computed(() => {
   const acts = familyActivities.value
     .filter(a => a.status === 'completed' && a.starts_at)
     .map(a => ({
        id: `act-${a.id}`,
        icon: '✓', color: '#0055ff', bg: '#e0e7ff',
        title: `${a.assigned_to_name || 'Someone'} completed ${a.title}`,
        time: new Date(a.starts_at),
        coinText: `+${a.coin_value} Coins`, coinColor: '#2563eb'
     }));
   
   const rews = claimedRewards.value.map(r => ({
        id: `rew-${r.redemption_id}`,
        icon: '🛍️', color: '#ff4444', bg: '#fee2e2',
        title: `${r.buyer_name || 'Someone'} got ${r.title}`,
        time: new Date(r.redeemed_at),
        coinText: `-${r.cost} Coins`, coinColor: '#ff4444'
     }));
     
   let all = [...acts, ...rews];
   all.sort((a,b) => b.time - a.time);
   
   all.forEach(item => {
      const ms = new Date().getTime() - item.time.getTime();
      const hrs = Math.floor(ms / 3600000);
      if (hrs > 24) item.timeStr = `${Math.floor(hrs/24)} days ago`;
      else if (hrs > 0) item.timeStr = `${hrs} hours ago`;
      else item.timeStr = `${Math.max(1, Math.floor(ms/60000))} mins ago`;
   });
   return all.slice(0, 3);
});

const timeGreeting = computed(() => {
  const h = new Date().getHours();
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
});

const getActorMaxGdp = (actor) => {
   const now = new Date();
   const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
   const hrs = daysInMonth * 24;
   return actor.care_time === 'full_time' ? hrs : Math.floor(hrs / 2);
};

const globalUsedThisMonth = computed(() => dashboard.value.used_this_month || 0);

const getActorRemainingGdp = (actor) => {
   const max = getActorMaxGdp(actor);
   if (!dashboard.value.objectsOfCare || dashboard.value.objectsOfCare.length === 0) return max;
   
   const total = dashboard.value.objectsOfCare.reduce((sum, o) => sum + getActorMaxGdp(o), 0);
   if (total === 0) return 0;
   
   const usedShare = globalUsedThisMonth.value * (max / total);
   return Math.max(0, Math.floor(max - usedShare));
};

const gradients = [
  'linear-gradient(to right, #3b82f6, #2563eb)', // Blue
  'linear-gradient(to right, #10b981, #059669)', // Green
  'linear-gradient(to right, #eab308, #ca8a04)', // Yellow
  'linear-gradient(to right, #ef4444, #dc2626)'  // Red
];

const getAssigneeGradient = (assigned_to) => {
  if (!assigned_to) return 'linear-gradient(to right, #94a3b8, #64748b)'; // Fallback gray
  const index = activeMembers.value.findIndex(m => m.user_id === assigned_to);
  if (index === -1) return 'linear-gradient(to right, #94a3b8, #64748b)';
  return gradients[index % gradients.length];
};
</script>

<template>
  <div class="dashboard-root" v-if="dashboard.members.length > 0" style="padding-top: 1rem;">
    <!-- Title Section -->
    <div class="dash-title-section" style="margin-bottom: 3rem;">
       <h1 class="dash-title" style="color: #1e1b4b; font-size: 3.5rem; font-weight: 800; letter-spacing: -1px; margin-bottom: 0.5rem; margin-top: 0;">Family Hub</h1>
       <p style="color: #64748b; font-size: 1.1rem; max-width: 600px; margin: 0; line-height: 1.5;">
         {{ timeGreeting }}, {{ familyStore.families?.[0]?.alias || familyStore.profile?.display_name || 'Caregiver' }}! Your family has earned <strong>{{ todayCoins || 0 }} coins</strong> today. <strong>{{ todayPendingTasks }} major tasks</strong> are still waiting for attention.
       </p>
    </div>

    <!-- Main Grid: Left (Members + Stats) | Right (Recent) -->
    <div class="dashboard-main-grid">
       
       <!-- LEFT COLUMN -->
       <div>
          
          <!-- Members Title -->
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
             <h2 style="font-size: 1.4rem; font-weight: 800; color: #1e293b; margin: 0;">Active Family Members</h2>
             <a href="#" @click.prevent="router.push('/profile')" style="color: var(--primary); font-weight: 700; text-decoration: none; font-size: 0.95rem; cursor: pointer;">Manage Tribe &rarr;</a>
          </div>

          <!-- Members Grid -->
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 1rem; margin-bottom: 3rem;">
             <div v-for="(m, i) in activeMembers" :key="m.user_id" 
                  class="mockup-member-card" :class="'color-' + (i % 4)">
                <div class="member-avatar"
                     :style="m.avatar_url ? `background-image: url('${appStore.apiBase}${m.avatar_url}'); background-size: cover; background-position: center; border-color: transparent;` : ''">
                   {{ m.avatar_url ? '' : (m.role === 'caregiver' ? (m.name === 'Mama'?'👩🏽':'👨🏽') : '👦🏽') }}
                </div>
                <div style="font-weight: 800; font-size: 1.15rem; color: #1e293b; margin-top: 0.8rem;">{{ m.name || `User ${m.user_id}` }}</div>
                <div style="font-size: 0.8rem; font-weight: 800; margin-top: 0.2rem; display: flex; align-items: center; gap: 0.4rem;" :class="`text-color-${i % 4}`">
                   <div style="width: 12px; height: 12px; border-radius: 50%; background: currentColor;"></div>
                   {{ m.coin_balance }}
                </div>
             </div>
             
             <!-- Objects of Care -->
             <div v-for="(o, i) in dashboard.objectsOfCare" :key="'obj-'+o.id" 
                  class="mockup-member-card" :class="'color-' + ((i+activeMembers.length) % 4)">
                <div class="member-avatar"
                     :style="o.avatar_url ? `background-image: url('${appStore.apiBase}${o.avatar_url}'); background-size: cover; background-position: center; border-color: transparent;` : 'background: #fbbf24; border-color: #f59e0b;'">
                   {{ o.avatar_url ? '' : (o.actor_type === 'child' ? '👶🏽' : (o.actor_type === 'pet' ? '🐶' : '👴🏽')) }}
                </div>
                <div style="font-weight: 800; font-size: 1.15rem; color: #1e293b; margin-top: 0.8rem;">{{ o.name || 'Dependent' }}</div>
                 <div style="font-size: 0.8rem; font-weight: 800; margin-top: 0.2rem; display: flex; align-items: center; gap: 0.4rem;" :class="`text-color-${(i+activeMembers.length) % 4}`">
                    <div style="width: 12px; height: 12px; border-radius: 50%; background: currentColor;"></div>
                    {{ getActorRemainingGdp(o).toLocaleString() }}
                 </div>
              </div>

             <!-- Pending Members -->
             <div v-for="(pm, i) in pendingMembers" :key="'pm-'+pm.user_id" 
                  style="border: 2px dashed #cbd5e1; background: #f8fafc; border-radius: 32px; padding: 1.5rem; display: flex; flex-direction: column; align-items: center; justify-content: center; position: relative;">
                <div class="member-avatar" style="background: #e2e8f0; border-color: #cbd5e1; color: #64748b; font-size: 2rem;">
                   ⏳
                </div>
                <div style="font-weight: 800; font-size: 1.15rem; color: #64748b; margin-top: 0.8rem; text-align: center;">{{ pm.name || `User ${pm.user_id}` }}</div>
                <div style="font-size: 0.75rem; font-weight: 800; text-transform: uppercase; letter-spacing: 1px; color: #94a3b8; margin-top: 0.2rem;">
                   Pending Approval
                </div>
                <button @click="approveMember(pm.user_id)" style="margin-top: 1rem; width: 100%; background: #22c55e; color: white; border: none; padding: 0.5rem; border-radius: 9999px; font-weight: 800; cursor: pointer; transition: transform 0.2s; box-shadow: 0 4px 6px rgba(34,197,94,0.3);" onmouseover="this.style.transform='scale(1.05)'" onmouseout="this.style.transform='scale(1)'">
                   APPROVE
                </button>
             </div>
           </div>

          <!-- Available Offers -->
          <div v-if="availableOffers.length > 0" style="margin-bottom: 3rem;">
             <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 1.2rem;">
               <h2 style="font-size: 1.4rem; font-weight: 800; color: #1e293b; margin: 0;">Task Offers & Bribes</h2>
               <div style="background: rgba(255,215,0,0.15); color: #b45309; padding: 0.3rem 0.6rem; border-radius: 999px; font-size: 0.75rem; font-weight: 900;">{{ availableOffers.length }} ACTIVE</div>
             </div>
             <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 1rem;">
               <div v-for="offer in availableOffers" :key="'offer-'+offer.id" 
                    style="background: white; border: 1px solid var(--card-border); border-radius: 20px; padding: 1.2rem; box-shadow: 0 4px 6px rgba(0,0,0,0.02); display: flex; flex-direction: column; gap: 0.8rem; cursor: pointer; transition: all 0.2s;"
                    @click="navigateToDaily(offer.starts_at.split('T')[0])"
                    onmouseover="this.style.transform='translateY(-2px)'; this.style.boxShadow='0 8px 15px rgba(0,0,0,0.05)';"
                    onmouseout="this.style.transform='none'; this.style.boxShadow='0 4px 6px rgba(0,0,0,0.02)';">
                  <div style="display: flex; justify-content: space-between; align-items: flex-start;">
                    <div style="font-size: 1.8rem; display: flex; align-items: center; justify-content: center; width: 40px; height: 40px; background: #f8fafc; border-radius: 50%;">{{ offer.category === 'care' ? '❤️' : '🍽️' }}</div>
                    <div style="background: rgba(255,215,0,0.9); color: #854d0e; padding: 0.2rem 0.6rem; border-radius: 8px; font-size: 0.9rem; font-weight: 900;">+{{ offer.bounty_amount }}cc</div>
                  </div>
                  <div style="margin-top: 0.2rem;">
                    <div style="font-weight: 800; font-size: 1.05rem; color: #1e293b; line-height: 1.2; margin-bottom: 0.3rem;">{{ offer.title }}</div>
                    <div style="font-size: 0.8rem; color: #64748b; font-weight: 600; display: flex; align-items: center; gap: 0.3rem;">
                      <span class="material-symbols-rounded" style="font-size: 0.9rem;">calendar_today</span>
                      {{ new Date(offer.starts_at).toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' }) }} • {{ new Date(offer.starts_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) }}
                    </div>
                  </div>
               </div>
             </div>
          </div>

          <!-- Giant Stats Bar -->
          <div class="stats-pills-grid">
             <!-- Coins Pill -->
             <div class="stat-pill stat-pill--blue" @click="navigateToStats"
                  onmouseover="this.style.transform='scale(1.02)'"
                  onmouseout="this.style.transform='scale(1)'">
                <div>
                  <div style="text-transform: uppercase; font-size: 0.8rem; font-weight: 800; opacity: 0.85; letter-spacing: 1px; margin-bottom: 0.5rem;">Total Coins Earned</div>
                  <div class="stat-pill-value">{{ dashboard.members.reduce((sum, m) => sum + (m.coin_balance || 0), 0).toLocaleString() }}</div>
                </div>
                <div class="stat-pill-icon">🪙</div>
             </div>

             <!-- Tasks Pill -->
             <div class="stat-pill stat-pill--green" @click="navigateToStats"
                  onmouseover="this.style.transform='scale(1.02)'"
                  onmouseout="this.style.transform='scale(1)'">
                <div>
                  <div style="text-transform: uppercase; font-size: 0.8rem; font-weight: 800; opacity: 0.85; letter-spacing: 1px; margin-bottom: 0.5rem;">Tasks Completed Today</div>
                  <div class="stat-pill-value">{{ completedToday.length }}<span style="opacity:0.4; font-size: 2rem;">/{{ scheduledInstances.length }}</span></div>
                </div>
                <div class="stat-pill-icon">✔</div>
             </div>
          </div>

       </div>

       <!-- RIGHT COLUMN -->
       <div style="min-height: 0; display: flex; flex-direction: column;">
          <div style="background: #f3f4fb; border-radius: 32px; padding: 2.5rem; flex: 1; display: flex; flex-direction: column; overflow: hidden;">
             <h3 style="font-size: 1.5rem; font-weight: 800; color: #1e1b4b; margin-top: 0; margin-bottom: 2rem; flex-shrink: 0;">Recent Activity</h3>
             
             <div style="display: flex; flex-direction: column; gap: 1.5rem; flex: 1; overflow-y: auto; padding-right: 0.5rem; padding-bottom: 1rem;">
               <div v-for="item in recentActivitiesList" :key="item.id" style="display: flex; align-items: flex-start; gap: 1rem;">
                  <div :style="`width: 40px; height: 40px; border-radius: 50%; background: ${item.bg}; color: ${item.color}; display: flex; align-items: center; justify-content: center; font-size: 1.2rem; flex-shrink: 0; font-weight: bold;`">
                     {{ item.icon }}
                  </div>
                  <div>
                     <div style="font-weight: 800; color: #1e293b; font-size: 0.95rem; line-height: 1.3;" v-html="item.title.replace(/(completed|added|spent|got|organized)/, '<span style=\'font-weight:600; color:#64748b;\'>$1</span>')"></div>
                     <div style="display: flex; align-items: center; gap: 0.5rem; margin-top: 0.4rem;">
                       <span style="font-size: 0.75rem; font-weight: 700; color: #94a3b8;">{{ item.timeStr }}</span>
                       <span style="font-size: 0.75rem; font-weight: 800;" :style="`color: ${item.coinColor};`">{{ item.coinText }}</span>
                     </div>
                  </div>
               </div>
               
               <div v-if="recentActivitiesList.length === 0" style="color: #94a3b8; font-weight: 600;">No activity yet.</div>
             </div>

             <VButton type="secondary" block @click="navigateToStats" style="margin-top: 2rem; background: #e0e7ff; color: #3730a3; border: none; flex-shrink: 0;">View Full Audit Log</VButton>
          </div>
       </div>

    </div>

    <!-- FULL-WIDTH BOTTOM ROW -->
    <div class="week-section">
       <div class="week-header">
          <div class="week-title-row">
            <h2 style="font-size: 1.4rem; font-weight: 800; color: #1e293b; margin: 0;">This Week's Schedule</h2>
            <button @click="openAbsenceModal" class="log-off-btn">+ Log Time Off</button>
          </div>
          <div class="week-pagination-row">
             <button @click="currentWeekOffset--" class="pagination-btn">&laquo;</button>
             <div class="pagination-label">{{ weekLabel }}</div>
             <button @click="currentWeekOffset++" class="pagination-btn">&raquo;</button>
          </div>
       </div>

       <div class="week-scroll">
       <div class="mockup-weekly-row" style="background: white; border-radius: 32px; box-shadow: 0 4px 6px rgba(0,0,0,0.02); display: flex; border: 1px solid var(--card-border); min-height: 250px; overflow: hidden;">
          <div v-for="dayObj in processedWeekDays" :key="dayObj.date.toISOString()" 
               class="mockup-day-col"
               @click="navigateToDaily(dayObj.dateStr)">
            
            <div style="text-align: center; padding: 1.2rem 0; border-bottom: 1px solid var(--card-border); position: relative;" 
                 :style="dayObj.hasAbsence ? 'background: #fef2f2; color: #ef4444;' : (dayObj.date.toDateString() === new Date().toDateString() ? 'background: #e0f2fe; color: var(--primary);' : 'color: #64748b;')">
              <div v-if="dayObj.hasAbsence" style="position: absolute; top: 5px; right: 5px; font-size: 0.8rem;" title="Absence recorded">✈️</div>
              <div style="font-weight: 800; font-size: 0.85rem; text-transform: uppercase;">{{ dayObj.date.toLocaleDateString('en-US', { weekday: 'short' }) }}</div>
              <div style="font-size: 1.6rem; font-weight: 800; margin-top: 0.2rem;">{{ dayObj.date.getDate() }}</div>
            </div>

            <div style="flex: 1; padding: 0.8rem; display: flex; flex-direction: column; gap: 0.6rem;">
              <!-- Small Absence Indicators in Column -->
              <div v-for="abs in dayObj.dayAbsences" :key="abs.id" 
                   style="background: #fee2e2; border: 1px solid #fecaca; border-radius: 10px; padding: 0.5rem 0.7rem; font-size: 0.75rem; color: #b91c1c; display: flex; flex-direction: column; gap: 0.2rem; box-shadow: 0 2px 4px rgba(185, 28, 28, 0.05);">
                <div style="display: flex; align-items: center; gap: 0.3rem; font-weight: 800; font-size: 0.65rem; text-transform: uppercase; letter-spacing: 0.5px;">
                  <span>✈️</span> {{ abs.user_alias || abs.user_name }}
                </div>
                <div style="font-weight: 700; opacity: 0.9; line-height: 1.2; word-break: break-word;">{{ abs.title }}</div>
              </div>
              <div v-for="a in dayObj.acts" :key="a.id" style="border-radius: 12px; padding: 0.5rem 0.8rem; font-size: 0.8rem; color: #fff; box-shadow: 0 4px 6px rgba(0,0,0,0.1); display: flex; flex-direction: column; gap: 0.3rem; cursor: pointer;" :style="{ background: getAssigneeGradient(a.assigned_to) }" @click.stop="navigateToDaily(dayObj.dateStr)">
                <div style="display:flex; align-items: center; justify-content: space-between; gap: 0.2rem;">
                  <div style="display:flex; align-items: center; gap: 0.3rem; flex: 1; min-width: 0;">
                    <span style="font-size: 0.95rem; flex-shrink: 0;">{{ a.category === 'care' ? '❤️' : '🍽️' }}</span>
                    <div style="font-weight: 800; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">{{ a.title }}</div>
                  </div>
                  <span v-if="a.bounty_amount" style="background: rgba(255,215,0,0.95); color: #854d0e; padding: 0.1rem 0.3rem; border-radius: 4px; font-size: 0.65rem; font-weight: 800; line-height: 1; flex-shrink: 0; white-space: nowrap;">+{{a.bounty_amount}}cc</span>
                </div>
                <div style="background: rgba(0,0,0,0.15); padding: 2px 6px; border-radius: 999px; display: inline-block; font-size: 0.75rem; font-weight: 700; align-self: flex-start;">
                  {{ new Date(a.starts_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) }}
                </div>
              </div>
            </div>
            
          </div>
       </div>
       </div><!-- end week-scroll -->
    </div>

    <!-- Add Care Object Modal -->
    <div v-if="showCareObjectModal" class="modal-overlay">
      <VCard title="Add Care Dependent" style="max-width: 400px; width: 100%;">
        <p class="text-sm" style="color: var(--text-secondary); margin-bottom: 1.5rem;">
          Register a new baby, child, elderly dependent, or pet.
        </p>
        <div style="display: flex; flex-direction: column; gap: 1rem; margin-bottom: 1.5rem;">
          <VInput v-model="careObjectForm.name" label="Dependent Name" placeholder="E.g. Fluffy, Junior..." />
          <VSelect v-model="careObjectForm.actorType" :options="typeOptions" label="Care Type" />
          <VSelect v-model="careObjectForm.careTime" :options="timeOptions" label="Care Requirement" />
        </div>
        <div style="display:flex; justify-content: flex-end; gap: 1rem;">
          <VButton type="secondary" @click="showCareObjectModal = false">Cancel</VButton>
          <VButton type="primary" @click="createCareObject">Add to Family</VButton>
        </div>
      </VCard>
    </div>

    <!-- Absence Logging Modal -->
    <div v-if="showAbsenceModal" class="modal-overlay">
      <VCard title="Log Time Off" style="max-width: 400px; width: 100%;">
        <p class="text-sm" style="color: var(--text-secondary); margin-bottom: 1.5rem;">
          Record when you'll be unavailable.
        </p>
        
        <div style="margin-bottom: 1rem;">
          <label style="display: block; margin-bottom: 0.4rem; color: var(--text-primary); font-size: 0.9rem; font-weight: 600;">Title (e.g., Business Trip)</label>
          <input type="text" v-model="absenceForm.title" style="width: 100%; padding: 0.75rem; border-radius: var(--radius-button); font-size: 1rem; background: var(--input-bg); color: var(--text-primary); border: 1px solid var(--input-border); outline: none;" placeholder="Enter reason..." />
        </div>
        
        <div style="display: flex; flex-direction: column; gap: 1rem; margin-bottom: 1.8rem;">
          <div>
            <label style="display: block; margin-bottom: 0.4rem; color: var(--text-primary); font-size: 0.9rem; font-weight: 600;">Start Time</label>
            <input type="datetime-local" v-model="absenceForm.startTime" style="width: 100%; padding: 0.75rem; border-radius: var(--radius-button); font-size: 1rem; background: var(--input-bg); color: var(--text-primary); border: 1px solid var(--input-border); outline: none;" />
          </div>
          <div>
            <label style="display: block; margin-bottom: 0.4rem; color: var(--text-primary); font-size: 0.9rem; font-weight: 600;">End Time</label>
            <input type="datetime-local" v-model="absenceForm.endTime" style="width: 100%; padding: 0.75rem; border-radius: var(--radius-button); font-size: 1rem; background: var(--input-bg); color: var(--text-primary); border: 1px solid var(--input-border); outline: none;" />
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

    <!-- Render child modal routes (e.g. Daily Details) -->
    <router-view />
  </div>
</template>

<style scoped>
.dashboard-root {
  max-width: 1300px;
  margin: 0 auto;
}

.log-off-btn {
  background: rgba(var(--primary-rgb), 0.1);
  color: var(--primary);
  border: 1px solid var(--primary);
  padding: 0.4rem 1.2rem;
  border-radius: 999px;
  font-size: 0.9rem;
  font-weight: 800;
  cursor: pointer;
  transition: all 0.2s;
}
.log-off-btn:hover {
  background: var(--primary);
  color: white;
  transform: translateY(-1px);
}

.mockup-member-card {
  background: white;
  border-radius: 20px;
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  box-shadow: 0 4px 6px rgba(0,0,0,0.05);
  transition: transform 0.2s;
}
.mockup-member-card.color-0 { border-bottom: 6px solid #0055ff; }
.mockup-member-card.color-1 { border-bottom: 6px solid #22c55e; }
.mockup-member-card.color-2 { border-bottom: 6px solid #eab308; }
.mockup-member-card.color-3 { border-bottom: 6px solid #ff4444; }

.text-color-0 { color: #0055ff; }
.text-color-1 { color: #22c55e; }
.text-color-2 { color: #eab308; }
.text-color-3 { color: #ff4444; }

.mockup-weekly-row .mockup-day-col {
  flex: 1;
  border-right: 1px solid var(--card-border);
  display: flex;
  flex-direction: column;
  cursor: pointer;
  transition: background 0.2s;
}
.mockup-weekly-row .mockup-day-col:last-child {
  border-right: none;
}
.mockup-weekly-row .mockup-day-col:hover {
  background: #f8fafc;
}

.gradient-pink {
  background: linear-gradient(to right, #a855f7, #ec4899);
}
.gradient-orange {
  background: linear-gradient(to right, #f97316, #eab308);
}

.member-avatar {
  background: #f1f5f9;
  width: 80px;
  height: 80px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 3rem;
  box-shadow: 0 4px 10px rgba(0,0,0,0.05);
}

/* ── Section spacing ─────────────────────────────────────── */
.week-section { margin-top: 4rem; margin-bottom: 4rem; }
.week-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
}
.week-title-row {
  display: flex;
  align-items: center;
  gap: 1.5rem;
}
.week-pagination-row {
  display: flex;
  align-items: center;
  gap: 1rem;
}
.pagination-btn {
  background: var(--input-bg);
  border: 1px solid var(--input-border);
  width: 36px;
  height: 36px;
  border-radius: 50%;
  color: var(--primary);
  font-weight: 800;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}
.pagination-btn:hover {
  background: #f1f5f9;
}
.pagination-label {
  font-weight: 800;
  font-size: 1.1rem;
  color: var(--text-primary);
}

/* ── Stats pills ─────────────────────────────────────────── */
.stat-pill {
  cursor: pointer;
  border-radius: 9999px;
  padding: 2.5rem 3rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}
.stat-pill--blue  { background: #0055ff; color: white; box-shadow: 0 10px 30px rgba(0, 85, 255, 0.4); }
.stat-pill--green { background: #33ff99; color: #064e3b; box-shadow: 0 10px 30px rgba(51, 255, 153, 0.4); }
.stat-pill-value  { font-size: 3.5rem; font-weight: 800; line-height: 1; }
.stat-pill-icon   { width: 80px; height: 80px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 2.5rem; }
.stat-pill--blue  .stat-pill-icon { background: rgba(255,255,255,0.2); }
.stat-pill--green .stat-pill-icon { background: rgba(0,0,0,0.08); }

/* ── Main layout grids ───────────────────────────────────── */
.dashboard-main-grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 3rem;
}

.stats-pills-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
}

/* ── Weekly scroll wrapper ───────────────────────────────── */
.week-scroll {
  overflow-x: auto;
  border-radius: 32px;
  -webkit-overflow-scrolling: touch;
}
.week-scroll .mockup-weekly-row { min-width: 700px; }
.week-scroll .mockup-day-col    { min-width: 100px; }

/* ── Responsive ──────────────────────────────────────────── */
@media (max-width: 768px) {
  .dashboard-root { padding: 1rem; }
  .dash-title { font-size: 2.2rem; letter-spacing: -0.5px; }

  /* Collapse main 2-col → 1-col */
  .dashboard-main-grid { grid-template-columns: 1fr; gap: 1.5rem; }

  /* Stats pills stack + become rectangular */
  .stats-pills-grid { grid-template-columns: 1fr; gap: 1rem; }
  .stat-pill { border-radius: 24px; padding: 1.5rem 2rem; }
  .stat-pill-value { font-size: 2.5rem; }
  .stat-pill-icon { width: 60px; height: 60px; font-size: 2rem; }

  .week-section { margin-top: 2rem; margin-bottom: 2rem; }
  .week-header {
    flex-direction: column;
    align-items: stretch;
    gap: 1.2rem;
  }
  .week-title-row {
    justify-content: space-between;
    gap: 0.5rem;
  }
  .week-pagination-row {
    justify-content: space-between;
    background: white;
    border: 1px solid var(--card-border);
    padding: 0.5rem 1rem;
    border-radius: 999px;
    box-shadow: 0 2px 10px rgba(0,0,0,0.02);
  }

  /* Transform to Vertical Agenda Calendar */
  .week-scroll .mockup-weekly-row {
    flex-direction: column;
    min-width: 0;
  }
  .mockup-weekly-row .mockup-day-col {
    border-right: none;
    border-bottom: 1px solid var(--card-border);
  }
  .mockup-weekly-row .mockup-day-col:last-child {
    border-bottom: none;
  }
}

@media (max-width: 480px) {
  .dash-title { font-size: 1.8rem; }
  .stat-pill { padding: 1.25rem 1.5rem; }
}

</style>
