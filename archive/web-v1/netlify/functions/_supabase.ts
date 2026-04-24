import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || '';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

export const supabaseAnon = supabaseUrl && supabaseAnonKey
  ? createClient(supabaseUrl, supabaseAnonKey)
  : null;

export const supabaseAdmin = supabaseUrl && supabaseServiceKey
  ? createClient(supabaseUrl, supabaseServiceKey)
  : null;

export const getAuthToken = (event: { headers: Record<string, string | undefined> }) => {
  const auth = event.headers['authorization'] || event.headers['Authorization'];
  if (!auth) return null;
  const parts = auth.split(' ');
  if (parts.length !== 2) return null;
  return parts[1];
};

export const requireUser = async (event: { headers: Record<string, string | undefined> }) => {
  if (!supabaseAnon) throw new Error('Supabase is not configured.');
  const token = getAuthToken(event);
  if (!token) throw new Error('Missing Authorization token.');
  const { data, error } = await supabaseAnon.auth.getUser(token);
  if (error || !data?.user) throw new Error('Invalid session.');
  return { user: data.user, token };
};
