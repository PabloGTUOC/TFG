<script setup>
import { ref, watchEffect, onMounted } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useFamilyStore } from '../stores/family';
import { useRouter } from 'vue-router';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';
import VSelect from '../components/VSelect.vue';

const appStore = useAuthStore();
const familyStore = useFamilyStore();
const router = useRouter();

const mode = ref('selection'); // 'selection', 'create', 'join', 'token'

const createForm = ref({ 
  name: '',
  alias: '',
  mainCaretakerName: '',
  mainCaretakerEmail: '',
  caretakers: [{ name: '', email: '' }], 
  objectsOfCare: [
    { name: '', type: 'child', careTime: 'full_time' }
  ]
});

watchEffect(() => {
  if (familyStore.profile) {
    if (!createForm.value.mainCaretakerName) createForm.value.mainCaretakerName = familyStore.profile.display_name || '';
    if (!createForm.value.mainCaretakerEmail) createForm.value.mainCaretakerEmail = familyStore.profile.email || '';
  }
});

const pendingInvites = ref([]);
const joinForm = ref({ familyId: '', alias: '' });
const tokenForm = ref({ token: '', alias: '' });

const loadPendingInvites = async () => {
  try {
    const data = await appStore.request('/api/me/invites', { headers: appStore.authHeaders() });
    pendingInvites.value = data.invites || [];
  } catch { /* silent */ }
};

const acceptInvite = (invite) => appStore.runAction(async () => {
  await appStore.request('/api/families/join-request', {
    method: 'POST',
    headers: appStore.authHeaders(),
    body: JSON.stringify({ familyId: invite.family_id, alias: joinForm.value.alias || undefined })
  });
  await familyStore.fetchUserData();
  router.push('/dashboard');
}, 'You joined the family!');

const joinByToken = () => appStore.runAction(async () => {
  let token = tokenForm.value.token.trim();
  // Accept either the full URL or just the UUID
  const match = token.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i);
  if (!match) throw new Error('No valid invite token found. Paste the full invite link or just the token.');
  token = match[0];

  await appStore.request('/api/families/join-by-token', {
    method: 'POST',
    headers: appStore.authHeaders(),
    body: JSON.stringify({ token, alias: tokenForm.value.alias.trim() || undefined })
  });
  await familyStore.fetchUserData();
  router.push('/dashboard');
}, 'You joined the family!');

const addCaretaker = () => {
  createForm.value.caretakers.push({ name: '', email: '' });
};
const removeCaretaker = (index) => {
  createForm.value.caretakers.splice(index, 1);
};

const addObjectOfCare = () => {
  createForm.value.objectsOfCare.push({ name: '', type: 'child', careTime: 'full_time' });
};
const removeObjectOfCare = (index) => {
  createForm.value.objectsOfCare.splice(index, 1);
};

const objectTypeOptions = [
  { value: 'child', label: 'Child' },
  { value: 'elderly', label: 'Elderly' },
  { value: 'pet', label: 'Pet' }
];

const careTimeOptions = [
  { value: 'full_time', label: 'Full Time (24 coins/day)' },
  { value: 'part_time', label: 'Part Time (12 coins/day)' }
];

onMounted(() => { loadPendingInvites(); });

const createFamily = () => appStore.runAction(async () => {
  if (!createForm.value.name) throw new Error("Family name is required.");
  
  const validCaretakers = createForm.value.caretakers.filter(e => e.email.trim() !== '');
  const validObjects = createForm.value.objectsOfCare.filter(o => o.name.trim() !== '');

  await appStore.request('/api/families', {
    method: 'POST',
    headers: appStore.authHeaders(),
    body: JSON.stringify({
      name: createForm.value.name,
      alias: createForm.value.alias,
      mainCaretakerName: createForm.value.mainCaretakerName,
      caretakers: validCaretakers,
      objectsOfCare: validObjects
    })
  });
  
  await familyStore.fetchUserData();
  router.push('/dashboard');
}, 'Family created successfully!');

