<script setup>
import { ref } from 'vue';
import { storeToRefs } from 'pinia';
import { useAppStore } from './stores/app';

const appStore = useAppStore();
const { apiBase, token, success, error } = storeToRefs(appStore);

const backendStatus = ref('Not checked');
const backendPayload = ref(null);
const me = ref(null);
const loginHistory = ref([]);
const families = ref([]);
const activities = ref([]);
const dashboard = ref({ members: [], calendar: [] });
const offers = ref([]);

const createFamilyForm = ref({ name: '', monthlyCoinBudget: 1000 });
const joinFamilyForm = ref({ familyId: '', role: 'member' });
const roleForm = ref({ familyId: '', userId: '', role: 'member' });
const recalcForm = ref({ familyId: '' });
const familyId = ref('');
const createActivityForm = ref({ familyId: '', assignedToUserId: '', title: '', category: 'care', startsAt: '', endsAt: '', coinValue: '' });
const approveActivityForm = ref({ activityId: '' });
const profileForm = ref({ displayName: '', email: '' });
const dashboardFamilyId = ref('');
const marketplaceFamilyId = ref('');
const offerForm = ref({ familyId: '', title: '', coinCost: '' });
const redeemForm = ref({ offerId: '' });

function authHeaders() {
  return { 'Content-Type': 'application/json', Authorization: `Bearer ${token.value}` };
}

async function request(path, options = {}) {
  const response = await fetch(`${apiBase.value}${path}`, options);
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || `Request failed (${response.status})`);
  return data;
}

async function runAction(fn, okMessage) {
  appStore.clearMessages();
  try {
    await fn();
    if (okMessage) appStore.setSuccess(okMessage);
  } catch (err) {
    appStore.setError(err.message);
  }
}

const checkBackend = () => runAction(async () => {
  backendPayload.value = await request('/health');
  backendStatus.value = 'Online';
}, 'Backend health check succeeded.');

const loadMe = () => runAction(async () => {
  const data = await request('/api/me', { headers: authHeaders() });
  me.value = data.user;
  profileForm.value.displayName = data.user?.display_name || '';
  profileForm.value.email = data.user?.email || '';
}, 'Loaded current user.');

const updateProfile = () => runAction(async () => {
  const data = await request('/api/me/profile', { method: 'PATCH', headers: authHeaders(), body: JSON.stringify(profileForm.value) });
  me.value = data.user;
}, 'Profile updated.');

const loadLoginHistory = () => runAction(async () => {
  const data = await request('/api/me/login-history', { headers: authHeaders() });
  loginHistory.value = data.loginHistory || [];
}, 'Loaded login history.');

const fetchFamilies = () => runAction(async () => {
  const data = await request('/api/families', { headers: authHeaders() });
  families.value = data.families || [];
}, 'Loaded families.');

const createFamily = () => runAction(async () => {
  await request('/api/families', { method: 'POST', headers: authHeaders(), body: JSON.stringify({ name: createFamilyForm.value.name, monthlyCoinBudget: Number(createFamilyForm.value.monthlyCoinBudget) || 1000 }) });
  await fetchFamilies();
}, 'Family created.');

const joinFamily = () => runAction(async () => {
  await request(`/api/families/${joinFamilyForm.value.familyId}/join`, { method: 'POST', headers: authHeaders(), body: JSON.stringify({ role: joinFamilyForm.value.role }) });
  await fetchFamilies();
}, 'Joined family.');

const updateRole = () => runAction(async () => {
  await request(`/api/families/${roleForm.value.familyId}/members/${roleForm.value.userId}/role`, { method: 'PATCH', headers: authHeaders(), body: JSON.stringify({ role: roleForm.value.role }) });
  await fetchFamilies();
}, 'Role updated.');

const recalculateMonthly = () => runAction(async () => {
  await request(`/api/families/${recalcForm.value.familyId}/recalculate-monthly`, { method: 'POST', headers: authHeaders() });
  await fetchFamilies();
}, 'Monthly recalculation completed.');

const fetchActivities = () => runAction(async () => {
  const data = await request(`/api/activities?familyId=${familyId.value}`, { headers: authHeaders() });
  activities.value = data.activities || [];
}, 'Loaded activities.');

const createActivity = () => runAction(async () => {
  await request('/api/activities', { method: 'POST', headers: authHeaders(), body: JSON.stringify({ familyId: Number(createActivityForm.value.familyId), assignedToUserId: Number(createActivityForm.value.assignedToUserId), title: createActivityForm.value.title, category: createActivityForm.value.category, startsAt: createActivityForm.value.startsAt, endsAt: createActivityForm.value.endsAt, coinValue: createActivityForm.value.coinValue ? Number(createActivityForm.value.coinValue) : undefined }) });
  if (!familyId.value) familyId.value = createActivityForm.value.familyId;
  await fetchActivities();
}, 'Activity created.');

const approveActivity = () => runAction(async () => {
  await request(`/api/activities/${approveActivityForm.value.activityId}/approve`, { method: 'POST', headers: authHeaders() });
  await fetchActivities();
}, 'Activity approved.');

const loadDashboard = () => runAction(async () => {
  dashboard.value = await request(`/api/dashboard/${dashboardFamilyId.value}`, { headers: authHeaders() });
}, 'Dashboard loaded.');

const loadOffers = () => runAction(async () => {
  const data = await request(`/api/marketplace/offers/${marketplaceFamilyId.value}`, { headers: authHeaders() });
  offers.value = data.offers || [];
}, 'Marketplace offers loaded.');

