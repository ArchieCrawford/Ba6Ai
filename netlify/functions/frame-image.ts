import type { Handler } from '@netlify/functions';
import { Resvg } from '@resvg/resvg-js';

const escapeText = (value: string) =>
  value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const buildSvg = (state: string, fid?: string, message?: string) => {
  const safeState = escapeText(state.toUpperCase());
  const safeMessage = message ? escapeText(message) : '';
  const fidLine = fid ? `FID ${escapeText(fid)}` : '';

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg width="1200" height="630" viewBox="0 0 1200 630" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#050505" />
      <stop offset="50%" stop-color="#0b0b0b" />
      <stop offset="100%" stop-color="#111111" />
    </linearGradient>
    <linearGradient id="accent" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#00e0ff" />
      <stop offset="100%" stop-color="#9b7bff" />
    </linearGradient>
  </defs>
  <rect width="1200" height="630" fill="url(#bg)" />
  <rect x="60" y="80" width="1080" height="470" rx="32" fill="#0a0a0a" stroke="#1f1f1f" stroke-width="2" />
  <text x="110" y="180" fill="#ffffff" font-family="Arial, sans-serif" font-size="54" font-weight="700">BA6 AI</text>
  <text x="110" y="250" fill="url(#accent)" font-family="Arial, sans-serif" font-size="32" font-weight="600">${safeState}</text>
  ${fidLine ? `<text x="110" y="305" fill="#9ca3af" font-family="Arial, sans-serif" font-size="22">${fidLine}</text>` : ''}
  ${safeMessage ? `<text x="110" y="360" fill="#fca5a5" font-family="Arial, sans-serif" font-size="20">${safeMessage}</text>` : ''}
  <text x="110" y="470" fill="#6b7280" font-family="Arial, sans-serif" font-size="18">Decentralized AI routing. Chat. Images. Video.</text>
</svg>`;
};

export const handler: Handler = async (event) => {
  const query = event.queryStringParameters || {};
  const state = query.state || 'home';
  const fid = query.fid;
  const message = query.message;
  const format = (query.format || 'svg').toLowerCase();

  const svg = buildSvg(state, fid, message);

  if (format === 'png') {
    const resvg = new Resvg(svg, { fitTo: { mode: 'width', value: 1200 } });
    const pngData = resvg.render().asPng();
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'image/png',
        'Cache-Control': 'no-store'
      },
      body: pngData.toString('base64'),
      isBase64Encoded: true
    };
  }

  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'image/svg+xml; charset=utf-8',
      'Cache-Control': 'no-store'
    },
    body: svg
  };
};
