import { setActivePinia, createPinia } from 'pinia';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { useAuthStore } from '../auth';

// Mock Firebase
vi.mock('../../firebase', () => ({
  auth: {}
}));

vi.mock('firebase/auth', () => ({
  signInWithEmailAndPassword: vi.fn(),
  createUserWithEmailAndPassword: vi.fn(),
  signOut: vi.fn(),
  onIdTokenChanged: vi.fn(),
  GoogleAuthProvider: vi.fn(),
  signInWithPopup: vi.fn(),
}));

// Mock family store
vi.mock('../family', () => ({
  useFamilyStore: vi.fn(() => ({
    fetchUserData: vi.fn().mockResolvedValue(),
    $reset: vi.fn(),
  }))
}));

describe('Auth Store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('initializes with default state', () => {
    const store = useAuthStore();
    expect(store.user).toBeNull();
    expect(store.token).toBe('');
    expect(store.authReady).toBe(false);
  });

  it('sets success message correctly', () => {
    const store = useAuthStore();
    store.setSuccess('Success!');
    expect(store.success).toBe('Success!');
    expect(store.error).toBe('');
  });

  it('sets error message correctly', () => {
    const store = useAuthStore();
    store.setError('Error!');
    expect(store.error).toBe('Error!');
    expect(store.success).toBe('');
  });

  it('clears messages', () => {
    const store = useAuthStore();
    store.setSuccess('Success!');
    store.clearMessages();
    expect(store.success).toBe('');
    expect(store.error).toBe('');
  });

  it('authHeaders returns proper headers', () => {
    const store = useAuthStore();
    store.token = 'dummy-token';
    const headers = store.authHeaders();
    expect(headers).toEqual({
      'Content-Type': 'application/json',
      Authorization: 'Bearer dummy-token'
    });
  });
});
