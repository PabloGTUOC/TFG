import { createApp } from 'vue';
import { createPinia } from 'pinia';
import { registerSW } from 'virtual:pwa-register';
import router from './router';
import App from './App.vue';
import { useAuthStore } from './stores/auth';
import './style.css';

registerSW({ immediate: true });

const app = createApp(App);
app.use(createPinia());

// Start auth listener immediately
useAuthStore().initAuthListener();

app.use(router);
app.mount('#app');
