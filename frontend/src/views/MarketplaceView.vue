<script setup>
import { ref, computed, onMounted } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useFamilyStore } from '../stores/family';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';
import { useCurrentFamily } from '../composables/useCurrentFamily';

const appStore = useAuthStore();
const familyStore = useFamilyStore();
const { familyId, role } = useCurrentFamily();
const rewards = ref([]);
const claimedRewards = ref([]);
const rewardForm = ref({ title: '', description: '', amount: '', maxUses: '', validFrom: '', validUntil: '' });

const isMainCaregiver = computed(() => role.value === 'main_caregiver');

const loadRewards = () => appStore.runAction(async () => {
  const fid = familyId.value;
  if (!fid) return;
  const data = await appStore.request(`/api/marketplace/rewards/${fid}`, { headers: appStore.authHeaders() });
  rewards.value = data.rewards || [];
  claimedRewards.value = data.claimed || [];
}, 'Marketplace loaded.');

onMounted(() => {
  loadRewards();
});

const createReward = () => appStore.runAction(async () => {
  const fid = familyId.value;
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
      cost: Number(rewardForm.value.amount),
      maxUses: rewardForm.value.maxUses ? Number(rewardForm.value.maxUses) : undefined,
      validFrom: rewardForm.value.validFrom || undefined,
      validUntil: rewardForm.value.validUntil || undefined
    }) 
  });
  
  rewardForm.value = { title: '', description: '', amount: '', maxUses: '', validFrom: '', validUntil: '' };
  appStore.setSuccess("Reward created!");
  await loadRewards();
});

const redeemReward = (reward) => appStore.runAction(async () => {
  if (!confirm(`Are you sure you want to spend ${reward.cost} coins on '${reward.title}'?`)) return;

  await appStore.request(`/api/marketplace/rewards/${reward.id}/redeem`, { 
    method: 'POST', 
    headers: appStore.authHeaders() 
  });
  
  appStore.setSuccess(`Successfully redeemed ${reward.title}!`);
  await familyStore.fetchUserData(); // Refresh user coins immediately
  await loadRewards();
});

const formatDate = (ds) => {
  if (!ds) return '';
  const d = new Date(ds);
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
};
</script>

<template>
  <div style="display: flex; flex-direction: column; gap: 2rem;">
    <!-- Available Rewards -->
    <VCard title="The Reward Store">
      <p style="color:var(--text-secondary); margin-bottom: 2rem; max-width: 600px;">
        Spend your hard-earned CareCoins here! When you buy a reward, the coins are deducted from your personal bank.
      </p>

      <ul v-if="rewards.length > 0" class="reward-grid">
        <li v-for="r in rewards" :key="r.id" class="reward-item">
          <div class="reward-content">
            <h3 class="reward-title">{{ r.title }}</h3>
            <p v-if="r.description" class="reward-desc">{{ r.description }}</p>
            
            <div style="margin-top: 1rem; display: flex; flex-direction: column; gap: 0.3rem;">
              <span v-if="r.max_uses" class="text-xs" style="color: #fbbf24; font-weight: 500;">
                ⚠️ Only {{ r.max_uses - r.uses }} remaining!
              </span>
              <span v-if="r.valid_until" class="text-xs" style="color: #ef4444; font-weight: 500;">
                ⏳ Expires: {{ formatDate(r.valid_until) }}
              </span>
            </div>
          </div>
          <div class="reward-footer">
            <span class="reward-cost">{{ r.cost }} cc</span>
            <VButton type="primary" class="text-sm" style="padding: 0.4rem 0.8rem;" @click="redeemReward(r)">Buy</VButton>
          </div>
        </li>
      </ul>
      <p v-else style="color:var(--text-secondary); background: var(--input-bg); padding: 2rem; border-radius: 8px; text-align: center;">
        No active rewards available. Tell the Main Caregiver to create some fun treats!
      </p>
    </VCard>

    <!-- Claimed Rewards List (Backpack / Fulfillment) -->
    <VCard title="Recently Claimed Rewards">
      <div v-if="claimedRewards.length > 0" style="display:flex; flex-direction:column; gap:1rem;">
        <div v-for="c in claimedRewards" :key="c.redemption_id" style="display:flex; align-items:center; gap:1.5rem; padding: 1rem 1.5rem; background: var(--bg-surface); border-radius: 12px; border: 1px solid var(--input-border);">
           <div style="width:45px; height:45px; border-radius:50%; background:#2563eb; display:flex; align-items:center; justify-content:center; font-size:1.5rem; overflow:hidden;" :style="c.buyer_avatar ? `background-image:url('${appStore.apiBase}${c.buyer_avatar}'); background-size:cover;`:''">
              {{ c.buyer_avatar ? '' : '👤' }}
           </div>
           <div style="flex:1;">
             <strong style="color:var(--text-primary); display:block; font-size: 1.1rem; font-weight:800;">{{ c.buyer_name }}</strong>
             <span class="text-sm" style="color:var(--text-secondary);">Redeemed "<strong style="color: var(--text-primary);">{{ c.title }}</strong>"</span>
           </div>
           <div class="text-sm" style="color:#94a3b8; text-align: right;">
             <div>{{ formatDate(c.redeemed_at) }}</div>
             <div style="color: #10b981; font-weight: 600; margin-top: 0.2rem;">✓ Claimed</div>
           </div>
        </div>
      </div>
      <p v-else class="text-sm" style="color:var(--text-secondary);">No rewards claimed yet.</p>
    </VCard>

    <!-- Admin Create Form -->
    <VCard v-if="isMainCaregiver" title="Admins: Create New Reward">
      <p class="text-sm" style="color:var(--text-secondary); margin-bottom: 1.5rem;">
        Add new treats that caregivers can purchase. Once created, they can be redeemed by anyone with enough coins. Set limits or deadlines to make them exclusive!
      </p>
      <div class="grid three">
        <VInput v-model="rewardForm.title" label="Reward Title" placeholder="e.g. Winner picks the movie" />
        <VInput v-model="rewardForm.description" label="Description" placeholder="Optional details..." />
        <VInput v-model="rewardForm.amount" type="number" label="Coin Cost" placeholder="e.g. 15" />
      </div>
      <div class="grid three" style="margin-top: 1rem;">
        <VInput v-model="rewardForm.maxUses" type="number" label="Max Uses (Optional)" placeholder="e.g. 1 (One-time only)" />
        <VInput v-model="rewardForm.validFrom" type="datetime-local" label="Valid From (Optional)" />
        <VInput v-model="rewardForm.validUntil" type="datetime-local" label="Valid Until (Optional)" />
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
  padding: 0;
  margin: 0;
  list-style: none;
}
.reward-item {
  display: flex;
  flex-direction: column;
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: var(--radius-card, 32px);
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
  color: var(--text-primary);
  margin: 0 0 0.5rem 0;
  font-size: 1.125rem;
  font-weight: 800;
}
.reward-desc {
  color: var(--text-secondary);
  font-size: 0.875rem;
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

.grid.three {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 1rem;
}
</style>
