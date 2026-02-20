import type { Handler } from '@netlify/functions';
import { randomBytes } from 'crypto';
import { requireUser, supabaseAdmin } from './_supabase';

export const handler: Handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  try {
    const { user } = await requireUser(event);
    const nonce = randomBytes(16).toString('hex');

    if (!supabaseAdmin) throw new Error('Supabase admin not configured.');

    const { error } = await supabaseAdmin
      .from('wallet_nonces')
      .upsert({ user_id: user.id, nonce, created_at: new Date().toISOString() }, { onConflict: 'user_id' });

    if (error) throw error;

    return {
      statusCode: 200,
      body: JSON.stringify({
        nonce,
        message: `BA6 AI wants you to sign in. Nonce: ${nonce}`
      })
    };
  } catch (err: any) {
    return { statusCode: 401, body: JSON.stringify({ error: err.message }) };
  }
};
