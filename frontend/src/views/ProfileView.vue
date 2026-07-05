<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useFamilyStore } from '../stores/family';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import AccountSettings from '../components/profile/AccountSettings.vue';
import FamilyCircle from '../components/profile/FamilyCircle.vue';
import WalletPanel from '../components/profile/WalletPanel.vue';
import { useCurrentFamily } from '../composables/useCurrentFamily';

const appStore    = useAuthStore();
const familyStore = useFamilyStore();
const { family, role, familyId } = useCurrentFamily();
const isCaregiver = computed(() => role.value === 'caregiver');
const actors      = computed(() => familyStore.actors || []);

const activeTab = ref('profile');

// ── Profile form ──────────────────────────────────────────────
const profileForm = ref({
  displayName: familyStore.profile?.display_name || '',
  email:       familyStore.profile?.email        || '',
  alias:       family.value?.alias              || ''
});
const updateProfile = () => appStore.runAction(async () => {
  await appStore.request('/api/me/profile', {
    method: 'PATCH', headers: appStore.authHeaders(),
    body: JSON.stringify({ displayName: profileForm.value.displayName, email: profileForm.value.email, familyId: family.value?.family_id, alias: profileForm.value.alias })
  });
  await familyStore.fetchUserData();
}, 'Personal details updated successfully!');

// ── Confirm dialog ────────────────────────────────────────────
const showConfirm    = ref(false);
const confirmTitle   = ref('');
const confirmBody    = ref('');
const confirmDanger  = ref(false);
let   pendingConfirmFn = null;
const requestConfirm = (title, body, danger, fn) => {
  confirmTitle.value = title; confirmBody.value = body; confirmDanger.value = danger;
  pendingConfirmFn = fn; showConfirm.value = true;
};
const runConfirm = async () => {
  showConfirm.value = false;
  if (pendingConfirmFn) await pendingConfirmFn();
  pendingConfirmFn = null;
};

const deleteAccount = () => requestConfirm(
  'Delete account',
  'Your profile will be anonymized and all your pending activities deleted. This cannot be undone.',
  true,
  () => appStore.runAction(async () => {
    await appStore.request('/api/me', { method: 'DELETE', headers: appStore.authHeaders() });
    await appStore.logout();
  }, 'Account deleted.')
);
const deleteFamily = () => requestConfirm(
  'Delete family',
  'If there are other caregivers this sends them a deletion request. All family data will be permanently removed.',
  true,
  () => appStore.runAction(async () => {
    const res = await appStore.request(`/api/families/${familyId.value}`, { method: 'DELETE', headers: appStore.authHeaders() });
    if (res.deleted) { window.location.href = '/'; }
    else if (res.pendingApproval) { appStore.setSuccess('Deletion request sent to other caregivers.'); await loadDeletionRequests(); }
  }, 'Family deletion processed.')
);

// ── Coin ledger ───────────────────────────────────────────────
const ledgerInfo    = ref([]);
const currentMonth  = ref(`${new Date().getFullYear()}-${String(new Date().getMonth()+1).padStart(2,'0')}`);
const walletPanelRef = ref(null);

const loadLedger = async () => {
  if (!family.value) return;
  try {
    const data = await appStore.request(`/api/me/ledger?familyId=${family.value.family_id}&month=${currentMonth.value}`, { headers: appStore.authHeaders() });
    ledgerInfo.value = data.ledger || [];
  } catch { appStore.setError('Failed to fetch ledger'); }
};
const uncheckActivity = (item) => requestConfirm(
  'Un-check activity',
  `This will revert ${Math.abs(item.amount)} cc from your balance for "${item.activity_title}".`,
  false,
  () => appStore.runAction(async () => {
    await appStore.request(`/api/activities/${item.activity_id}/revert`, { method: 'POST', headers: appStore.authHeaders() });
    await familyStore.fetchUserData();
    await loadLedger();
  }, 'Activity unchecked and balance reverted.')
);
watch(currentMonth, () => loadLedger());

// ── Family members & invitations ──────────────────────────────
const familyMembers  = ref([]);
const invitations    = ref([]);
const loadInvitations = async () => {
  const fid = familyId.value; if (!fid) return;
  try {
    const memData = await appStore.request(`/api/families/${fid}/members`, { headers: appStore.authHeaders() });
    familyMembers.value = memData.members || [];
  } catch { appStore.setError('Failed to load family members.'); }
  if (!isCaregiver.value) return;
  try {
    const data = await appStore.request(`/api/families/${fid}/invitations`, { headers: appStore.authHeaders() });
    invitations.value = data.invitations || [];
  } catch { appStore.setError('Failed to load pending invitations.'); }
};

