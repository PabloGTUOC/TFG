import { defineStore } from 'pinia';
import { useAuthStore } from './auth';

export const useFamilyStore = defineStore('family', {
  state: () => ({
    profile: null,
    families: [],
    pendingRequests: [],
    actors: [],
  }),
  actions: {
    async fetchUserData() {
      const authStore = useAuthStore();
      try {
        const data = await authStore.request('/api/me', { headers: authStore.authHeaders() });
        this.profile = data.user || null;
        this.families = data.families || [];
        this.pendingRequests = data.pendingRequests || [];
        this.actors = data.actors || [];

        if (!authStore.loginEventId) {
          const loginData = await authStore.request('/api/me/login-event', {
            method: 'POST',
            headers: authStore.authHeaders()
          });
          authStore.loginEventId = loginData.eventId;
        }
      } catch (e) {
        console.error('Backend auth sync failed', e);
      }
    }
  }
});
