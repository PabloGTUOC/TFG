import { setActivePinia, createPinia } from 'pinia';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { useFamilyStore } from '../family';
import { useAuthStore } from '../auth';

// Mock Firebase
vi.mock('../../firebase', () => ({
  auth: {}
}));
vi.mock('firebase/auth', () => ({
  onIdTokenChanged: vi.fn(),
}));

describe('Family Store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('initializes with default state', () => {
    const store = useFamilyStore();
    expect(store.profile).toBeNull();
    expect(store.families).toEqual([]);
    expect(store.pendingRequests).toEqual([]);
    expect(store.actors).toEqual([]);
  });

  it('fetchUserData populates state correctly', async () => {
    const authStore = useAuthStore();
    
    // Setup mock responses
    authStore.authHeaders = vi.fn().mockReturnValue({});
    authStore.request = vi.fn().mockImplementation((url) => {
      if (url === '/api/me') {
        return Promise.resolve({
          user: { id: 1, name: 'Test User' },
          families: [{ id: 1, name: 'Test Family' }],
          pendingRequests: [{ id: 2, name: 'Pending Family' }],
          actors: [{ id: 1, name: 'Dog' }]
        });
      }
      if (url === '/api/me/login-event') {
        return Promise.resolve({ eventId: 'event-123' });
      }
      return Promise.resolve();
    });

    const store = useFamilyStore();
    await store.fetchUserData();

    expect(store.profile).toEqual({ id: 1, name: 'Test User' });
    expect(store.families).toEqual([{ id: 1, name: 'Test Family' }]);
    expect(store.pendingRequests).toEqual([{ id: 2, name: 'Pending Family' }]);
    expect(store.actors).toEqual([{ id: 1, name: 'Dog' }]);
    expect(authStore.loginEventId).toBe('event-123');
  });
});
