<script setup>
import { ref, computed, watch } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useFamilyStore } from '../stores/family';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';
import VSelect from '../components/VSelect.vue';
import { useRouter } from 'vue-router';

const appStore = useAuthStore();
const familyStore = useFamilyStore();
const router = useRouter();

const dashboard = ref({ members: [], calendar: [], objectsOfCare: [] });
const familyActivities = ref([]);
const claimedRewards = ref([]);
const currentWeekOffset = ref(0);

const getFamilyId = () => familyStore.families?.[0]?.family_id || familyStore.families?.[0]?.id;
const isMainCaregiver = computed(() => familyStore.families?.[0]?.role === 'main_caregiver');

const loadDashboard = () => appStore.runAction(async () => {
  const fid = getFamilyId();
  if (!fid) return;
  dashboard.value = await appStore.request(`/api/dashboard/${fid}`, { headers: appStore.authHeaders() });
  const activitiesData = await appStore.request(`/api/activities?familyId=${fid}`, { headers: appStore.authHeaders() });
  familyActivities.value = activitiesData.activities || [];
  
  try {
    const rewardsData = await appStore.request(`/api/marketplace/rewards/${fid}`, { headers: appStore.authHeaders() });
    claimedRewards.value = rewardsData.claimed || [];
  } catch(e) {}
}, 'Family dashboard loaded.');

watch(() => getFamilyId(), (newFid) => {
  if (newFid) loadDashboard();
}, { immediate: true });

const activeMembers = computed(() => dashboard.value.members.filter(m => m.status !== 'pending'));
const pendingMembers = computed(() => dashboard.value.members.filter(m => m.status === 'pending'));

// --- Pending Approval Logic ---
const approveMember = (userId) => appStore.runAction(async () => {
   const fid = getFamilyId();
   await appStore.request(`/api/families/${fid}/members/${userId}/approve`, {
     method: 'POST',
     headers: appStore.authHeaders()
   });
   await loadDashboard();
}, 'Member approved!');

// --- Avatar Upload Logic ---
const avatarInput = ref(null);
const triggerAvatarUpload = () => {
  if (avatarInput.value) avatarInput.value.click();
};
const handleAvatarUpload = async (event) => {
  const file = event.target.files[0];
  if (!file) return;

  const formData = new FormData();
  formData.append('avatar', file);

  await appStore.runAction(async () => {
    const headers = appStore.authHeaders();
    delete headers['Content-Type']; // Let browser set multipart boundary
    
    const res = await fetch(`${appStore.apiBase}/api/me/avatar`, {
      method: 'POST',
      headers: { Authorization: headers.Authorization },
      body: formData
    });
    
    if (!res.ok) {
        const d = await res.json().catch(()=>({}));
        throw new Error(d.error || 'Upload failed');
    }
    await loadDashboard();
    await familyStore.fetchUserData(); // Refresh profile in family store too
  }, 'Avatar updated successfully!');
};

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
  const fid = getFamilyId();
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
       acts 
     };
  });
});

const navigateToDaily = (dateStr) => {
  router.push(`/daily/${dateStr}`);
};
</script>

