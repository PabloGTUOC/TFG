import { ref } from 'vue';
import { getToken, onMessage } from 'firebase/messaging';
import { getFirebaseMessaging } from '../firebase';
import { useAuthStore } from '../stores/auth';
import { useRouter } from 'vue-router';

const VAPID_KEY = import.meta.env.VITE_FIREBASE_VAPID_KEY;

let currentToken = null;
let foregroundListenerActive = false;

export function useNotifications() {
  const authStore = useAuthStore();
  const router = useRouter();
  const permission = ref(typeof Notification !== 'undefined' ? Notification.permission : 'denied');

  async function upsertToken(messaging) {
    const token = await getToken(messaging, { vapidKey: VAPID_KEY });
    if (token && token !== currentToken) {
      currentToken = token;
      await authStore.request('/api/me/fcm-token', {
        method: 'POST',
        headers: authStore.authHeaders(),
        body: JSON.stringify({ token }),
      });
    }
  }

  function setupForegroundListener(messaging) {
    if (foregroundListenerActive) return;
    foregroundListenerActive = true;
    onMessage(messaging, (payload) => {
      const { title, body } = payload.notification || {};
      const url = payload.data?.url;
      if (!title || Notification.permission !== 'granted') return;
      const n = new Notification(title, { body, icon: '/icon-192.png', badge: '/icon-192.png' });
      navigator.setAppBadge?.();
      n.onclick = () => { window.focus(); navigator.clearAppBadge?.(); if (url) router.push(url); };
    });
  }

  // Call on app startup: silently refreshes token if permission already granted
  async function init() {
    permission.value = typeof Notification !== 'undefined' ? Notification.permission : 'denied';
    if (permission.value !== 'granted') return;

    const messaging = await getFirebaseMessaging();
    if (!messaging) return;
    try {
      await upsertToken(messaging);
      setupForegroundListener(messaging);
    } catch (err) {
      console.error('FCM init error:', err);
    }
  }

  async function enable() {
    const messaging = await getFirebaseMessaging();
    if (!messaging) return;

    const result = await Notification.requestPermission();
    permission.value = result;
    if (result !== 'granted') return;

    try {
      await upsertToken(messaging);
      setupForegroundListener(messaging);
    } catch (err) {
      console.error('FCM token error:', err);
    }
  }

  async function disable() {
    if (!currentToken) return;
    try {
      await authStore.request('/api/me/fcm-token', {
        method: 'DELETE',
        headers: authStore.authHeaders(),
        body: JSON.stringify({ token: currentToken }),
      });
      currentToken = null;
      foregroundListenerActive = false;
    } catch (err) {
      console.error('FCM disable error:', err);
    }
  }

  return { permission, init, enable, disable };
}
