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
  background: var(--bg);
}
.join-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r-lg);
  padding: 3rem 2.5rem;
  max-width: 420px;
  width: 100%;
  text-align: center;
  box-shadow: 0 10px 25px -5px rgba(0,0,0,0.05);
}
.join-icon { font-size: 3rem; margin-bottom: 1rem; }
h1 {
  font-size: 1.8rem;
  font-weight: 800;
  color: var(--text-primary);
  margin: 0 0 0.5rem;
  letter-spacing: -0.02em;
}
.join-sub { color: var(--text-secondary); margin: 0 0 2rem; font-size: 0.95rem; }

.join-form { display: flex; flex-direction: column; gap: 1rem; text-align: left; }
.field-label {
  font-size: 0.78rem;
  font-weight: 700;
  color: var(--text-secondary);
}
.alias-input {
  padding: 0.75rem 1rem;
  border: 1px solid var(--input-border);
  border-radius: var(--r-pill);
  font-size: 1rem;
  color: var(--text-primary);
  background: var(--input-bg);
  outline: none;
  font-family: var(--font-family);
  transition: border-color 0.2s, box-shadow 0.2s;
  width: 100%;
  box-sizing: border-box;
}
.alias-input:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(37,99,235,0.15);
  background: var(--surface);
}

.join-btn {
  background: var(--primary);
  color: #fff;
  border: none;
  border-radius: var(--r-pill);
  padding: 0.85rem 2rem;
  font-weight: 800;
  font-size: 1rem;
  font-family: var(--font-family);
  cursor: pointer;
  box-shadow: 0 4px 14px rgba(37,99,235,0.3);
  transition: opacity 0.15s, transform 0.15s;
  min-height: 44px;
}
.join-btn:hover:not(:disabled) { opacity: 0.9; transform: translateY(-1px); }
.join-btn:active:not(:disabled) { transform: scale(0.98); }
.join-btn:disabled { opacity: 0.6; cursor: not-allowed; }

.join-error {
  background: var(--danger-soft);
  border: 1px solid var(--danger-soft);
  color: var(--danger);
  border-radius: var(--r-md);
  padding: 1rem;
  font-size: 0.9rem;
  font-weight: 600;
  margin-bottom: 1rem;
}
.join-success {
  background: var(--success-soft);
  border: 1px solid var(--success-soft);
  color: var(--success);
  border-radius: var(--r-md);
  padding: 1rem;
  font-size: 0.9rem;
  font-weight: 700;
}
.back-link {
  background: none;
  border: none;
  color: var(--text-secondary);
  font-size: 0.85rem;
  font-family: var(--font-family);
  cursor: pointer;
  margin-top: 1.5rem;
  text-decoration: underline;
}
</style>