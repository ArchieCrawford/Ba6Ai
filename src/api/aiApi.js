import { supabase } from './supabaseClient.js';

const requireSupabase = () => {
  if (!supabase) throw new Error('Supabase is not configured.');
};

export const aiApi = {
  getModels: async () => {
    return [
      { id: 'llama-3-70b', name: 'Llama 3 70B', type: 'text' },
      { id: 'llama-3-8b', name: 'Llama 3 8B', type: 'text' },
      { id: 'stable-diffusion-xl', name: 'SDXL', type: 'image' }
    ];
  },

  chat: async (conversationId, message, model) => {
    requireSupabase();
    const { data: { user } } = await supabase.auth.getUser();

    await supabase.from('messages').insert({ conversation_id: conversationId, role: 'user', content: message });

    const monthKey = new Date().toISOString().substring(0, 7);
    await supabase.rpc('increment_text_usage', { user_id_param: user.id, month_key_param: monthKey });

    const response = await fetch('/.netlify/functions/venice-chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
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

    const monthKey = new Date().toISOString().substring(0, 7);
    await supabase.rpc('increment_image_usage', { user_id_param: user.id, month_key_param: monthKey });

    const response = await fetch('/.netlify/functions/venice-image', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
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
