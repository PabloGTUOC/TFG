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

const isCaregiver = computed(() => role.value === 'caregiver');

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
  await familyStore.fetchUserData();
  await loadRewards();
});

const formatDate = (ds) => {
  if (!ds) return '';
  const d = new Date(ds);
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
};

const EMOJIS = ['🎬','🏆','🍕','🎮','⭐','🎁','🌟','🍦','🎉','🛍️'];

// Converts any string ID (including UUIDs) to a stable integer for palette selection
const hashId = (id) => String(id).split('').reduce((acc, c) => acc + c.charCodeAt(0), 0);
</script>

<template>
  <div class="marketplace-container" style="display: flex; flex-direction: column; gap: 2rem;">

    <!-- Available Rewards -->
    <VCard title="The Reward Store">
      <p style="color:var(--text-secondary); margin-bottom: 2rem; max-width: 600px;">
        Spend your hard-earned CareCoins here! When you buy a reward, the coins are deducted from your personal bank.
      </p>

      <ul v-if="rewards.length > 0" class="reward-grid">
        <li v-for="r in rewards" :key="r.id" class="reward-item">

          <!-- Gradient Banner -->
          <div class="reward-banner" :class="'banner-' + (hashId(r.id) % 5)">
            <div class="reward-icon">{{ EMOJIS[hashId(r.id) % EMOJIS.length] }}</div>
          </div>

          <!-- Body -->
          <div class="reward-content">
            <h3 class="reward-title">{{ r.title }}</h3>
            <p v-if="r.description" class="reward-desc">{{ r.description }}</p>
            <div v-if="r.max_uses || r.valid_until" style="margin-top: 0.75rem; display: flex; flex-wrap: wrap; gap: 0.4rem;">
              <span v-if="r.max_uses" class="badge badge-warning">⚠️ {{ r.max_uses - r.uses }} left</span>
              <span v-if="r.valid_until" class="badge badge-danger">⏳ Expires {{ formatDate(r.valid_until) }}</span>
            </div>
          </div>

          <!-- Footer -->
          <div class="reward-footer">
            <div class="coin-badge">
              <span>🪙</span>
              <span class="coin-amount">{{ r.cost }}</span>
              <span class="coin-label">cc</span>
            </div>
            <button class="buy-btn" @click="redeemReward(r)">Buy Now</button>
          </div>
        </li>
      </ul>

      <p v-else style="color:var(--text-secondary); background: var(--input-bg); padding: 2rem; border-radius: 8px; text-align: center;">
        No active rewards available. Tell the Main Caregiver to create some fun treats!
      </p>
    </VCard>

    <!-- Claimed Rewards -->
    <VCard title="Recently Claimed Rewards">
      <div v-if="claimedRewards.length > 0" style="display:flex; flex-direction:column; gap:1rem;">
        <div v-for="c in claimedRewards" :key="c.redemption_id"
             style="display:flex; align-items:center; gap:1.5rem; padding: 1rem 1.5rem;
                    background: var(--bg-surface); border-radius: 12px; border: 1px solid var(--input-border);">
          <div style="width:45px; height:45px; border-radius:50%; background:#2563eb;
                      display:flex; align-items:center; justify-content:center; font-size:1.5rem; overflow:hidden;"
               :style="c.buyer_avatar ? `background-image:url('${appStore.apiBase}${c.buyer_avatar}'); background-size:cover;` : ''">
            {{ c.buyer_avatar ? '' : '👤' }}
          </div>
          <div style="flex:1;">
            <strong style="color:var(--text-primary); display:block; font-size:1.1rem; font-weight:800;">{{ c.buyer_name }}</strong>
            <span class="text-sm" style="color:var(--text-secondary);">
              Redeemed "<strong style="color:var(--text-primary);">{{ c.title }}</strong>"
            </span>
          </div>
          <div class="text-sm" style="color:#94a3b8; text-align:right;">
            <div>{{ formatDate(c.redeemed_at) }}</div>
            <div style="color:#10b981; font-weight:600; margin-top:0.2rem;">✓ Claimed</div>
          </div>
        </div>
      </div>
      <p v-else class="text-sm" style="color:var(--text-secondary);">No rewards claimed yet.</p>
    </VCard>

    <!-- Admin Create Form -->
    <VCard v-if="isCaregiver" title="Create New Reward">
      <p class="text-sm" style="color:var(--text-secondary); margin-bottom: 1.5rem;">
        Add new treats that caregivers can purchase. Once created, they can be redeemed by anyone with enough coins.
        Set limits or deadlines to make them exclusive!
      </p>
      <div class="grid three">
        <VInput v-model="rewardForm.title"       label="Reward Title"        placeholder="e.g. Winner picks the movie" />
        <VInput v-model="rewardForm.description" label="Description"          placeholder="Optional details..." />
        <VInput v-model="rewardForm.amount"      type="number" label="Coin Cost" placeholder="e.g. 15" />
      </div>
      <div class="grid three" style="margin-top: 1rem;">
        <VInput v-model="rewardForm.maxUses"    type="number"         label="Max Uses (Optional)"    placeholder="e.g. 1 (One-time only)" />
        <VInput v-model="rewardForm.validFrom"  type="datetime-local" label="Valid From (Optional)" />
        <VInput v-model="rewardForm.validUntil" type="datetime-local" label="Valid Until (Optional)" />
      </div>
      <VButton type="outline" @click="createReward" style="margin-top: 1.5rem; width: 100%; max-width: 250px;">
        Add Reward to Store
      </VButton>
    </VCard>

  </div>
