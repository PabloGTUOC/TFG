<script setup>
import { ref } from 'vue';
import { useAppStore } from '../stores/app';
import { useRouter } from 'vue-router';
import VCard from '../components/VCard.vue';
import VButton from '../components/VButton.vue';
import VInput from '../components/VInput.vue';

const appStore = useAppStore();
const router = useRouter();

const isRegistering = ref(false);
const email = ref('');
const password = ref('');
const loading = ref(false);

const submit = async () => {
  if (!email.value || !password.value) {
    appStore.setError("Email and password are required.");
    return;
  }
  loading.value = true;
  try {
    if (isRegistering.value) {
      await appStore.register(email.value, password.value);
    } else {
      await appStore.login(email.value, password.value);
    }
    // Auth guard in router or App.vue will handle the switch now, but we can redirect manually:
    router.push('/dashboard');
  } catch (err) {
    // Error is set in store automatically
  } finally {
    loading.value = false;
  }
};
</script>

<template>
  <div class="login-wrapper">
    <VCard :title="isRegistering ? 'Create CareCoins Account' : 'Welcome to CareCoins'" style="max-width: 450px; margin: 0 auto;">
      <p style="text-align: center; margin-bottom: 2rem;">
        {{ isRegistering ? 'Sign up to start sharing responsibly.' : 'Sign in to access your dashboard.' }}
      </p>

      <form @submit.prevent="submit" class="grid">
        <VInput v-model="email" type="email" label="Email Address" placeholder="hello@carecoins.app" :disabled="loading" />
        <VInput v-model="password" type="password" label="Password" placeholder="••••••••" :disabled="loading" />
        
        <VButton type="primary" block :disabled="loading" style="margin-top: 1rem;">
          {{ loading ? 'Processing...' : (isRegistering ? 'Sign Up' : 'Sign In') }}
        </VButton>
      </form>

      <div class="toggle-mode">
        <span>{{ isRegistering ? 'Already have an account?' : 'New to CareCoins?' }}</span>
        <a href="#" @click.prevent="isRegistering = !isRegistering">
          {{ isRegistering ? 'Sign In instead' : 'Create an account' }}
        </a>
      </div>
    </VCard>
  </div>
</template>

<style scoped>
.login-wrapper {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 4rem 1rem;
}
.toggle-mode {
  text-align: center;
  margin-top: 2rem;
  font-size: 0.9rem;
  color: var(--text-secondary);
}
.toggle-mode a {
  color: var(--accent-primary);
  text-decoration: none;
  font-weight: 600;
  margin-left: 0.5rem;
}
.toggle-mode a:hover {
  text-decoration: underline;
}
</style>
