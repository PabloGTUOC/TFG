<script setup>
import { ref } from 'vue';
import { useAppStore } from '../stores/app';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';

const appStore = useAppStore();
const dashboardFamilyId = ref('');
const dashboard = ref({ members: [], calendar: [] });

const loadDashboard = () => appStore.runAction(async () => {
  dashboard.value = await appStore.request(`/api/dashboard/${dashboardFamilyId.value}`, { headers: appStore.authHeaders() });
}, 'Dashboard loaded.');
</script>

<template>
  <VCard title="Dashboard and Calendar Analytics">
    <div class="row">
      <VInput v-model="dashboardFamilyId" type="number" label="Family ID" placeholder="1" />
      <VButton type="secondary" @click="loadDashboard">Load dashboard</VButton>
    </div>

    <div v-if="dashboard.members.length > 0" style="margin-top: 2rem;">
      <h3>Family Balances</h3>
      <div class="grid three">
        <div v-for="m in dashboard.members" :key="m.user_id" class="balance-card">
          <div class="user-name">{{ m.name || `User ${m.user_id}` }}</div>
          <div class="role-badge">{{ m.role }}</div>
          <div class="coin-amount">{{ m.coin_balance }} <small>cc</small></div>
        </div>
      </div>

      <hr />

      <h3>Calendar Summary (30 days)</h3>
      <ul class="calendar-list">
        <li v-for="d in dashboard.calendar" :key="d.day">
          <strong>{{ new Date(d.day).toLocaleDateString() }}</strong>: {{ d.total_activities }} activities scored / 
          <span style="color:var(--success);">{{ d.approved_coins }} coins earned</span>
        </li>
      </ul>
    </div>
  </VCard>
</template>

<style scoped>
.balance-card {
  background: var(--input-bg);
  border: 1px solid var(--input-border);
  padding: 1.2rem;
  border-radius: 12px;
  text-align: center;
  position: relative;
  overflow: hidden;
}
.balance-card::before {
  content: '';
  position: absolute;
  top: 0; left: 0; right: 0; height: 3px;
  background: var(--accent-gradient);
}
.user-name {
  font-weight: 600;
  color: #fff;
  font-size: 1.1rem;
  margin-bottom: 0.2rem;
}
.role-badge {
  font-size: 0.75rem;
  background: rgba(139, 92, 246, 0.2);
  color: #c4b5fd;
  padding: 2px 8px;
  border-radius: 999px;
  display: inline-block;
  margin-bottom: 1rem;
}
.coin-amount {
  font-size: 2rem;
  font-weight: 700;
  color: var(--accent-primary);
  line-height: 1;
}
.coin-amount small {
  font-size: 1rem;
  color: var(--text-secondary);
}
</style>
