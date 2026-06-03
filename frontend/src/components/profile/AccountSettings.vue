<script setup>
import { ref } from 'vue';
import { useAuthStore } from '../../stores/auth';
import { useFamilyStore } from '../../stores/family';
import { useNotifications } from '../../composables/useNotifications';
import { avatarStyle } from '../../utils/avatarStyle';

const props = defineProps({
  family:    Object,
  profileForm: Object,
});
const emit = defineEmits(['update:profileForm', 'update-profile', 'delete-account']);

const appStore    = useAuthStore();
const familyStore = useFamilyStore();
const { permission: notifPermission, enable: enableNotifications, disable: disableNotifications } = useNotifications();

const notifPrefDefs = [
  { key: 'activity_assigned',  label: 'Activity assigned to me' },
  { key: 'activity_validated', label: 'Activity approved & coins earned' },
  { key: 'activity_completed', label: 'Family activity completed' },
  { key: 'bounty_offered',     label: 'Bounty offered on a shift' },
  { key: 'family_events',      label: 'Family management events' },
];
const notifPrefs = ref({ activity_assigned: true, activity_validated: true, activity_completed: true, bounty_offered: true, family_events: true });

const loadNotifPrefs = async () => {
  if (notifPermission.value !== 'granted') return;
  try {
    const data = await appStore.request('/api/me/notification-preferences', { headers: appStore.authHeaders() });
    notifPrefs.value = data;
  } catch { /* ignore */ }
};
const saveNotifPrefs = async () => {
  try {
    await appStore.request('/api/me/notification-preferences', { method: 'PUT', headers: appStore.authHeaders(), body: JSON.stringify(notifPrefs.value) });
  } catch { appStore.setError('Failed to save notification preferences.'); }
};
const handleEnableNotifications = async () => { await enableNotifications(); await loadNotifPrefs(); };

const userAvatarInput = ref(null);
const handleUserAvatarUpload = async (event) => {
  const file = event.target.files[0];
  if (!file) return;
  const formData = new FormData();
  formData.append('avatar', file);
  await appStore.runAction(async () => {
    const headers = appStore.authHeaders(); delete headers['Content-Type'];
    await appStore.request('/api/me/avatar', { method: 'POST', headers, body: formData });
    await familyStore.fetchUserData();
  }, 'Your avatar updated successfully!');
};

defineExpose({ loadNotifPrefs });
</script>

