<script setup>
import { ref, onMounted, onUnmounted } from 'vue';
import { storeToRefs } from 'pinia';
import { useAuthStore } from './stores/auth';
import { useFamilyStore } from './stores/family';
import { useRouter } from 'vue-router';

const authStore = useAuthStore();
const familyStore = useFamilyStore();
const router = useRouter();
const { success, error, user, authReady } = storeToRefs(authStore);
const { families } = storeToRefs(familyStore);

const showDropdown = ref(false);
const profileMenuRef = ref(null);

const closeDropdown = (e) => {
  if (showDropdown.value && profileMenuRef.value && !profileMenuRef.value.contains(e.target)) {
    showDropdown.value = false;
  }
};

onMounted(() => document.addEventListener('click', closeDropdown));
onUnmounted(() => document.removeEventListener('click', closeDropdown));

const handleLogout = async () => {
  await authStore.logout();
  router.push('/login');
};
</script>

<template>
  <div v-if="!authReady" class="loading-screen">
    <h2>Loading CareCoins...</h2>
  </div>
  <div v-else class="app-layout">
    
    <!-- Floating Pill Navigation -->
    <header class="pill-header" v-if="user">
      <div class="pill-container">
        
        <div class="logo">
          <span class="text-2xl">🪙</span> 
          <strong class="text-xl" style="color: #1e293b; letter-spacing:-0.5px; margin-left: 0.2rem;">CareCoins</strong>
        </div>
        
        <nav class="pill-nav" v-if="families && families.length > 0">
          <router-link to="/dashboard">Family</router-link>
          <router-link to="/activities">Activities</router-link>
          <router-link to="/marketplace">Marketplace</router-link>
          <router-link to="/profile">Personal Area</router-link>
        </nav>
        
        <div class="pill-profile" ref="profileMenuRef">
           <!-- Right Side Avatar & Dropdown -->
           <div class="avatar-block" @click="showDropdown = !showDropdown" title="User Menu">
             <div class="avatar" :style="familyStore.profile?.avatar_url ? `background-image: url('${authStore.apiBase}${familyStore.profile.avatar_url}'); background-size: cover; background-position: center; border: 1px solid #3b82f6;` : ''">
               {{ familyStore.profile?.avatar_url ? '' : (familyStore.profile?.actor_type === 'caregiver' ? '👩🏽' : '👨🏽') }}
             </div>
             <span class="text-xs" style="margin-left:4px; color: #64748b;">▼</span>
           </div>
           
           <div v-if="showDropdown" class="profile-dropdown">
             <a href="#" @click.prevent="showDropdown = false; handleLogout()" class="dropdown-item logout-link">Logout</a>
           </div>
        </div>

      </div>
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
/* App Root Styling */
body {
  margin: 0;
  font-family: 'Inter', -apple-system, sans-serif;
  background-color: #eef2ff; /* Extremely soft blue to mimic the wavy background */
  position: relative;
  overflow-x: hidden;
}

/* Wavy Background Illusion */
body::before {
  content: '';
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background-image: radial-gradient(circle at top right, #e0e7ff, transparent 400px), 
                    radial-gradient(circle at bottom left, #e0e7ff, transparent 500px);
  z-index: -1;
}

.app-layout {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

/* -------------------
   Pill Navbar
------------------- */
.pill-header {
  width: 100%;
  display: flex;
  justify-content: center;
  padding: 1.5rem 0 0 0;
  box-sizing: border-box;
}

.pill-container {
  max-width: 1000px;
  width: calc(100% - 2rem);
  background: #ffffff;
  border-radius: 999px;
  padding: 0.6rem 1.5rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.05);
  position: relative;
  z-index: 100;
  box-sizing: border-box;
}

.logo {
  display: flex;
  align-items: center;
}

.pill-nav {
  display: flex;
  gap: 1.5rem;
}

.pill-nav a {
  color: #64748b;
  text-decoration: none;
  font-weight: 600;
  font-size: 1rem;
  padding: 0.4rem 0.8rem;
  border-radius: 999px;
  transition: all 0.2s;
}

.pill-nav a:hover {
  color: #1e293b;
  background: #f1f5f9;
}

.pill-nav a.router-link-active {
  color: #1e293b;
  background: #e0f2fe; /* Light baby blue active state */
}

/* Profile Avatar Section */
.pill-profile {
  position: relative;
}

.avatar-block {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  cursor: pointer;
  padding: 0.2rem 0.5rem;
  border-radius: 999px;
  transition: background 0.2s;
}

.avatar-block:hover {
  background: #f1f5f9;
}

.avatar {
  background: #cbd5e1;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.1rem;
}

.profile-dropdown {
  position: absolute;
  top: calc(100% + 10px);
  right: 0;
  background: #ffffff;
  border-radius: 12px;
  box-shadow: 0 10px 30px rgba(0,0,0,0.15);
  padding: 0.5rem 0;
  min-width: 160px;
  display: flex;
  flex-direction: column;
  z-index: 1000;
  border: 1px solid #f1f5f9;
  overflow: hidden;
}

.dropdown-item {
  padding: 0.8rem 1.5rem;
  text-align: left;
  text-decoration: none;
  font-weight: 500;
  font-size: 0.95rem;
  color: #1e293b;
  transition: background 0.2s, color 0.2s;
  display: block;
}

.dropdown-item:hover {
  background: #f8fafc;
}

.dropdown-item.logout-link {
  color: #ef4444;
}

.dropdown-item.logout-link:hover {
  background: #fef2f2;
}

/* -------------------
   Main Body layout
------------------- */
.main-content {
  flex: 1;
  padding: 2rem 0;
  max-width: 1000px;
  width: calc(100% - 2rem);
  margin: 0 auto;
  box-sizing: border-box;
}

/* Notifications */
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
.loading-screen {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  color: var(--accent-primary);
}
</style>
