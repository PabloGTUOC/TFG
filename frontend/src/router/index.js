import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useFamilyStore } from '../stores/family'
import LoginView from '../views/LoginView.vue'
import SettingsView from '../views/SettingsView.vue'
import ProfileView from '../views/ProfileView.vue'
import ActivitiesView from '../views/ActivitiesView.vue'
import DashboardView from '../views/DashboardView.vue'
import DailyView from '../views/DailyView.vue'
import MarketplaceView from '../views/MarketplaceView.vue'
import OnboardingView from '../views/OnboardingView.vue'
import StatsView from '../views/StatsView.vue'
import JoinView from '../views/JoinView.vue'

const router = createRouter({
    history: createWebHistory(import.meta.env.BASE_URL),
    routes: [
        { path: '/login', name: 'login', component: LoginView, meta: { guest: true } },
        { path: '/join', name: 'join', component: JoinView, meta: { requiresAuth: true } },
        { path: '/onboarding', name: 'onboarding', component: OnboardingView, meta: { requiresAuth: true } },
        { path: '/settings', name: 'settings', component: SettingsView, meta: { requiresAuth: true } },
        { path: '/profile', name: 'profile', component: ProfileView, meta: { requiresAuth: true } },
        { path: '/activities', name: 'activities', component: ActivitiesView, meta: { requiresAuth: true } },
        { path: '/dashboard', name: 'dashboard', component: DashboardView, meta: { requiresAuth: true } },
        { path: '/daily/:date', name: 'daily', component: DailyView, meta: { requiresAuth: true } },
        { path: '/marketplace', name: 'marketplace', component: MarketplaceView, meta: { requiresAuth: true } },
        { path: '/stats', name: 'stats', component: StatsView, meta: { requiresAuth: true } },
        // Catch-all
        { path: '/:pathMatch(.*)*', redirect: '/dashboard' }
    ]
});

router.beforeEach(async (to, from, next) => {
    const authStore = useAuthStore();
    const familyStore = useFamilyStore();

    await authStore.waitForAuth();

    const isAuthenticated = !!authStore.user;

    if (to.meta.requiresAuth && !isAuthenticated) {
        // Preserve the destination so we can return after login
        sessionStorage.setItem('returnUrl', to.fullPath);
        next('/login');
    } else if (isAuthenticated) {
        const hasFamilies = familyStore.families && familyStore.families.length > 0;
        const noFamilyAllowed = ['onboarding', 'settings', 'profile', 'join'];

        if (!hasFamilies && !noFamilyAllowed.includes(to.name)) {
            next('/onboarding');
        } else if (to.meta.guest) {
            // After login, honour any stored return URL (e.g. /join?token=...)
            const returnUrl = sessionStorage.getItem('returnUrl');
            if (returnUrl) {
                sessionStorage.removeItem('returnUrl');
                next(returnUrl);
            } else {
                next(hasFamilies ? '/dashboard' : '/onboarding');
            }
        } else {
            next();
        }
    } else {
        next();
    }
});

export default router;
