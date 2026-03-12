import { createRouter, createWebHistory } from 'vue-router'
import { useAppStore } from '../stores/app'
import LoginView from '../views/LoginView.vue'
import SettingsView from '../views/SettingsView.vue'
import ProfileView from '../views/ProfileView.vue'
import FamiliesView from '../views/FamiliesView.vue'
import ActivitiesView from '../views/ActivitiesView.vue'
import DashboardView from '../views/DashboardView.vue'
import MarketplaceView from '../views/MarketplaceView.vue'

const router = createRouter({
    history: createWebHistory(import.meta.env.BASE_URL),
    routes: [
        { path: '/login', name: 'login', component: LoginView, meta: { guest: true } },
        { path: '/', name: 'settings', component: SettingsView, meta: { requiresAuth: true } },
        { path: '/profile', name: 'profile', component: ProfileView, meta: { requiresAuth: true } },
        { path: '/families', name: 'families', component: FamiliesView, meta: { requiresAuth: true } },
        { path: '/activities', name: 'activities', component: ActivitiesView, meta: { requiresAuth: true } },
        { path: '/dashboard', name: 'dashboard', component: DashboardView, meta: { requiresAuth: true } },
        { path: '/marketplace', name: 'marketplace', component: MarketplaceView, meta: { requiresAuth: true } },
        // Catch-all
        { path: '/:pathMatch(.*)*', redirect: '/dashboard' }
    ]
});

router.beforeEach(async (to, from, next) => {
    const store = useAppStore();

    // Wait for Firebase to initialize its listen state
    if (!store.authReady) {
        await new Promise(resolve => {
            const wait = setInterval(() => {
                if (store.authReady) {
                    clearInterval(wait);
                    resolve();
                }
            }, 50);
        });
    }

    const isAuthenticated = !!store.user;

    if (to.meta.requiresAuth && !isAuthenticated) {
        next('/login');
    } else if (to.meta.guest && isAuthenticated) {
        next('/dashboard');
    } else {
        next();
    }
});

export default router;