<template>
  <div class="dashboard-root" v-if="dashboard.members.length > 0">
    
    <!-- Top Row: Members and Actions -->
    <div class="dashboard-top-row">
      <!-- Family at a Glance -->
      <VCard title="Family at a Glance" class="top-card">
         <div class="family-members-row">
           <!-- Human Caregivers / Members -->
           <div v-for="m in activeMembers" :key="m.user_id" class="member-badge">
              <div class="member-avatar"
                   :style="m.avatar_url ? `background-image: url('${appStore.apiBase}${m.avatar_url}'); background-size: cover; background-position: center; border-color: transparent;` : ''"
                   @click="m.user_id === familyStore.profile?.id ? triggerAvatarUpload() : null"
                   :class="{'cursor-pointer hover-scale': m.user_id === familyStore.profile?.id}"
                   :title="m.user_id === familyStore.profile?.id ? 'Click to change avatar' : ''">
                 {{ m.avatar_url ? '' : (m.role === 'main_caregiver' || m.role === 'caregiver' ? (m.name === 'Mama'?'👩🏽':'👨🏽') : '👦🏽') }}
              </div>
              <div class="member-name">{{ m.name || `User ${m.user_id}` }}</div>
              <div class="member-coins">🪙 {{ m.coin_balance }} cc</div>
           </div>

           <!-- Objects of Care -->
           <div v-for="o in dashboard.objectsOfCare" :key="'obj-'+o.id" class="member-badge">
              <div class="member-avatar" style="background: #fbbf24; border-color: #f59e0b;">{{ o.actor_type === 'child' ? '👶🏽' : (o.actor_type === 'pet' ? '🐶' : '👴🏽') }}</div>
              <div class="member-name">{{ o.name || 'Dependent' }}</div>
              <div class="member-coins" style="color: #94a3b8;">{{ o.care_time === 'full_time' ? 'Full Time' : 'Part Time' }}</div>
           </div>
         </div>

         <!-- Pending Members Requests -->
         <div v-if="pendingMembers.length > 0" class="pending-section" style="margin-top: 2rem; border-top: 1px solid rgba(255,255,255,0.1); padding-top: 1.5rem;">
            <h4 class="text-base" style="color:#f8fafc; margin-bottom: 1rem;">Pending Requests</h4>
            <div v-for="p in pendingMembers" :key="p.user_id" style="display:flex; justify-content:space-between; align-items:center; background: rgba(0,0,0,0.2); padding: 0.8rem 1rem; border-radius: 8px; margin-bottom: 0.5rem;">
               <span class="text-sm" style="color:#e2e8f0; font-weight: 500;">{{ p.name }} wants to join</span>
               <button v-if="isMainCaregiver" class="action-block primary-action" style="width: auto; padding: 0.5rem 1rem; margin: 0; font-size: 0.85rem;" @click="approveMember(p.user_id)">Approve</button>
               <span v-else class="text-xs" style="color:#94a3b8; font-style: italic;">Wait for admin</span>
            </div>
         </div>
      </VCard>

      <!-- Quick Actions -->
      <div class="quick-actions-card top-card">
         <h3 style="margin-top: 0; margin-bottom: 1.5rem; text-align: center; color: #e2e8f0;">Quick Actions</h3>
         <button class="action-block primary-action" @click="router.push('/activities')">
            <span class="text-xl">⊕</span> Add Activity
         </button>
         <button class="action-block secondary-action" @click="router.push('/marketplace')">
            <span class="text-xl">💰</span> Claim Coins
         </button>
         <button v-if="isMainCaregiver" class="action-block" style="background:#f8fafc; color:#0f172a; margin-top: 1rem; margin-bottom: 0;" @click="showCareObjectModal = true">
            <span class="text-xl">🐶</span> Add Dependent
         </button>
      </div>
    </div>

    <!-- Claimed Rewards (Backpack) -->
    <VCard v-if="claimedRewards.length > 0" title="Family Backpack (Recently Claimed)" style="margin-top: 2rem;">
      <div style="display:flex; flex-wrap: wrap; gap:1rem;">
        <div v-for="c in claimedRewards" :key="c.redemption_id" style="flex: 1; min-width: 250px; display:flex; align-items:center; gap:1rem; padding: 1rem; background: var(--bg-surface); border-radius: 12px; border: 1px solid var(--input-border);">
           <div style="width:40px; height:40px; border-radius:50%; background:#2563eb; display:flex; align-items:center; justify-content:center; font-size:1.2rem; overflow:hidden;" :style="c.buyer_avatar ? `background-image:url('${appStore.apiBase}${c.buyer_avatar}'); background-size:cover;`:''">
              {{ c.buyer_avatar ? '' : '👤' }}
           </div>
           <div style="flex:1;">
             <strong style="color:#fff; display:block; font-size: 1rem;">{{ c.buyer_name }}</strong>
             <span class="text-sm" style="color:var(--text-secondary);">got "{{ c.title }}"</span>
           </div>
           <div class="text-xs" style="color:#10b981; font-weight: 600; text-align:right;">
             {{ new Date(c.redeemed_at).toLocaleDateString([], { month: 'short', day: 'numeric'}) }}
           </div>
        </div>
      </div>
    </VCard>

    <!-- Full Width Calendar -->
    <VCard title="Weekly Highlights" style="padding: 0; overflow: hidden; display: flex; flex-direction: column; margin-top: 2rem;">
       <div class="calendar-toolbar" style="display:flex; justify-content: space-between; align-items: center; padding: 1.5rem; background: #60a5fa; color: #fff;">
          <button @click="currentWeekOffset--" class="mock-nav-btn">&laquo;</button>
          <div style="font-weight: 600; font-size:1.1rem;">{{ weekLabel }}</div>
          <button @click="currentWeekOffset++" class="mock-nav-btn">&raquo;</button>
       </div>

       <div class="weekly-row">
          <div v-for="dayObj in processedWeekDays" :key="dayObj.date.toISOString()" 
               class="day-column" 
               @click="navigateToDaily(dayObj.dateStr)">
            
            <div class="day-header" :class="{'is-today': dayObj.date.toDateString() === new Date().toDateString()}">
              {{ dayObj.date.toLocaleDateString('en-US', { weekday: 'short' }) }}
              <div class="day-number">{{ dayObj.date.getDate() }}</div>
            </div>

            <div class="day-content">
              <div v-for="a in dayObj.acts" :key="a.id" class="highlight-chip">
                <div class="h-title">{{ a.title }}</div>
                <div class="h-time">🕑 {{ new Date(a.starts_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) }}</div>
              </div>
            </div>

          </div>
       </div>
    </VCard>

    <!-- Hidden Avatar Input -->
    <input type="file" ref="avatarInput" style="display: none;" accept="image/*" @change="handleAvatarUpload">

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

    <!-- Render child modal routes (e.g. Daily Details) -->
    <router-view />
  </div>
