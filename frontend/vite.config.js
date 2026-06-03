import { defineConfig, loadEnv } from 'vite';
import fs from 'fs';
import vue from '@vitejs/plugin-vue';
import { VitePWA } from 'vite-plugin-pwa';

function buildFirebaseSW(env) {
  const config = {
    apiKey:            env.VITE_FIREBASE_API_KEY            || 'AIzaSyAvzOHlhLnUpDxQKQPqj4H_cpmECpNiEO4',
    authDomain:        env.VITE_FIREBASE_AUTH_DOMAIN        || 'tfg-carecoins.firebaseapp.com',
    projectId:         env.VITE_FIREBASE_PROJECT_ID         || 'tfg-carecoins',
    storageBucket:     env.VITE_FIREBASE_STORAGE_BUCKET     || 'tfg-carecoins.firebasestorage.app',
    messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID || '1088534743968',
    appId:             env.VITE_FIREBASE_APP_ID             || '1:1088534743968:web:6933bcab8c61fc8bd7f2c5',
  };

  return `importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp(${JSON.stringify(config, null, 2)});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification || {};
  if (!title) return;
  self.registration.showNotification(title, {
    body,
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    data: payload.data || {},
  });
  self.navigator?.setAppBadge?.();
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  self.navigator?.clearAppBadge?.();
  const url = event.notification.data?.url || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.navigate(url);
          return client.focus();
        }
      }
      return clients.openWindow(url);
    })
  );
});
`;
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');

  return {
    plugins: [
      vue(),
      {
        name: 'generate-firebase-sw',
        buildStart() {
          fs.writeFileSync('./public/firebase-messaging-sw.js', buildFirebaseSW(env));
        },
      },
      VitePWA({
        registerType: 'autoUpdate',
        includeAssets: ['favicon.svg'],
        manifest: {
          name: 'CareCoins',
          short_name: 'CareCoins',
          start_url: '/',
          display: 'standalone',
          background_color: '#F7F8FA',
          theme_color: '#2563EB',
          icons: [
            {
              src: '/icon-192.png',
              sizes: '192x192',
              type: 'image/png'
            },
            {
              src: '/icon-512.png',
              sizes: '512x512',
              type: 'image/png'
            },
            {
              src: '/icon-512.png',
              sizes: '512x512',
              type: 'image/png',
              purpose: 'maskable'
            }
          ]
        }
      })
    ],
    server: {
      host: true,
      port: 5173,
      strictPort: true,
      headers: {
        "Cross-Origin-Opener-Policy": "same-origin-allow-popups"
      }
    },
    test: {
      environment: 'jsdom',
      globals: true,
      pool: 'vmThreads',
      exclude: ['**/node_modules/**', 'e2e/**'],
    }
  };
});
