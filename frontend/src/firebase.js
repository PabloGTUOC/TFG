import { initializeApp } from 'firebase/app';
import { initializeAuth, getAuth, connectAuthEmulator, browserLocalPersistence, indexedDBLocalPersistence } from 'firebase/auth';
import { getMessaging, isSupported } from 'firebase/messaging';

const firebaseConfig = {
    apiKey: import.meta.env.VITE_FIREBASE_API_KEY || "AIzaSy_mock_api_key_for_dev_change_me",
    authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || "carecoins-dev.firebaseapp.com",
    projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || "carecoins-dev",
    storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET || "carecoins-dev.appspot.com",
    messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || "123456789",
    appId: import.meta.env.VITE_FIREBASE_APP_ID || "1:123456789:web:abcdef"
};

const app = initializeApp(firebaseConfig);

// In emulator mode use localStorage so Playwright storageState() can capture the token.
// In production keep the default (indexedDB) for better security.
export const auth = import.meta.env.VITE_USE_EMULATOR === 'true'
  ? initializeAuth(app, { persistence: browserLocalPersistence })
  : getAuth(app);

if (import.meta.env.VITE_USE_EMULATOR === 'true') {
  connectAuthEmulator(auth, 'http://localhost:9099', { disableWarnings: true });
}

export async function getFirebaseMessaging() {
  if (!(await isSupported())) return null;
  return getMessaging(app);
}