</template>

<style scoped>
.dashboard-top-row {
  display: grid;
  grid-template-columns: 7fr 3fr;
  gap: 2rem;
  align-items: stretch;
}
.top-card {
  margin: 0;
  display: flex;
  flex-direction: column;
}

/* Family At A Glance */
.family-members-row {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 4rem;
  padding: 1rem 0;
}
.member-badge {
  display: flex;
  flex-direction: column;
  align-items: center;
}
.member-avatar {
  background: #60a5fa;
  width: 90px;
  height: 90px;
  border-radius: 50%;
  border: 4px solid #3b82f6;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 3rem;
  margin-bottom: 0.8rem;
  box-shadow: 0 10px 20px rgba(59, 130, 246, 0.3);
}
.cursor-pointer { cursor: pointer; }
.hover-scale { transition: transform 0.2s, box-shadow 0.2s; }
.hover-scale:hover { transform: scale(1.05); box-shadow: 0 12px 25px rgba(59, 130, 246, 0.5); }

.member-name {
  font-weight: 700;
  color: #f8fafc;
  font-size: 1.25rem;
}
.member-coins {
  font-size: 0.875rem;
  color: #64748b;
  font-weight: 600;
  margin-top: 0.2rem;
}

/* Weekly Highlights Grid */
.mock-nav-btn {
  background: transparent;
  border: none;
  color: #fff;
  font-size: 1.5rem;
  cursor: pointer;
}
.weekly-row {
  display: flex;
  min-height: 400px;
}
.day-column {
  flex: 1;
  border-right: 1px solid #e2e8f0;
  display: flex;
  flex-direction: column;
  transition: background 0.2s;
  cursor: pointer;
}
.day-column:last-child {
  border-right: none;
}
.day-column:hover {
  background: #f8fafc;
}

.day-header {
  text-align: center;
  padding: 1rem 0;
  border-bottom: 1px solid #e2e8f0;
  font-weight: 600;
  color: #64748b;
  display: flex;
  flex-direction: column;
  align-items: center;
}
.is-today {
  background: #e0f2fe;
  color: #2563eb;
}

.day-content {
  flex: 1;
  padding: 0.5rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.highlight-chip {
  background: #93c5fd;
  border-radius: 6px;
  padding: 0.4rem 0.6rem;
  font-size: 0.8rem;
  color: #1e3a8a;
  box-shadow: 0 2px 5px rgba(0,0,0,0.05);
  border: 1px solid #60a5fa;
}
.h-title {
  font-weight: 600;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.h-time {
  font-size: 0.7rem;
  opacity: 0.8;
  margin-top: 2px;
}

/* Right Col Features */
.quick-actions-card {
  background: #475569;
  border-radius: 16px;
  padding: 2rem;
  box-shadow: 0 10px 25px rgba(0,0,0,0.1);
}

.action-block {
  width: 100%;
  padding: 1rem;
  border-radius: 999px;
  border: none;
  font-weight: 700;
  font-size: 1rem;
  margin-bottom: 1rem;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  transition: transform 0.1s, opacity 0.2s;
}
.action-block:active { transform: scale(0.98); }
.action-block:hover { opacity: 0.9; }

.primary-action {
  background: #e2e8f0;
  color: #0f172a;
}
.secondary-action {
  background: #e0f2fe;
  color: #0f172a;
  margin-bottom: 0;
}

.sidebar-link {
  color: #475569;
  text-decoration: none;
  font-weight: 600;
  font-size: 0.95rem;
  border-bottom: 1px solid transparent;
  transition: all 0.2s;
}
.sidebar-link:hover {
  color: #2563eb;
  border-bottom-color: #2563eb;
}

.modal-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 1000;
  display: flex; align-items: center; justify-content: center;
}
</style>
