import { defineStore } from 'pinia';
import { watch } from 'vue';
import { auth } from '../firebase';
import {
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut,
  onIdTokenChanged,
  GoogleAuthProvider,
  signInWithPopup
} from 'firebase/auth';

export const useAuthStore = defineStore('auth', {
  state: () => ({
    apiBase: import.meta.env.VITE_API_BASE || 'http://localhost:3000',
    user: null,
    token: '',
    authReady: false,
    loginEventId: null,
    success: '',
    error: '',
  }),
  actions: {
    initAuthListener() {
      onIdTokenChanged(auth, async (user) => {
        this.user = user;
        if (user) {
          this.token = await user.getIdToken();
          const { useFamilyStore } = await import('./family.js');
          await useFamilyStore().fetchUserData();
        } else {
          this.token = '';
          this.loginEventId = null;
          const { useFamilyStore } = await import('./family.js');
          useFamilyStore().$reset();
        }
        this.authReady = true;
      });
    },

    // Returns a promise that resolves once Firebase auth state is known.
    waitForAuth() {
      if (this.authReady) return Promise.resolve();
      return new Promise(resolve => {
        const unwatch = watch(() => this.authReady, (ready) => {
          if (ready) { unwatch(); resolve(); }
        }, { immediate: true });
      });
    },

    async login(email, password) {
      this.clearMessages();
      try {
        const cred = await signInWithEmailAndPassword(auth, email, password);
        this.user = cred.user;
        this.token = await cred.user.getIdToken();
        const { useFamilyStore } = await import('./family.js');
        await useFamilyStore().fetchUserData();
        this.setSuccess('Logged in successfully!');
      } catch (err) {
        this.setError(err.message);
        throw err;
      }
    },

    async register(email, password) {
      this.clearMessages();
      try {
        const cred = await createUserWithEmailAndPassword(auth, email, password);
        this.user = cred.user;
        this.token = await cred.user.getIdToken();
        const { useFamilyStore } = await import('./family.js');
        await useFamilyStore().fetchUserData();
        this.setSuccess('Account created successfully!');
      } catch (err) {
        this.setError(err.message);
        throw err;
      }
    },

    async loginWithGoogle() {
      this.clearMessages();
      try {
        const provider = new GoogleAuthProvider();
        const cred = await signInWithPopup(auth, provider);
        this.user = cred.user;
        this.token = await cred.user.getIdToken();
        const { useFamilyStore } = await import('./family.js');
        await useFamilyStore().fetchUserData();
        this.setSuccess('Logged in with Google successfully!');
      } catch (err) {
        this.setError(err.message);
        throw err;
      }
    },

    async logout() {
      this.clearMessages();
      try {
        if (this.token) {
          await this.request('/api/me/logout-event', {
            method: 'POST',
            headers: this.authHeaders(),
            body: JSON.stringify({ eventId: this.loginEventId })
          });
        }
      } catch (e) {
        console.error('Failed to safely track backend logout: ', e);
      }
      this.token = '';
      this.loginEventId = null;
      await signOut(auth);
    },

    authHeaders() {
      return { 'Content-Type': 'application/json', Authorization: `Bearer ${this.token}` };
    },

    async request(path, options = {}) {
      const response = await fetch(`${this.apiBase}${path}`, options);
      const data = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(data.error || `Request failed (${response.status})`);
      return data;
    },

    async runAction(fn, okMessage) {
      this.clearMessages();
      try {
        await fn();
        if (okMessage) this.setSuccess(okMessage);
      } catch (err) {
        this.setError(err.message);
      }
    },

    setSuccess(message) {
      this.success = message;
      this.error = '';
    },

    setError(message) {
      this.error = message;
      this.success = '';
    },

    clearMessages() {
      this.success = '';
      this.error = '';
    },
  }
});
