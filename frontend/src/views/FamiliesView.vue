<script setup>
import { ref } from 'vue';
import { useAppStore } from '../stores/app';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';
import VSelect from '../components/VSelect.vue';

const appStore = useAppStore();
const families = ref([]);
const createFamilyForm = ref({ name: '', monthlyCoinBudget: 1000 });
const joinFamilyForm = ref({ familyId: '', role: 'member' });
const roleForm = ref({ familyId: '', userId: '', role: 'member' });
const recalcForm = ref({ familyId: '' });

const roleOptions = [
  { value: 'member', label: 'Member' },
  { value: 'caregiver', label: 'Caregiver' },
  { value: 'main_caregiver', label: 'Main Caregiver' }
];

const fetchFamilies = () => appStore.runAction(async () => {
  const data = await appStore.request('/api/families', { headers: appStore.authHeaders() });
  families.value = data.families || [];
}, 'Loaded families.');

const createFamily = () => appStore.runAction(async () => {
  await appStore.request('/api/families', { 
    method: 'POST', 
    headers: appStore.authHeaders(), 
    body: JSON.stringify({ name: createFamilyForm.value.name, monthlyCoinBudget: Number(createFamilyForm.value.monthlyCoinBudget) || 1000 }) 
  });
  await fetchFamilies();
}, 'Family created.');

const joinFamily = () => appStore.runAction(async () => {
  await appStore.request(`/api/families/${joinFamilyForm.value.familyId}/join`, { 
    method: 'POST', 
    headers: appStore.authHeaders(), 
    body: JSON.stringify({ role: joinFamilyForm.value.role }) 
  });
  await fetchFamilies();
}, 'Joined family.');

const updateRole = () => appStore.runAction(async () => {
  await appStore.request(`/api/families/${roleForm.value.familyId}/members/${roleForm.value.userId}/role`, { 
    method: 'PATCH', 
    headers: appStore.authHeaders(), 
    body: JSON.stringify({ role: roleForm.value.role }) 
  });
  await fetchFamilies();
}, 'Role updated.');

const recalculateMonthly = () => appStore.runAction(async () => {
  await appStore.request(`/api/families/${recalcForm.value.familyId}/recalculate-monthly`, { 
    method: 'POST', 
    headers: appStore.authHeaders() 
  });
  await fetchFamilies();
}, 'Monthly recalculation completed.');
</script>

<template>
  <VCard title="Families Management">
    <VButton type="secondary" @click="fetchFamilies" style="margin-bottom: 1.5rem;">Load my families</VButton>
    <ul v-if="families.length > 0">
      <li v-for="f in families" :key="f.id">
        <strong>#{{ f.id }} {{ f.name }}</strong> ({{ f.role }}) - Coins: <span style="color: var(--success);">{{ f.coin_balance }}</span>
      </li>
    </ul>

    <hr />

    <h3>Create new family</h3>
    <div class="grid two">
      <VInput v-model="createFamilyForm.name" label="Family Name" placeholder="eg. The Smiths" />
      <VInput v-model="createFamilyForm.monthlyCoinBudget" type="number" label="Monthly Coin Budget" placeholder="1000" />
    </div>
    <VButton type="primary" @click="createFamily" style="margin-top: 1rem;">Create family</VButton>

    <hr />

    <h3>Join existing family</h3>
    <div class="grid two">
      <VInput v-model="joinFamilyForm.familyId" type="number" label="Family ID" placeholder="123" />
      <VSelect v-model="joinFamilyForm.role" :options="roleOptions" label="Request Role" />
    </div>
    <VButton type="primary" @click="joinFamily" style="margin-top: 1rem;">Join family</VButton>

    <hr />

    <h3>Update role (Requires main_caregiver)</h3>
    <div class="grid three">
      <VInput v-model="roleForm.familyId" type="number" label="Family ID" />
      <VInput v-model="roleForm.userId" type="number" label="User ID" />
      <VSelect v-model="roleForm.role" :options="roleOptions" label="New Role" />
    </div>
    <VButton type="danger" @click="updateRole" style="margin-top: 1rem;">Update role</VButton>

    <hr />

    <h3>Recalculate Month</h3>
    <div class="row">
      <VInput v-model="recalcForm.familyId" type="number" label="Family ID" />
      <VButton type="outline" @click="recalculateMonthly">Recalculate monthly coins</VButton>
    </div>
  </VCard>
</template>
