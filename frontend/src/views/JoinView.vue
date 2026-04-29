<script setup>
import { ref, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { useFamilyStore } from '../stores/family';

const route  = useRoute();
const router = useRouter();
const appStore    = useAuthStore();
const familyStore = useFamilyStore();

const alias   = ref('');
const status  = ref('idle'); // idle | joining | success | error
const message = ref('');

onMounted(async () => {
  const token = route.query.token;
  if (!token) {
    status.value  = 'error';
    message.value = 'No invite token found in the link.';
    return;
  }

  // Not logged in — store the full URL and redirect to login
  await appStore.waitForAuth();
  if (!appStore.user) {
    sessionStorage.setItem('returnUrl', route.fullPath);
    router.push('/login');
  }
});

const join = async () => {
  const token = route.query.token;
  if (!token) return;

  status.value = 'joining';
  try {
    await appStore.request('/api/families/join-by-token', {
      method: 'POST',
      headers: appStore.authHeaders(),
      body: JSON.stringify({ token, alias: alias.value.trim() || undefined })
    });
    await familyStore.fetchUserData();
    status.value = 'success';
    setTimeout(() => router.push('/dashboard'), 1500);
  } catch (err) {
    status.value  = 'error';
    message.value = err.message || 'Failed to join family.';
  }
};
</script>

<template>
  <div class="join-wrapper">
    <div class="join-card">
      <div class="join-icon">🏠</div>
      <h1>You've been invited!</h1>
      <p class="join-sub">Someone shared a CareCoins family invite with you.</p>

      <div v-if="status === 'error'" class="join-error">
        {{ message }}
      </div>

      <div v-else-if="status === 'success'" class="join-success">
        You joined successfully! Redirecting…
      </div>

      <div v-else class="join-form">
        <label class="field-label">Your alias (optional)</label>
        <input
          v-model="alias"
          type="text"
          class="alias-input"
          placeholder="e.g. Mama, Uncle Joe…"
          :disabled="status === 'joining'"
        />
        <button
          class="join-btn"
          @click="join"
          :disabled="status === 'joining'"
        >
          {{ status === 'joining' ? 'Joining…' : 'Accept & Join Family' }}
        </button>
      </div>

      <button class="back-link" @click="router.push('/dashboard')">
        Go to dashboard instead
      </button>
    </div>
  </div>
</template>

<style scoped>
.join-wrapper {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 2rem 1rem;
  background: linear-gradient(135deg, #eef2ff 0%, #f5f3ff 100%);
}
.join-card {
  background: #fff;
  border-radius: 24px;
  padding: 3rem 2.5rem;
  max-width: 420px;
  width: 100%;
  text-align: center;
  box-shadow: 0 20px 60px rgba(99,102,241,0.15);
}
.join-icon { font-size: 3rem; margin-bottom: 1rem; }
h1 {
  font-size: 1.8rem;
  font-weight: 900;
  color: #1e1b4b;
  margin: 0 0 0.5rem;
}
.join-sub { color: #64748b; margin: 0 0 2rem; font-size: 0.95rem; }

.join-form { display: flex; flex-direction: column; gap: 1rem; text-align: left; }
.field-label {
  font-size: 0.78rem;
  font-weight: 700;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.alias-input {
  padding: 0.75rem 1rem;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  font-size: 1rem;
  color: #1e293b;
  background: #f8fafc;
  outline: none;
  transition: border-color 0.2s;
}
.alias-input:focus { border-color: #6366f1; background: #fff; }

.join-btn {
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  color: #fff;
  border: none;
  border-radius: 9999px;
  padding: 0.85rem 2rem;
  font-weight: 800;
  font-size: 1rem;
  cursor: pointer;
  box-shadow: 0 4px 14px rgba(99,102,241,0.4);
  transition: transform 0.15s, box-shadow 0.15s;
}
.join-btn:hover:not(:disabled) { transform: scale(1.03); box-shadow: 0 6px 20px rgba(99,102,241,0.5); }
.join-btn:disabled { opacity: 0.6; cursor: not-allowed; }

.join-error {
  background: #fef2f2;
  border: 1px solid #fecaca;
  color: #dc2626;
  border-radius: 12px;
  padding: 1rem;
  font-size: 0.9rem;
  margin-bottom: 1rem;
}
.join-success {
  background: #f0fdf4;
  border: 1px solid #bbf7d0;
  color: #16a34a;
  border-radius: 12px;
  padding: 1rem;
  font-size: 0.9rem;
  font-weight: 700;
}
.back-link {
  background: none;
  border: none;
  color: #94a3b8;
  font-size: 0.85rem;
  cursor: pointer;
  margin-top: 1.5rem;
  text-decoration: underline;
}
</style>