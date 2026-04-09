<script setup>
import { ref, watch, onMounted, computed } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useFamilyStore } from '../stores/family';
import VCard from '../components/VCard.vue';
import VInput from '../components/VInput.vue';
import VButton from '../components/VButton.vue';
import { useCurrentFamily } from '../composables/useCurrentFamily';

const appStore = useAuthStore();
const familyStore = useFamilyStore();
const actors = computed(() => familyStore.actors || []);

const userAvatarInput = ref(null);

const handleUserAvatarUpload = async (event) => {
  const file = event.target.files[0];
  if (!file) return;
  const formData = new FormData();
  formData.append('avatar', file);
  await appStore.runAction(async () => {
    const headers = appStore.authHeaders();
    delete headers['Content-Type'];
    const res = await fetch(`${appStore.apiBase}/api/me/avatar`, {
      method: 'POST', headers: { Authorization: headers.Authorization }, body: formData
    });
    if (!res.ok) throw new Error('Upload failed');
    await familyStore.fetchUserData();
  }, 'Your avatar updated successfully!');
};

const triggerActorUpload = (actorId) => {
  const el = document.getElementById(`actor-upload-${actorId}`);
  if (el) el.click();
};

const handleActorAvatarUpload = async (event, actorId, fid) => {
  const file = event.target.files[0];
  if (!file) return;
  const formData = new FormData();
  formData.append('avatar', file);
  await appStore.runAction(async () => {
    const headers = appStore.authHeaders();
    delete headers['Content-Type'];
    const res = await fetch(`${appStore.apiBase}/api/families/${fid}/actors/${actorId}/avatar`, {
      method: 'POST', headers: { Authorization: headers.Authorization }, body: formData
    });
    if (!res.ok) throw new Error('Upload failed');
    await familyStore.fetchUserData();
  }, 'Dependent avatar updated successfully!');
};

const { family } = useCurrentFamily();
const ledgerInfo = ref([]);

const profileForm = ref({
  displayName: familyStore.profile?.display_name || '',
  email: familyStore.profile?.email || '',
  alias: family.value?.alias || ''
});

const updateProfile = () => appStore.runAction(async () => {
  await appStore.request('/api/me/profile', {
    method: 'PATCH',
    headers: appStore.authHeaders(),
    body: JSON.stringify({
      displayName: profileForm.value.displayName,
      email: profileForm.value.email,
      familyId: family.value?.family_id,
      alias: profileForm.value.alias
    })
  });
  await familyStore.fetchUserData();
}, 'Personal details updated successfully!');

const today = new Date();
const currentMonth = ref(`${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`);

const loadLedger = async () => {
  if (!family.value) return;
  try {
    const data = await appStore.request(`/api/me/ledger?familyId=${family.value.family_id}&month=${currentMonth.value}`, {
      headers: appStore.authHeaders()
    });
    ledgerInfo.value = data.ledger || [];
  } catch (err) {
    appStore.setError('Failed to fetch ledger');
  }
};