// ── Deletion requests ─────────────────────────────────────────
const deletionRequests  = ref([]);
const loadDeletionRequests = async () => {
  const fid = familyId.value; if (!fid || !isCaregiver.value) return;
  try {
    const data = await appStore.request(`/api/families/${fid}/deletion-requests`, { headers: appStore.authHeaders() });
    deletionRequests.value = data.deletionRequests || [];
  } catch { appStore.setError('Failed to load deletion requests.'); }
};
const respondToDeletionRequest = (reqId, action) => appStore.runAction(async () => {
  const res = await appStore.request(`/api/families/${familyId.value}/deletion-requests/${reqId}/${action}`, { method: 'POST', headers: appStore.authHeaders() });
  if (res.deleted) { window.location.href = '/'; }
  else { await loadDeletionRequests(); }
}, `Deletion request ${action}d.`);

// ── AccountSettings ref (for loadNotifPrefs) ──────────────────
const accountSettingsRef = ref(null);

onMounted(() => { loadLedger(); loadInvitations(); loadDeletionRequests(); accountSettingsRef.value?.loadNotifPrefs(); });
watch(isCaregiver, (v) => { if (v) { loadInvitations(); loadDeletionRequests(); } });
</script>

<template>
  <div class="personal-area">
    <div class="page-heading">
      <h1>Personal Area</h1>
      <p>Manage your family profile and tracking preferences.</p>
    </div>

    <div v-if="family" class="family-banner">
      <div class="family-banner__left">
        <span class="family-banner__icon">🏠</span>
        <div>
          <div class="family-banner__name">{{ family.name }}</div>
          <div class="family-banner__sub">Your Family Hub</div>
        </div>
      </div>
      <div class="family-banner__id">
        <span class="family-id-label">Family ID</span>
        <span class="family-id-value">{{ family.family_id }}</span>
      </div>
    </div>

    <!-- Deletion request banner -->
    <div v-if="deletionRequests.length > 0" class="deletion-requests-banner">
      <h3 style="margin-top:0;color:#b91c1c;display:flex;align-items:center;gap:0.5rem;"><span>⚠️</span> Pending Family Deletion Requests</h3>
      <div v-for="req in deletionRequests" :key="req.id" style="background:rgba(255,255,255,0.6);padding:1rem;border-radius:8px;margin-bottom:1rem;">
        <p style="margin:0 0 0.5rem 0;"><strong>{{ req.requested_by_name }}</strong> has requested to permanently delete this family.</p>
        <div style="font-size:0.85rem;color:#7f1d1d;margin-bottom:1rem;">
          <div><strong>Approvals Status:</strong></div>
          <div v-for="a in req.approvals" :key="a.caregiver_id" style="display:flex;gap:0.5rem;align-items:center;margin-top:0.25rem;">
            <span>{{ a.caregiver_name }}:</span>
            <span :style="{ fontWeight:'bold', color: a.status==='approved' ? '#166534' : a.status==='rejected' ? '#991b1b' : '#b45309' }">{{ a.status.toUpperCase() }}</span>
          </div>
        </div>
        <div style="display:flex;gap:1rem;">
          <button @click="respondToDeletionRequest(req.id,'approve')" style="background:#ef4444;color:white;border:none;padding:0.5rem 1rem;border-radius:9999px;font-weight:bold;cursor:pointer;">Approve Deletion</button>
          <button @click="respondToDeletionRequest(req.id,'reject')"  style="background:#fff;color:#ef4444;border:1px solid #ef4444;padding:0.5rem 1rem;border-radius:9999px;font-weight:bold;cursor:pointer;">Reject</button>
        </div>
      </div>
    </div>

    <div class="profile-tab-bar">
      <button :class="['ptab', activeTab==='profile' && 'ptab--active']" @click="activeTab='profile'">My Profile</button>
      <button :class="['ptab', activeTab==='family'  && 'ptab--active']" @click="activeTab='family'">Family</button>
      <button :class="['ptab', activeTab==='wallet'  && 'ptab--active']" @click="activeTab='wallet'">Wallet</button>
    </div>

    <div class="two-col-grid">
      <div class="left-col" :class="{ 'tab-hidden': activeTab === 'wallet' }">
        <div :class="{ 'tab-hidden': activeTab !== 'profile' }">
          <AccountSettings
            ref="accountSettingsRef"
            :family="family"
            :profile-form="profileForm"
            @update:profile-form="profileForm = $event"
            @update-profile="updateProfile"
            @delete-account="deleteAccount"
          />
        </div>
        <div :class="{ 'tab-hidden': activeTab !== 'family' }">
          <FamilyCircle
            :family="family"
            :family-id="familyId"
            :is-caregiver="isCaregiver"
            :actors="actors"
            :family-members="familyMembers"
            :invitations="invitations"
            @reload-members="loadInvitations"
            @delete-family="deleteFamily"
          />
        </div>
      </div>

      <div class="right-col" :class="{ 'tab-hidden': activeTab !== 'wallet' }">
        <WalletPanel
          ref="walletPanelRef"
          :family="family"
          :ledger-info="ledgerInfo"
          @uncheck-activity="uncheckActivity"
        />
      </div>
    </div>
  </div>

  <div v-if="showConfirm" class="modal-overlay" @click.self="showConfirm = false">
    <VCard :title="confirmTitle" style="max-width:380px;width:100%;">
      <p style="color:var(--text-secondary);line-height:1.55;margin-bottom:1.5rem;">{{ confirmBody }}</p>
      <div style="display:flex;gap:1rem;justify-content:flex-end;">
        <VButton type="secondary" @click="showConfirm = false">Cancel</VButton>
        <VButton :type="confirmDanger ? 'danger' : 'primary'" @click="runConfirm">Confirm</VButton>
      </div>
    </VCard>
  </div>
