import type { Handler } from '@netlify/functions';
import Stripe from 'stripe';
import { supabaseAdmin } from './_supabase';

const stripeSecret = process.env.STRIPE_SECRET_KEY || '';
const stripeWebhookSecret = process.env.STRIPE_WEBHOOK_SECRET || '';
const stripe = stripeSecret ? new Stripe(stripeSecret, { apiVersion: '2023-10-16' }) : null;

const PRO_PRICE_ID = process.env.STRIPE_PRO_PRICE_ID || '';
const TEAM_PRICE_ID = process.env.STRIPE_TEAM_PRICE_ID || '';

const planFromPrice = (priceId?: string | null) => {
  if (!priceId) return null;
  if (priceId === PRO_PRICE_ID) return 'pro';
  if (priceId === TEAM_PRICE_ID) return 'team';
  return null;
};

const updateProfileByUserId = async (userId: string, updates: Record<string, any>) => {
  if (!supabaseAdmin) throw new Error('Supabase admin not configured.');
  return supabaseAdmin.from('profiles').update({ ...updates, updated_at: new Date().toISOString() }).eq('id', userId);
};

const updateProfileByCustomer = async (customerId: string, updates: Record<string, any>) => {
  if (!supabaseAdmin) throw new Error('Supabase admin not configured.');
  return supabaseAdmin
    .from('profiles')
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq('stripe_customer_id', customerId);
};

const findProfileByCustomer = async (customerId: string) => {
  if (!supabaseAdmin) throw new Error('Supabase admin not configured.');
  const { data, error } = await supabaseAdmin
    .from('profiles')
    .select('id')
    .eq('stripe_customer_id', customerId)
    .maybeSingle();
  if (error) throw error;
  return data?.id || null;
};

export const handler: Handler = async (event) => {
  if (!stripe || !stripeWebhookSecret) {
    return { statusCode: 500, body: JSON.stringify({ error: 'Stripe webhook not configured.' }) };
  }

  const sig = event.headers['stripe-signature'] || event.headers['Stripe-Signature'];
  if (!sig) return { statusCode: 400, body: 'Missing Stripe signature.' };

  const rawBody = event.isBase64Encoded
    ? Buffer.from(event.body || '', 'base64')
    : Buffer.from(event.body || '', 'utf8');

  let stripeEvent: Stripe.Event;
  try {
    stripeEvent = stripe.webhooks.constructEvent(rawBody, sig, stripeWebhookSecret);
  } catch (err: any) {
    return { statusCode: 400, body: `Webhook Error: ${err.message}` };
  }

  try {
    if (stripeEvent.type === 'checkout.session.completed') {
      const session = stripeEvent.data.object as Stripe.Checkout.Session;
      const userId = session.metadata?.userId || session.client_reference_id || null;
      const plan = session.metadata?.plan || null;
      const customerId = typeof session.customer === 'string' ? session.customer : null;
      const subscriptionId = typeof session.subscription === 'string' ? session.subscription : null;

      if (userId) {
        await updateProfileByUserId(userId, {
          plan: plan || 'pro',
          stripe_customer_id: customerId,
          stripe_subscription_id: subscriptionId
        });
      }
    }

    if (stripeEvent.type === 'customer.subscription.updated' || stripeEvent.type === 'customer.subscription.deleted') {
      const subscription = stripeEvent.data.object as Stripe.Subscription;
      const customerId = typeof subscription.customer === 'string' ? subscription.customer : null;
      const subscriptionId = subscription.id;
      const priceId = subscription.items?.data?.[0]?.price?.id || null;
      const plan = planFromPrice(priceId);
      const status = subscription.status;

      if (customerId) {
        const userId = await findProfileByCustomer(customerId);
        if (userId) {
          const nextPlan = (stripeEvent.type === 'customer.subscription.deleted' || status !== 'active') ? 'free' : (plan || 'free');
          await updateProfileByUserId(userId, {
            plan: nextPlan,
            stripe_customer_id: customerId,
            stripe_subscription_id: subscriptionId
          });
        } else {
          const nextPlan = (stripeEvent.type === 'customer.subscription.deleted' || status !== 'active') ? 'free' : (plan || 'free');
          await updateProfileByCustomer(customerId, {
            plan: nextPlan,
            stripe_subscription_id: subscriptionId
          });
        }
      }
    }

    return { statusCode: 200, body: JSON.stringify({ received: true }) };
  } catch (err: any) {
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }
};
