import { getEnv } from '../config/env.js';

const STRIPE_PRO_PRICE_ID = getEnv('STRIPE_PRO_PRICE_ID');
const STRIPE_TEAM_PRICE_ID = getEnv('STRIPE_TEAM_PRICE_ID');

const ACTIVE_STATUSES = new Set(['active', 'trialing', 'past_due']);

export const resolvePlanFromSubscription = (subscription, fallback = 'free') => {
  if (!subscription) return fallback;
  const status = (subscription.subscription_status || '').toLowerCase();
  if (!ACTIVE_STATUSES.has(status)) return fallback;

  const priceId = subscription.price_id;
  if (STRIPE_TEAM_PRICE_ID && priceId === STRIPE_TEAM_PRICE_ID) return 'team';
  if (STRIPE_PRO_PRICE_ID && priceId === STRIPE_PRO_PRICE_ID) return 'pro';
  return fallback;
};

export const getStripePriceIds = () => ({
  pro: STRIPE_PRO_PRICE_ID,
  team: STRIPE_TEAM_PRICE_ID
});