</template>

<style scoped>
/* ── Grid ───────────────────────────────────────── */
.reward-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 1.5rem;
  padding: 0;
  margin: 0;
  list-style: none;
}

/* ── Card ───────────────────────────────────────── */
.reward-item {
  display: flex;
  flex-direction: column;
  border-radius: 24px;
  overflow: hidden;
  background: #fff;
  box-shadow: 0 4px 20px rgba(0,0,0,0.07);
  transition: transform 0.25s ease, box-shadow 0.25s ease;
}
.reward-item:hover {
  transform: translateY(-6px);
  box-shadow: 0 18px 40px rgba(99,102,241,0.18);
}

/* ── Banner ─────────────────────────────────────── */
.reward-banner {
  height: 110px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.banner-0 { background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%); }
.banner-1 { background: linear-gradient(135deg, #ec4899 0%, #f43f5e 100%); }
.banner-2 { background: linear-gradient(135deg, #f59e0b 0%, #ef4444 100%); }
.banner-3 { background: linear-gradient(135deg, #10b981 0%, #0ea5e9 100%); }
.banner-4 { background: linear-gradient(135deg, #3b82f6 0%, #06b6d4 100%); }

.reward-icon {
  font-size: 3.2rem;
  filter: drop-shadow(0 4px 10px rgba(0,0,0,0.3));
  animation: float 3s ease-in-out infinite;
}
@keyframes float {
  0%, 100% { transform: translateY(0px); }
  50%       { transform: translateY(-6px); }
}

/* ── Body ───────────────────────────────────────── */
.reward-content {
  padding: 1.25rem 1.5rem;
  flex: 1;
}
.reward-title {
  color: #1e293b;
  margin: 0 0 0.4rem;
  font-size: 1.1rem;
  font-weight: 800;
  line-height: 1.3;
}
.reward-desc {
  color: #64748b;
  font-size: 0.85rem;
  line-height: 1.5;
  margin: 0;
}

.badge {
  display: inline-block;
  font-size: 0.73rem;
  font-weight: 700;
  padding: 0.2rem 0.65rem;
  border-radius: 9999px;
}
.badge-warning { background: #fef3c7; color: #92400e; }
.badge-danger  { background: #fee2e2; color: #991b1b; }

/* ── Footer ─────────────────────────────────────── */
.reward-footer {
  padding: 1rem 1.5rem;
  border-top: 1px solid #f1f5f9;
  background: #fafafa;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.coin-badge {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%);
  padding: 0.4rem 0.9rem;
  border-radius: 9999px;
  box-shadow: 0 3px 10px rgba(245,158,11,0.35);
}
.coin-amount { color: #fff; font-weight: 900; font-size: 1.1rem; }
.coin-label  { color: rgba(255,255,255,0.75); font-weight: 700; font-size: 0.8rem; }

.buy-btn {
  background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
  color: #fff;
  border: none;
  border-radius: 9999px;
  padding: 0.55rem 1.3rem;
  font-weight: 800;
  font-size: 0.9rem;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(99,102,241,0.4);
  transition: transform 0.15s, box-shadow 0.15s;
}
.buy-btn:hover  { transform: scale(1.06); box-shadow: 0 6px 18px rgba(99,102,241,0.55); }
.buy-btn:active { transform: scale(0.97); }

/* ── Admin form ─────────────────────────────────── */
.grid.three {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 1rem;
}

@media (max-width: 768px) {
  .marketplace-container {
    padding: 0 1rem;
  }
}
</style>
