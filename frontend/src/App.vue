<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue';
import { storeToRefs } from 'pinia';
import { useAuthStore } from './stores/auth';
import { useFamilyStore } from './stores/family';
import { useRouter } from 'vue-router';
import { Home, Calendar, ShoppingBag, User, CircleDollarSign, Menu, X } from 'lucide-vue-next';
import { avatarStyle } from './utils/avatarStyle';

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

onMounted(() => {
  document.addEventListener('click', closeDropdown);
});

onUnmounted(() => {
  document.removeEventListener('click', closeDropdown);
});

const handleLogout = async () => {
  await authStore.logout();
  router.push('/login');
};

const profileInitial = computed(() => {
  const name = familyStore.profile?.display_name || user.value?.email || '';
  return (name.trim()[0] || '?').toUpperCase();
});

const coinAliasInitial = computed(() => {
  const alias = families.value?.[0]?.alias || familyStore.profile?.display_name || 'C';
  return (alias.trim()[0] || 'C').toUpperCase();
});
</script>

<template>
  <div v-if="!authReady" class="loading-screen">
    <h2>Loading CareCoins...</h2>
  </div>
  <div v-else class="app-layout">

    <!-- Floating Pill Navigation -->
    <header class="pill-header" v-if="user">
      <div class="pill-container">

        <div class="logo" @click="router.push('/dashboard')" title="Go to Family Hub">
          <span class="logo-mark">
            <img src="/icon-mark.svg" width="18" height="18" alt="Logo" style="display: block;" />
          </span>
          <strong class="logo-text">CareCoins</strong>
        </div>

        <nav class="pill-nav desktop-only" v-if="families && families.length > 0">
          <router-link to="/dashboard">
            <Home :size="18" :stroke-width="2" />
            <span>Family</span>
          </router-link>
          <router-link to="/activities">
            <Calendar :size="18" :stroke-width="2" />
            <span>Activities</span>
          </router-link>
          <router-link to="/marketplace">
            <ShoppingBag :size="18" :stroke-width="2" />
            <span>Marketplace</span>
          </router-link>
          <router-link to="/profile">
            <User :size="18" :stroke-width="2" />
            <span>Personal</span>
          </router-link>
        </nav>

        <div class="pill-right">
          <!-- Coin Counter -->
          <div v-if="families && families.length > 0" class="coin-counter" :title="families[0].alias || 'Go to Personal Area'" @click="router.push('/profile')">
            <span class="coin-avatar">{{ coinAliasInitial }}</span>
            <span class="coin-amount">{{ families[0].coin_balance }}</span>
            <span class="coin-unit">cc</span>
          </div>

          <div class="pill-profile desktop-only" ref="profileMenuRef">
            <div class="avatar-block" @click="showDropdown = !showDropdown" title="User Menu">
              <div class="avatar"
                :style="familyStore.profile?.avatar_url ? avatarStyle(authStore.apiBase, familyStore.profile.avatar_url) : null">
                <span v-if="!familyStore.profile?.avatar_url">{{ profileInitial }}</span>
              </div>
            </div>

            <div v-if="showDropdown" class="profile-dropdown">
              <a href="#" @click.prevent="showDropdown = false; handleLogout()" class="dropdown-item logout-link">Logout</a>
            </div>
          </div>

          <button class="hamburger-btn mobile-only" @click="isMenuOpen = !isMenuOpen" aria-label="Open menu">
            <Menu v-if="!isMenuOpen" :size="16" :stroke-width="2" />
            <X v-else :size="16" :stroke-width="2" />
          </button>
        </div>

      </div>
    </header>

    <!-- Mobile Menu Overlay -->
    <div v-if="isMenuOpen" class="mobile-menu-overlay">
      <div style="padding: 2rem; display: flex; flex-direction: column; gap: 2rem; width: 100%; flex: 1;">
         <div style="display: flex; align-items: center; gap: 1rem; padding-bottom: 2rem; border-bottom: 1px solid var(--border);">
           <div class="avatar avatar-lg"
             :style="familyStore.profile?.avatar_url ? avatarStyle(authStore.apiBase, familyStore.profile.avatar_url) : null">
             <span v-if="!familyStore.profile?.avatar_url">{{ profileInitial }}</span>
           </div>
           <div>
             <div style="font-weight: 800; font-size: 1.3rem;">{{ familyStore.profile?.display_name || 'Caregiver' }}</div>
             <div style="font-size: 0.95rem; color: var(--text-secondary);">{{ familyStore.profile?.email }}</div>
           </div>
         </div>

         <nav class="mobile-nav" v-if="families && families.length > 0">
            <router-link to="/dashboard" @click="isMenuOpen = false">
              <Home :size="20" :stroke-width="2" />
              <span>Family Hub</span>
            </router-link>
            <router-link to="/activities" @click="isMenuOpen = false">
              <Calendar :size="20" :stroke-width="2" />
              <span>Activities</span>
            </router-link>
            <router-link to="/marketplace" @click="isMenuOpen = false">
              <ShoppingBag :size="20" :stroke-width="2" />
              <span>Marketplace</span>
            </router-link>
            <router-link to="/profile" @click="isMenuOpen = false">
              <User :size="20" :stroke-width="2" />
              <span>Personal</span>
            </router-link>
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
.app-layout {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

/* -------------------
   Floating Pill Navigation
------------------- */
.pill-header {
  width: 96%;
  max-width: 1140px;
  margin: 18px auto 8px;
  position: sticky;
  top: 18px;
  z-index: 1000;
  display: flex;
  justify-content: center;
  box-sizing: border-box;
  pointer-events: none;
}

.pill-container {
  pointer-events: auto;
  width: 100%;
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-sizing: border-box;
  background: rgba(255, 255, 255, 0.85);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  padding: 12px 24px;
  border-radius: var(--r-pill);
  border: 1px solid rgba(14, 23, 38, 0.06);
  box-shadow: 0 4px 24px rgba(14, 23, 38, 0.06);
}

.logo {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  font-family: var(--font);
}

.logo-mark {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  background: var(--primary);
  color: #fff;
  border-radius: var(--r-sm);
}

.logo-text {
  color: var(--text-primary);
  font-weight: 800;
  font-size: 20px;
  letter-spacing: -0.3px;
}

.pill-nav {
  display: flex;
  gap: 8px;
}

.pill-nav a {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--text-secondary);
  text-decoration: none;
  font-weight: 700;
  font-size: 15px;
  padding: 10px 18px;
  border-radius: var(--r-pill);
  transition: color 0.2s, background 0.2s;
}

