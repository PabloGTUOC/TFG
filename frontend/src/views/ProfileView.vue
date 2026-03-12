<script setup>
import { ref } from 'vue';
import { useAppStore } from '../stores/app';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';

const appStore = useAppStore();
const me = ref(null);
const loginHistory = ref([]);
const profileForm = ref({ displayName: '', email: '' });

const loadMe = () => appStore.runAction(async () => {
  const data = await appStore.request('/api/me', { headers: appStore.authHeaders() });
  me.value = data.user;
  profileForm.value.displayName = data.user?.display_name || '';
  profileForm.value.email = data.user?.email || '';
}, 'Loaded current user.');

const updateProfile = () => appStore.runAction(async () => {
  const data = await appStore.request('/api/me/profile', { method: 'PATCH', headers: appStore.authHeaders(), body: JSON.stringify(profileForm.value) });
  me.value = data.user;
}, 'Profile updated.');

const loadLoginHistory = () => appStore.runAction(async () => {
  const data = await appStore.request('/api/me/login-history', { headers: appStore.authHeaders() });
  loginHistory.value = data.loginHistory || [];
}, 'Loaded login history.');
</script>

<template>
  <VCard title="User Profile">
    <div class="row">
      <VButton type="secondary" @click="loadMe">Load my profile</VButton>
      <VButton type="secondary" @click="loadLoginHistory">Load login history</VButton>
    </div>
    
    <h3>Update Info</h3>
    <div class="grid two">
      <VInput v-model="profileForm.displayName" label="Display Name" placeholder="John Doe" />
      <VInput v-model="profileForm.email" label="Email Address" placeholder="john@example.com" />
    </div>
    <VButton type="primary" @click="updateProfile" style="margin-top: 1rem;">Update profile</VButton>
    
    <pre v-if="me" style="margin-top: 1.5rem;">{{ me }}</pre>
    
    <h3 v-if="loginHistory.length > 0" style="margin-top: 1.5rem;">Login History</h3>
    <ul v-if="loginHistory.length > 0">
      <li v-for="item in loginHistory" :key="item.id">
        {{ new Date(item.login_at).toLocaleString() }} - {{ item.ip_address }} - {{ item.user_agent }}
      </li>
    </ul>
  </VCard>
</template>
