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

    const assistantMessage = `This is a mock response from ${model}. In a real deployment, this would be fetched from Venice AI via a secure server route.`;

    const { data } = await supabase.from('messages')
      .insert({ conversation_id: conversationId, role: 'assistant', content: assistantMessage })
      .select().single();

    return data;
  },

  generateImage: async (prompt, model) => {
    requireSupabase();
    const { data: { user } } = await supabase.auth.getUser();

    const monthKey = new Date().toISOString().substring(0, 7);
    await supabase.rpc('increment_image_usage', { user_id_param: user.id, month_key_param: monthKey });

    const imageUrl = `https://api.dicebear.com/7.x/shapes/svg?seed=${encodeURIComponent(prompt)}`;

    const { data } = await supabase.from('generations')
      .insert({ user_id: user.id, prompt, image_url: imageUrl, model })
      .select().single();

    return data;
  }
};
