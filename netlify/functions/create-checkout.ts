import type { Handler } from '@netlify/functions';
import Stripe from 'stripe';
import { requireUser } from './_supabase';

const stripeSecret = process.env.STRIPE_SECRET_KEY || '';
const stripe = stripeSecret ? new Stripe(stripeSecret, { apiVersion: '2023-10-16' }) : null;

const PRO_PRICE_ID = process.env.STRIPE_PRO_PRICE_ID || '';
const TEAM_PRICE_ID = process.env.STRIPE_TEAM_PRICE_ID || '';
const SITE_URL = process.env.SITE_URL || '';

export const handler: Handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  if (!stripe) {
    return { statusCode: 500, body: JSON.stringify({ error: 'Stripe is not configured.' }) };
  }

  let body: { plan?: string } = {};
  try {
    body = JSON.parse(event.body || '{}');
  } catch (err) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Invalid JSON body.' }) };
  }

  const plan = body.plan;
  if (plan !== 'pro' && plan !== 'team') {
    return { statusCode: 400, body: JSON.stringify({ error: 'Plan must be pro or team.' }) };
  }

  if (!SITE_URL) {
    return { statusCode: 500, body: JSON.stringify({ error: 'Missing SITE_URL.' }) };
  }

  const priceId = plan === 'pro' ? PRO_PRICE_ID : TEAM_PRICE_ID;
  if (!priceId) {
    return { statusCode: 500, body: JSON.stringify({ error: 'Missing Stripe price id.' }) };
  }

  try {
    const { user } = await requireUser(event);

    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [{ price: priceId, quantity: 1 }],
      allow_promotion_codes: true,
      success_url: `${SITE_URL}/?checkout=success`,
      cancel_url: `${SITE_URL}/?checkout=cancel`,
      customer_email: user.email || undefined,
      client_reference_id: user.id,
      metadata: { userId: user.id, plan },
      subscription_data: { metadata: { userId: user.id, plan } }
    });

    return {
      statusCode: 200,
      body: JSON.stringify({ url: session.url })
    };
  } catch (err: any) {
    return { statusCode: 401, body: JSON.stringify({ error: err.message }) };
  }
};
