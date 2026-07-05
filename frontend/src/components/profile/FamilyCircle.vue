<script setup>
import { ref, computed } from 'vue';
import QRCode from 'qrcode';
import { useAuthStore } from '../../stores/auth';
import { useFamilyStore } from '../../stores/family';
import VSelect from '../VSelect.vue';
import { avatarStyle } from '../../utils/avatarStyle';

const props = defineProps({
  family:       Object,
  familyId:     [Number, String],
  isCaregiver:  Boolean,
  actors:       Array,
  familyMembers: Array,
  invitations:  Array,
});
const emit = defineEmits(['reload-members', 'delete-family']);

const appStore    = useAuthStore();
const familyStore = useFamilyStore();

const typeOptions = [
  { value: 'child',   label: '👶 Child / Baby' },
  { value: 'pet',     label: '🐾 Pet' },
  { value: 'elderly', label: '👴 Elderly' },
];
const timeOptions = [
  { value: 'full_time', label: 'Full Time' },
  { value: 'part_time', label: 'Part Time' },
];

const showAddActor   = ref(false);
const showInviteForm = ref(false);
const addActorForm   = ref({ name: '', actorType: 'child', careTime: 'full_time' });
const inviteForm     = ref({ email: '', name: '' });

const combinedCircleItems = computed(() => {
  const humans = (props.familyMembers || []).map(m => ({
    id: 'user_' + m.id, user_id: m.id, family_id: props.familyId,
    name: m.name, actor_type: m.role || 'member', avatar_url: m.avatar_url, care_time: null,
  }));
  return [...humans, ...(props.actors || [])];
});

const actorBadge = (type) => {
  const map = { child: { label: 'Junior Explorer', color: '#6366f1' }, pet: { label: 'Furry Friend', color: '#10b981' }, elderly: { label: 'Guiding Star', color: '#f59e0b' }, caregiver: { label: 'Caregiver', color: '#059669' }, member: { label: 'Family Member', color: '#3b82f6' }, person: { label: 'Family Member', color: '#3b82f6' } };
  return map[type] || { label: type.replace(/_/g, ' '), color: '#94a3b8' };
};

const triggerActorUpload = (actorId) => { const el = document.getElementById(`actor-upload-${actorId}`); if (el) el.click(); };
const handleActorAvatarUpload = async (event, actorId, fid) => {
  const file = event.target.files[0]; if (!file) return;
  const formData = new FormData(); formData.append('avatar', file);
  await appStore.runAction(async () => {
    const headers = appStore.authHeaders(); delete headers['Content-Type'];
    await appStore.request(`/api/families/${fid}/actors/${actorId}/avatar`, { method: 'POST', headers, body: formData });
    await familyStore.fetchUserData();
  }, 'Dependent avatar updated successfully!');
};

const removeActor = (actorId, fid) => appStore.runAction(async () => {
  await appStore.request(`/api/families/${fid}/actors/${actorId}`, { method: 'DELETE', headers: appStore.authHeaders() });
  await familyStore.fetchUserData();
}, 'Pet removed successfully.');

const addActor = () => appStore.runAction(async () => {
  const fid = props.familyId;
  if (!fid) throw new Error('No family found.');
  if (!addActorForm.value.name.trim()) throw new Error('Name is required.');
  await appStore.request(`/api/families/${fid}/actors`, { method: 'POST', headers: appStore.authHeaders(), body: JSON.stringify(addActorForm.value) });
  addActorForm.value = { name: '', actorType: 'child', careTime: 'full_time' };
  showAddActor.value = false;
  await familyStore.fetchUserData();
}, 'Dependent added!');

const sendInvite = () => appStore.runAction(async () => {
  const fid = props.familyId;
  if (!fid) throw new Error('No family found.');
  const email = inviteForm.value.email.trim();
  if (!email) throw new Error('Email is required.');
  await appStore.request(`/api/families/${fid}/invitations`, { method: 'POST', headers: appStore.authHeaders(), body: JSON.stringify({ email, name: inviteForm.value.name.trim() || undefined }) });
  inviteForm.value = { email: '', name: '' };
  showInviteForm.value = false;
  emit('reload-members');
}, 'Invitation saved!');

// Invite link + QR
const inviteLink     = ref('');
const inviteQr       = ref('');
const generatingLink = ref(false);
const linkCopied     = ref(false);
const canShare       = computed(() => !!navigator.share);

