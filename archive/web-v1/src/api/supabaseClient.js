import { createClient } from '@supabase/supabase-js';
import { getEnv } from '../config/env.js';

const supabaseUrl = getEnv('SUPABASE_URL');
const supabaseAnonKey = getEnv('SUPABASE_ANON_KEY');

export const isConfigured = Boolean(supabaseUrl && supabaseAnonKey);
export const supabase = isConfigured
  ? createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: true,
        detectSessionInUrl: true
      }
    })
  : null;
