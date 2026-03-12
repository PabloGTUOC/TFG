import { defineStore } from 'pinia';

export const useAppStore = defineStore('app', {
  state: () => ({
    apiBase: 'http://localhost:3000',
    token: '',
    success: '',
    error: ''
  }),
  actions: {
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
    }
  }
});
