<script setup>
import { storeToRefs } from 'pinia';
import { useAppStore } from './stores/app';
import { useRouter } from 'vue-router';

const appStore = useAppStore();
const router = useRouter();
const { success, error, user, families, authReady } = storeToRefs(appStore);

const handleLogout = async () => {
  await appStore.logout();
  router.push('/login');
};
</script>

<template>
  <div v-if="!authReady" class="loading-screen">
    <h2>Loading CareCoins...</h2>
  </div>
  <div v-else class="app-layout">
    <header class="app-header">
      <h1>CareCoins</h1>
      <nav class="navbar" v-if="user && families && families.length > 0">
        <router-link to="/dashboard">Family</router-link>
        <router-link to="/activities">Activities</router-link>
        <router-link to="/marketplace">Marketplace</router-link>
        <router-link to="/profile">Personal Area</router-link>
        <a href="#" @click.prevent="handleLogout" class="logout-link">Logout</a>
      </nav>
      <!-- Allow logout from onboarding -->
      <nav class="navbar" v-else-if="user && (!families || families.length === 0)">
        <a href="#" @click.prevent="handleLogout" class="logout-link">Logout</a>
      </nav>
    </header>

    <main class="main-content">
      <router-view></router-view>

      <div class="notifications">
        <p v-if="success" class="success-message">{{ success }}</p>
        <p v-if="error" class="error-message">{{ error }}</p>
      </div>
    </main>
  </div>
</template>

<style>
.app-layout {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}
.app-header {
  padding: 1.5rem;
  background-color: #1a1a2e;
  text-align: center;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}
.app-header h1 {
  margin-top: 0;
  margin-bottom: 1rem;
  font-size: 2rem;
  font-weight: bold;
}
.navbar {
  display: flex;
  justify-content: center;
  gap: 1.5rem;
  flex-wrap: wrap;
}
.navbar a {
  color: #a8a8b3;
  text-decoration: none;
  font-weight: 500;
  padding-bottom: 5px;
  transition: color 0.3s;
}
.navbar a:hover,
.navbar a.router-link-active {
  color: #fff;
  border-bottom: 2px solid #5b21b6;
}
.main-content {
  flex: 1;
  padding: 2rem;
  max-width: 1000px;
  width: 100%;
  margin: 0 auto;
}
.notifications {
  position: fixed;
  bottom: 2rem;
  right: 2rem;
  z-index: 50;
}
.success-message {
  background-color: #10b981;
  color: white;
  padding: 1rem;
  border-radius: 8px;
  margin-top: 0;
  margin-bottom: 0.5rem;
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}
.error-message {
  background-color: #ef4444;
  color: white;
  padding: 1rem;
  border-radius: 8px;
  margin-top: 0;
  margin-bottom: 0.5rem;
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}
.logout-link {
  color: #fca5a5 !important;
  margin-left: 1rem;
}
.logout-link:hover {
  color: #ef4444 !important;
  border-bottom-color: #ef4444 !important;
}
.loading-screen {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  color: var(--accent-primary);
}
</style>
