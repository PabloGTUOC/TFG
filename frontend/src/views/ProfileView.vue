<script setup>
import { ref, watch, onMounted, computed } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useFamilyStore } from '../stores/family';
import VCard from '../components/VCard.vue';
import VInput from '../components/VInput.vue';
import VButton from '../components/VButton.vue';
import VSelect from '../components/VSelect.vue';
import { useCurrentFamily } from '../composables/useCurrentFamily';

const appStore = useAuthStore();
const familyStore = useFamilyStore();
const actors = computed(() => familyStore.actors || []);
const userAvatarInput = ref(null);

// ── Avatar uploads ────────────────────────────────────────
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

// ── Current family ────────────────────────────────────────
const { family, role, familyId } = useCurrentFamily();
const isMainCaregiver = computed(() => role.value === 'main_caregiver');

// ── Add Dependent ─────────────────────────────────────────
const typeOptions = [
  { value: 'child',   label: '👶 Child / Baby' },
  { value: 'pet',     label: '🐾 Pet' },
  { value: 'elderly', label: '👴 Elderly' },
];
const timeOptions = [
  { value: 'full_time', label: 'Full Time' },
  { value: 'part_time', label: 'Part Time' },
];
const addActorForm = ref({ name: '', actorType: 'child', careTime: 'full_time' });
const showAddActor = ref(false);

const addActor = () => appStore.runAction(async () => {
  const fid = familyId.value;
  if (!fid) throw new Error('No family found.');
  if (!addActorForm.value.name.trim()) throw new Error('Name is required.');
  await appStore.request(`/api/families/${fid}/actors`, {
    method: 'POST',
    headers: appStore.authHeaders(),
    body: JSON.stringify(addActorForm.value)
  });
  addActorForm.value = { name: '', actorType: 'child', careTime: 'full_time' };
  showAddActor.value = false;
  await familyStore.fetchUserData();
}, 'Dependent added!');

// ── Invite caregiver & Members ──────────────────────────────
const invitations = ref([]);
const familyMembers = ref([]);
const showInviteForm = ref(false);
const inviteForm = ref({ email: '', name: '' });

const loadInvitations = async () => {
  const fid = familyId.value;
  if (!fid) return;
  try {
    const memData = await appStore.request(`/api/families/${fid}/members`, { headers: appStore.authHeaders() });
    familyMembers.value = memData.members || [];
  } catch { /* silent */ }

  if (!isMainCaregiver.value) return;
  try {
    const data = await appStore.request(`/api/families/${fid}/invitations`, { headers: appStore.authHeaders() });
    invitations.value = data.invitations || [];
  } catch { /* silent */ }
};

const sendInvite = () => appStore.runAction(async () => {
  const fid = familyId.value;
  if (!fid) throw new Error('No family found.');
  const email = inviteForm.value.email.trim();
  if (!email) throw new Error('Email is required.');
  await appStore.request(`/api/families/${fid}/invitations`, {
    method: 'POST',
    headers: appStore.authHeaders(),
    body: JSON.stringify({ email, name: inviteForm.value.name.trim() || undefined })
  });
  inviteForm.value = { email: '', name: '' };
  showInviteForm.value = false;
  await loadInvitations();
}, 'Invitation saved! They can now join using the Family ID.');

// ── Profile form ──────────────────────────────────────────
const profileForm = ref({
  displayName: familyStore.profile?.display_name || '',
  email:       familyStore.profile?.email || '',
  alias:       family.value?.alias || ''
});

const updateProfile = () => appStore.runAction(async () => {
  await appStore.request('/api/me/profile', {
    method: 'PATCH',
    headers: appStore.authHeaders(),
    body: JSON.stringify({
      displayName: profileForm.value.displayName,
      email:       profileForm.value.email,
      familyId:    family.value?.family_id,
      alias:       profileForm.value.alias
    })
  });
  await familyStore.fetchUserData();
}, 'Personal details updated successfully!');

// ── Coin ledger ───────────────────────────────────────────
const today = new Date();
const currentMonth = ref(`${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`);
const ledgerInfo = ref([]);
const showFullLedger = ref(false);