</script>

<template>
  <div class="onboarding-wrapper">
    <div class="onboarding-header">
      <h2>Welcome to CareCoins! 🎉</h2>
      <p>Before we get you to the dashboard, you need to belong to a family. You can either create your own new family hub, or request to join an existing one.</p>
    </div>

    <div v-if="familyStore.pendingRequests.length > 0" class="pending-notice">
      You have a pending request to join <strong>{{ familyStore.pendingRequests[0].name }}</strong>. Please wait for the main caregiver to approve your access.
    </div>

    <!-- SELECTION MODE -->
    <div v-if="mode === 'selection'">
      <!-- Pending email invitations -->
      <div v-if="pendingInvites.length > 0" class="invites-section">
        <h3 class="invites-title">You have been invited to join:</h3>
        <div v-for="inv in pendingInvites" :key="inv.id" class="invite-row">
          <div>
            <div class="invite-family">{{ inv.family_name }}</div>
            <div class="invite-meta" v-if="inv.inviter_name">Invited as {{ inv.inviter_name }}</div>
          </div>
          <VButton type="primary" @click="acceptInvite(inv)">Accept</VButton>
        </div>
      </div>

      <div class="grid two">
        <VCard title="Create a New Family">
          <p class="desc">Start fresh as the Main Caregiver, invite others, and define who needs care.</p>
          <VButton type="primary" block @click="mode = 'create'" style="margin-top: 1rem;">Create Family</VButton>
        </VCard>

        <VCard title="Join via Invite Link">
          <p class="desc">Received an invite link or QR code? Paste the link here to join instantly.</p>
          <VButton type="secondary" block @click="mode = 'token'" style="margin-top: 1rem;">Use Invite Link</VButton>
        </VCard>
      </div>
    </div>

    <!-- CREATE MODE -->
    <VCard v-if="mode === 'create'" title="Setup Your New Family">
      <VButton type="outline" @click="mode = 'selection'" style="margin-bottom: 2rem;">&larr; Back</VButton>
      
      <div class="form-section">
        <h3>1. Family Details</h3>
        <p class="desc">Define the family name and your unique identity within it.</p>
        <div class="grid two">
          <VInput v-model="createForm.name" label="Family Name" placeholder="e.g. The Smiths" />
          <VInput v-model="createForm.alias" label="Your Alias (Role)" placeholder="e.g. Dada, Mama, Nanny" />
        </div>
      </div>

      <hr />

      <div class="form-section">
        <h3>2. Caregivers</h3>
        <p class="desc">You are the Main Caregiver. You can update your display name here. If you want to invite others, add them below.</p>
        
        <div class="list-item" style="margin-bottom: 1.5rem;">
          <VInput v-model="createForm.mainCaretakerName" placeholder="Your Display Name" style="flex: 1;" />
          <VInput v-model="createForm.mainCaretakerEmail" type="email" placeholder="Your Email" style="flex: 1;" disabled />
        </div>

        <h4 style="margin-bottom: 0.5rem; color: var(--text-secondary); font-size: 0.9rem;">Invited Caregivers</h4>
        <div v-for="(ct, index) in createForm.caretakers" :key="'ct'+index" class="list-item">
          <VInput v-model="createForm.caretakers[index].name" placeholder="Name (Optional)" style="flex: 1;" />
          <VInput v-model="createForm.caretakers[index].email" type="email" placeholder="caregiver@example.com" style="flex: 1;" />
          <VButton type="danger" @click="removeCaretaker(index)">X</VButton>
        </div>
        <VButton type="outline" @click="addCaretaker" style="margin-top: 0.5rem;">+ Add another caregiver</VButton>
      </div>

      <hr />

      <div class="form-section">
        <h3>3. Objects of Care</h3>
        <p class="desc">Who or what are you taking care of? This defines your family's daily CareCoin budget.</p>
        <div v-for="(obj, index) in createForm.objectsOfCare" :key="'obj'+index" class="care-object-item">
          <div class="grid three">
            <VInput v-model="obj.name" placeholder="Name (e.g. Tommy)" />
            <VSelect v-model="obj.type" :options="objectTypeOptions" />
            <VSelect v-model="obj.careTime" :options="careTimeOptions" />
          </div>
          <VButton type="danger" @click="removeObjectOfCare(index)" style="margin-left: 1rem; height: fit-content; align-self: flex-end; margin-bottom: 0.2rem;">X</VButton>
        </div>
        <VButton type="outline" @click="addObjectOfCare" style="margin-top: 0.5rem;">+ Add someone to care for</VButton>
      </div>

      <hr />

      <VButton type="primary" block @click="createFamily" style="margin-top: 1rem;">Complete Setup</VButton>
    </VCard>

    <!-- TOKEN MODE -->
    <VCard v-if="mode === 'token'" title="Join via Invite Link" style="max-width: 500px; margin: 0 auto;">
      <VButton type="outline" @click="mode = 'selection'" style="margin-bottom: 2rem;">&larr; Back</VButton>
      <p class="desc">Paste the full invite link (or just the token) you received, then choose an alias for yourself.</p>
      <div style="display: flex; flex-direction: column; gap: 1rem;">
        <VInput v-model="tokenForm.token" label="Invite Link or Token" placeholder="https://…/join?token=… or paste the token" />
        <VInput v-model="tokenForm.alias" label="Your Alias (optional)" placeholder="e.g. Dada, Uncle Joe" />
      </div>
      <VButton type="primary" block @click="joinByToken" style="margin-top: 1.5rem;">Join Family</VButton>
    </VCard>

  </div>
