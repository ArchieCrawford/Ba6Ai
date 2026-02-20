const DEFAULT_BASE_URL = ['https://api.neynar.com', '/v2/farcaster/frame/validate'].join('');

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  const apiKey = process.env.NEYNAR_API_KEY;
  if (!apiKey) {
    return { statusCode: 500, body: JSON.stringify({ error: 'Missing NEYNAR_API_KEY.' }) };
  }

  let payload = {};
  try {
    payload = JSON.parse(event.body || '{}');
  } catch (err) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Invalid JSON body.' }) };
  }

  const messageBytes = payload.message_bytes_in_hex;
  if (!messageBytes) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Missing message_bytes_in_hex.' }) };
  }

  const baseUrl = process.env.NEYNAR_BASE_URL || DEFAULT_BASE_URL;

  try {
    const response = await fetch(baseUrl, {
      method: 'POST',
      headers: {
        'accept': 'application/json',
        'api_key': apiKey,
        'content-type': 'application/json'
      },
      body: JSON.stringify({ message_bytes_in_hex: messageBytes })
    });

    const data = await response.json();
    if (!response.ok) {
      return {
        statusCode: response.status,
        body: JSON.stringify({ error: data?.error || data })
      };
    }

    return { statusCode: 200, body: JSON.stringify(data) };
  } catch (err) {
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }
};
