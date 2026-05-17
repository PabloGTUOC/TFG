import { ref } from 'vue';
import { getToken, onMessage } from 'firebase/messaging';
import { getFirebaseMessaging } from '../firebase';
import { useAuthStore } from '../stores/auth';

const VAPID_KEY = import.meta.env.VITE_FIREBASE_VAPID_KEY;

let currentToken = null;

export function useNotifications() {
  const authStore = useAuthStore();
  const permission = ref(typeof Notification !== 'undefined' ? Notification.permission : 'denied');

  async function enable() {
    const messaging = await getFirebaseMessaging();
    if (!messaging) return;

    const result = await Notification.requestPermission();
    permission.value = result;
    if (result !== 'granted') return;

    try {
      const token = await getToken(messaging, { vapidKey: VAPID_KEY });
      if (token && token !== currentToken) {
        currentToken = token;
        await authStore.request('/api/me/fcm-token', {
          method: 'POST',
          headers: authStore.authHeaders(),
          body: JSON.stringify({ token }),
        });
      }

      // Handle foreground messages (app is open)
      onMessage(messaging, (payload) => {
        const { title, body } = payload.notification || {};
        if (title && Notification.permission === 'granted') {
          new Notification(title, { body, icon: '/icon-192.png', badge: '/icon-192.png' });
        }
      });
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
    } catch (err) {
      console.error('FCM disable error:', err);
    }
  }

  return { permission, enable, disable };
}
