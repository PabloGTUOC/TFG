<script setup>
import { ref } from 'vue';
import { useAppStore } from '../stores/app';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';
import VSelect from '../components/VSelect.vue';

const appStore = useAppStore();
const familyId = ref('');
const activities = ref([]);

const createActivityForm = ref({ familyId: '', assignedToUserId: '', title: '', category: 'care', startsAt: '', endsAt: '', coinValue: '' });
const approveActivityForm = ref({ activityId: '' });

const categoryOptions = [
  { value: 'care', label: 'Care / Nurture' },
  { value: 'household', label: 'Household Duties' }
];

const fetchActivities = () => appStore.runAction(async () => {
  const data = await appStore.request(`/api/activities?familyId=${familyId.value}`, { headers: appStore.authHeaders() });
  activities.value = data.activities || [];
}, 'Loaded activities.');

const createActivity = () => appStore.runAction(async () => {
  await appStore.request('/api/activities', { 
    method: 'POST', 
    headers: appStore.authHeaders(), 
    body: JSON.stringify({ 
      familyId: Number(createActivityForm.value.familyId), 
      assignedToUserId: Number(createActivityForm.value.assignedToUserId), 
      title: createActivityForm.value.title, 
      category: createActivityForm.value.category, 
      startsAt: createActivityForm.value.startsAt, 
      endsAt: createActivityForm.value.endsAt, 
      coinValue: createActivityForm.value.coinValue ? Number(createActivityForm.value.coinValue) : undefined 
    }) 
  });
  if (!familyId.value) familyId.value = createActivityForm.value.familyId;
  await fetchActivities();
}, 'Activity created.');

const approveActivity = () => appStore.runAction(async () => {
  await appStore.request(`/api/activities/${approveActivityForm.value.activityId}/approve`, { method: 'POST', headers: appStore.authHeaders() });
  await fetchActivities();
}, 'Activity approved.');
</script>

<template>
  <VCard title="Activities Dashboard">
    <div class="row">
      <VInput v-model="familyId" type="number" label="Your Family ID" placeholder="eg. 1" />
      <VButton type="secondary" @click="fetchActivities">Load activities</VButton>
    </div>
    
    <ul v-if="activities.length > 0">
      <li v-for="a in activities" :key="a.id">
        <strong>#{{ a.id }} {{ a.title }}</strong> <span style="color:var(--text-secondary)">[{{ a.status }}]</span> - coins: <span style="color:var(--accent-primary)">{{ a.coin_value }}</span>
      </li>
    </ul>

    <hr />

    <h3>Register Activity</h3>
    <div class="grid two">
      <VInput v-model="createActivityForm.familyId" type="number" label="Family ID" />
      <VInput v-model="createActivityForm.assignedToUserId" type="number" label="Assigned User ID" />
      <VInput v-model="createActivityForm.title" label="Title" placeholder="Cleaning the living room" />
      <VSelect v-model="createActivityForm.category" :options="categoryOptions" label="Category" />
      <VInput v-model="createActivityForm.startsAt" type="datetime-local" label="Start Time" />
      <VInput v-model="createActivityForm.endsAt" type="datetime-local" label="End Time" />
      <VInput v-model="createActivityForm.coinValue" type="number" label="Coin Value (optional)" />
    </div>
    <VButton type="primary" @click="createActivity" style="margin-top: 1rem;">Create activity</VButton>

    <hr />

    <h3>Approve Activity</h3>
    <div class="row">
      <VInput v-model="approveActivityForm.activityId" type="number" label="Activity ID" placeholder="Activity ID to approve" />
      <VButton type="outline" @click="approveActivity">Approve</VButton>
    </div>
  </VCard>
</template>
