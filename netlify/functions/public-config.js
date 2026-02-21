exports.handler = async () => {
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store'
    },
    body: JSON.stringify({
      SUPABASE_URL: process.env.SUPABASE_URL || '',
      SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY || '',
      STRIPE_PRO_PRICE_ID: process.env.STRIPE_PRO_PRICE_ID || '',
      STRIPE_TEAM_PRICE_ID: process.env.STRIPE_TEAM_PRICE_ID || ''
    })
  };
};
