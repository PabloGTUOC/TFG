<script setup>
import { ref, computed, watch } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useFamilyStore } from '../stores/family';
import VCard from '../components/VCard.vue';
import { useRouter } from 'vue-router';

const appStore = useAuthStore();
const familyStore = useFamilyStore();
const router = useRouter();

const dashboard = ref({ members: [], calendar: [], objectsOfCare: [] });
const familyActivities = ref([]);
const currentWeekOffset = ref(0);

const getFamilyId = () => familyStore.families?.[0]?.family_id || familyStore.families?.[0]?.id;

const loadDashboard = () => appStore.runAction(async () => {
  const fid = getFamilyId();
  if (!fid) return;
  dashboard.value = await appStore.request(`/api/dashboard/${fid}`, { headers: appStore.authHeaders() });
  const activitiesData = await appStore.request(`/api/activities?familyId=${fid}`, { headers: appStore.authHeaders() });
  familyActivities.value = activitiesData.activities || [];
}, 'Family dashboard loaded.');

watch(() => getFamilyId(), (newFid) => {
  if (newFid) loadDashboard();
}, { immediate: true });

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
           <div v-for="m in dashboard.members" :key="m.user_id" class="member-badge">
              <div class="member-avatar">{{ m.role === 'caregiver' ? (m.name === 'Mama'?'👩🏽':'👨🏽') : '👦🏽' }}</div>
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
      </VCard>

      <!-- Quick Actions -->
      <div class="quick-actions-card top-card">
         <h3 style="margin-top: 0; margin-bottom: 1.5rem; text-align: center; color: #e2e8f0;">Quick Actions</h3>
         <button class="action-block primary-action" @click="router.push('/activities')">
            <span style="font-size: 1.2rem;">⊕</span> Add Activity
         </button>
         <button class="action-block secondary-action" @click="router.push('/marketplace')">
            <span style="font-size: 1.2rem;">💰</span> Claim Coins
         </button>
      </div>
    </div>

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
.member-name {
  font-weight: 700;
  color: #f8fafc;
  font-size: 1.2rem;
}
.member-coins {
  font-size: 0.9rem;
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
  font-size: 1.05rem;
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
</style>