const loadLedger = async () => {
  if (!family.value) return;
  try {
    const data = await appStore.request(
      `/api/me/ledger?familyId=${family.value.family_id}&month=${currentMonth.value}`,
      { headers: appStore.authHeaders() }
    );
    ledgerInfo.value = data.ledger || [];
  } catch {
    appStore.setError('Failed to fetch ledger');
  }
};

const uncheckActivity = async (item) => {
  if (!confirm(`Are you sure you want to un-check '${item.activity_title}'? It will revert ${item.amount} cc from your balance.`)) return;
  await appStore.runAction(async () => {
    await appStore.request(`/api/activities/${item.activity_id}/revert`, { method: 'POST', headers: appStore.authHeaders() });
    await familyStore.fetchUserData();
    await loadLedger();
  }, 'Activity unchecked and bank reverted.');
};

onMounted(() => { loadLedger(); loadInvitations(); });
watch(currentMonth, () => loadLedger());
watch(isMainCaregiver, (v) => { if (v) loadInvitations(); });

// ── Computed helpers ──────────────────────────────────────
const combinedCircleItems = computed(() => {
  const humans = familyMembers.value.map(m => ({
    id: 'user_' + m.id,
    user_id: m.id,
    family_id: familyId.value,
    name: m.name,
    actor_type: m.role || 'member',
    avatar_url: m.avatar_url,
    care_time: null
  }));
  return [...humans, ...actors.value];
});

const recentLedger = computed(() => ledgerInfo.value.slice(0, 3));
const tasksThisMonth = computed(() => ledgerInfo.value.filter(i => i.reason === 'activity_completed').length);

const coinTier = computed(() => {
  const bal = family.value?.coin_balance ?? 0;
  if (bal >= 1000) return { label: 'Platinum Parent', icon: '🏆' };
  if (bal >= 500)  return { label: 'Gold Caregiver',  icon: '🥇' };
  if (bal >= 200)  return { label: 'Silver Helper',   icon: '🥈' };
  return { label: 'Bronze Starter', icon: '🥉' };
});

const actorBadge = (type) => {
  const map = {
    child:   { label: 'Junior Explorer', color: '#6366f1' },
    pet:     { label: 'Furry Friend',    color: '#10b981' },
    elderly: { label: 'Guiding Star',   color: '#f59e0b' },
    main_caregiver: { label: 'Main Caregiver', color: '#4f46e5' },
    caregiver: { label: 'Caregiver', color: '#059669' },
    member: { label: 'Family Member', color: '#3b82f6' },
    person:  { label: 'Family Member',  color: '#3b82f6' },
  };
  return map[type] || { label: type.replace(/_/g, ' '), color: '#94a3b8' };
};