const uncheckActivity = async (item) => {
  if (!confirm(`Are you sure you want to logically un-check '${item.activity_title}'? It will formally revert ${item.amount} cc from your bank balance.`)) return;
  await appStore.runAction(async () => {
    await appStore.request(`/api/activities/${item.activity_id}/revert`, { method: 'POST', headers: appStore.authHeaders() });
    await familyStore.fetchUserData();
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
      <div style="display:flex; align-items:center; gap: 2rem; margin-bottom: 2rem;">
        <div 
          style="width: 100px; height: 100px; border-radius: 50%; background: #60a5fa; display: flex; align-items: center; justify-content: center; font-size: 3.5rem; border: 4px solid #3b82f6; cursor: pointer; overflow:hidden; position:relative;"
          :style="familyStore.profile?.avatar_url ? `background-image: url('${appStore.apiBase}${familyStore.profile.avatar_url}'); background-size: cover; background-position: center; border-color: transparent;` : ''"
          @click="userAvatarInput.click()"
          title="Click to update your picture"
        >
          {{ familyStore.profile?.avatar_url ? '' : '👤' }}
          <div style="position:absolute; bottom:0; background:rgba(0,0,0,0.6); width:100%; text-align:center; font-size: 0.65rem; color:#fff; padding:2px 0;">EDIT</div>
        </div>
        <div>
          <h2 style="margin:0; color:#fff;">{{ familyStore.profile?.display_name }}</h2>
          <div style="color:var(--text-secondary); font-size:0.9rem;">{{ familyStore.profile?.email }}</div>
        </div>
      </div>
      <input type="file" ref="userAvatarInput" style="display: none;" accept="image/*" @change="handleUserAvatarUpload">

      <div class="info-grid">
        <div class="info-item">
          <label>Full Name</label>
          <div class="val">{{ familyStore.profile?.display_name || 'N/A' }}</div>
        </div>
        <div class="info-item">
          <label>Email Address</label>
          <div class="val">{{ familyStore.profile?.email || 'N/A' }}</div>
        </div>
        <div class="info-item" v-if="family">
          <label>Active Family</label>
          <div class="val">{{ family.name }}</div>
        </div>
        <div class="info-item" v-if="family">
          <label>Your Role</label>
          <div class="val" style="text-transform: capitalize;">{{ family.role?.replace('_', ' ') }}</div>
        </div>
        <div class="info-item" v-if="family">
          <label>Your Alias</label>
          <div class="val">{{ family.alias || 'None Set' }}</div>
        </div>
      </div>
      
      <div style="margin-top: 2rem; padding-top: 1.5rem; border-top: 1px solid var(--card-border);">
        <h3 style="font-size: 1rem; margin-bottom: 1rem; color: var(--text-primary);">Update Details</h3>
        <div class="grid three">
          <VInput v-model="profileForm.displayName" label="Full Name" />
          <VInput v-model="profileForm.email" label="Email Address" />
          <VInput v-if="family" v-model="profileForm.alias" label="Your Alias" />
        </div>
        <VButton type="primary" @click="updateProfile" style="margin-top: 1.5rem;">Save Changes</VButton>
      </div>
    </VCard>

    <!-- Dependents (Actors) Management -->
    <VCard title="Family Dependents" v-if="actors.length > 0">
      <p style="color: var(--text-secondary); font-size: 0.9rem; margin-bottom: 1.5rem;">Manage avatars for your family objects of care.</p>
      <div style="display:flex; flex-wrap: wrap; gap: 1.5rem;">
        <div v-for="a in actors" :key="a.id" style="display:flex; align-items:center; gap: 1rem; background: var(--input-bg); padding: 1rem; border-radius: 12px; border: 1px solid var(--input-border); min-width: 250px; flex: 1;">
          <div 
            style="width: 60px; height: 60px; border-radius: 50%; background: #fbbf24; display: flex; align-items: center; justify-content: center; font-size: 2rem; border: 3px solid #f59e0b; cursor: pointer; overflow:hidden; position:relative; flex-shrink: 0;"
            :style="a.avatar_url ? `background-image: url('${appStore.apiBase}${a.avatar_url}'); background-size: cover; background-position: center; border-color: transparent;` : ''"
            @click="triggerActorUpload(a.id)"
            title="Click to update dependent picture"
          >
            {{ a.avatar_url ? '' : (a.actor_type === 'child' ? '👶🏽' : (a.actor_type === 'pet' ? '🐶' : '👴🏽')) }}
            <div style="position:absolute; bottom:0; background:rgba(0,0,0,0.6); width:100%; text-align:center; font-size: 0.55rem; color:#fff; padding:2px 0;">EDIT</div>
          </div>
          <input :id="'actor-upload-'+a.id" type="file" style="display: none;" accept="image/*" @change="handleActorAvatarUpload($event, a.id, a.family_id)">
          
          <div>
            <strong style="color: var(--text-primary); font-size: 1.1rem; display:block;">{{ a.name }}</strong>
            <span style="color: var(--text-secondary); font-size: 0.8rem; text-transform: capitalize;">{{ a.actor_type }} · {{ a.care_time.replace('_', ' ') }}</span>
          </div>
        </div>
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
  color: var(--text-primary);
  font-weight: 800;
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
  color: var(--text-primary);
  font-weight: 800;
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
