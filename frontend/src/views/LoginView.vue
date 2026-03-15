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
    router.push('/dashboard');
  } catch (err) {
    // Error is set in store
  } finally {
    loading.value = false;
  }
};

const handleGoogle = async () => {
  try {
    await appStore.loginWithGoogle();
    router.push('/dashboard');
  } catch (err) {
    // Error is set in store
  }
};
</script>

<template>
  <div class="login-wrapper">
    <VCard :title="isRegistering ? 'Create CareCoins Account' : 'Welcome to CareCoins'" style="max-width: 450px; margin: 0 auto;">
      <p style="text-align: center; margin-bottom: 2rem;">
        {{ isRegistering ? 'Sign up to start sharing responsibly.' : 'Sign in to access your dashboard.' }}
      </p>

      <form @submit.prevent="submit" class="grid" style="margin-bottom: 1.5rem;">
        <VInput v-model="email" type="email" label="Email Address" placeholder="hello@carecoins.app" :disabled="loading" />
        <VInput v-model="password" type="password" label="Password" placeholder="••••••••" :disabled="loading" />
        
        <VButton type="primary" block :disabled="loading" style="margin-top: 1rem;">
          {{ loading ? 'Processing...' : (isRegistering ? 'Sign Up' : 'Sign In') }}
        </VButton>
      </form>

      <div class="divider">
        <span>or</span>
      </div>

      <VButton type="secondary" block @click="handleGoogle" style="margin-top: 1rem; position: relative;">
        <!-- Simple Google G SVG embed -->
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" style="position: absolute; left: 1rem;">
          <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
          <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
          <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
          <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
        </svg>
        Sign in with Google
      </VButton>

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

.divider {
  display: flex;
  align-items: center;
  text-align: center;
  color: var(--text-secondary);
  font-size: 0.85rem;
  margin: 1.5rem 0;
}
.divider::before, 
.divider::after {
  content: '';
  flex: 1;
  border-bottom: 1px solid var(--card-border);
}
.divider span {
  padding: 0 0.8rem;
}
</style>