const formatLedgerDate = (ds) => {
  if (!ds) return '';
  const d = new Date(ds);
  const now = new Date();
  const diffDays = Math.floor((now - d) / 86400000);
  if (diffDays === 0) return `Today, ${d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
  if (diffDays === 1) return `Yesterday, ${d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
};
</script>

<template>
  <div class="personal-area">

    <!-- ── Page heading ─────────────────────────────────── -->
    <div class="page-heading">
      <h1>Personal Area</h1>
      <p>Manage your family profile and tracking preferences.</p>
    </div>

    <!-- ── Family banner ─────────────────────────────── -->
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

    <!-- ── Two-column grid ──────────────────────────────── -->
    <div class="two-col-grid">

      <!-- LEFT COLUMN -->
      <div class="left-col">

        <!-- Account Settings -->
        <div class="settings-card">
          <div class="settings-card__header">
            <div class="accent-bar"></div>
            <h2>Account Settings</h2>
          </div>

          <!-- Avatar row -->
          <div class="avatar-row">
            <div class="user-avatar"
                 :style="familyStore.profile?.avatar_url
                   ? `background-image:url('${appStore.apiBase}${familyStore.profile.avatar_url}'); background-size:cover; background-position:center;`
                   : ''"
                 @click="userAvatarInput.click()"
                 title="Click to change photo">
              <span v-if="!familyStore.profile?.avatar_url">👤</span>
              <div class="avatar-edit-badge">📷</div>
            </div>
            <div>
              <div class="user-name">{{ familyStore.profile?.display_name || 'Your Name' }}</div>
              <div class="user-email">{{ familyStore.profile?.email }}</div>
              <div class="user-role-pill" v-if="family">{{ family.role?.replace(/_/g, ' ') }}</div>
            </div>
          </div>
          <input type="file" ref="userAvatarInput" style="display:none;" accept="image/*" @change="handleUserAvatarUpload">

          <!-- Form -->
          <div class="settings-form">
            <div class="form-row">
              <div class="form-field">
                <label>Full Name</label>
                <input v-model="profileForm.displayName" type="text" class="text-input" placeholder="Your full name" />
              </div>
              <div class="form-field">
                <label>Email Address</label>
                <input v-model="profileForm.email" type="email" class="text-input" placeholder="your@email.com" />
              </div>
              <div class="form-field" v-if="family">
                <label>Your Alias</label>
                <input v-model="profileForm.alias" type="text" class="text-input" placeholder="e.g. Papa, Mama…" />
              </div>
            </div>
            <button class="update-btn" @click="updateProfile">Update Profile</button>
          </div>
        </div>

        <!-- Family Circle -->
        <div class="family-circle-section">
          <div class="section-header">
            <h2>Family Circle</h2>
            <div v-if="isMainCaregiver" style="display:flex; gap:0.6rem;">
              <button class="add-member-btn" @click="showAddActor = !showAddActor; showInviteForm = false">
                ➕ Add Dependent
              </button>
              <button class="invite-btn" @click="showInviteForm = !showInviteForm; showAddActor = false">
                📧 Invite Caregiver
              </button>
            </div>
          </div>

          <div v-if="combinedCircleItems.length > 0" class="circle-grid">
            <div v-for="a in combinedCircleItems" :key="a.id" class="circle-card">
              <div class="circle-avatar"
                   :style="(a.avatar_url ? `background-image:url('${appStore.apiBase}${a.avatar_url}'); background-size:cover; background-position:center; ` : '') + (a.user_id ? 'cursor: default;' : 'cursor: pointer;')"
                   @click="!a.user_id ? triggerActorUpload(a.id) : null">
                <span v-if="!a.avatar_url">
                  {{ a.actor_type === 'child' ? '👶🏽' : a.actor_type === 'pet' ? '🐾' : a.actor_type === 'elderly' ? '👴🏽' : '👤' }}
                </span>
                <div v-if="!a.user_id" class="circle-camera">📷</div>
              </div>
              <input v-if="!a.user_id" :id="'actor-upload-'+a.id" type="file" style="display:none;" accept="image/*"
                     @change="handleActorAvatarUpload($event, a.id, a.family_id)">
              <div class="circle-name">{{ a.name }}</div>
              <div class="circle-badge" :style="`color: ${actorBadge(a.actor_type).color}; border-color: ${actorBadge(a.actor_type).color}33;`">
                {{ actorBadge(a.actor_type).label.toUpperCase() }}
              </div>
            </div>
          </div>
          <div v-else class="empty-circle">No dependents added yet.</div>

          <!-- Add form -->
          <div v-if="isMainCaregiver && showAddActor" class="add-actor-form">
            <div class="form-row">
              <div class="form-field">
                <label>Name</label>
                <input v-model="addActorForm.name" type="text" class="text-input" placeholder="e.g. Luna, Grandpa…" />
              </div>
              <div class="form-field">
                <label>Type</label>
                <VSelect v-model="addActorForm.actorType" :options="typeOptions" />
              </div>
              <div class="form-field">
                <label>Care Requirement</label>
                <VSelect v-model="addActorForm.careTime" :options="timeOptions" />
              </div>
            </div>
            <div style="display:flex; gap:1rem; margin-top:1rem;">
              <button class="update-btn" @click="addActor">Save</button>
              <button class="cancel-btn" @click="showAddActor = false">Cancel</button>
            </div>
          </div>

          <!-- Invite form -->
          <div v-if="isMainCaregiver && showInviteForm" class="add-actor-form">
            <div class="form-row">
              <div class="form-field">
                <label>Email Address *</label>
                <input v-model="inviteForm.email" type="email" class="text-input" placeholder="caregiver@email.com" />
              </div>
              <div class="form-field">
                <label>Their Name (optional)</label>
                <input v-model="inviteForm.name" type="text" class="text-input" placeholder="e.g. Maria" />
              </div>
            </div>
            <p class="invite-hint">💡 They can join by searching for this family by name or ID on the app. Their invitation pre-approves them to join instantly.</p>
            <div style="display:flex; gap:1rem; margin-top:1rem;">
              <button class="update-btn" @click="sendInvite">Send Invite</button>
              <button class="cancel-btn" @click="showInviteForm = false">Cancel</button>
            </div>
          </div>

          <!-- Pending Invitations -->
          <div v-if="isMainCaregiver && invitations.length > 0" class="pending-invitations">
            <div class="pending-title">⏳ Pending Invitations</div>
            <div v-for="inv in invitations" :key="inv.id" class="pending-row">
              <div>
                <div class="pending-email">{{ inv.email }}</div>
                <div class="pending-name" v-if="inv.name">{{ inv.name }}</div>
              </div>
              <span class="pending-badge">Awaiting</span>
            </div>
          </div>
        </div>

      </div><!-- /left-col -->

      <!-- RIGHT COLUMN -->
      <div class="right-col">

        <!-- Balance Widget -->
        <div class="balance-widget">
          <div class="balance-label">TOTAL BALANCE</div>
          <div class="balance-amount">
            {{ (family?.coin_balance ?? 0).toLocaleString() }}
            <span class="balance-unit">COINS</span>
          </div>

          <div class="ledger-preview">
            <div v-for="item in recentLedger" :key="item.id" class="ledger-preview-row">
              <div class="lp-info">
                <div class="lp-title">{{ item.activity_title || item.reason }}</div>
                <div class="lp-date">{{ formatLedgerDate(item.created_at) }}</div>
              </div>
              <div class="lp-amount" :class="item.amount > 0 ? 'positive' : 'negative'">
                {{ item.amount > 0 ? '+' : '' }}{{ item.amount }}
              </div>
            </div>
            <div v-if="recentLedger.length === 0" class="lp-empty">No activity this month.</div>
          </div>

          <button class="ledger-toggle-btn" @click="showFullLedger = !showFullLedger">
            {{ showFullLedger ? 'Hide Ledger' : 'View Full Ledger' }}
          </button>
        </div>

        <!-- Full Ledger (expanded) -->
        <div v-if="showFullLedger" class="full-ledger-card">
          <div class="full-ledger-header">
            <span style="font-weight:800;">Monthly Ledger</span>
            <input type="month" v-model="currentMonth" class="month-picker" />
          </div>
          <div v-if="ledgerInfo.length > 0" class="ledger-list">
            <div v-for="item in ledgerInfo" :key="item.id" class="ledger-item">
              <div class="ledger-details">
                <strong class="ledger-title">{{ item.activity_title || item.reason }}</strong>
                <span class="ledger-date">{{ formatLedgerDate(item.created_at) }}</span>
                <span v-if="item.duration_minutes" class="ledger-duration">{{ item.duration_minutes }} min</span>
              </div>
              <div style="text-align:right;">
                <div :class="['ledger-amount-val', item.amount > 0 ? 'pos' : 'neg']">
                  {{ item.amount > 0 ? '+' : '' }}{{ item.amount }} cc
                </div>
                <button v-if="item.reason === 'activity_completed'"
                        class="uncheck-btn" @click="uncheckActivity(item)">Un-check</button>
              </div>
            </div>
          </div>
          <div v-else class="lp-empty" style="padding:1.5rem; text-align:center;">No activity this month.</div>
        </div>

        <!-- Activity Insights -->
        <div class="insights-card">
          <h3 class="insights-title">Activity Insights</h3>
          <div class="insight-row">
            <div class="insight-icon" style="background:#dcfce7;">✅</div>
            <div>
              <div class="insight-label">Tasks Mastered</div>
              <div class="insight-sub">{{ tasksThisMonth }} this month</div>
            </div>
          </div>
          <div class="insight-row">
            <div class="insight-icon" style="background:#fef9c3;">{{ coinTier.icon }}</div>
            <div>
              <div class="insight-label">Rank: {{ coinTier.label }}</div>
              <div class="insight-sub">{{ (family?.coin_balance ?? 0).toLocaleString() }} cc total</div>
            </div>
          </div>
        </div>

      </div><!-- /right-col -->
    </div>
  </div>
</template>

<style scoped>
/* ── Root ────────────────────────────────────────────────── */
.personal-area {
  max-width: 1200px;
  margin: 0 auto;
  padding-top: 1rem;
}

/* ── Page heading ────────────────────────────────────────── */
.page-heading {
  margin-bottom: 2.5rem;
}
.page-heading h1 {
  font-size: 3rem;
  font-weight: 900;
  color: #1e1b4b;
  margin: 0 0 0.4rem;
  letter-spacing: -1px;
}
.page-heading p {
  color: #64748b;
  font-size: 1rem;
  margin: 0;
}

/* ── Two-col grid ────────────────────────────────────────── */
.two-col-grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 2rem;
  align-items: start;
}
.left-col, .right-col {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

/* ── Account Settings card ───────────────────────────────── */
.settings-card {
  background: #fff;
  border-radius: 20px;
  padding: 2rem;
  box-shadow: 0 4px 20px rgba(0,0,0,0.06);
}
.settings-card__header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1.5rem;
}
.accent-bar {
  width: 4px;
  height: 28px;
  background: #6366f1;
  border-radius: 9999px;
}
.settings-card__header h2 {
  font-size: 1.2rem;
  font-weight: 800;
  color: #1e293b;
  margin: 0;
}

