import type { Handler } from '@netlify/functions';
import { requireUser, supabaseAdmin } from './_supabase';

const DEFAULT_BASE_URL = ['https://', 'api.', 'venice', '.ai', '/api', '/v1'].join('');
const BASE_URL = process.env.VENICE_BASE_URL || DEFAULT_BASE_URL;
const DEFAULT_MODEL = process.env.VENICE_IMAGE_MODEL || 'z-image-turbo';

const MODEL_ALIASES: Record<string, string> = {
  sdxl: 'z-image-turbo',
  'stable-diffusion-xl': 'z-image-turbo'
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

const mimeFor = (format?: string) => {
  const fmt = (format || 'webp').toLowerCase();
  if (fmt === 'png') return 'image/png';
  if (fmt === 'jpg' || fmt === 'jpeg') return 'image/jpeg';
  return 'image/webp';
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

  const prompt = payload.prompt;
  if (!prompt) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Missing prompt.' }) };
  }

  const model = MODEL_ALIASES[payload.model] || payload.model || DEFAULT_MODEL;
  const width = payload.width || 1024;
  const height = payload.height || 1024;
  const format = payload.format || 'webp';

  try {
    const { user } = await requireUser(event);
    const plan = await getPlan(user.id);
    const limits = PLAN_LIMITS[plan] || PLAN_LIMITS.free;
    const monthKey = getMonthKey();
    const usage = await ensureUsage(user.id, monthKey);

    if (usage.image_count >= limits.image) {
      return { statusCode: 402, body: JSON.stringify({ error: 'Image usage limit reached.' }) };
    }

    const response = await fetch(`${BASE_URL}/image/generate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify({ model, prompt, width, height, format })
    });

    const data = await response.json();
    if (!response.ok) {
      return {
        statusCode: response.status,
        body: JSON.stringify({ error: data?.error || data })
      };
    }

    const imageBase64 = data?.images?.[0];
    if (!imageBase64) {
      return { statusCode: 500, body: JSON.stringify({ error: 'No image returned from Venice.' }) };
    }

    if (!supabaseAdmin) throw new Error('Supabase admin not configured.');
    await supabaseAdmin
      .from('usage_monthly')
      .update({ image_count: usage.image_count + 1 })
      .eq('user_id', user.id)
      .eq('month_key', monthKey);

    const imageUrl = `data:${mimeFor(format)};base64,${imageBase64}`;
    return {
      statusCode: 200,
      body: JSON.stringify({ image_url: imageUrl, model: data?.model || model })
    };
  } catch (err: any) {
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }
};
