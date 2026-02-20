const DEFAULT_BASE_URL = ['https://', 'api.', 'venice', '.ai', '/api', '/v1'].join('');
const BASE_URL = process.env.VENICE_BASE_URL || DEFAULT_BASE_URL;
const DEFAULT_MODEL = process.env.VENICE_IMAGE_MODEL || 'z-image-turbo';

const MODEL_ALIASES = {
  sdxl: 'z-image-turbo',
  'stable-diffusion-xl': 'z-image-turbo'
};

const mimeFor = (format) => {
  const fmt = (format || 'webp').toLowerCase();
  if (fmt === 'png') return 'image/png';
  if (fmt === 'jpg' || fmt === 'jpeg') return 'image/jpeg';
  return 'image/webp';
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

  const prompt = payload.prompt;
  if (!prompt) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Missing prompt.' }) };
  }

  const model = MODEL_ALIASES[payload.model] || payload.model || DEFAULT_MODEL;
  const width = payload.width || 1024;
  const height = payload.height || 1024;
  const format = payload.format || 'webp';

  try {
    const response = await fetch(`${BASE_URL}/image/generate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify({ model, prompt, width, height, format })
    });

    const data = await response.json();
    if (!response.ok) {
      return {
        statusCode: response.status,
        body: JSON.stringify({ error: data?.error || data })
      };
    }

    const imageBase64 = data?.images?.[0];
    if (!imageBase64) {
      return { statusCode: 500, body: JSON.stringify({ error: 'No image returned from Venice.' }) };
    }

    const imageUrl = `data:${mimeFor(format)};base64,${imageBase64}`;
    return {
      statusCode: 200,
      body: JSON.stringify({ image_url: imageUrl, model: data?.model || model })
    };
  } catch (err) {
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }
};
