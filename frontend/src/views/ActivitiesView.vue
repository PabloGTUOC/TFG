<script setup>
import { ref, computed, watch } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useFamilyStore } from '../stores/family';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';
import VSelect from '../components/VSelect.vue';
import { useCurrentFamily } from '../composables/useCurrentFamily';

const appStore = useAuthStore();
const familyStore = useFamilyStore();
const { familyId } = useCurrentFamily();
const allActivities = ref([]);

const categoryFilter = ref('all');

// Show templates, sort alphabetically, filter by category
const templates = computed(() => {
  let arr = allActivities.value.filter(a => a.is_template);
  if (categoryFilter.value !== 'all') {
    arr = arr.filter(a => a.category === categoryFilter.value);
  }
  return arr.sort((a,b) => a.title.localeCompare(b.title));
});

const budgetInfo = ref(null);
const createActivityForm = ref({ title: '', category: 'care', durationMinutes: '60', coinValue: 0, isRecurrent: false });

const categoryOptions = [
  { value: 'care', label: 'Care / Nurture' },
  { value: 'household', label: 'Household Duties' }
];

const durationOptions = Array.from({ length: 24 }, (_, i) => {
  const mins = (i + 1) * 30;
  const hours = mins / 60;
  return {
    value: String(mins),
    label: hours === 0.5 ? '30 mins' :
           hours === 1 ? '1 hour' :
           Number.isInteger(hours) ? `${hours} hours` :
           `${Math.floor(hours)}h 30m`
  };
});

const fetchActivities = () => appStore.runAction(async () => {
  const fid = familyId.value;
  if (!fid) return;
  const data = await appStore.request(`/api/activities?familyId=${fid}`, { headers: appStore.authHeaders() });
  allActivities.value = data.activities || [];
  
  const budgetData = await appStore.request(`/api/families/${fid}/budget`, { headers: appStore.authHeaders() });
  budgetInfo.value = budgetData;
  updateSuggestedCoins(); // Initialize slider once budget is loaded
}, 'Loaded activities and budget.');

const baseScore = computed(() => {
  if (!budgetInfo.value) return 0;
  const hours = Number(createActivityForm.value.durationMinutes) / 60;
  return Math.round(hours * budgetInfo.value.baseRatePerHour);
});
const minCoins = computed(() => Math.max(1, Math.round(baseScore.value * 0.7)));
const maxCoins = computed(() => Math.max(1, Math.round(baseScore.value * 1.3)));

const updateSuggestedCoins = () => {
  if (baseScore.value > 0) {
    createActivityForm.value.coinValue = baseScore.value;
  }
};

watch(() => createActivityForm.value.durationMinutes, () => {
  updateSuggestedCoins();
});

watch(familyId, (newFid) => {
  if (newFid) fetchActivities();
}, { immediate: true });

const createActivity = () => appStore.runAction(async () => {
  const fid = familyId.value;
  if (!fid) throw new Error('No family found.');
  await appStore.request('/api/activities', {
    method: 'POST',
    headers: appStore.authHeaders(),
    body: JSON.stringify({
      familyId: Number(fid),
      title: createActivityForm.value.title,
      category: createActivityForm.value.category,
      durationMinutes: Number(createActivityForm.value.durationMinutes),
      coinValue: Number(createActivityForm.value.coinValue) || baseScore.value,
      isRecurrent: createActivityForm.value.isRecurrent
    })
  });
  createActivityForm.value.title = '';
  await fetchActivities();
}, 'Activity template created — pending approval.');

const approveActivity = (activityId) => appStore.runAction(async () => {
  await appStore.request(`/api/activities/${activityId}/approve`, { method: 'POST', headers: appStore.authHeaders() });
  await fetchActivities();
}, 'Activity approved! It is now available to drag onto the Family Times calendar.');
</script>

