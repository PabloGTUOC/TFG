<script setup>
import { ref, computed, watch } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useFamilyStore } from '../stores/family';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';
import VSelect from '../components/VSelect.vue';
import KpiCard from '../components/KpiCard.vue';
import { useRoute, useRouter } from 'vue-router';
import { useCurrentFamily } from '../composables/useCurrentFamily';
import { avatarStyle } from '../utils/avatarStyle';

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
  } catch(e) {
    console.error('Failed to load claimed rewards:', e);
  }
  
  await loadAbsences();
});

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
    return `${monthNames[first.getMonth()]} ${first.getDate()} — ${last.getDate()}`;
  }
  return `${monthNames[first.getMonth()]} ${first.getDate()} — ${monthNames[last.getMonth()]} ${last.getDate()}`;
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
        icon: '✓', color: '#2563EB', bg: '#E8EFFE',
        title: `${a.assigned_to_name || 'Someone'} completed ${a.title}`,
        time: new Date(a.starts_at),
        coinText: `+${a.coin_value} cc`, coinColor: '#16A34A'
     }));
   
   const rews = claimedRewards.value.map(r => ({
        id: `rew-${r.redemption_id}`,
        icon: '🛍️', color: '#DC2626', bg: '#FCE8E8',
        title: `${r.buyer_name || 'Someone'} got ${r.title}`,
        time: new Date(r.redeemed_at),
        coinText: `-${r.cost} cc`, coinColor: '#DC2626'
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

const MEMBER_THEMES = [
  { completed: '#2563EB', pending: '#EBAD25' }, // Blue -> Orange
  { completed: '#16A34A', pending: '#A3166F' }, // Green -> Pink
  { completed: '#D97706', pending: '#0668D9' }, // Orange -> Blue
  { completed: '#DC2626', pending: '#26DC8C' }  // Red -> Cyan
];

const getAssigneeColor = (assigned_to, status) => {
  if (!assigned_to) return '#94A3B8';
  const index = activeMembers.value.findIndex(m => m.user_id === assigned_to);
  if (index === -1) return '#94A3B8';
  const theme = MEMBER_THEMES[index % MEMBER_THEMES.length];
  return status === 'completed' ? theme.completed : theme.pending;
};

const HIGHLIGHT_VERBS = /completed|added|spent|got|organized/;
const splitHighlight = (text) => {
  const match = text.match(HIGHLIGHT_VERBS);
  if (!match) return [{ text, highlight: false }];
  const i = match.index;
  const word = match[0];
  return [
    { text: text.slice(0, i), highlight: false },
    { text: word, highlight: true },
    { text: text.slice(i + word.length), highlight: false },
  ].filter(p => p.text !== '');
};
</script>

<template>
  <div class="dashboard-root" v-if="dashboard.members.length > 0" style="padding-top: 1rem;">
    <!-- Title Section -->
    <div class="dash-title-section" style="margin-bottom: 2.5rem;">
       <h1 class="dash-title" style="color: var(--text-primary); font-size: 38px; font-weight: 800; letter-spacing: -1px; margin-bottom: 0.5rem; margin-top: 0;">Family Hub</h1>
       <p style="color: var(--text-secondary); font-size: 14px; max-width: 600px; margin: 0; line-height: 1.5;">
         {{ timeGreeting }}, {{ familyStore.families?.[0]?.alias || familyStore.profile?.display_name || 'Caregiver' }}! Your family has earned <strong style="color: var(--text-primary);">{{ todayCoins || 0 }} cc</strong> today. <strong style="color: var(--text-primary);">{{ todayPendingTasks }} tasks</strong> are waiting for attention.
       </p>
    </div>

    <!-- Members Section (full-width, above grid) -->
    <div class="members-section">
       <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
          <h2 style="font-size: 1.4rem; font-weight: 800; color: var(--text-primary); margin: 0;">Active Family Members</h2>
          <a href="#" @click.prevent="router.push('/profile')" class="manage-tribe-link" style="color: var(--primary); font-weight: 700; text-decoration: none; font-size: 0.95rem; cursor: pointer;">Manage Tribe &rarr;</a>
       </div>
       <div class="members-row">
          <div class="members-grid" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 1rem;">
             <div v-for="(m, i) in activeMembers" :key="m.user_id"
                  class="mockup-member-card" :class="'color-' + (i % 4)">
                <div class="member-avatar"
                     :style="m.avatar_url ? avatarStyle(appStore.apiBase, m.avatar_url) : null">
                   {{ m.avatar_url ? '' : (m.role === 'caregiver' ? (m.name === 'Mama'?'👩🏽':'👨🏽') : '👦🏽') }}
                </div>
                <div style="font-weight: 800; font-size: 1rem; color: var(--text-primary); margin-top: 0.8rem;">{{ m.name || `User ${m.user_id}` }}</div>
                <div style="font-size: 12px; font-weight: 800; margin-top: 0.3rem; display: flex; align-items: center; gap: 0.3rem;" :class="`text-color-${i % 4}`">
                   ● {{ m.coin_balance }} cc
                </div>
             </div>

             <!-- Objects of Care -->
             <div v-for="(o, i) in dashboard.objectsOfCare" :key="'obj-'+o.id"
                  class="mockup-member-card" :class="'color-' + ((i+activeMembers.length) % 4)">
                <div class="member-avatar"
                     :style="o.avatar_url ? avatarStyle(appStore.apiBase, o.avatar_url) : null">
                   {{ o.avatar_url ? '' : (o.actor_type === 'child' ? '👶🏽' : (o.actor_type === 'pet' ? '🐶' : '👴🏽')) }}
                </div>
                <div style="font-weight: 800; font-size: 1rem; color: var(--text-primary); margin-top: 0.8rem;">{{ o.name || 'Dependent' }}</div>
                <div style="font-size: 12px; font-weight: 800; margin-top: 0.3rem; display: flex; align-items: center; gap: 0.3rem;" :class="`text-color-${(i+activeMembers.length) % 4}`">
                   ● {{ getActorRemainingGdp(o).toLocaleString() }} cc
                </div>
             </div>

             <!-- Pending Members -->
             <div v-for="(pm, i) in pendingMembers" :key="'pm-'+pm.user_id"
                  style="border: 2px dashed var(--border); background: var(--bg); border-radius: var(--r-lg); padding: 1.5rem; display: flex; flex-direction: column; align-items: center; justify-content: center; position: relative;">
                <div class="member-avatar" style="background: var(--bg); color: var(--text-secondary); font-size: 2rem;">
                   ⏳
                </div>
                <div style="font-weight: 800; font-size: 1rem; color: var(--text-secondary); margin-top: 0.8rem; text-align: center;">{{ pm.name || `User ${pm.user_id}` }}</div>
                <div style="font-size: 11px; font-weight: 800; text-transform: uppercase; letter-spacing: 1px; color: var(--text-secondary); margin-top: 0.2rem;">Pending Approval</div>
                <button @click="approveMember(pm.user_id)" style="margin-top: 1rem; width: 100%; background: var(--success); color: white; border: none; padding: 0.5rem; border-radius: var(--r-pill); font-weight: 800; cursor: pointer;">
                   Approve
                </button>
             </div>
          </div>

          <!-- Today Summary chip (mobile only) -->
          <div class="today-card mockup-member-card color-0" @click="navigateToStats">
             <div class="member-avatar" style="background: var(--primary-soft);">
                <span style="font-size: 1.2rem;">✅</span>
             </div>
             <div style="font-weight: 800; font-size: 0.85rem; color: var(--text-primary); margin-top: 0.6rem;">Today</div>
             <div style="font-size: 14px; font-weight: 800; margin-top: 0.2rem; color: var(--primary);">{{ completedToday.length }}/{{ scheduledInstances.length }}</div>
             <div style="font-size: 10px; font-weight: 700; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.5px;">tasks</div>
             <div v-if="todayPendingTasks > 0" style="margin-top: 0.4rem; background: var(--warning-soft); color: var(--warning); font-size: 9px; font-weight: 900; padding: 1px 6px; border-radius: 999px; line-height: 1.6;">{{ todayPendingTasks }} due</div>
          </div>
       </div>
    </div>

    <!-- Main Grid: Left (Offers + KPIs) | Right (Recent) -->
    <div class="dashboard-main-grid">

       <!-- LEFT COLUMN -->
       <div>

          <!-- Available Offers -->
          <div v-if="availableOffers.length > 0" style="margin-bottom: 3rem;">
             <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 1.2rem;">
               <h2 style="font-size: 1.4rem; font-weight: 800; color: var(--text-primary); margin: 0;">Task Offers & Bribes</h2>
               <div style="background: var(--warning-soft); color: var(--warning); padding: 0.3rem 0.6rem; border-radius: var(--r-pill); font-size: 0.75rem; font-weight: 900;">{{ availableOffers.length }} ACTIVE</div>
             </div>
             <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 1rem;">
               <div v-for="offer in availableOffers" :key="'offer-'+offer.id"
                    style="background: var(--surface); border: 1px solid var(--border); border-radius: var(--r-lg); padding: 1.2rem; box-shadow: 0 1px 2px rgba(14,23,38,0.04); display: flex; flex-direction: column; gap: 0.8rem; cursor: pointer; transition: box-shadow 0.2s;"
                    @click="navigateToDaily(offer.starts_at.split('T')[0])">
                  <div style="display: flex; justify-content: space-between; align-items: flex-start;">
                    <div style="font-size: 1.8rem; display: flex; align-items: center; justify-content: center; width: 40px; height: 40px; background: var(--bg); border-radius: 50%;">{{ offer.category === 'care' ? '❤️' : '🍽️' }}</div>
                    <div style="background: var(--warning-soft); color: var(--warning); padding: 0.2rem 0.6rem; border-radius: var(--r-sm); font-size: 0.9rem; font-weight: 900;">+{{ offer.bounty_amount }}cc</div>
                  </div>
                  <div style="margin-top: 0.2rem;">
                    <div style="font-weight: 800; font-size: 1.05rem; color: var(--text-primary); line-height: 1.2; margin-bottom: 0.3rem;">{{ offer.title }}</div>
                    <div style="font-size: 0.8rem; color: var(--text-secondary); font-weight: 600; display: flex; align-items: center; gap: 0.3rem;">
                      <span class="material-symbols-rounded" style="font-size: 0.9rem;">calendar_today</span>
                      {{ new Date(offer.starts_at).toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' }) }} • {{ new Date(offer.starts_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) }}
                    </div>
                  </div>
               </div>
             </div>
          </div>

          <!-- KPI Grid -->
          <div class="kpi-grid" @click="navigateToStats" style="cursor: pointer;">
             <KpiCard
                label="Family Balance"
                accent="primary"
                :value="dashboard.members.reduce((sum, m) => sum + (m.coin_balance || 0), 0).toLocaleString()"
                unit="cc"
                :subtitle="`across ${dashboard.members.length} ${dashboard.members.length === 1 ? 'member' : 'members'}`"
             />
             <KpiCard
                label="Tasks Today"
                accent="success"
                :value="`${completedToday.length}/${scheduledInstances.length}`"
                :subtitle="todayPendingTasks > 0 ? `${todayPendingTasks} awaiting validation` : 'on track'"
                :progress="scheduledInstances.length ? (completedToday.length / scheduledInstances.length) * 100 : 0"
             />
             <KpiCard
                label="Open Bounties"
                accent="warning"
                :value="availableOffers.length"
                :subtitle="availableOffers.length ? `${availableOffers.reduce((s, o) => s + (o.bounty_amount || 0), 0)} cc up for grabs` : 'No bounties open'"
             />
             <KpiCard
                label="Recent Activity"
                accent="ink"
                :value="recentActivitiesList.length"
                :subtitle="recentActivitiesList.length ? 'completed recently' : 'no recent activity'"
             />
          </div>

       </div>

       <!-- RIGHT COLUMN -->
       <div style="min-height: 0; display: flex; flex-direction: column;">
          <div style="background: var(--surface); border: 1px solid var(--border); border-radius: var(--r-lg); padding: 24px; flex: 1; display: flex; flex-direction: column; overflow: hidden;">
             <h3 style="font-size: 16px; font-weight: 800; color: var(--text-primary); margin-top: 0; margin-bottom: 1.5rem; flex-shrink: 0;">Recent Activity</h3>
             
             <div style="display: flex; flex-direction: column; gap: 1.5rem; flex: 1; overflow-y: auto; padding-right: 0.5rem; padding-bottom: 1rem;">
               <div v-for="item in recentActivitiesList" :key="item.id" style="display: flex; align-items: flex-start; gap: 1rem;">
                  <div :style="`width: 40px; height: 40px; border-radius: 50%; background: ${item.bg}; color: ${item.color}; display: flex; align-items: center; justify-content: center; font-size: 1.2rem; flex-shrink: 0; font-weight: bold;`">
                     {{ item.icon }}
                  </div>
                  <div>
                     <div style="font-weight: 800; color: var(--text-primary); font-size: 0.95rem; line-height: 1.3;">
                       <template v-for="(part, i) in splitHighlight(item.title)" :key="i">
                         <span v-if="part.highlight" style="font-weight:600; color:var(--text-secondary);">{{ part.text }}</span>
                         <span v-else>{{ part.text }}</span>
                       </template>
                     </div>
                     <div style="display: flex; align-items: center; gap: 0.5rem; margin-top: 0.4rem;">
                       <span style="font-size: 0.75rem; font-weight: 700; color: var(--text-secondary);">{{ item.timeStr }}</span>
                       <span style="font-size: 0.75rem; font-weight: 800;" :style="`color: ${item.coinColor};`">{{ item.coinText }}</span>
                     </div>
                  </div>
               </div>
               
               <div v-if="recentActivitiesList.length === 0" style="color: var(--text-secondary); font-weight: 600;">No activity yet.</div>
             </div>

             <button @click="navigateToStats" style="margin-top: 1.5rem; width: 100%; padding: 10px; border-radius: var(--r-pill); border: 1px solid var(--border); background: var(--surface); font-weight: 700; font-size: 12px; color: var(--text-secondary); cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 6px; flex-shrink: 0;">
               See all activity
             </button>
          </div>
       </div>

    </div>

    <!-- FULL-WIDTH BOTTOM ROW -->
    <div class="week-section" style="background: var(--surface); border-radius: 20px; padding: 2rem; box-shadow: 0 4px 20px rgba(0,0,0,0.03); border: 1px solid var(--border);">
       <div class="week-header" style="margin-bottom: 2rem;">
          <div>
            <div style="font-size: 0.8rem; font-weight: 800; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 1px; margin-bottom: 0.5rem;">This Week</div>
            <h2 style="font-size: 2rem; font-weight: 800; color: var(--text-primary); margin: 0; line-height: 1;">{{ weekLabel }}</h2>
          </div>
          
          <div style="display: flex; align-items: center; gap: 1rem;">
            <button @click="openAbsenceModal" class="log-off-btn">+ Log Time Off</button>
            <div class="week-pagination-row" style="margin-left: 0.5rem;">
               <button @click="currentWeekOffset--" class="pagination-btn">&laquo;</button>
               <button @click="currentWeekOffset++" class="pagination-btn">&raquo;</button>
            </div>
          </div>
       </div>

       <div class="week-scroll">
       <div class="mockup-weekly-row" style="display: flex; gap: 0.8rem; min-height: 250px;">
          <div v-for="dayObj in processedWeekDays" :key="dayObj.date.toISOString()"
               class="mockup-day-col"
               :class="dayObj.hasAbsence ? 'day-col--absence' : (dayObj.date.toDateString() === new Date().toDateString() ? 'day-col--today' : '')"
               @click="navigateToDaily(dayObj.dateStr)">

            <div class="day-header"
                 :class="dayObj.date.toDateString() === new Date().toDateString() ? 'day-header--today-text' : ''">
              <div v-if="dayObj.hasAbsence" style="position: absolute; top: -2px; right: -2px; font-size: 0.9rem;" title="Absence recorded">✈️</div>
              <div class="day-label">{{ dayObj.date.toLocaleDateString('en-US', { weekday: 'short' }) }}</div>
              <div class="day-num">{{ dayObj.date.getDate() }}</div>
            </div>

            <div style="flex: 1; display: flex; flex-direction: column; gap: 5px;">
              <!-- Absence chips -->
              <div v-for="abs in dayObj.dayAbsences" :key="abs.id"
                   style="background: var(--danger-soft); border: 1px solid var(--danger-soft); border-radius: var(--r-sm); padding: 4px 6px; font-size: 10px; color: var(--danger); display: flex; flex-direction: column; gap: 2px;">
                <div style="display: flex; align-items: center; gap: 3px; font-weight: 800; font-size: 9px; text-transform: uppercase; letter-spacing: 0.5px;">
                  ✈️ {{ abs.user_alias || abs.user_name }}
                </div>
                <div style="font-weight: 700; line-height: 1.2; word-break: break-word;">{{ abs.title }}</div>
              </div>
              <!-- Activity chips -->
              <div v-for="a in dayObj.acts" :key="a.id"
                   style="border-radius: var(--r-sm); padding: 4px 6px; font-size: 10px; font-weight: 600; color: #fff; display: flex; flex-direction: column; gap: 3px; cursor: pointer;"
                   :style="[
                     a.status === 'rejected'
                       ? { background: 'var(--danger-soft)', color: 'var(--danger)', border: '1px solid var(--danger-soft)', opacity: 1 }
                       : { background: getAssigneeColor(a.assigned_to, a.status), opacity: a.status === 'completed' ? 1 : 0.8 }
                   ]"
                   @click.stop="navigateToDaily(dayObj.dateStr)">
                <div style="display:flex; align-items: center; justify-content: space-between; gap: 2px;">
                  <div style="white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex: 1;">
                    <span v-if="a.status === 'rejected'" title="Rejected" style="margin-right:2px;">⚠️</span>{{ a.title }}
                  </div>
                  <span v-if="a.bounty_amount" style="background: rgba(255,255,255,0.25); padding: 1px 4px; border-radius: 999px; font-size: 9px; font-weight: 800; flex-shrink: 0;">+{{a.bounty_amount}}cc</span>
                </div>
                <div style="opacity: 0.8; font-size: 9px;">
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
  max-width: 1080px;
  margin: 0 auto;
}

.log-off-btn {
  background: var(--primary-soft);
  color: var(--primary);
  border: 1px solid var(--primary);
  padding: 0.4rem 1.2rem;
  border-radius: var(--r-pill);
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  transition: background 0.2s, color 0.2s;
}
.log-off-btn:hover {
  background: var(--primary);
  color: white;
}

.mockup-member-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r-lg);
  padding: 18px;
  display: flex;
  flex-direction: column;
  align-items: center;
  box-shadow: 0 1px 2px rgba(14,23,38,0.04);
  text-align: center;
  transition: transform 0.2s;
}
.mockup-member-card:hover { transform: translateY(-2px); }
.mockup-member-card.color-0 { border-bottom: 5px solid var(--primary); }
.mockup-member-card.color-1 { border-bottom: 5px solid var(--success); }
.mockup-member-card.color-2 { border-bottom: 5px solid var(--warning); }
.mockup-member-card.color-3 { border-bottom: 5px solid var(--danger); }

.text-color-0 { color: var(--primary); }
.text-color-1 { color: var(--success); }
.text-color-2 { color: var(--warning); }
.text-color-3 { color: var(--danger); }

.mockup-weekly-row .mockup-day-col {
  flex: 1;
  background: var(--bg);
  border-radius: var(--r-md);
  padding: 0.8rem;
  display: flex;
  flex-direction: column;
  cursor: pointer;
  transition: all 0.2s;
  border: 1px solid transparent;
}
.mockup-weekly-row .mockup-day-col:hover { 
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(14,23,38,0.05);
}
.day-col--today {
  background: var(--primary-soft) !important;
  border: 1px solid var(--primary) !important;
}
.day-col--absence {
  background: var(--danger-soft) !important;
  border: 1px solid var(--danger-soft) !important;
}

.day-header {
  text-align: left;
  padding-bottom: 10px;
  margin-bottom: 10px;
  position: relative;
  color: var(--text-primary);
  border-bottom: none;
}
.day-header--today-text { color: var(--primary); }
.day-label { font-weight: 800; font-size: 0.8rem; text-transform: uppercase; color: inherit; opacity: 0.7; }
.day-num { font-size: 1.6rem; font-weight: 800; line-height: 1; margin-top: 2px; color: inherit; }

.member-avatar {
  background: var(--bg);
  width: 60px;
  height: 60px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 2rem;
}

/* ── Section spacing ─────────────────────────────────────── */
.members-section { margin-bottom: 2.5rem; }
.members-row { display: block; }
.today-card { display: none !important; }
.week-section { margin-top: 1.5rem; margin-bottom: 4rem; }
.week-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
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
  background: var(--bg);
}
.pagination-label {
  font-weight: 800;
  font-size: 1.1rem;
  color: var(--text-primary);
}

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

