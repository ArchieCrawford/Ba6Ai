import { supabase } from './supabaseClient.js';

const requireSupabase = () => {
  if (!supabase) throw new Error('Supabase is not configured.');
};

export const aiApi = {
  getModels: async () => {
    const fallback = [
      { id: 'venice-uncensored', name: 'Venice Uncensored 1.1', type: 'text' },
      { id: 'qwen3-4b', name: 'Venice Small', type: 'text' },
      { id: 'mistral-31-24b', name: 'Venice Medium', type: 'text' },
      { id: 'z-image-turbo', name: 'Z-Image Turbo', type: 'image' }
    ];

    try {
      const response = await fetch('/.netlify/functions/venice-models');
      if (!response.ok) return fallback;
      const models = await response.json();
      if (!Array.isArray(models) || models.length === 0) return fallback;
      return models;
    } catch (err) {
      return fallback;
    }
  },

  chat: async (conversationId, message, model) => {
    requireSupabase();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('Not signed in.');
    if (!conversationId) throw new Error('Missing conversation id.');

    await supabase.from('messages').insert({ conversation_id: conversationId, role: 'user', content: message });

    const { data: { session } } = await supabase.auth.getSession();
    const accessToken = session?.access_token || '';

    const response = await fetch('/.netlify/functions/venice-chat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': accessToken ? `Bearer ${accessToken}` : ''
      },
      body: JSON.stringify({ message, model })
    });

    if (!response.ok) {
      const errorBody = await response.json().catch(() => ({}));
      throw new Error(errorBody?.error || 'Venice chat request failed.');
    }

    const data = await response.json();
    const assistantMessage = data?.content || 'No response content returned.';

    const { data: saved } = await supabase.from('messages')
      .insert({ conversation_id: conversationId, role: 'assistant', content: assistantMessage })
      .select().single();

    return saved;
  },

  generateImage: async (prompt, model) => {
    requireSupabase();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('Not signed in.');

    const { data: { session } } = await supabase.auth.getSession();
    const accessToken = session?.access_token || '';

    const response = await fetch('/.netlify/functions/venice-image', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': accessToken ? `Bearer ${accessToken}` : ''
      },
      body: JSON.stringify({ prompt, model })
    });

    if (!response.ok) {
      const errorBody = await response.json().catch(() => ({}));
      throw new Error(errorBody?.error || 'Venice image request failed.');
    }

    const data = await response.json();
    const imageUrl = data?.image_url || '';
    if (!imageUrl) throw new Error('No image returned from Venice.');

    const { data: saved } = await supabase.from('generations')
      .insert({ user_id: user.id, prompt, image_url: imageUrl, model })
      .select().single();

    return saved;
  }
};
