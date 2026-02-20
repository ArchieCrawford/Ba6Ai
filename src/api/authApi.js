import { supabase, isConfigured } from './supabaseClient.js';

const requireSupabase = () => {
  if (!supabase) throw new Error('Supabase is not configured.');
};

export const authApi = {
  isConfigured: () => isConfigured,
  signUp: (email, password, displayName) => {
    requireSupabase();
    return supabase.auth.signUp({ email, password, options: { data: { display_name: displayName } } });
  },
  signIn: (email, password) => {
    requireSupabase();
    return supabase.auth.signInWithPassword({ email, password });
  },
  signOut: () => {
    requireSupabase();
    return supabase.auth.signOut();
  },
  getUser: () => {
    requireSupabase();
    return supabase.auth.getUser();
  },
  getSession: () => {
    requireSupabase();
    return supabase.auth.getSession();
  },
  onAuthStateChange: (callback) => {
    if (!supabase) {
      return { data: { subscription: { unsubscribe: () => {} } } };
    }
    return supabase.auth.onAuthStateChange(callback);
  }
};