</template>

<style scoped>
.onboarding-wrapper {
  max-width: 900px;
  margin: 0 auto;
  padding: 2rem 1rem;
}
.onboarding-header {
  text-align: center;
  margin-bottom: 3rem;
}
.onboarding-header h2 {
  font-size: 2.5rem;
  margin-bottom: 1rem;
  background: var(--accent-gradient);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
.onboarding-header p {
  color: var(--text-secondary);
  font-size: 1.1rem;
  max-width: 600px;
  margin: 0 auto;
  line-height: 1.6;
}
.desc {
  color: var(--text-secondary);
  font-size: 0.9rem;
  margin-bottom: 1.5rem;
}
.form-section {
  margin-bottom: 1.5rem;
}
.form-section h3 {
  margin-bottom: 0.5rem;
  color: var(--text-primary);
}
.list-item {
  display: flex;
  gap: 1rem;
  margin-bottom: 0.5rem;
  align-items: flex-end;
}
.care-object-item {
  display: flex;
  align-items: center;
  margin-bottom: 0.5rem;
  background: rgba(255, 255, 255, 0.03);
  padding: 1rem;
  border-radius: 8px;
}
.care-object-item .grid {
  flex: 1;
}
hr {
  border-color: var(--card-border);
  margin: 2rem 0;
}
.pending-notice {
  background: rgba(234, 179, 8, 0.1);
  border: 1px solid rgba(234, 179, 8, 0.5);
  color: #fef08a;
  padding: 1rem;
  border-radius: 8px;
  text-align: center;
  margin-bottom: 2rem;
}
.invites-section {
  background: #f0fdf4;
  border: 1px solid #bbf7d0;
  border-radius: 16px;
  padding: 1.5rem;
  margin-bottom: 2rem;
}
.invites-title {
  font-size: 1rem;
  font-weight: 800;
  color: #15803d;
  margin: 0 0 1rem;
}
.invite-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: #fff;
  border-radius: 12px;
  padding: 0.9rem 1.1rem;
  margin-bottom: 0.6rem;
  border: 1px solid #dcfce7;
}
.invite-family { font-weight: 800; color: #1e293b; font-size: 0.95rem; }
.invite-meta   { font-size: 0.78rem; color: #64748b; margin-top: 0.15rem; }

@media (max-width: 768px) {
  .list-item {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>