/* Avatar row */
.avatar-row {
  display: flex;
  align-items: center;
  gap: 1.5rem;
  margin-bottom: 1.5rem;
}
.user-avatar {
  width: 80px;
  height: 80px;
  border-radius: 50%;
  background: #60a5fa;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 2.5rem;
  cursor: pointer;
  position: relative;
  flex-shrink: 0;
  overflow: hidden;
  border: 3px solid #e0e7ff;
  transition: border-color 0.2s;
}
.user-avatar:hover { border-color: #6366f1; }
.avatar-edit-badge {
  position: absolute;
  bottom: 2px;
  right: 2px;
  background: #6366f1;
  border-radius: 50%;
  width: 22px;
  height: 22px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.7rem;
}
.user-name  { font-weight: 800; font-size: 1.1rem; color: #1e293b; }
.user-email { font-size: 0.85rem; color: #64748b; margin-top: 0.1rem; }
.user-role-pill {
  display: inline-block;
  margin-top: 0.4rem;
  background: #e0e7ff;
  color: #4338ca;
  font-size: 0.72rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  padding: 0.2rem 0.7rem;
  border-radius: 9999px;
}

/* Form */
.settings-form { margin-top: 0.5rem; }
.form-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 1rem;
  margin-bottom: 1.25rem;
}
.form-field label {
  display: block;
  font-size: 0.78rem;
  font-weight: 700;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 0.35rem;
}
.text-input {
  width: 100%;
  box-sizing: border-box;
  padding: 0.65rem 1rem;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  font-size: 0.95rem;
  color: #1e293b;
  background: #f8fafc;
  outline: none;
  transition: border-color 0.2s;
}
.text-input:focus { border-color: #6366f1; background: #fff; }

.update-btn {
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  color: #fff;
  border: none;
  border-radius: 9999px;
  padding: 0.7rem 2rem;
  font-weight: 800;
  font-size: 1rem;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(99,102,241,0.35);
  transition: transform 0.15s, box-shadow 0.15s;
}
.update-btn:hover { transform: scale(1.04); box-shadow: 0 6px 18px rgba(99,102,241,0.5); }
.cancel-btn {
  background: #f1f5f9;
  color: #64748b;
  border: none;
  border-radius: 9999px;
  padding: 0.7rem 2rem;
  font-weight: 700;
  font-size: 1rem;
  cursor: pointer;
}

/* ── Family Circle ────────────────────────────────────────── */
.family-circle-section {
  background: #fff;
  border-radius: 20px;
  padding: 2rem;
  box-shadow: 0 4px 20px rgba(0,0,0,0.06);
}
.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
}
.section-header h2 {
  font-size: 1.3rem;
  font-weight: 800;
  color: #1e293b;
  margin: 0;
}
.add-member-btn {
  background: none;
  border: none;
  color: #6366f1;
  font-weight: 700;
  font-size: 0.9rem;
  cursor: pointer;
  transition: opacity 0.15s;
}
.add-member-btn:hover { opacity: 0.7; }

.circle-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(130px, 1fr));
  gap: 1.5rem;
}
.circle-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.6rem;
  background: #f8fafc;
  border-radius: 20px;
  padding: 1.5rem 1rem;
  transition: transform 0.2s;
}
.circle-card:hover { transform: translateY(-3px); }
.circle-avatar {
  width: 80px;
  height: 80px;
  border-radius: 50%;
  background: #fbbf24;
  border: 3px solid #f59e0b;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 2.2rem;
  cursor: pointer;
  position: relative;
  overflow: hidden;
  transition: border-color 0.2s;
}
.circle-avatar:hover { border-color: #6366f1; }
.circle-camera {
  position: absolute;
  bottom: 2px;
  right: 2px;
  background: #6366f1;
  border-radius: 50%;
  width: 22px;
  height: 22px;
  font-size: 0.7rem;
  display: flex;
  align-items: center;
  justify-content: center;
}
.circle-name {
  font-weight: 800;
  font-size: 1rem;
  color: #1e293b;
}
.circle-badge {
  font-size: 0.68rem;
  font-weight: 800;
  letter-spacing: 0.5px;
  border: 1px solid;
  border-radius: 9999px;
  padding: 0.15rem 0.6rem;
}
.empty-circle {
  color: #94a3b8;
  background: #f8fafc;
  border-radius: 12px;
  padding: 1.5rem;
  text-align: center;
  font-size: 0.9rem;
}
.add-actor-form {
  margin-top: 1.5rem;
  padding-top: 1.5rem;
  border-top: 1px solid #f1f5f9;
}

/* ── Balance Widget ───────────────────────────────────────── */
.balance-widget {
  background: #0f172a;
  border-radius: 24px;
  padding: 2rem;
  color: #fff;
}
.balance-label {
  font-size: 0.72rem;
  font-weight: 800;
  letter-spacing: 1px;
  color: #94a3b8;
  text-transform: uppercase;
  margin-bottom: 0.5rem;
}
.balance-amount {
  font-size: 2.8rem;
  font-weight: 900;
  line-height: 1;
  margin-bottom: 1.5rem;
}
.balance-unit {
  font-size: 1.2rem;
  font-weight: 700;
  color: #fbbf24;
  margin-left: 0.3rem;
}

/* Ledger preview */
.ledger-preview { display: flex; flex-direction: column; gap: 0.75rem; margin-bottom: 1.5rem; }
.ledger-preview-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem 1rem;
  background: rgba(255,255,255,0.06);
  border-radius: 12px;
}
.lp-title  { font-weight: 700; font-size: 0.9rem; color: #f1f5f9; }
.lp-date   { font-size: 0.75rem; color: #64748b; margin-top: 0.1rem; }
.lp-amount { font-weight: 800; font-size: 1rem; }
.lp-amount.positive { color: #34d399; }
.lp-amount.negative { color: #f87171; }
.lp-empty  { color: #475569; font-size: 0.85rem; text-align: center; padding: 0.5rem; }

.ledger-toggle-btn {
  width: 100%;
  background: rgba(255,255,255,0.08);
  border: 1px solid rgba(255,255,255,0.12);
  color: #e2e8f0;
  border-radius: 9999px;
  padding: 0.65rem;
  font-weight: 700;
  font-size: 0.9rem;
  cursor: pointer;
  transition: background 0.2s;
}
.ledger-toggle-btn:hover { background: rgba(255,255,255,0.14); }

/* Full Ledger card */
.full-ledger-card {
  background: #fff;
  border-radius: 20px;
  padding: 1.5rem;
  box-shadow: 0 4px 20px rgba(0,0,0,0.06);
}
.full-ledger-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  font-size: 0.95rem;
  color: #1e293b;
}
.month-picker {
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 0.35rem 0.6rem;
  font-size: 0.85rem;
  outline: none;
}
.ledger-list { display: flex; flex-direction: column; gap: 0.6rem; }
.ledger-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.8rem 1rem;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
}
.ledger-details { display: flex; flex-direction: column; gap: 0.15rem; }
.ledger-title   { font-size: 0.95rem; font-weight: 700; color: #1e293b; }
.ledger-date    { font-size: 0.75rem; color: #94a3b8; }
.ledger-duration {
  font-size: 0.72rem; color: #c4b5fd;
  background: rgba(139,92,246,0.1);
  padding: 1px 6px; border-radius: 4px; width: fit-content;
}
.ledger-amount-val { font-weight: 700; font-size: 1rem; }
.ledger-amount-val.pos { color: #10b981; }
.ledger-amount-val.neg { color: #ef4444; }
.uncheck-btn {
  margin-top: 0.4rem;
  background: none;
  border: 1px solid #ef4444;
  color: #ef4444;
  border-radius: 6px;
  padding: 2px 8px;
  font-size: 0.72rem;
  font-weight: 700;
  cursor: pointer;
}

/* ── Activity Insights ────────────────────────────────────── */
.insights-card {
  background: #eef2ff;
  border-radius: 20px;
  padding: 1.75rem;
}
.insights-title {
  font-size: 1.1rem;
  font-weight: 800;
  color: #1e293b;
  margin: 0 0 1.25rem;
}
.insight-row {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 0.75rem 0;
  border-bottom: 1px solid rgba(99,102,241,0.1);
}
.insight-row:last-child { border-bottom: none; }
.insight-icon {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.4rem;
  flex-shrink: 0;
}
.insight-label { font-weight: 700; color: #1e293b; font-size: 0.95rem; }
.insight-sub   { font-size: 0.8rem; color: #64748b; margin-top: 0.1rem; }

/* ── Family banner ────────────────────────────────────────── */
.family-banner {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
  border-radius: 16px;
  padding: 1rem 1.75rem;
  margin-bottom: 2rem;
  box-shadow: 0 6px 20px rgba(99,102,241,0.3);
}
.family-banner__left {
  display: flex;
  align-items: center;
  gap: 1rem;
}
.family-banner__icon { font-size: 1.8rem; }
.family-banner__name {
  font-size: 1.2rem;
  font-weight: 900;
  color: #fff;
  letter-spacing: -0.3px;
}
.family-banner__sub {
  font-size: 0.78rem;
  color: rgba(255,255,255,0.65);
  font-weight: 600;
  margin-top: 0.1rem;
}
.family-banner__id {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  background: rgba(255,255,255,0.15);
  border: 1px solid rgba(255,255,255,0.25);
  border-radius: 9999px;
  padding: 0.45rem 1.1rem;
}
.family-id-label {
  font-size: 0.72rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: rgba(255,255,255,0.65);
}
.family-id-value {
  font-size: 1rem;
  font-weight: 900;
  color: #fff;
  font-family: monospace;
  letter-spacing: 0.5px;
}

/* ── Invite Caregiver ─────────────────────────────────────── */
.invite-btn {
  background: none;
  border: 1.5px solid #6366f1;
  color: #6366f1;
  font-weight: 700;
  font-size: 0.85rem;
  border-radius: 9999px;
  padding: 0.3rem 0.9rem;
  cursor: pointer;
  transition: background 0.15s, color 0.15s;
}
.invite-btn:hover { background: #6366f1; color: #fff; }

.invite-hint {
  font-size: 0.82rem;
  color: #64748b;
  background: #f8fafc;
  border-left: 3px solid #6366f1;
  border-radius: 0 8px 8px 0;
  padding: 0.6rem 1rem;
  margin: 0.75rem 0 0;
}

/* Pending invitations */
.pending-invitations {
  margin-top: 1.5rem;
  padding-top: 1.25rem;
  border-top: 1px solid #f1f5f9;
}
.pending-title {
  font-size: 0.78rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: #94a3b8;
  margin-bottom: 0.75rem;
}
.pending-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.65rem 0.9rem;
  background: #fafafa;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  margin-bottom: 0.5rem;
}
.pending-email { font-size: 0.9rem; font-weight: 700; color: #1e293b; }
.pending-name  { font-size: 0.77rem; color: #64748b; margin-top: 0.1rem; }
.pending-badge {
  font-size: 0.7rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.3px;
  color: #f59e0b;
  background: #fef3c7;
  border: 1px solid #fde68a;
  border-radius: 9999px;
  padding: 0.2rem 0.65rem;
}

/* ── Responsive ───────────────────────────────────────────── */
@media (max-width: 768px) {
  .two-col-grid { grid-template-columns: 1fr; }
  .page-heading h1 { font-size: 2rem; }
}
</style>
