<script setup>
import { ref, computed, watch } from 'vue';
import { useAppStore } from '../stores/app';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';
import VSelect from '../components/VSelect.vue';

const appStore = useAppStore();
const allActivities = ref([]);

// Show only templates in this view (instances live on the calendar)
const templates = computed(() => allActivities.value.filter(a => a.is_template));

const budgetInfo = ref(null);
const createActivityForm = ref({ title: '', category: 'care', durationMinutes: '60', coinValue: 0 });

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

const getFamilyId = () => appStore.families?.[0]?.family_id || appStore.families?.[0]?.id;

const fetchActivities = () => appStore.runAction(async () => {
  const fid = getFamilyId();
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

watch(() => getFamilyId(), (newFid) => {
  if (newFid) fetchActivities();
}, { immediate: true });

const createActivity = () => appStore.runAction(async () => {
  const fid = getFamilyId();
  if (!fid) throw new Error('No family found.');
  await appStore.request('/api/activities', {
    method: 'POST',
    headers: appStore.authHeaders(),
    body: JSON.stringify({
      familyId: Number(fid),
      title: createActivityForm.value.title,
      category: createActivityForm.value.category,
      durationMinutes: Number(createActivityForm.value.durationMinutes),
      coinValue: Number(createActivityForm.value.coinValue) || baseScore.value
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
  <div style="display: flex; flex-direction: column; gap: 2rem;">

    <!-- Activity Templates List -->
    <VCard title="Activity Catalogue">
      <p style="font-size: 0.85rem; color: var(--text-secondary); margin-bottom: 1rem;">
        Approved activities appear in the <strong>Family Times</strong> calendar sidebar and can be dragged to any day, as many times as needed.
      </p>
      <ul v-if="templates.length > 0" style="list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 0.6rem;">
        <li v-for="a in templates" :key="a.id"
            style="padding: 0.8rem 1rem; border-radius: 8px; border: 1px solid var(--input-border); background: var(--input-bg); display:flex; justify-content: space-between; align-items:center;">
          <span>
            <strong style="color: #fff;">{{ a.title }}</strong>
            <span
              :style="{
                marginLeft: '0.5rem',
                fontSize: '0.7rem',
                padding: '2px 7px',
                borderRadius: '999px',
                background: a.status === 'approved' ? 'rgba(16,185,129,0.2)' : 'rgba(245,158,11,0.2)',
                color: a.status === 'approved' ? '#a7f3d0' : '#fde68a'
              }">
              {{ a.status }}
            </span>
            <br/>
            <small style="color: var(--text-secondary);">
              {{ a.category }} ·
              {{ Math.floor(a.duration_minutes / 60) > 0 ? Math.floor(a.duration_minutes / 60) + 'h ' : '' }}{{ a.duration_minutes % 60 > 0 ? (a.duration_minutes % 60) + 'm' : '' }}
              · <span style="color: var(--accent-primary);">{{ a.coin_value }} cc</span>
            </small>
          </span>
          <VButton v-if="a.status === 'pending'" type="secondary"
                   style="font-size:0.75rem; padding: 0.3rem 0.8rem; white-space: nowrap;"
                   @click="approveActivity(a.id)">
            ✓ Approve
          </VButton>
          <span v-else style="font-size: 0.75rem; color: #a7f3d0;">✓ In sidebar</span>
        </li>
      </ul>
      <p v-else style="color:var(--text-secondary);">No activity templates yet. Create one below!</p>
    </VCard>

    <div class="grid two" v-if="budgetInfo">
      <!-- Create Template -->
      <VCard title="Register New Activity" style="height: 100%;">
        <p style="font-size: 0.85rem; color: var(--text-secondary); margin-bottom: 1rem;">
          Define a reusable activity template. Once approved, it appears in the Family Times sidebar and can be scheduled any number of times.
        </p>
        <div style="display: flex; flex-direction: column; gap: 1rem;">
          <VInput v-model="createActivityForm.title" label="Title" placeholder="Park Visit, Bedtime routine…" />
          <div class="grid two">
            <VSelect v-model="createActivityForm.category" :options="categoryOptions" label="Category" />
            <VSelect v-model="createActivityForm.durationMinutes" :options="durationOptions" label="Duration" />
          </div>
          
          <div v-if="budgetInfo" style="margin-top: 0.5rem; background: var(--bg-surface); padding: 1rem; border-radius: 8px; border: 1px solid var(--input-border);">
            <div style="display:flex; justify-content: space-between; margin-bottom: 0.5rem;">
              <label style="font-size: 0.85rem; color: var(--text-secondary);">Coin Value Reward (cc)</label>
              <strong style="color: var(--accent-primary);">{{ createActivityForm.coinValue }} cc</strong>
            </div>
            <input type="range" 
                   v-model="createActivityForm.coinValue" 
                   :min="minCoins" 
                   :max="maxCoins" 
                   step="1"
                   style="width: 100%; cursor: pointer;" />
            <div style="display:flex; justify-content: space-between; font-size: 0.7rem; color: var(--text-secondary); margin-top: 0.2rem;">
              <span>Min: {{ minCoins }}</span>
              <span>Suggested: {{ baseScore }}</span>
              <span>Max: {{ maxCoins }}</span>
            </div>
          </div>
        </div>
        <VButton type="primary" @click="createActivity" style="margin-top: 1.5rem;">Create activity template</VButton>
      </VCard>

      <!-- Monthly Budget Guide -->
      <VCard title="Family Budget Health" style="height: 100%;">
        <p style="font-size: 0.85rem; color: var(--text-secondary); margin-bottom: 1rem;">
          Your family's economy is anchored to the cumulative amount of care generated per month.
        </p>
        
        <div style="text-align: center; margin-bottom: 2rem; margin-top: 1.5rem;">
          <div style="font-size: 0.85rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 1px;">Remaining this Month</div>
          <div style="font-size: 3rem; font-weight: 700; color: #fff; line-height: 1.2;">
            {{ budgetInfo.remainingBudget }} <small style="font-size: 1.2rem; color: #b49af9;">cc</small>
          </div>
        </div>
        
        <div style="background: rgba(255, 255, 255, 0.03); padding: 1rem; border-radius: 8px; font-size: 0.85rem;">
          <div style="display:flex; justify-content: space-between; margin-bottom: 0.5rem;">
            <span style="color: var(--text-secondary);">Total Monthly Pool:</span>
            <strong>{{ budgetInfo.monthlyBudget }} cc</strong>
          </div>
          <div style="display:flex; justify-content: space-between; margin-bottom: 0.5rem;">
            <span style="color: var(--text-secondary);">Scheduled/Used:</span>
            <strong>{{ budgetInfo.usedThisMonth }} cc</strong>
          </div>
          <div style="display:flex; justify-content: space-between;">
            <span style="color: var(--text-secondary);">Estimated Rate:</span>
            <strong>~{{ budgetInfo.baseRatePerHour }} cc / hr</strong>
          </div>
        </div>
      </VCard>
    </div>


  </div>
</template>

