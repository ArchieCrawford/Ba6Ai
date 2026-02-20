import { supabase } from './supabaseClient.js';

const requireSupabase = () => {
  if (!supabase) throw new Error('Supabase is not configured.');
};

const handleApiError = (error, tableName) => {
  if (error) {
    if (error.status === 404 || error.code === 'PGRST116') {
      return { error: `Table "${tableName}" not found. Please run the SQL migrations.` };
    }
    return { error: error.message };
  }
  return { error: null };
};

export const dbApi = {
  getProfile: async (userId) => {
    requireSupabase();
    const { data, error } = await supabase
      .from('profiles')
      .select('*, usage(*)')
      .eq('id', userId)
      .maybeSingle();
    return { data, error: handleApiError(error, 'profiles').error };
  },

  getConversations: async () => {
    requireSupabase();
    const { data, error } = await supabase
      .from('conversations')
      .select('*')
      .order('created_at', { ascending: false });
    return { data: data || [], error: handleApiError(error, 'conversations').error };
  },

  createConversation: async (title, model) => {
    requireSupabase();
    const { data: { user } } = await supabase.auth.getUser();
    const { data, error } = await supabase
      .from('conversations')
      .insert({ user_id: user.id, title, model })
      .select()
      .single();
    if (error) throw new Error(handleApiError(error, 'conversations').error);
    return data;
  },

  getMessages: async (conversationId) => {
    requireSupabase();
    const { data, error } = await supabase
      .from('messages')
      .select('*')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: true });
    return { data: data || [], error: handleApiError(error, 'messages').error };
  },

  getGenerations: async () => {
    requireSupabase();
    const { data, error } = await supabase
      .from('generations')
      .select('*')
      .order('created_at', { ascending: false });
    return { data: data || [], error: handleApiError(error, 'generations').error };
  }
};
