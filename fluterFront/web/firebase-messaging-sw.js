/* Firebase Cloud Messaging service worker for the Flutter web build.
 * Handles background push while the app tab is closed or unfocused.
 * Config mirrors lib/firebase_options.dart (web). */
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAvzOHlhLnUpDxQKQPqj4H_cpmECpNiEO4',
  appId: '1:1088534743968:web:6933bcab8c61fc8bd7f2c5',
  messagingSenderId: '1088534743968',
  projectId: 'tfg-carecoins',
  authDomain: 'tfg-carecoins.firebaseapp.com',
  storageBucket: 'tfg-carecoins.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification || {};
  if (!title) return;
  self.registration.showNotification(title, {
    body,
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    data: { url: payload.data && payload.data.url },
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      if (list.length > 0) return list[0].focus();
      return clients.openWindow('/');
    })
  );
});
