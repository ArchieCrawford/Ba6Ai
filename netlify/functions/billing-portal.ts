import type { Handler } from '@netlify/functions';
import Stripe from 'stripe';
import { requireUser, supabaseAdmin } from './_supabase';

const stripeSecret = process.env.STRIPE_SECRET_KEY || '';
const stripe = stripeSecret ? new Stripe(stripeSecret, { apiVersion: '2023-10-16' }) : null;
const SITE_URL = process.env.SITE_URL || '';

const getCustomerId = async (userId: string, email?: string | null) => {
  if (!supabaseAdmin) return null;

  const { data: profile } = await supabaseAdmin
    .from('profiles')
    .select('stripe_customer_id')
    .eq('id', userId)
    .maybeSingle();

  if (profile?.stripe_customer_id) return profile.stripe_customer_id;

  if (email) {
    const { data: customer } = await supabaseAdmin
      .schema('stripe')
      .from('customers')
      .select('id')
      .eq('email', email)
      .maybeSingle();

    if (customer?.id) return customer.id;
  }

  return null;
};

export const handler: Handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  if (!stripe) {
    return { statusCode: 500, body: JSON.stringify({ error: 'Stripe is not configured.' }) };
  }

  if (!SITE_URL) {
    return { statusCode: 500, body: JSON.stringify({ error: 'Missing SITE_URL.' }) };
  }

  try {
    const { user } = await requireUser(event);

    let customerId = await getCustomerId(user.id, user.email);

    if (!customerId) {
      const created = await stripe.customers.create({
        email: user.email || undefined,
        metadata: { userId: user.id }
      });
      customerId = created.id;

      if (supabaseAdmin) {
        await supabaseAdmin
          .from('profiles')
          .update({ stripe_customer_id: customerId })
          .eq('id', user.id);
      }
    }

    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: `${SITE_URL}/settings`
    });

    return {
      statusCode: 200,
      body: JSON.stringify({ url: session.url })
    };
  } catch (err: any) {
    return { statusCode: 401, body: JSON.stringify({ error: err.message }) };
  }
};
