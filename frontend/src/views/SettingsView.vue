<script setup>
import { ref } from 'vue';
import { storeToRefs } from 'pinia';
import { useAppStore } from '../stores/app';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';

const appStore = useAppStore();
const { apiBase, user } = storeToRefs(appStore);

const backendStatus = ref('Not checked');
const backendPayload = ref(null);

const checkBackend = () => appStore.runAction(async () => {
  backendPayload.value = await appStore.request('/health');
  backendStatus.value = 'Online';
}, 'Backend health check succeeded.');
</script>

<template>
  <VCard title="Connection Settings">
    <p>Configure your development backend URL.</p>
    <div class="row">
      <VInput v-model="apiBase" label="Backend API URL" placeholder="http://localhost:3000" />
    </div>
    
    <VButton type="primary" @click="checkBackend">Check backend health</VButton>
    <p><strong>Status:</strong> {{ backendStatus }}</p>
    <pre v-if="backendPayload">{{ backendPayload }}</pre>
  </VCard>
  
  <VCard title="Debug Info" style="margin-top: 1.5rem;">
    <p><strong>Firebase UID:</strong> {{ user?.uid }}</p>
    <p><strong>Email:</strong> {{ user?.email }}</p>
    <!-- We can add token preview here if we wanted to debug without the console, but it's long! -->
  </VCard>
</template>