const generateInviteLink = async () => {
  const fid = props.familyId; if (!fid) return;
  generatingLink.value = true;
  try {
    const data = await appStore.request(`/api/families/${fid}/invite-links`, { method: 'POST', headers: appStore.authHeaders(), body: JSON.stringify({}) });
    inviteLink.value = `${window.location.origin}/join?token=${data.link.id}`;
    inviteQr.value   = await QRCode.toDataURL(inviteLink.value, { width: 200, margin: 2 });
  } catch (err) { appStore.setError(err.message || 'Failed to generate invite link.'); }
  finally { generatingLink.value = false; }
};
const copyInviteLink = async () => {
  try { await navigator.clipboard.writeText(inviteLink.value); linkCopied.value = true; setTimeout(() => { linkCopied.value = false; }, 2000); }
  catch { appStore.setError('Could not copy to clipboard.'); }
};
const shareInviteLink = () => navigator.share({ title: 'Join my CareCoins family', text: "I've invited you to join my family on CareCoins.", url: inviteLink.value }).catch(() => {});
</script>

<template>
  <div class="family-circle-section">
    <div class="section-header">
      <h2>Family Circle</h2>
      <div v-if="isCaregiver" class="section-actions">
        <button class="add-member-btn" @click="showAddActor = !showAddActor; showInviteForm = false">➕ Add Dependent</button>
        <button class="invite-btn" @click="showInviteForm = !showInviteForm; showAddActor = false">📧 Invite Caregiver</button>
      </div>
    </div>

    <div v-if="combinedCircleItems.length > 0" class="circle-grid">
      <div v-for="a in combinedCircleItems" :key="a.id" class="circle-card">
        <div class="circle-avatar"
             :style="[a.avatar_url ? avatarStyle(appStore.apiBase, a.avatar_url) : {}, { cursor: a.user_id ? 'default' : 'pointer' }]"
             @click="!a.user_id ? triggerActorUpload(a.id) : null">
          <span v-if="!a.avatar_url">{{ a.actor_type === 'child' ? '👶🏽' : a.actor_type === 'pet' ? '🐾' : a.actor_type === 'elderly' ? '👴🏽' : '👤' }}</span>
          <div v-if="!a.user_id" class="circle-camera">📷</div>
        </div>
        <input v-if="!a.user_id" :id="'actor-upload-'+a.id" type="file" style="display:none;" accept="image/*" @change="handleActorAvatarUpload($event, a.id, a.family_id)">
        <div class="circle-name">{{ a.name }}</div>
        <div class="circle-badge" :style="`color:${actorBadge(a.actor_type).color};border-color:${actorBadge(a.actor_type).color}33;`">{{ actorBadge(a.actor_type).label.toUpperCase() }}</div>
        <button v-if="isCaregiver && a.actor_type === 'pet'" class="remove-actor-btn" @click.stop="removeActor(a.id, a.family_id)" title="Remove pet">✕</button>
      </div>
    </div>
    <div v-else class="empty-circle">No dependents added yet.</div>

    <div v-if="isCaregiver && showAddActor" class="add-actor-form">
      <div class="form-row">
        <div class="form-field"><label>Name</label><input v-model="addActorForm.name" type="text" class="text-input" placeholder="e.g. Luna, Grandpa…" /></div>
        <div class="form-field"><label>Type</label><VSelect v-model="addActorForm.actorType" :options="typeOptions" /></div>
        <div class="form-field"><label>Care Requirement</label><VSelect v-model="addActorForm.careTime" :options="timeOptions" /></div>
      </div>
      <div style="display:flex;gap:1rem;margin-top:1rem;">
        <button class="update-btn" @click="addActor">Save</button>
        <button class="cancel-btn" @click="showAddActor = false">Cancel</button>
      </div>
    </div>

    <div v-if="isCaregiver && showInviteForm" class="add-actor-form">
      <div class="form-row">
        <div class="form-field"><label>Email Address *</label><input v-model="inviteForm.email" type="email" class="text-input" placeholder="caregiver@email.com" /></div>
        <div class="form-field"><label>Their Name (optional)</label><input v-model="inviteForm.name" type="text" class="text-input" placeholder="e.g. Maria" /></div>
      </div>
      <div style="display:flex;gap:1rem;margin-top:1rem;">
        <button class="update-btn" @click="sendInvite">Send Invite</button>
        <button class="cancel-btn" @click="showInviteForm = false">Cancel</button>
      </div>
    </div>

    <div v-if="isCaregiver" class="invite-link-section">
      <div class="invite-link-header">
        <span class="invite-link-title">Shareable Invite Link</span>
        <button class="gen-link-btn" @click="generateInviteLink" :disabled="generatingLink">{{ generatingLink ? 'Generating…' : inviteLink ? '↻ New Link' : '🔗 Generate Link' }}</button>
      </div>
      <div v-if="inviteLink" class="invite-link-body">
        <div class="qr-wrap"><img :src="inviteQr" alt="Invite QR" class="qr-img" /><p class="qr-hint">Scan with phone camera</p></div>
        <div class="link-actions">
          <div class="link-box">{{ inviteLink }}</div>
          <div class="action-btns">
            <button class="action-btn copy-btn" @click="copyInviteLink">{{ linkCopied ? '✓ Copied!' : '📋 Copy Link' }}</button>
            <button v-if="canShare" class="action-btn share-btn" @click="shareInviteLink">📤 Share</button>
          </div>
          <p class="link-note">Anyone with this link can join the family as a Caregiver.</p>
        </div>
      </div>
      <p v-else class="link-empty">Generate a link to share with caregivers via WhatsApp, email, or QR code.</p>
    </div>

    <div v-if="isCaregiver" style="margin-top:2rem;padding-top:1.5rem;border-top:1px solid #f1f5f9;text-align:center;">
      <button @click="emit('delete-family')" style="background:none;color:#ef4444;border:1px solid #ef4444;border-radius:9999px;padding:0.5rem 1.5rem;font-weight:700;font-size:0.9rem;cursor:pointer;">🗑️ Delete Family</button>
      <p style="font-size:0.75rem;color:#94a3b8;margin-top:0.5rem;">This action is permanent and cannot be undone.</p>
    </div>

    <div v-if="isCaregiver && invitations.length > 0" class="pending-invitations">
      <div class="pending-title">⏳ Pending Invitations</div>
      <div v-for="inv in invitations" :key="inv.id" class="pending-row">
        <div><div class="pending-email">{{ inv.email }}</div><div class="pending-name" v-if="inv.name">{{ inv.name }}</div></div>
        <span class="pending-badge">Awaiting</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.family-circle-section { background:#fff; border-radius:20px; padding:2rem; box-shadow:0 4px 20px rgba(0,0,0,0.06); }
.section-header { display:flex; justify-content:space-between; align-items:center; margin-bottom:1.5rem; }
.section-header h2 { font-size:1.3rem; font-weight:800; color:#1e293b; margin:0; }
.section-actions { display:flex; gap:0.5rem; flex-wrap:wrap; }
.add-member-btn { background:none; border:none; color:#6366f1; font-weight:700; font-size:0.9rem; cursor:pointer; transition:opacity 0.15s; }
.add-member-btn:hover { opacity:0.7; }
.invite-btn { background:none; border:1.5px solid #6366f1; color:#6366f1; font-weight:700; font-size:0.85rem; border-radius:9999px; padding:0.3rem 0.9rem; cursor:pointer; transition:background 0.15s,color 0.15s; }
.invite-btn:hover { background:#6366f1; color:#fff; }
.circle-grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(130px,1fr)); gap:1.5rem; }
.circle-card { display:flex; flex-direction:column; align-items:center; gap:0.6rem; background:#f8fafc; border-radius:20px; padding:1.5rem 1rem; transition:transform 0.2s; }
.circle-card:hover { transform:translateY(-3px); }
.circle-avatar { width:80px; height:80px; border-radius:50%; background:#fbbf24; border:3px solid #f59e0b; display:flex; align-items:center; justify-content:center; font-size:2.2rem; cursor:pointer; position:relative; overflow:hidden; transition:border-color 0.2s; }
.circle-avatar:hover { border-color:#6366f1; }
.circle-camera { position:absolute; bottom:2px; right:2px; background:#6366f1; border-radius:50%; width:22px; height:22px; font-size:0.7rem; display:flex; align-items:center; justify-content:center; }
.circle-name { font-weight:800; font-size:1rem; color:#1e293b; }
.circle-badge { font-size:0.68rem; font-weight:800; letter-spacing:0.5px; border:1px solid; border-radius:9999px; padding:0.15rem 0.6rem; }
.remove-actor-btn { margin-top:0.4rem; background:none; border:1px solid #fca5a5; color:#ef4444; border-radius:9999px; width:1.5rem; height:1.5rem; font-size:0.65rem; cursor:pointer; transition:background 0.15s,color 0.15s; }
.remove-actor-btn:hover { background:#ef4444; color:#fff; border-color:#ef4444; }
.empty-circle { color:#94a3b8; background:#f8fafc; border-radius:12px; padding:1.5rem; text-align:center; font-size:0.9rem; }
.add-actor-form { margin-top:1.5rem; padding-top:1.5rem; border-top:1px solid #f1f5f9; }
.form-row { display:grid; grid-template-columns:repeat(auto-fit,minmax(180px,1fr)); gap:1rem; margin-bottom:1.25rem; }
.form-field label { display:block; font-size:0.78rem; font-weight:700; color:#64748b; text-transform:uppercase; letter-spacing:0.5px; margin-bottom:0.35rem; }
.text-input { width:100%; box-sizing:border-box; padding:0.65rem 1rem; border:1px solid #e2e8f0; border-radius:12px; font-size:1rem; color:#1e293b; background:#f8fafc; outline:none; transition:border-color 0.2s; }
.text-input:focus { border-color:#6366f1; background:#fff; }
.update-btn { background:linear-gradient(135deg,#6366f1,#8b5cf6); color:#fff; border:none; border-radius:9999px; padding:0.7rem 2rem; font-weight:800; font-size:1rem; cursor:pointer; }
.cancel-btn { background:#f1f5f9; color:#64748b; border:none; border-radius:9999px; padding:0.7rem 2rem; font-weight:700; font-size:1rem; cursor:pointer; }
.pending-invitations { margin-top:1.5rem; padding-top:1.25rem; border-top:1px solid #f1f5f9; }
.pending-title { font-size:0.78rem; font-weight:800; text-transform:uppercase; letter-spacing:0.5px; color:#94a3b8; margin-bottom:0.75rem; }
.pending-row { display:flex; justify-content:space-between; align-items:center; padding:0.65rem 0.9rem; background:#fafafa; border:1px solid #e2e8f0; border-radius:10px; margin-bottom:0.5rem; }
.pending-email { font-size:0.9rem; font-weight:700; color:#1e293b; }
.pending-name  { font-size:0.77rem; color:#64748b; margin-top:0.1rem; }
.pending-badge { font-size:0.7rem; font-weight:800; text-transform:uppercase; letter-spacing:0.3px; color:#f59e0b; background:#fef3c7; border:1px solid #fde68a; border-radius:9999px; padding:0.2rem 0.65rem; }
.invite-link-section { margin-top:1.5rem; padding-top:1.5rem; border-top:1px solid #f1f5f9; }
.invite-link-header { display:flex; justify-content:space-between; align-items:center; margin-bottom:1rem; }
.invite-link-title { font-size:0.85rem; font-weight:800; text-transform:uppercase; letter-spacing:0.5px; color:#64748b; }
.gen-link-btn { background:#eef2ff; color:#6366f1; border:1.5px solid #c7d2fe; border-radius:9999px; padding:0.35rem 1rem; font-weight:700; font-size:0.82rem; cursor:pointer; transition:background 0.15s; }
.gen-link-btn:hover:not(:disabled) { background:#e0e7ff; }
.gen-link-btn:disabled { opacity:0.5; cursor:not-allowed; }
.invite-link-body { display:flex; gap:1.5rem; align-items:flex-start; flex-wrap:wrap; }
.qr-wrap { text-align:center; flex-shrink:0; }
.qr-img  { width:140px; height:140px; border-radius:12px; border:1px solid #e2e8f0; }
.qr-hint { font-size:0.72rem; color:#94a3b8; margin-top:0.4rem; }
.link-actions { flex:1; min-width:0; display:flex; flex-direction:column; gap:0.75rem; }
.link-box { background:#f8fafc; border:1px solid #e2e8f0; border-radius:10px; padding:0.6rem 0.9rem; font-size:0.75rem; color:#475569; word-break:break-all; font-family:monospace; }
.action-btns { display:flex; gap:0.6rem; flex-wrap:wrap; }
.action-btn { border:none; border-radius:9999px; padding:0.5rem 1.1rem; font-weight:700; font-size:0.85rem; cursor:pointer; transition:transform 0.15s; }
.action-btn:hover { transform:scale(1.04); }
.copy-btn  { background:#6366f1; color:#fff; box-shadow:0 2px 8px rgba(99,102,241,0.3); }
.share-btn { background:#10b981; color:#fff; box-shadow:0 2px 8px rgba(16,185,129,0.3); }
.link-note  { font-size:0.75rem; color:#94a3b8; margin:0; }
.link-empty { font-size:0.82rem; color:#94a3b8; font-style:italic; margin:0; }
@media (max-width:768px) { .section-header { flex-direction:column; align-items:flex-start; gap:0.75rem; } .invite-link-body { flex-direction:column; align-items:center; } .link-actions { min-width:unset; width:100%; } }
@media (max-width:480px) { .circle-grid { grid-template-columns:repeat(auto-fill,minmax(90px,1fr)); } .circle-avatar { width:60px; height:60px; font-size:1.4rem; } }
</style>