</template>

<style scoped>
.personal-area { max-width:1080px; margin:0 auto; padding-top:1rem; }
.page-heading { margin-bottom:2.5rem; }
.page-heading h1 { font-size:3rem; font-weight:800; color:#1e1b4b; margin:0 0 0.4rem; letter-spacing:-1px; }
.page-heading p  { color:#64748b; font-size:1rem; margin:0; }
.two-col-grid { display:grid; grid-template-columns:2fr 1fr; gap:2rem; align-items:start; }
.left-col, .right-col { display:flex; flex-direction:column; gap:2rem; min-width:0; }
.family-banner { display:flex; justify-content:space-between; align-items:center; background:linear-gradient(135deg,#6366f1 0%,#8b5cf6 100%); border-radius:16px; padding:1rem 1.75rem; margin-bottom:2rem; box-shadow:0 6px 20px rgba(99,102,241,0.3); }
.family-banner__left { display:flex; align-items:center; gap:1rem; }
.family-banner__icon { font-size:1.8rem; }
.family-banner__name { font-size:1.2rem; font-weight:800; color:#fff; letter-spacing:-0.3px; }
.family-banner__sub  { font-size:0.78rem; color:rgba(255,255,255,0.65); font-weight:600; margin-top:0.1rem; }
.family-banner__id { display:flex; align-items:center; gap:0.6rem; background:rgba(255,255,255,0.15); border:1px solid rgba(255,255,255,0.25); border-radius:9999px; padding:0.45rem 1.1rem; }
.family-id-label { font-size:0.72rem; font-weight:800; text-transform:uppercase; letter-spacing:0.5px; color:rgba(255,255,255,0.65); }
.family-id-value { font-size:1rem; font-weight:800; color:#fff; font-family:monospace; letter-spacing:0.5px; }
.deletion-requests-banner { background:#fee2e2; border:1px solid #fca5a5; border-radius:16px; padding:1.5rem; margin-bottom:2rem; color:#991b1b; }
.profile-tab-bar { display:none; }
@media (max-width:768px) {
  .personal-area { padding:1.5rem 1rem; }
  .two-col-grid { grid-template-columns:1fr; gap:1.5rem; }
  .page-heading h1 { font-size:2rem; }
  .profile-tab-bar { display:flex; background:var(--bg); border-radius:var(--r-pill); padding:4px; gap:4px; margin-bottom:1.5rem; border:1px solid var(--border); }
  .ptab { flex:1; padding:10px 8px; border:none; background:transparent; border-radius:var(--r-pill); font-size:0.85rem; font-weight:700; color:var(--text-secondary); cursor:pointer; transition:background 0.15s,color 0.15s; min-height:44px; -webkit-tap-highlight-color:transparent; }
  .ptab--active { background:var(--surface); color:var(--primary); box-shadow:0 1px 4px rgba(14,23,38,0.08); }
  .tab-hidden { display:none !important; }
}
@media (max-width:480px) { .page-heading h1 { font-size:1.5rem; } .page-heading p { font-size:0.85rem; } }
</style>