<template>
  <div style="display: flex; flex-direction: column; gap: 1rem;">
    <!-- Header -->
    <h2 style="margin-bottom: 1rem; font-weight: 800; letter-spacing: -0.02em;">Family Admin and Budget Hub</h2>

    <div class="grid three" style="align-items: stretch; gap: 1.5rem;" v-if="budgetInfo">

      <!-- Column 1: Activity Catalogue List -->
      <VCard title="Activity Catalogue" class="fixed-card">
        <!-- Category Filters -->
        <div style="margin-bottom: 1.5rem; display:flex; gap: 0.5rem; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 1rem;">
           <button class="filter-btn" :class="{active: categoryFilter === 'all'}" @click="categoryFilter = 'all'">All</button>
           <button class="filter-btn" :class="{active: categoryFilter === 'care'}" @click="categoryFilter = 'care'">Care</button>
           <button class="filter-btn" :class="{active: categoryFilter === 'household'}" @click="categoryFilter = 'household'">Household</button>
        </div>
        
        <!-- Scroller -->
        <div class="activity-scroll-area" style="flex: 1; overflow-y: auto; padding-right: 0.8rem; display: flex; flex-direction: column; gap: 1.2rem; min-height: 0;">
          <div v-for="a in templates" :key="a.id" class="activity-pill">
             <div class="pill-info">
               <div class="pill-title">
                 {{ a.title }} <span v-if="a.is_recurrent" title="Recurring Activity" style="font-size: 0.9rem;">🔁</span>
                 <span v-if="a.status === 'approved'" class="mock-badge">approved</span>
               </div>
               <div class="pill-meta">
                 {{ a.category }} · {{ Math.floor(a.duration_minutes / 60) > 0 ? Math.floor(a.duration_minutes / 60) + 'h ' : '' }}{{ a.duration_minutes % 60 > 0 ? (a.duration_minutes % 60) + 'm' : '' }} · <span style="color: #f59e0b;">🪙 {{ a.coin_value }}cc</span>
               </div>
             </div>
             
             <!-- Action Button -->
             <button v-if="a.status === 'pending'" class="action-btn pending-btn" @click="approveActivity(a.id)">Approve</button>
          </div>
          
          <div v-if="templates.length === 0" style="color:var(--text-secondary); text-align: center; margin-top: 2rem;">
             No activities found.
          </div>
        </div>
      </VCard>

      <!-- Column 2: Register New Activity -->
      <VCard title="Register New Activity" class="fixed-card">
        <p class="text-sm" style="color: var(--text-secondary); margin-bottom: 1.5rem; line-height: 1.4; flex-shrink: 0;">
          Define a reusable activity template. Once approved, it appears in the Family Times sidebar and can be scheduled any number of times.
        </p>
        <div style="display: flex; flex-direction: column; gap: 1.2rem;">
          <VInput v-model="createActivityForm.title" label="Title" placeholder="Park Visit, Bedtime routine…" />
          <VSelect v-model="createActivityForm.category" :options="categoryOptions" label="Category" />
          <VSelect v-model="createActivityForm.durationMinutes" :options="durationOptions" label="Duration" />
          
          <label style="display: flex; align-items: center; gap: 0.5rem; color: #e2e8f0; font-size: 0.9rem; cursor: pointer;">
            <input type="checkbox" v-model="createActivityForm.isRecurrent" style="width: 1rem; height: 1rem; cursor: pointer;" />
            <span>🔁 This is a recurring activity</span>
          </label>
          
          <!-- Slider Component -->
          <div class="mock-slider-box">
            <div style="display:flex; justify-content: space-between; margin-bottom: 0.8rem;">
              <label class="text-sm" style="color: var(--text-secondary);">Coin Value Reward (cc)</label>
              <strong style="color: #c084fc;">{{ createActivityForm.coinValue }} cc</strong>
            </div>
            <input type="range" 
                   v-model="createActivityForm.coinValue" 
                   :min="minCoins" 
                   :max="maxCoins" 
                   step="1"
                   class="v-slider"
                   style="width: 100%; cursor: pointer;" />
            <div class="text-xs" style="display:flex; justify-content: space-between; color: rgba(255,255,255,0.4); margin-top: 0.4rem;">
              <span>Min: {{ minCoins }}</span>
              <span>Suggested: {{ baseScore }}</span>
              <span>Max: {{ maxCoins }}</span>
            </div>
          </div>
        </div>
        <button class="mock-create-btn" @click="createActivity">Create activity template</button>
      </VCard>

      <!-- Column 3: Family Budget Health Gauge -->
      <VCard title="Family Budget Health" class="fixed-card">
        <div style="flex: 1; display: flex; flex-direction: column; justify-content: space-between; align-items: center; width: 100%;">
          
          <div class="gauge-container" style="text-align: center; position: relative; width: 100%; flex: 1; display: flex; flex-direction: column; justify-content: center; margin-bottom: 2rem;">
            <div class="text-xs" style="color: var(--text-secondary); text-transform: uppercase; letter-spacing: 1px; margin-bottom: 1.5rem; font-weight: 600;">Remaining this month</div>
            
            <!-- Custom SVG Semi-Circle -->
            <svg viewBox="0 0 200 120" style="width: 100%; max-width: 250px; margin: 0 auto; overflow: visible;">
              <!-- Background Arc -->
              <path d="M 20 100 A 80 80 0 0 1 180 100" fill="none" stroke="#1e293b" stroke-width="14" stroke-linecap="round" />
              <!-- Foreground Arc (Dynamic) -->
              <path d="M 20 100 A 80 80 0 0 1 180 100" fill="none" stroke="#a855f7" stroke-width="14" stroke-linecap="round"
                    :stroke-dasharray="252" 
                    :stroke-dashoffset="252 - (252 * (budgetInfo.remainingBudget / budgetInfo.monthlyBudget))" 
                    style="transition: stroke-dashoffset 1s ease-in-out;" />
            </svg>
            
            <div class="gauge-content">
              <div class="text-4xl" style="font-weight: 800; color: var(--text-primary); line-height: 1; font-size: 3.5rem; margin-top: 1rem;">
                {{ budgetInfo.remainingBudget }}<span class="text-xl" style="color: var(--accent-primary); margin-left: 0.2rem;">cc</span>
              </div>
            </div>
          </div>
          
          <!-- Budget Stats -->
          <div class="text-sm" style="background: var(--input-bg); padding: 1.5rem; border-radius: 12px; width: 100%; max-width: 250px; border: 1px solid var(--input-border); box-shadow: inset 0 2px 10px rgba(0,0,0,0.02);">
            <div style="display:flex; justify-content: space-between; margin-bottom: 1rem;">
              <span style="color: var(--text-secondary);">Total Monthly Pool</span>
              <strong style="color: var(--text-primary); font-size: 1.05rem; font-weight:800;">{{ budgetInfo.monthlyBudget }} cc</strong>
            </div>
            <div style="display:flex; justify-content: space-between; margin-bottom: 1rem; border-top: 1px dashed var(--input-border); padding-top: 0.8rem;">
              <span style="color: var(--text-secondary);">Scheduled/Used</span>
              <strong style="color: var(--text-primary); font-size: 1.05rem; font-weight:800;">{{ budgetInfo.usedThisMonth }} cc</strong>
            </div>
            <div style="display:flex; justify-content: space-between; border-top: 1px dashed var(--input-border); padding-top: 0.8rem;">
              <span style="color: var(--text-secondary);">Estimated Rate</span>
              <strong style="color: #fbbf24; font-size: 1.05rem;">~{{ budgetInfo.baseRatePerHour }} cc / hr</strong>
            </div>
          </div>
          
        </div>
      </VCard>

    </div>

  </div>
