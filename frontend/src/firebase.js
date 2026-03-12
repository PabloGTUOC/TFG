import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
    apiKey: import.meta.env.VITE_FIREBASE_API_KEY || "AIzaSy_mock_api_key_for_dev_change_me",
    authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || "carecoins-dev.firebaseapp.com",
    projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || "carecoins-dev",
    storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET || "carecoins-dev.appspot.com",
    messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || "123456789",
    appId: import.meta.env.VITE_FIREBASE_APP_ID || "1:123456789:web:abcdef"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
