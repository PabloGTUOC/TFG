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
const isMenuOpen = ref(false);

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
        
        <div class="logo" @click="router.push('/dashboard')" style="cursor: pointer;" title="Go to Family Hub">
          <span class="text-2xl">🪙</span> 
          <strong class="text-xl" style="color: #1e293b; letter-spacing:-0.5px; margin-left: 0.2rem;">CareCoins</strong>
        </div>
        
        <nav class="pill-nav desktop-only" v-if="families && families.length > 0">
          <router-link to="/dashboard">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9 22 9 12 15 12 15 22"></polyline></svg>
            Family
          </router-link>
          <router-link to="/activities">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>
            Activities
          </router-link>
          <router-link to="/marketplace">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"></path><line x1="3" y1="6" x2="21" y2="6"></line><path d="M16 10a4 4 0 0 1-8 0"></path></svg>
            Marketplace
          </router-link>
          <router-link to="/profile">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>
            Personal Area
          </router-link>
        </nav>
        
        <div style="display:flex; align-items:center; gap: 1rem;">
          <!-- Coin Counter -->
          <div v-if="families && families.length > 0" class="coin-counter" style="background: var(--success); color: white; padding: 0.4rem 0.8rem; border-radius: 999px; font-weight: 800; display:flex; align-items:center; gap:0.5rem; box-shadow: 0 4px 10px rgba(34, 197, 94, 0.3);">
            <span class="coin-label" style="background: rgba(255,255,255,0.25); padding: 0.1rem 0.5rem; border-radius: 999px; font-size: 0.9rem;">{{ families[0].alias || familyStore.profile?.display_name || 'Caregiver' }}</span>
            <span>{{ families[0].coin_balance }} cc</span>
          </div>

          <div class="pill-profile desktop-only" ref="profileMenuRef">
             <!-- Right Side Avatar & Dropdown -->
             <div class="avatar-block" @click="showDropdown = !showDropdown" title="User Menu">
               <div class="avatar" :style="familyStore.profile?.avatar_url ? `background-image: url('${authStore.apiBase}${familyStore.profile.avatar_url}'); background-size: cover; background-position: center; border: 2px solid var(--accent-primary);` : ''">
                 {{ familyStore.profile?.avatar_url ? '' : (familyStore.profile?.actor_type === 'caregiver' ? '👩🏽' : '👨🏽') }}
               </div>
             </div>
             
             <div v-if="showDropdown" class="profile-dropdown">
               <a href="#" @click.prevent="showDropdown = false; handleLogout()" class="dropdown-item logout-link">Logout</a>
             </div>
          </div>
          
          <button class="hamburger-btn mobile-only" @click="isMenuOpen = !isMenuOpen">
            <svg v-if="!isMenuOpen" width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 12h18M3 6h18M3 18h18"/></svg>
            <svg v-else width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12"/></svg>
          </button>
        </div>

      </div>
    </header>

    <!-- Mobile Menu Overlay -->
    <div v-if="isMenuOpen" class="mobile-menu-overlay">
      <div style="padding: 2rem; display: flex; flex-direction: column; gap: 2rem; width: 100%; flex: 1;">
         <!-- User Avatar Mobile -->
         <div style="display: flex; align-items: center; gap: 1rem; padding-bottom: 2rem; border-bottom: 1px solid rgba(0,0,0,0.1);">
           <div class="avatar" :style="familyStore.profile?.avatar_url ? `background-image: url('${authStore.apiBase}${familyStore.profile.avatar_url}'); background-size: cover; background-position: center; border: 2px solid var(--accent-primary); width: 60px; height: 60px; font-size: 2.5rem;` : 'width: 60px; height: 60px; font-size: 2.5rem;'">
             {{ familyStore.profile?.avatar_url ? '' : (familyStore.profile?.actor_type === 'caregiver' ? '👩🏽' : '👨🏽') }}
           </div>
           <div>
             <div style="font-weight: 800; font-size: 1.3rem;">{{ familyStore.profile?.display_name || 'Caregiver' }}</div>
             <div style="font-size: 0.95rem; color: var(--text-secondary);">{{ familyStore.profile?.email }}</div>
           </div>
         </div>
         
         <nav class="mobile-nav" v-if="families && families.length > 0">
            <router-link to="/dashboard" @click="isMenuOpen = false">Family Hub</router-link>
            <router-link to="/activities" @click="isMenuOpen = false">Activities</router-link>
            <router-link to="/marketplace" @click="isMenuOpen = false">Marketplace</router-link>
            <router-link to="/profile" @click="isMenuOpen = false">Personal Area</router-link>
         </nav>
         
         <div style="flex: 1;"></div>
         <button class="mobile-logout" @click="isMenuOpen = false; handleLogout()">Logout</button>
      </div>
    </div>

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
/* App Root Styling handled in style.css, but app-layout handles flex */
.app-layout {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

/* -------------------
   Pill Navbar (The Editorial Playground)
------------------- */
.pill-header {
  width: 100%;
  position: sticky;
  top: 0;
  z-index: 1000;
  display: flex;
  justify-content: center;
  padding: 1.5rem 0 0 0;
  box-sizing: border-box;
  background: transparent;
  pointer-events: none;
}

.pill-container {
  pointer-events: auto;
  max-width: 1000px;
  width: calc(100% - 2rem);
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-sizing: border-box;
  background: rgba(255, 255, 255, 0.85);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  padding: 0.5rem 1rem;
  border-radius: 999px;
  border: 1px solid rgba(0,0,0,0.05);
  box-shadow: 0 4px 20px rgba(0,0,0,0.04);
}

.logo {
  display: flex;
  align-items: center;
  font-family: var(--font-family);
}

.pill-nav {
  display: flex;
  gap: 0.5rem;
}

.pill-nav a {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #64748b;
  text-decoration: none;
  font-weight: 700;
  font-size: 0.95rem;
  padding: 0.6rem 1.2rem;
  border-radius: 999px;
  transition: all 0.2s;
}

.pill-nav a:hover {
  color: var(--text-primary);
  background: rgba(0,0,0,0.04);
}

.pill-nav a.router-link-active {
  background: #e0e7ff;
  color: #3730a3;
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
  padding: 0.75rem 0 2rem 0;
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
  z-index: 20000;
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

.desktop-only { }
.mobile-only { display: none !important; }
.hamburger-btn { background: none; border: none; cursor: pointer; color: var(--text-primary); display: flex; align-items: center; justify-content: center; padding: 0.5rem; }

.mobile-menu-overlay {
  position: fixed;
  top: 65px;
  left: 0; right: 0; bottom: 0;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
  z-index: 999;
  display: flex;
  flex-direction: column;
}
.mobile-nav {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}
.mobile-nav a {
  font-size: 1.6rem;
  font-weight: 800;
  color: var(--text-primary);
  text-decoration: none;
}
.mobile-nav a.router-link-active { color: var(--accent-primary); }
.mobile-logout {
  background: #fef2f2; color: #ef4444; border: none; padding: 1.2rem; border-radius: 16px; font-size: 1.2rem; font-weight: 800; width: 100%; cursor: pointer;
}

/* Tablet / large phone: nav wraps at 768px */
@media (max-width: 768px) {
  .desktop-only { display: none !important; }
  .mobile-only { display: flex !important; }
  
  .pill-header { 
    padding: 0; 
    background: rgba(255, 255, 255, 0.9);
    backdrop-filter: blur(24px);
    border-bottom: 1px solid var(--card-border);
    pointer-events: auto;
  }
  .pill-container {
    width: 100%;
    padding: 0.75rem 1rem;
    border-radius: 0;
    border: none;
    box-shadow: none;
    background: transparent;
  }
  .main-content { width: 100%; padding: 0.75rem 0; }
}

/* Phone: smaller text, hide coin label */
@media (max-width: 480px) {
  .pill-nav a { font-size: 0.75rem; padding: 0.3rem 0.25rem; }
  .coin-label { display: none; }
  .main-content { padding: 0.5rem 0; }
}
</style>
