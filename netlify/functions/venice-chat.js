const BASE_URL = process.env.VENICE_BASE_URL || 'https://api.venice.ai/api/v1';
const DEFAULT_MODEL = process.env.VENICE_CHAT_MODEL || 'venice-uncensored';

const MODEL_ALIASES = {
  'llama-3-8b': DEFAULT_MODEL,
  'llama-3-70b': DEFAULT_MODEL
};

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  const apiKey = process.env.VENICE_API_KEY;
  if (!apiKey) {
    return { statusCode: 500, body: JSON.stringify({ error: 'Missing VENICE_API_KEY.' }) };
  }

  let payload = {};
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

    const content = data?.choices?.[0]?.message?.content || '';
    return {
      statusCode: 200,
      body: JSON.stringify({
        content,
        model: data?.model || model,
        usage: data?.usage || null
      })
    };
  } catch (err) {
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }
};
