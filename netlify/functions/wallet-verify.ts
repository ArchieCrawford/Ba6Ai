import type { Handler } from '@netlify/functions';
import { verifyMessage } from 'ethers';
import { requireUser, supabaseAdmin } from './_supabase';

export const handler: Handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  let body: { address?: string; signature?: string; nonce?: string; chain_id?: number } = {};
  try {
    body = JSON.parse(event.body || '{}');
  } catch (err) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Invalid JSON body.' }) };
  }

  const address = (body.address || '').toLowerCase();
  const signature = body.signature || '';
  const nonce = body.nonce || '';
  const chainId = body.chain_id || null;

  if (!address || !signature || !nonce) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Missing address, signature, or nonce.' }) };
  }

  try {
    const { user } = await requireUser(event);
    if (!supabaseAdmin) throw new Error('Supabase admin not configured.');

    const { data: nonceRow, error: nonceError } = await supabaseAdmin
      .from('wallet_nonces')
      .select('nonce')
      .eq('user_id', user.id)
      .maybeSingle();

    if (nonceError) throw nonceError;
    if (!nonceRow || nonceRow.nonce !== nonce) {
      return { statusCode: 400, body: JSON.stringify({ error: 'Nonce mismatch.' }) };
    }

    const message = `BA6 AI wants you to sign in. Nonce: ${nonce}`;
    const recovered = verifyMessage(message, signature).toLowerCase();
    if (recovered !== address) {
      return { statusCode: 400, body: JSON.stringify({ error: 'Signature verification failed.' }) };
    }

    const { data: existing } = await supabaseAdmin
      .from('wallets')
      .select('user_id')
      .eq('address', address)
      .maybeSingle();

    if (existing && existing.user_id !== user.id) {
      return { statusCode: 409, body: JSON.stringify({ error: 'Wallet already linked to another account.' }) };
    }

    const { error: insertError } = await supabaseAdmin
      .from('wallets')
      .upsert({ user_id: user.id, address, chain_id: chainId }, { onConflict: 'address' });

    if (insertError) throw insertError;

    await supabaseAdmin.from('wallet_nonces').delete().eq('user_id', user.id);

    return { statusCode: 200, body: JSON.stringify({ success: true, address }) };
  } catch (err: any) {
    return { statusCode: 401, body: JSON.stringify({ error: err.message }) };
  }
};