<template>
  <div class="settings-card">
    <div class="settings-card__header">
      <div class="accent-bar"></div>
      <h2>Account Settings</h2>
    </div>

    <div class="avatar-row">
      <div class="user-avatar"
           :style="familyStore.profile?.avatar_url ? avatarStyle(appStore.apiBase, familyStore.profile.avatar_url) : ''"
           @click="userAvatarInput.click()" title="Click to change photo">
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

    <div class="settings-form">
      <div class="form-row">
        <div class="form-field">
          <label>Full Name</label>
          <input :value="profileForm.displayName" @input="emit('update:profileForm', { ...profileForm, displayName: $event.target.value })" type="text" class="text-input" placeholder="Your full name" />
        </div>
        <div class="form-field">
          <label>Email Address</label>
          <input :value="profileForm.email" @input="emit('update:profileForm', { ...profileForm, email: $event.target.value })" type="email" class="text-input" placeholder="your@email.com" />
        </div>
        <div class="form-field" v-if="family">
          <label>Your Alias</label>
          <input :value="profileForm.alias" @input="emit('update:profileForm', { ...profileForm, alias: $event.target.value })" type="text" class="text-input" placeholder="e.g. Papa, Mama…" />
        </div>
      </div>
      <div style="display:flex;justify-content:space-between;align-items:center;margin-top:1rem;">
        <button class="update-btn" @click="emit('update-profile')">Update Profile</button>
        <button @click="emit('delete-account')" style="color:#ef4444;border:1px solid #ef4444;background:none;border-radius:9999px;padding:0.5rem 1.1rem;font-weight:700;font-size:0.85rem;cursor:pointer;">Delete Account</button>
      </div>

      <div style="margin-top:1rem;padding-top:1rem;border-top:1px solid var(--border);">
        <div style="font-size:0.85rem;font-weight:700;color:var(--text-secondary);margin-bottom:0.75rem;">Push Notifications</div>
        <button v-if="notifPermission !== 'granted'" class="update-btn" @click="handleEnableNotifications">Enable Notifications</button>
        <div v-else>
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:0.75rem;">
            <span style="font-size:0.85rem;color:var(--success);font-weight:600;">✓ Notifications enabled</span>
            <button @click="disableNotifications" style="font-size:0.8rem;color:var(--text-secondary);background:none;border:none;cursor:pointer;text-decoration:underline;">Disable</button>
          </div>
          <div class="notif-pref-list">
            <label v-for="pref in notifPrefDefs" :key="pref.key" class="notif-pref-row">
              <span class="notif-pref-label">{{ pref.label }}</span>
              <input type="checkbox" class="notif-pref-toggle" v-model="notifPrefs[pref.key]" @change="saveNotifPrefs" />
            </label>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.settings-card { background:#fff; border-radius:20px; padding:2rem; box-shadow:0 4px 20px rgba(0,0,0,0.06); }
.settings-card__header { display:flex; align-items:center; gap:0.75rem; margin-bottom:1.5rem; }
.accent-bar { width:4px; height:28px; background:#6366f1; border-radius:9999px; }
.settings-card__header h2 { font-size:1.2rem; font-weight:800; color:#1e293b; margin:0; }
.avatar-row { display:flex; align-items:center; gap:1.5rem; margin-bottom:1.5rem; }
.user-avatar { width:80px; height:80px; border-radius:50%; background:#60a5fa; display:flex; align-items:center; justify-content:center; font-size:2.5rem; cursor:pointer; position:relative; flex-shrink:0; overflow:hidden; border:3px solid #e0e7ff; transition:border-color 0.2s; }
.user-avatar:hover { border-color:#6366f1; }
.avatar-edit-badge { position:absolute; bottom:2px; right:2px; background:#6366f1; border-radius:50%; width:22px; height:22px; display:flex; align-items:center; justify-content:center; font-size:0.7rem; }
.user-name { font-weight:800; font-size:1.1rem; color:#1e293b; }
.user-email { font-size:0.85rem; color:#64748b; margin-top:0.1rem; }
.user-role-pill { display:inline-block; margin-top:0.4rem; background:#e0e7ff; color:#4338ca; font-size:0.72rem; font-weight:800; text-transform:uppercase; letter-spacing:0.5px; padding:0.2rem 0.7rem; border-radius:9999px; }
.settings-form { margin-top:0.5rem; }
.form-row { display:grid; grid-template-columns:repeat(auto-fit, minmax(180px,1fr)); gap:1rem; margin-bottom:1.25rem; }
.form-field label { display:block; font-size:0.78rem; font-weight:700; color:#64748b; text-transform:uppercase; letter-spacing:0.5px; margin-bottom:0.35rem; }
.text-input { width:100%; box-sizing:border-box; padding:0.65rem 1rem; border:1px solid #e2e8f0; border-radius:12px; font-size:0.95rem; color:#1e293b; background:#f8fafc; outline:none; transition:border-color 0.2s; }
.text-input:focus { border-color:#6366f1; background:#fff; }
.update-btn { background:linear-gradient(135deg,#6366f1,#8b5cf6); color:#fff; border:none; border-radius:9999px; padding:0.7rem 2rem; font-weight:800; font-size:1rem; cursor:pointer; box-shadow:0 4px 12px rgba(99,102,241,0.35); transition:transform 0.15s, box-shadow 0.15s; }
.update-btn:hover { transform:scale(1.04); box-shadow:0 6px 18px rgba(99,102,241,0.5); }
.notif-pref-list { display:flex; flex-direction:column; gap:2px; background:var(--bg,#f8fafc); border:1px solid var(--border,#e2e8f0); border-radius:12px; overflow:hidden; }
.notif-pref-row { display:flex; justify-content:space-between; align-items:center; padding:0.6rem 0.9rem; cursor:pointer; transition:background 0.12s; border-bottom:1px solid var(--border,#e2e8f0); }
.notif-pref-row:last-child { border-bottom:none; }
.notif-pref-row:hover { background:rgba(99,102,241,0.04); }
.notif-pref-label { font-size:0.85rem; font-weight:600; color:var(--text-primary,#1e293b); }
.notif-pref-toggle { appearance:none; -webkit-appearance:none; width:40px; height:22px; background:#cbd5e1; border-radius:9999px; position:relative; cursor:pointer; flex-shrink:0; transition:background 0.2s; }
.notif-pref-toggle:checked { background:#6366f1; }
.notif-pref-toggle::after { content:''; position:absolute; top:3px; left:3px; width:16px; height:16px; background:#fff; border-radius:50%; transition:transform 0.2s; box-shadow:0 1px 3px rgba(0,0,0,0.2); }
.notif-pref-toggle:checked::after { transform:translateX(18px); }
@media (max-width:480px) { .form-row { grid-template-columns:1fr; } .avatar-row { gap:1rem; } .user-avatar { width:60px; height:60px; font-size:1.5rem; } }
</style>
