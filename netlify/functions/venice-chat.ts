import type { Handler } from '@netlify/functions';
import { requireUser, supabaseAdmin } from './_supabase';

const DEFAULT_BASE_URL = ['https://', 'api.', 'venice', '.ai', '/api', '/v1'].join('');
const BASE_URL = process.env.VENICE_BASE_URL || DEFAULT_BASE_URL;
const DEFAULT_MODEL = process.env.VENICE_CHAT_MODEL || 'venice-uncensored';

const MODEL_ALIASES: Record<string, string> = {
  'llama-3-8b': DEFAULT_MODEL,
  'llama-3-70b': DEFAULT_MODEL
};

const PLAN_LIMITS: Record<string, { text: number; image: number }> = {
  free: { text: 25, image: 5 },
  pro: { text: 1000, image: 250 },
  team: { text: 5000, image: 1000 }
};

const getMonthKey = () => new Date().toISOString().slice(0, 7);

const ensureUsage = async (userId: string, monthKey: string) => {
  if (!supabaseAdmin) throw new Error('Supabase admin not configured.');
  const { data, error } = await supabaseAdmin
    .from('usage_monthly')
    .select('text_count, image_count')
    .eq('user_id', userId)
    .eq('month_key', monthKey)
    .maybeSingle();
  if (error) throw error;
  if (data) return data;

  const { error: insertError } = await supabaseAdmin
    .from('usage_monthly')
    .insert({ user_id: userId, month_key: monthKey, text_count: 0, image_count: 0 });
  if (insertError) throw insertError;
  return { text_count: 0, image_count: 0 };
};

const getPlan = async (userId: string) => {
  if (!supabaseAdmin) throw new Error('Supabase admin not configured.');
  const { data, error } = await supabaseAdmin
    .from('profiles')
    .select('plan')
    .eq('id', userId)
    .maybeSingle();
  if (error) throw error;
  return (data?.plan || 'free').toLowerCase();
};

export const handler: Handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  const apiKey = process.env.VENICE_API_KEY;
  if (!apiKey) {
    return { statusCode: 500, body: JSON.stringify({ error: 'Missing VENICE_API_KEY.' }) };
  }

  let payload: any = {};
  try {
    payload = JSON.parse(event.body || '{}');
  } catch (err) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Invalid JSON body.' }) };
  }

  const model = MODEL_ALIASES[payload.model] || payload.model || DEFAULT_MODEL;
  const messages = Array.isArray(payload.messages) && payload.messages.length
    ? payload.messages
    : (payload.message ? [{ role: 'user', content: payload.message }] : []);

  if (!messages.length) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Missing message.' }) };
  }

  try {
    const { user } = await requireUser(event);
    const plan = await getPlan(user.id);
    const limits = PLAN_LIMITS[plan] || PLAN_LIMITS.free;
    const monthKey = getMonthKey();
    const usage = await ensureUsage(user.id, monthKey);

    if (usage.text_count >= limits.text) {
      return { statusCode: 402, body: JSON.stringify({ error: 'Text usage limit reached.' }) };
    }

    const response = await fetch(`${BASE_URL}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify({ model, messages })
    });

    const data = await response.json();
    if (!response.ok) {
      return {
        statusCode: response.status,
        body: JSON.stringify({ error: data?.error || data })
      };
    }

    if (!supabaseAdmin) throw new Error('Supabase admin not configured.');
    await supabaseAdmin
      .from('usage_monthly')
      .update({ text_count: usage.text_count + 1 })
      .eq('user_id', user.id)
      .eq('month_key', monthKey);

    const content = data?.choices?.[0]?.message?.content || '';
    return {
      statusCode: 200,
      body: JSON.stringify({
        content,
        model: data?.model || model,
        usage: data?.usage || null
      })
    };
  } catch (err: any) {
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }
};
