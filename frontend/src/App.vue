<script setup>
import { ref } from 'vue';

const apiBase = ref('http://localhost:3000');
const token = ref('');
const familyId = ref('');
const backendStatus = ref('Not checked');
const backendPayload = ref(null);
const families = ref([]);
const activities = ref([]);
const error = ref('');
const success = ref('');

const createFamilyForm = ref({
  name: '',
  monthlyCoinBudget: 1000
});

const joinFamilyForm = ref({
  familyId: '',
  role: 'member'
});

const createActivityForm = ref({
  familyId: '',
  assignedToUserId: '',
  title: '',
  category: 'care',
  startsAt: '',
  endsAt: '',
  coinValue: ''
});

const approveActivityForm = ref({
  activityId: ''
});

function clearMessages() {
  error.value = '';
  success.value = '';
}

function authHeaders() {
  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token.value}`
  };
}

async function request(path, options = {}) {
  const response = await fetch(`${apiBase.value}${path}`, options);
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.error || `Request failed (${response.status})`);
  }
  return data;
}

async function checkBackend() {
  clearMessages();
  backendPayload.value = null;

  try {
    const data = await request('/health');
    backendStatus.value = 'Online';
    backendPayload.value = data;
    success.value = 'Backend health check succeeded.';
  } catch (err) {
    backendStatus.value = 'Offline';
    error.value = `Could not connect to backend: ${err.message}`;
  }
}

async function fetchFamilies() {
  clearMessages();
  try {
    const data = await request('/api/families', {
      headers: authHeaders()
    });
    families.value = data.families || [];
    success.value = `Loaded ${families.value.length} families.`;
  } catch (err) {
    error.value = err.message;
  }
}

async function createFamily() {
  clearMessages();
  if (!createFamilyForm.value.name.trim()) {
    error.value = 'Family name is required.';
    return;
  }

  try {
    await request('/api/families', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({
        name: createFamilyForm.value.name,
        monthlyCoinBudget: Number(createFamilyForm.value.monthlyCoinBudget) || 1000
      })
    });
    success.value = 'Family created successfully.';
    createFamilyForm.value.name = '';
    await fetchFamilies();
  } catch (err) {
    error.value = err.message;
  }
}

async function joinFamily() {
  clearMessages();
  if (!joinFamilyForm.value.familyId) {
    error.value = 'Family ID is required to join.';
    return;
  }

  try {
    await request(`/api/families/${joinFamilyForm.value.familyId}/join`, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ role: joinFamilyForm.value.role })
    });
    success.value = 'Joined family successfully.';
    await fetchFamilies();
  } catch (err) {
    error.value = err.message;
  }
}

async function fetchActivities() {
  clearMessages();
  activities.value = [];
  if (!familyId.value) {
    error.value = 'Enter a family ID to load activities.';
    return;
  }

  try {
    const data = await request(`/api/activities?familyId=${familyId.value}`, {
      headers: authHeaders()
    });
    activities.value = data.activities || [];
    success.value = `Loaded ${activities.value.length} activities.`;
  } catch (err) {
    error.value = err.message;
  }
}

async function createActivity() {
  clearMessages();

  try {
    await request('/api/activities', {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({
        familyId: Number(createActivityForm.value.familyId),
        assignedToUserId: Number(createActivityForm.value.assignedToUserId),
        title: createActivityForm.value.title,
        category: createActivityForm.value.category,
        startsAt: createActivityForm.value.startsAt,
        endsAt: createActivityForm.value.endsAt,
        coinValue: createActivityForm.value.coinValue
          ? Number(createActivityForm.value.coinValue)
          : undefined
      })
    });

    success.value = 'Activity created successfully.';
    if (!familyId.value && createActivityForm.value.familyId) {
      familyId.value = createActivityForm.value.familyId;
    }
    await fetchActivities();
  } catch (err) {
    error.value = err.message;
  }
}

async function approveActivity() {
  clearMessages();
  if (!approveActivityForm.value.activityId) {
    error.value = 'Activity ID is required to approve.';
    return;
  }

  try {
    await request(`/api/activities/${approveActivityForm.value.activityId}/approve`, {
      method: 'POST',
      headers: authHeaders()
    });
    success.value = 'Activity approved successfully.';
    await fetchActivities();
  } catch (err) {
    error.value = err.message;
  }
}
</script>

<template>
  <main>
    <h1>CareCoins Dashboard (Vue)</h1>
    <p>
      Backend status + complete currently implemented API actions: list/create/join families and
      list/create/approve activities.
    </p>

    <section class="card">
      <h2>Connection</h2>
      <label>
        Backend API URL
        <input v-model="apiBase" placeholder="http://localhost:3000" />
      </label>
      <label>
        Firebase ID Token
        <input v-model="token" type="password" placeholder="Paste Bearer token" />
      </label>
      <button @click="checkBackend">Check backend health</button>
      <p><strong>Status:</strong> {{ backendStatus }}</p>
      <pre v-if="backendPayload">{{ backendPayload }}</pre>
    </section>

    <section class="card">
      <h2>Families</h2>
      <div class="row">
        <button @click="fetchFamilies">Load my families</button>
      </div>

      <h3>Create family</h3>
      <div class="grid two">
        <label>
          Name
          <input v-model="createFamilyForm.name" placeholder="My Family" />
        </label>
        <label>
          Monthly coin budget
          <input v-model="createFamilyForm.monthlyCoinBudget" type="number" min="1" />
        </label>
      </div>
      <button @click="createFamily">Create family</button>

      <h3>Join family</h3>
      <div class="grid two">
        <label>
          Family ID
          <input v-model="joinFamilyForm.familyId" type="number" min="1" />
        </label>
        <label>
          Role
          <select v-model="joinFamilyForm.role">
            <option value="member">member</option>
            <option value="caregiver">caregiver</option>
            <option value="main_caregiver">main_caregiver</option>
          </select>
        </label>
      </div>
      <button @click="joinFamily">Join family</button>

      <ul>
        <li v-for="family in families" :key="family.id">
          #{{ family.id }} - {{ family.name }} (role: {{ family.role }}, coins:
          {{ family.coin_balance }}, monthly budget: {{ family.monthly_coin_budget }})
        </li>
      </ul>
    </section>

    <section class="card">
      <h2>Activities</h2>
      <label>
        Family ID for listing
        <input v-model="familyId" type="number" placeholder="1" />
      </label>
      <button @click="fetchActivities">Load activities</button>

      <h3>Create activity</h3>
      <div class="grid two">
        <label>
          Family ID
          <input v-model="createActivityForm.familyId" type="number" min="1" />
        </label>
        <label>
          Assigned user ID
          <input v-model="createActivityForm.assignedToUserId" type="number" min="1" />
        </label>
        <label>
          Title
          <input v-model="createActivityForm.title" placeholder="Prepare lunch" />
        </label>
        <label>
          Category
          <select v-model="createActivityForm.category">
            <option value="care">care</option>
            <option value="household">household</option>
          </select>
        </label>
        <label>
          Starts at
          <input v-model="createActivityForm.startsAt" type="datetime-local" />
        </label>
        <label>
          Ends at
          <input v-model="createActivityForm.endsAt" type="datetime-local" />
        </label>
        <label>
          Coin value (optional)
          <input v-model="createActivityForm.coinValue" type="number" min="1" />
        </label>
      </div>
      <button @click="createActivity">Create activity</button>

      <h3>Approve activity</h3>
      <div class="row">
        <label>
          Activity ID
          <input v-model="approveActivityForm.activityId" type="number" min="1" />
        </label>
      </div>
      <button @click="approveActivity">Approve activity</button>

      <ul>
        <li v-for="activity in activities" :key="activity.id">
          #{{ activity.id }} - {{ activity.title }} [{{ activity.status }}]
          ({{ activity.duration_minutes }} min, coins: {{ activity.coin_value }})
        </li>
      </ul>
    </section>

    <p v-if="success" class="success">{{ success }}</p>
    <p v-if="error" class="error">{{ error }}</p>
  </main>
</template>