.pill-nav a:hover {
  color: var(--text-primary);
}

.pill-nav a.router-link-active {
  color: var(--primary);
  background: var(--primary-soft);
}

.pill-right {
  display: flex;
  align-items: center;
  gap: 10px;
}

/* Coin counter */
.coin-counter {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 14px 6px 6px;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: var(--r-pill);
  cursor: pointer;
  transition: border-color 0.15s, box-shadow 0.15s;
}
.coin-counter:hover {
  border-color: var(--primary);
  box-shadow: 0 2px 8px rgba(14, 23, 38, 0.05);
}

.coin-avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 26px;
  height: 26px;
  border-radius: 50%;
  background: var(--primary);
  color: #fff;
  font-weight: 800;
  font-size: 13px;
}

.coin-amount {
  color: var(--text-primary);
  font-weight: 800;
  font-size: 15px;
}

.coin-unit {
  color: var(--text-secondary);
  font-weight: 700;
  font-size: 13px;
}

/* Profile avatar */
.pill-profile {
  position: relative;
}

.avatar-block {
  cursor: pointer;
  border-radius: 50%;
  transition: transform 0.15s;
}

.avatar-block:hover {
  transform: scale(1.05);
}

.avatar {
  background: var(--text-primary);
  color: #fff;
  width: 38px;
  height: 38px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 15px;
}

.avatar.avatar-lg {
  width: 60px;
  height: 60px;
  font-size: 22px;
}