.kpi-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 14px;
  margin-top: 1.5rem;
}

@media (max-width: 768px) {
  .kpi-grid {
    grid-template-columns: 1fr 1fr;
    gap: 8px;
  }
}

/* ── Weekly scroll wrapper ───────────────────────────────── */
.week-scroll {
  overflow-x: auto;
  border-radius: var(--r-lg);
  -webkit-overflow-scrolling: touch;
}
.week-scroll .mockup-weekly-row { min-width: 700px; }
.week-scroll .mockup-day-col    { min-width: 100px; }

/* ── Responsive ──────────────────────────────────────────── */
@media (max-width: 768px) {
  .dashboard-root {
    padding: 1rem;
    display: flex;
    flex-direction: column;
  }
  .dash-title-section { order: 1; }
  .members-section    { order: 2; margin-bottom: 1.5rem; }
  .week-section       { order: 3; margin-top: 0; }
  .dashboard-main-grid { order: 4; }

  .dash-title { font-size: 2.2rem; letter-spacing: -0.5px; }

  .dashboard-main-grid { grid-template-columns: 1fr; gap: 1.5rem; }

  .manage-tribe-link { display: none; }

  /* Members row: grid + today chip side by side */
  .members-row {
    display: flex;
    align-items: stretch;
    gap: 0.6rem;
  }
  .members-grid {
    flex: 1;
    min-width: 0;
    grid-template-columns: repeat(auto-fit, minmax(80px, 1fr)) !important;
    gap: 0.6rem !important;
  }

  /* Compact member cards on mobile */
  .mockup-member-card { padding: 12px 8px; }
  .member-avatar { width: 44px; height: 44px; font-size: 1.3rem; }

  /* Today summary chip */
  .today-card {
    display: flex !important;
    width: 90px;
    min-width: 90px;
    flex-shrink: 0;
    cursor: pointer;
  }

  .week-section { margin-top: 2rem; margin-bottom: 2rem; padding: 1rem !important; }
  .week-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 1.2rem;
  }
  .week-header > div:last-child {
    width: 100%;
    display: flex;
    justify-content: space-between;
  }
  .week-title-row {
    justify-content: space-between;
    gap: 0.5rem;
  }
  .week-pagination-row {
    justify-content: space-between;
    background: var(--surface);
    border: 1px solid var(--border);
    padding: 0.5rem 1rem;
    border-radius: var(--r-pill);
  }
}

@media (max-width: 480px) {
  .dash-title { font-size: 24px; }
}

</style>
