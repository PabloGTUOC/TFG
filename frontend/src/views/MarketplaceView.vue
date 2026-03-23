<script setup>
import { ref, computed, onMounted } from 'vue';
import { useAppStore } from '../stores/app';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';

const appStore = useAppStore();
const rewards = ref([]);
const rewardForm = ref({ title: '', description: '', amount: '' });

const getFamilyId = () => appStore.families?.[0]?.family_id || appStore.families?.[0]?.id;
const isMainCaregiver = computed(() => appStore.families?.[0]?.role === 'main_caregiver');

const loadRewards = () => appStore.runAction(async () => {
  const fid = getFamilyId();
  if (!fid) return;
  const data = await appStore.request(`/api/marketplace/rewards/${fid}`, { headers: appStore.authHeaders() });
  rewards.value = data.rewards || [];
}, 'Marketplace loaded.');

onMounted(() => {
  loadRewards();
});

const createReward = () => appStore.runAction(async () => {
  const fid = getFamilyId();
  if (!fid) throw new Error("No family found.");
  if (!rewardForm.value.title || !rewardForm.value.amount) {
    throw new Error("Title and cost are required.");
  }
  
  await appStore.request('/api/marketplace/rewards', { 
    method: 'POST', 
    headers: appStore.authHeaders(), 
    body: JSON.stringify({ 
      familyId: Number(fid), 
      title: rewardForm.value.title,
      description: rewardForm.value.description,
      cost: Number(rewardForm.value.amount) 
    }) 
  });
  
  rewardForm.value.title = '';
  rewardForm.value.description = '';
  rewardForm.value.amount = '';
  appStore.setSuccess("Reward template created!");
  await loadRewards();
});

const redeemReward = (reward) => appStore.runAction(async () => {
  if (!confirm(`Are you sure you want to spend ${reward.cost} coins on '${reward.title}'?`)) return;

  await appStore.request(`/api/marketplace/rewards/${reward.id}/redeem`, { 
    method: 'POST', 
    headers: appStore.authHeaders() 
  });
  
  appStore.setSuccess(`Successfully redeemed ${reward.title}!`);
  await appStore.fetchUserData(); // Refresh user coins immediately
  await loadRewards();
});
</script>

<template>
  <div style="display: flex; flex-direction: column; gap: 2rem;">
    <VCard title="The Reward Store">
      <p style="color:var(--text-secondary); margin-bottom: 2rem; max-width: 600px;">
        Spend your hard-earned CareCoins here! When you buy a reward, the coins are deducted from your personal bank.
      </p>

      <ul v-if="rewards.length > 0" class="reward-grid">
        <li v-for="r in rewards" :key="r.id" class="reward-item">
          <div class="reward-content">
            <h3 class="reward-title">{{ r.title }}</h3>
            <p v-if="r.description" class="reward-desc">{{ r.description }}</p>
          </div>
          <div class="reward-footer">
            <span class="reward-cost">{{ r.cost }} cc</span>
            <VButton type="primary" style="padding: 0.4rem 0.8rem; font-size: 0.8rem;" @click="redeemReward(r)">Buy</VButton>
          </div>
        </li>
      </ul>
      <p v-else style="color:var(--text-secondary); background: var(--input-bg); padding: 2rem; border-radius: 8px; text-align: center;">
        No rewards available yet. Tell the Main Caregiver to create some fun treats!
      </p>
    </VCard>

    <VCard v-if="isMainCaregiver" title="Admins: Create New Reward">
      <p style="color:var(--text-secondary); margin-bottom: 1.5rem; font-size: 0.9rem;">
        Add new treats that caregivers can purchase. Once created, they can be redeemed endlessly by anyone with enough coins.
      </p>
      <div class="grid three">
        <VInput v-model="rewardForm.title" label="Reward Title" placeholder="e.g. Winner picks the movie" />
        <VInput v-model="rewardForm.description" label="Description" placeholder="Optional details..." />
        <VInput v-model="rewardForm.amount" type="number" label="Coin Cost" placeholder="e.g. 15" />
      </div>
      <VButton type="outline" @click="createReward" style="margin-top: 1.5rem; width: 100%; max-width: 250px;">Add Reward to Store</VButton>
    </VCard>
  </div>
</template>

<style scoped>
.reward-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1.5rem;
}
.reward-item {
  display: flex;
  flex-direction: column;
  background: var(--bg-surface);
  border: 1px solid var(--input-border);
  border-radius: 12px;
  overflow: hidden;
  transition: transform 0.2s, box-shadow 0.2s;
}
.reward-item:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 16px rgba(0,0,0,0.2);
  border-color: rgba(139, 92, 246, 0.4);
}
.reward-content {
  padding: 1.5rem;
  flex: 1;
}
.reward-title {
  color: #fff;
  margin: 0 0 0.5rem 0;
  font-size: 1.15rem;
  font-weight: 600;
}
.reward-desc {
  color: var(--text-secondary);
  font-size: 0.9rem;
  line-height: 1.4;
  margin: 0;
}
.reward-footer {
  background: var(--input-bg);
  padding: 1rem 1.5rem;
  border-top: 1px solid var(--input-border);
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.reward-cost {
  color: var(--accent-secondary);
  font-weight: 700;
  font-size: 1.25rem;
}
</style>