.profile-dropdown {
  position: absolute;
  top: calc(100% + 10px);
  right: 0;
  background: var(--surface);
  border-radius: var(--r-md);
  box-shadow: 0 10px 30px rgba(14, 23, 38, 0.12);
  padding: 6px 0;
  min-width: 160px;
  display: flex;
  flex-direction: column;
  z-index: 1000;
  border: 1px solid var(--border);
  overflow: hidden;
}

.dropdown-item {
  padding: 10px 16px;
  text-align: left;
  text-decoration: none;
  font-weight: 600;
  font-size: 13px;
  color: var(--text-primary);
  transition: background 0.15s;
  display: block;
}

.dropdown-item:hover {
  background: var(--bg);
}

.dropdown-item.logout-link {
  color: var(--danger);
}

.dropdown-item.logout-link:hover {
  background: var(--danger-soft);
}

/* Hamburger */
.hamburger-btn {
  width: 38px;
  height: 38px;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 50%;
  cursor: pointer;
  color: var(--text-primary);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
}

/* -------------------
   Main Body layout
------------------- */
.main-content {
  flex: 1;
  padding: 12px 0 32px 0;
  width: 92%;
  max-width: 1080px;
  margin: 0 auto;
  box-sizing: border-box;
}

/* Page-level container utility — match the floating-nav width */
.page-container {
  width: 100%;
  max-width: 1080px;
  margin: 0 auto;
  padding: 20px 40px;
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
  background: var(--success);
  color: #fff;
  padding: 14px 18px;
  border-radius: var(--r-md);
  margin: 0 0 8px;
  box-shadow: 0 4px 12px rgba(14, 23, 38, 0.12);
  font-weight: 700;
}
.error-message {
  background: var(--danger);
  color: #fff;
  padding: 14px 18px;
  border-radius: var(--r-md);
  margin: 0 0 8px;
  box-shadow: 0 4px 12px rgba(14, 23, 38, 0.12);
  font-weight: 700;
}
.loading-screen {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  color: var(--primary);
}

.desktop-only { }
.mobile-only { display: none !important; }

/* Mobile menu overlay */
.mobile-menu-overlay {
  position: fixed;
  top: 65px;
  left: 0; right: 0; bottom: 0;
  background: rgba(255, 255, 255, 0.96);
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
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 1.4rem;
  font-weight: 800;
  color: var(--text-primary);
  text-decoration: none;
  min-height: 44px;
}
.mobile-nav a.router-link-active { color: var(--primary); }
.mobile-logout {
  background: var(--danger-soft);
  color: var(--danger);
  border: none;
  padding: 18px;
  border-radius: var(--r-md);
  font-size: 1.1rem;
  font-weight: 800;
  width: 100%;
  cursor: pointer;
}

/* Tablet / large phone */
@media (max-width: 768px) {
  .desktop-only { display: none !important; }
  .mobile-only { display: flex !important; }

  .pill-header {
    width: calc(100% - 24px);
    margin: 12px 12px 4px;
    top: 12px;
  }
  .pill-container {
    padding: 6px 10px 6px 12px;
  }
  .logo-mark { width: 24px; height: 24px; }
  .logo-text { font-size: 14px; }
  .coin-counter { padding: 4px 10px 4px 4px; }
  .coin-avatar { width: 18px; height: 18px; font-size: 10px; }
  .coin-amount { font-size: 12px; }
  .coin-unit { font-size: 10px; }

  .main-content {
    width: 100%;
    padding: 12px 0 32px;
  }
  .page-container {
    padding: 16px 18px;
  }
}

@media (max-width: 480px) {
  .main-content { padding: 8px 0 24px; }
  /* Ensure 44px minimum tap area for hamburger */
  .hamburger-btn {
    width: 44px;
    height: 44px;
  }
  /* Pill nav links at very small screens get full padding */
  .pill-nav a {
    padding: 10px 10px;
    min-height: 44px;
  }
}

@media (prefers-reduced-motion: reduce) {
  .pill-nav a,
  .avatar-block,
  .avatar-block:hover,
  .hamburger-btn {
    transition: none;
  }
  .avatar-block:hover { transform: none; }
}
</style>
