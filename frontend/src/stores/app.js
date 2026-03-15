import { defineStore } from 'pinia';
import { auth } from '../firebase';
import {
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut,
  onIdTokenChanged,
  GoogleAuthProvider,
  signInWithPopup
} from 'firebase/auth';

export const useAppStore = defineStore('app', {
  state: () => ({
    apiBase: import.meta.env.VITE_API_BASE || 'http://localhost:3000',
    user: null, // Firebase user object
    profile: null, // Backend profile
    families: [], // List of user's active families
    pendingRequests: [], // Families the user requested to join
    loginEventId: null, // Backend login event reference
    token: '',
    success: '',
    error: '',
    authReady: false // Wait for initial auth state before rendering logic
  }),
  actions: {
    async fetchUserData() {
      try {
        const data = await this.request('/api/me', { headers: this.authHeaders() });
        this.profile = data.user || null;
        this.families = data.families || [];
        this.pendingRequests = data.pendingRequests || [];

        if (!this.loginEventId) {
          const loginData = await this.request('/api/me/login-event', {
            method: 'POST',
            headers: this.authHeaders()
          });
          this.loginEventId = loginData.eventId;
        }
      } catch (e) {
        console.error("Backend auth sync failed", e);
      }
    },
    initAuthListener() {
      // Firebase automatically manages token refresh, so we listen to changes
      onIdTokenChanged(auth, async (user) => {
        this.user = user;
        if (user) {
          this.token = await user.getIdToken();
          await this.fetchUserData();
        } else {
          this.token = '';
          this.profile = null;
          this.families = [];
          this.loginEventId = null;
        }
        this.authReady = true;
      });
    },
    async login(email, password) {
      this.clearMessages();
      try {
        await signInWithEmailAndPassword(auth, email, password);
        this.setSuccess('Logged in successfully!');
      } catch (err) {
        this.setError(err.message);
        throw err;
      }
    },
    async register(email, password) {
      this.clearMessages();
      try {
        await createUserWithEmailAndPassword(auth, email, password);
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
        await signInWithPopup(auth, provider);
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
        console.error("Failed to safely track backend logout: ", e);
      }

      this.token = '';
      this.loginEventId = null;
      this.families = [];
      this.profile = null;
      await signOut(auth);
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
    }
  }
});
