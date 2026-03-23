<script setup>
import { ref, watch, onMounted } from 'vue';
import { useAppStore } from '../stores/app';
import VCard from '../components/VCard.vue';
import VInput from '../components/VInput.vue';
import VButton from '../components/VButton.vue';

const appStore = useAppStore();

const activeFamily = appStore.families?.[0]; // Default to the first joined family
const ledgerInfo = ref([]);

const profileForm = ref({ 
  displayName: appStore.profile?.display_name || '', 
  email: appStore.profile?.email || '',
  alias: activeFamily?.alias || ''
});

const updateProfile = () => appStore.runAction(async () => {
  await appStore.request('/api/me/profile', { 
    method: 'PATCH', 
    headers: appStore.authHeaders(), 
    body: JSON.stringify({
      displayName: profileForm.value.displayName,
      email: profileForm.value.email,
      familyId: activeFamily?.family_id,
      alias: profileForm.value.alias
    }) 
  });
  await appStore.fetchUserData();
}, 'Personal details updated successfully!');

const today = new Date();
const currentMonth = ref(`${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`);

const loadLedger = async () => {
  if (!activeFamily) return;
  try {
    const data = await appStore.request(`/api/me/ledger?familyId=${activeFamily.family_id}&month=${currentMonth.value}`, {
      headers: appStore.authHeaders()
    });
    ledgerInfo.value = data.ledger || [];
  } catch (err) {
    appStore.setError("Failed to fetch ledger");
  }
};

const uncheckActivity = async (item) => {
  if (!confirm(`Are you sure you want to logically un-check '${item.activity_title}'? It will formally revert ${item.amount} cc from your bank balance.`)) return;
  await appStore.runAction(async () => {
    await appStore.request(`/api/activities/${item.activity_id}/revert`, { method: 'POST', headers: appStore.authHeaders() });
    await appStore.fetchUserData();
    await loadLedger();
  }, "Activity mathematically unchecked and bank successfully reverted.");
};

onMounted(() => {
  loadLedger();
});

watch(currentMonth, () => {
  loadLedger();
});
</script>

<template>
  <div class="profile-layout" style="display: flex; flex-direction: column; gap: 2rem;">
    <!-- Personal Information Card -->
    <VCard title="Profile & Identity">
      <div class="info-grid">
        <div class="info-item">
          <label>Full Name</label>
          <div class="val">{{ appStore.profile?.display_name || 'N/A' }}</div>
        </div>
        <div class="info-item">
          <label>Email Address</label>
          <div class="val">{{ appStore.profile?.email || 'N/A' }}</div>
        </div>
        <div class="info-item" v-if="activeFamily">
          <label>Active Family</label>
          <div class="val">{{ activeFamily.name }}</div>
        </div>
        <div class="info-item" v-if="activeFamily">
          <label>Your Role</label>
          <div class="val" style="text-transform: capitalize;">{{ activeFamily.role?.replace('_', ' ') }}</div>
        </div>
        <div class="info-item" v-if="activeFamily">
          <label>Your Alias</label>
          <div class="val">{{ activeFamily.alias || 'None Set' }}</div>
        </div>
      </div>
      
      <div style="margin-top: 2rem; padding-top: 1.5rem; border-top: 1px solid var(--card-border);">
        <h3 style="font-size: 1rem; margin-bottom: 1rem; color: var(--text-primary);">Update Details</h3>
        <div class="grid three">
          <VInput v-model="profileForm.displayName" label="Full Name" />
          <VInput v-model="profileForm.email" label="Email Address" />
          <VInput v-if="activeFamily" v-model="profileForm.alias" label="Your Alias" />
        </div>
        <VButton type="primary" @click="updateProfile" style="margin-top: 1.5rem;">Save Changes</VButton>
      </div>
    </VCard>

    <!-- Coin Ledger Card -->
    <VCard title="Monthly Coin Ledger">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; flex-wrap: wrap; gap: 1rem;">
        <p style="color: var(--text-secondary); font-size: 0.9rem; margin: 0; max-width: 400px;">
          Review your activity receipts and total CareCoins earned month over month.
        </p>
        <VInput type="month" v-model="currentMonth" style="width: 200px;" />
      </div>

      <div v-if="ledgerInfo.length > 0" class="ledger-list">
        <div v-for="item in ledgerInfo" :key="item.id" class="ledger-item">
          <div class="ledger-details">
            <strong class="ledger-title">{{ item.activity_title || item.reason }}</strong>
            <span class="ledger-date">{{ new Date(item.created_at).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' }) }}</span>
            <span v-if="item.duration_minutes" class="ledger-duration">{{ item.duration_minutes }} min</span>
          </div>
          <div class="ledger-amount" style="text-align: right;">
            <div :class="{ positive: item.amount > 0 }" style="font-weight: 600; font-size: 1.1rem;">
              {{ item.amount > 0 ? '+' : '' }}{{ item.amount }} cc
            </div>
            <div v-if="item.reason === 'activity_completed'" style="margin-top: 0.5rem;">
              <VButton type="outline" style="border-color: var(--error); color: var(--error); padding: 2px 8px; font-size: 0.75rem; border-radius: 4px; box-shadow: none;" @click="uncheckActivity(item)">Un-check</VButton>
            </div>
          </div>
        </div>
      </div>
      <div v-else style="text-align: center; padding: 2rem; color: var(--text-secondary); background: var(--input-bg); border-radius: 8px;">
        No ledger activity found for this month.
      </div>
    </VCard>
  </div>
</template>

<style scoped>
.info-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1.5rem;
}
.info-item label {
  display: block;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--text-secondary);
  margin-bottom: 0.2rem;
}
.info-item .val {
  font-size: 1.1rem;
  color: #fff;
  font-weight: 500;
}

.ledger-list {
  display: flex;
  flex-direction: column;
  gap: 0.8rem;
}
.ledger-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  background: var(--input-bg);
  border: 1px solid var(--input-border);
  border-radius: 8px;
}
.ledger-details {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}
.ledger-title {
  font-size: 1.05rem;
  color: #fff;
}
.ledger-date {
  font-size: 0.8rem;
  color: var(--text-secondary);
}
.ledger-duration {
  font-size: 0.75rem;
  color: #c4b5fd;
  background: rgba(139, 92, 246, 0.1);
  padding: 2px 6px;
  border-radius: 4px;
  width: fit-content;
  margin-top: 0.2rem;
}
.ledger-amount {
  font-size: 1.5rem;
  font-weight: bold;
}
.ledger-amount.positive {
  color: var(--success);
}
</style>