const createOffer = () => runAction(async () => {
  await request('/api/marketplace/offers', { method: 'POST', headers: authHeaders(), body: JSON.stringify({ familyId: Number(offerForm.value.familyId), title: offerForm.value.title, coinCost: Number(offerForm.value.coinCost) }) });
  marketplaceFamilyId.value = offerForm.value.familyId;
  await loadOffers();
}, 'Offer created.');

const redeemOffer = () => runAction(async () => {
  await request(`/api/marketplace/offers/${redeemForm.value.offerId}/redeem`, { method: 'POST', headers: authHeaders() });
  if (marketplaceFamilyId.value) await loadOffers();
}, 'Offer redeemed.');
</script>

<template>
  <main>
    <h1>CareCoins</h1>
    <section class="card"><h2>Connection</h2>
      <input v-model="apiBase" placeholder="Backend API URL" />
      <input v-model="token" type="password" placeholder="Firebase ID Token" />
      <button @click="checkBackend">Check backend health</button>
      <p><strong>Status:</strong> {{ backendStatus }}</p><pre v-if="backendPayload">{{ backendPayload }}</pre>
    </section>

    <section class="card"><h2>User / Auth flows</h2>
      <button @click="loadMe">Load my profile</button>
      <button @click="loadLoginHistory">Load login history</button>
      <div class="grid two">
        <input v-model="profileForm.displayName" placeholder="Display name" />
        <input v-model="profileForm.email" placeholder="Email" />
      </div>
      <button @click="updateProfile">Update profile</button>
      <pre v-if="me">{{ me }}</pre>
      <ul><li v-for="item in loginHistory" :key="item.id">{{ item.login_at }} - {{ item.ip_address }} - {{ item.user_agent }}</li></ul>
    </section>

    <section class="card"><h2>Families + Role Management + Monthly Recalc</h2>
      <button @click="fetchFamilies">Load my families</button>
      <div class="grid two"><input v-model="createFamilyForm.name" placeholder="Family name" /><input v-model="createFamilyForm.monthlyCoinBudget" type="number" /></div>
      <button @click="createFamily">Create family</button>
      <div class="grid two"><input v-model="joinFamilyForm.familyId" type="number" placeholder="Family ID" /><select v-model="joinFamilyForm.role"><option>member</option><option>caregiver</option><option>main_caregiver</option></select></div>
      <button @click="joinFamily">Join family</button>
      <div class="grid three"><input v-model="roleForm.familyId" type="number" placeholder="Family ID" /><input v-model="roleForm.userId" type="number" placeholder="User ID" /><select v-model="roleForm.role"><option>member</option><option>caregiver</option><option>main_caregiver</option></select></div>
      <button @click="updateRole">Update role</button>
      <div class="row"><input v-model="recalcForm.familyId" type="number" placeholder="Family ID" /><button @click="recalculateMonthly">Recalculate monthly coins</button></div>
      <ul><li v-for="f in families" :key="f.id">#{{ f.id }} {{ f.name }} / {{ f.role }} / coins: {{ f.coin_balance }}</li></ul>
    </section>

    <section class="card"><h2>Activities</h2>
      <div class="row"><input v-model="familyId" type="number" placeholder="Family ID" /><button @click="fetchActivities">Load activities</button></div>
      <div class="grid two">
        <input v-model="createActivityForm.familyId" type="number" placeholder="Family ID" />
        <input v-model="createActivityForm.assignedToUserId" type="number" placeholder="Assigned user ID" />
        <input v-model="createActivityForm.title" placeholder="Title" />
        <select v-model="createActivityForm.category"><option>care</option><option>household</option></select>
        <input v-model="createActivityForm.startsAt" type="datetime-local" />
        <input v-model="createActivityForm.endsAt" type="datetime-local" />
        <input v-model="createActivityForm.coinValue" type="number" placeholder="Coin value" />
      </div>
      <button @click="createActivity">Create activity</button>
      <div class="row"><input v-model="approveActivityForm.activityId" type="number" placeholder="Activity ID" /><button @click="approveActivity">Approve</button></div>
      <ul><li v-for="a in activities" :key="a.id">#{{ a.id }} {{ a.title }} [{{ a.status }}] coins:{{ a.coin_value }}</li></ul>
    </section>

    <section class="card"><h2>Dashboard / Calendar</h2>
      <div class="row"><input v-model="dashboardFamilyId" type="number" placeholder="Family ID" /><button @click="loadDashboard">Load dashboard</button></div>
      <h3>Balances</h3><ul><li v-for="m in dashboard.members" :key="m.user_id">{{ m.name }} - {{ m.role }} - {{ m.coin_balance }}</li></ul>
      <h3>Calendar summary (30 days)</h3><ul><li v-for="d in dashboard.calendar" :key="d.day">{{ d.day }}: {{ d.total_activities }} activities / {{ d.approved_coins }} coins</li></ul>
    </section>

    <section class="card"><h2>Marketplace</h2>
      <div class="row"><input v-model="marketplaceFamilyId" type="number" placeholder="Family ID" /><button @click="loadOffers">Load offers</button></div>
      <div class="grid three"><input v-model="offerForm.familyId" type="number" placeholder="Family ID" /><input v-model="offerForm.title" placeholder="Offer title" /><input v-model="offerForm.coinCost" type="number" placeholder="Coin cost" /></div>
      <button @click="createOffer">Create offer</button>
      <div class="row"><input v-model="redeemForm.offerId" type="number" placeholder="Offer ID" /><button @click="redeemOffer">Redeem offer</button></div>
      <ul><li v-for="o in offers" :key="o.id">#{{ o.id }} {{ o.title }} - {{ o.coin_cost }} - {{ o.status }}</li></ul>
    </section>

    <p v-if="success" class="success">{{ success }}</p>
    <p v-if="error" class="error">{{ error }}</p>
  </main>
</template>
