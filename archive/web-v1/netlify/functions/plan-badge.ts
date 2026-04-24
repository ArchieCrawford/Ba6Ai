import type { Handler } from '@netlify/functions';
import { Resvg } from '@resvg/resvg-js';
import { supabaseAdmin } from './_supabase';

const PRO_PRICE_ID = process.env.STRIPE_PRO_PRICE_ID || '';
const TEAM_PRICE_ID = process.env.STRIPE_TEAM_PRICE_ID || '';

const LIMITS: Record<string, { text: number; image: number }> = {
  free: { text: 25, image: 5 },
  pro: { text: 1000, image: 250 },
  team: { text: 5000, image: 1000 }
};

const ACTIVE_STATUSES = new Set(['active', 'trialing', 'past_due']);

const resolvePlanFromSubscription = (subscription: any, fallback = 'free') => {
  if (!subscription) return fallback;
  const status = String(subscription.subscription_status || '').toLowerCase();
  if (!ACTIVE_STATUSES.has(status)) return fallback;
  if (TEAM_PRICE_ID && subscription.price_id === TEAM_PRICE_ID) return 'team';
  if (PRO_PRICE_ID && subscription.price_id === PRO_PRICE_ID) return 'pro';
  return fallback;
};

const escapeText = (value: string) =>
  value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const buildSvg = (plan: string, usage: { text: number; image: number }, handle?: string) => {
  const limits = LIMITS[plan] || LIMITS.free;
  const safePlan = escapeText(plan.toUpperCase());
  const safeHandle = handle ? `@${escapeText(handle)}` : '';

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg width="1200" height="630" viewBox="0 0 1200 630" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#050505" />
      <stop offset="50%" stop-color="#0b0b0b" />
      <stop offset="100%" stop-color="#111111" />
    </linearGradient>
    <linearGradient id="accent" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#00e0ff" />
      <stop offset="100%" stop-color="#9b7bff" />
    </linearGradient>
  </defs>
  <rect width="1200" height="630" fill="url(#bg)" />
  <rect x="70" y="90" width="1060" height="450" rx="36" fill="#0a0a0a" stroke="#202020" stroke-width="2" />
  <text x="130" y="190" fill="#ffffff" font-family="Arial, sans-serif" font-size="48" font-weight="700">BA6 AI</text>
  <text x="130" y="255" fill="url(#accent)" font-family="Arial, sans-serif" font-size="30" font-weight="600">${safePlan} PLAN</text>
  ${safeHandle ? `<text x="130" y="305" fill="#9ca3af" font-family="Arial, sans-serif" font-size="22">${safeHandle}</text>` : ''}
  <text x="130" y="380" fill="#e5e7eb" font-family="Arial, sans-serif" font-size="26">Text: ${usage.text}/${limits.text}</text>
  <text x="130" y="430" fill="#e5e7eb" font-family="Arial, sans-serif" font-size="26">Images: ${usage.image}/${limits.image}</text>
  <text x="130" y="490" fill="#6b7280" font-family="Arial, sans-serif" font-size="18">Usage resets monthly</text>
</svg>`;
};

export const handler: Handler = async (event) => {
  const query = event.queryStringParameters || {};
  const format = String(query.format || 'svg').toLowerCase();
  const fid = query.fid ? String(query.fid) : null;
  let userId = query.userId ? String(query.userId) : null;

  let plan = 'free';
  let handle: string | undefined;
  let usage = { text: 0, image: 0 };

  if (supabaseAdmin) {
    try {
      let profile: any = null;

      if (!userId && fid) {
        const { data } = await supabaseAdmin
          .from('profiles')
          .select('id, plan, farcaster_username')
          .eq('farcaster_fid', fid)
          .maybeSingle();
        if (data) {
          profile = data;
          userId = data.id;
        }
      }

      if (userId && !profile) {
        const { data } = await supabaseAdmin
          .from('profiles')
          .select('id, plan, farcaster_username')
          .eq('id', userId)
          .maybeSingle();
        if (data) profile = data;
      }

      if (profile) {
        plan = (profile.plan || 'free').toLowerCase();
        handle = profile.farcaster_username || undefined;
      }

      if (userId) {
        const { data: subscription } = await supabaseAdmin
          .from('subscription_status_all')
          .select('user_id, price_id, subscription_status')
          .eq('user_id', userId)
          .maybeSingle();
        if (subscription) plan = resolvePlanFromSubscription(subscription, plan);

        const monthKey = new Date().toISOString().slice(0, 7);
        const { data: usageRow } = await supabaseAdmin
          .from('usage_monthly')
          .select('text_count, image_count')
          .eq('user_id', userId)
          .eq('month_key', monthKey)
          .maybeSingle();
        if (usageRow) {
          usage = {
            text: usageRow.text_count || 0,
            image: usageRow.image_count || 0
          };
        }
      }
    } catch (err) {
      // Fall back to default badge.
    }
  }

  const svg = buildSvg(plan, usage, handle);

  if (format === 'png') {
    const resvg = new Resvg(svg, { fitTo: { mode: 'width', value: 1200 } });
    const pngData = resvg.render().asPng();
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'image/png',
        'Cache-Control': 'no-store'
      },
      body: pngData.toString('base64'),
      isBase64Encoded: true
    };
  }

  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'image/svg+xml; charset=utf-8',
      'Cache-Control': 'no-store'
    },
    body: svg
  };
};