</template>

<style scoped>
:deep(.fixed-card) {
  height: 720px;
  display: flex !important;
  flex-direction: column;
}
:deep(.fixed-card .v-card-body) {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* Filter Buttons */
.filter-btn {
  background: transparent;
  border: none;
  font-size: 0.85rem;
  color: var(--text-secondary);
  cursor: pointer;
  padding: 0.3rem 0;
  border-bottom: 2px solid transparent;
  transition: all 0.2s;
}
.filter-btn.active {
  color: #c084fc;
  border-bottom: 2px solid #c084fc;
  font-weight: 600;
}

/* Scrolling Area */
.activity-scroll-area::-webkit-scrollbar {
  width: 6px;
}
.activity-scroll-area::-webkit-scrollbar-thumb {
  background: rgba(255,255,255,0.1);
  border-radius: 3px;
}

/* Light Theme Task Pills */
.activity-pill {
  background: var(--card-bg);
  border-radius: 16px;
  padding: 0.8rem 1.4rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border: 1px solid var(--card-border);
  box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05);
  color: var(--text-primary);
}
.pill-info {
  display: flex;
  flex-direction: column;
}
.pill-title {
  font-size: 1rem;
  font-weight: 800;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
.pill-meta {
  font-size: 0.75rem;
  opacity: 0.85;
  margin-top: 0.2rem;
}
.mock-badge {
  background: #10b981;
  color: #fff;
  font-size: 0.75rem;
  padding: 2px 6px;
  border-radius: 999px;
  text-transform: lowercase;
  font-weight: 600;
  letter-spacing: 0.5px;
}

/* Claim / Approve Buttons inside Pills */
.action-btn {
  border: none;
  border-radius: 20px;
  padding: 0.4rem 1.2rem;
  font-weight: 600;
  font-size: 0.85rem;
  cursor: pointer;
  box-shadow: inset 0 0 0 1px rgba(0,0,0,0.1);
  transition: transform 0.1s;
}
.action-btn:active { transform: scale(0.95); }
.claim-btn {
  background: #7c3aed;
  color: #fff;
  box-shadow: 0 4px 10px rgba(124, 58, 237, 0.4);
}
.pending-btn {
  background: #fff;
  color: #f59e0b;
  border: 1px solid #f59e0b;
}

/* Registration Form Specifics */
.mock-slider-box {
  margin-top: 0.5rem;
  background: transparent;
  padding: 1rem 0;
  border-top: 1px solid rgba(255,255,255,0.05);
}
.mock-create-btn {
  margin-top: 1.5rem;
  width: 100%;
  background: linear-gradient(to right, #a855f7, #ec4899);
  color: #fff;
  font-weight: 600;
  font-size: 0.95rem;
  padding: 0.9rem;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  transition: opacity 0.2s;
  box-shadow: 0 4px 15px rgba(236, 72, 153, 0.3);
}
.mock-create-btn:hover { opacity: 0.9; }

/* Range Slider Styling */
.v-slider {
  -webkit-appearance: none;
  appearance: none;
  background: #334155;
  height: 6px;
  border-radius: 3px;
  outline: none;
}
.v-slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 16px;
  height: 16px;
  border-radius: 50%;
  background: #38bdf8;
  cursor: pointer;
}

/* Gauge Positioning */
.gauge-content {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -10%);
  width: 100%;
}
</style>

