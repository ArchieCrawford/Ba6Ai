import type { Handler } from '@netlify/functions';
import { verifyFrameAction } from '../../lib/neynar';

const SITE_URL = (process.env.SITE_URL || '').replace(/\/+$/, '');
const FRAME_POST_URL = (process.env.FRAME_POST_URL || `${SITE_URL}/.netlify/functions/frame-action`).replace(/\/+$/, '');
const FRAME_IMAGE_URL = `${SITE_URL}/.netlify/functions/frame-image`;
const PLAN_BADGE_URL = `${SITE_URL}/.netlify/functions/plan-badge`;

const escapeHtml = (value: string) =>
  value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

type FrameButton = {
  label: string;
  action?: 'post' | 'link';
  target?: string;
};

type FrameConfig = {
  title: string;
  description: string;
  image: string;
  postUrl: string;
  buttons: FrameButton[];
  state?: string;
  inputText?: string;
};

const renderFrame = (config: FrameConfig) => {
  const meta: string[] = [];
  meta.push(`<meta charset="UTF-8" />`);
  meta.push(`<meta property="og:title" content="${escapeHtml(config.title)}" />`);
  meta.push(`<meta property="og:description" content="${escapeHtml(config.description)}" />`);
  meta.push(`<meta property="og:image" content="${escapeHtml(config.image)}" />`);
  meta.push(`<meta property="og:type" content="website" />`);

  meta.push(`<meta name="fc:frame" content="1" />`);
  meta.push(`<meta name="fc:frame:image" content="${escapeHtml(config.image)}" />`);
  meta.push(`<meta name="fc:frame:post_url" content="${escapeHtml(config.postUrl)}" />`);

  if (config.state) {
    meta.push(`<meta name="fc:frame:state" content="${escapeHtml(config.state)}" />`);
  }

  if (config.inputText) {
    meta.push(`<meta name="fc:frame:input:text" content="${escapeHtml(config.inputText)}" />`);
  }

  config.buttons.forEach((button, index) => {
    const idx = index + 1;
    meta.push(`<meta name="fc:frame:button:${idx}" content="${escapeHtml(button.label)}" />`);
    if (button.action && button.action !== 'post') {
      meta.push(`<meta name="fc:frame:button:${idx}:action" content="${button.action}" />`);
    }
    if (button.target) {
      meta.push(`<meta name="fc:frame:button:${idx}:target" content="${escapeHtml(button.target)}" />`);
    }
  });

  return `<!DOCTYPE html><html lang="en"><head>${meta.join('')}</head><body>BA6 AI Frame</body></html>`;
};

const frameImageUrl = (state: string, fid?: number | string, extra?: Record<string, string>) => {
  const params = new URLSearchParams();
  params.set('state', state);
  if (fid !== undefined && fid !== null) params.set('fid', String(fid));
  if (extra) {
    Object.entries(extra).forEach(([key, value]) => params.set(key, value));
  }
  return `${FRAME_IMAGE_URL}?${params.toString()}`;
};

const planBadgeUrl = (fid?: number | string) => {
  const params = new URLSearchParams();
  if (fid !== undefined && fid !== null) params.set('fid', String(fid));
  return `${PLAN_BADGE_URL}?${params.toString()}`;
};

const buildHomeFrame = (fid?: number | string): FrameConfig => ({
  title: 'BA6 AI - AI inside Farcaster',
  description: 'Chat + Images + Wallet login inside Farcaster frames',
  image: frameImageUrl('home', fid),
  postUrl: FRAME_POST_URL,
  buttons: [
    { label: 'Chat' },
    { label: 'Images' },
    { label: 'Sign In' },
    { label: 'Plan Status' }
  ],
  state: 'home'
});

const buildChatFrame = (fid?: number | string): FrameConfig => ({
  title: 'BA6 AI - Chat',
  description: 'Open BA6 AI chat and keep building.',
  image: frameImageUrl('chat', fid),
  postUrl: FRAME_POST_URL,
  buttons: [
    { label: 'Open Chat', action: 'link', target: `${SITE_URL}/app?tab=chat` },
    { label: 'Back' }
  ],
  inputText: 'Ask BA6 AI',
  state: 'chat'
});

const buildImageFrame = (fid?: number | string): FrameConfig => ({
  title: 'BA6 AI - Images',
  description: 'Generate visuals with BA6 AI.',
  image: frameImageUrl('image', fid),
  postUrl: FRAME_POST_URL,
  buttons: [
    { label: 'Open Images', action: 'link', target: `${SITE_URL}/app?tab=images` },
    { label: 'Back' }
  ],
  inputText: 'Describe an image',
  state: 'image'
});

const buildSigninFrame = (fid?: number | string): FrameConfig => ({
  title: 'BA6 AI - Sign In',
  description: 'Open BA6 AI to connect your wallet.',
  image: frameImageUrl('signin', fid),
  postUrl: FRAME_POST_URL,
  buttons: [
    { label: 'Open BA6 AI', action: 'link', target: `${SITE_URL}/app` },
    { label: 'Back' }
  ],
  state: 'signin'
});

const buildPlanFrame = (fid?: number | string): FrameConfig => ({
  title: 'BA6 AI - Plan Status',
  description: 'Your BA6 AI plan badge and usage snapshot.',
  image: planBadgeUrl(fid),
  postUrl: FRAME_POST_URL,
  buttons: [{ label: 'Back' }],
  state: 'plan'
});

const buildErrorFrame = (message: string): FrameConfig => ({
  title: 'BA6 AI - Frame Error',
  description: message,
  image: frameImageUrl('error', undefined, { message }),
  postUrl: FRAME_POST_URL,
  buttons: [{ label: 'Back' }],
  state: 'error'
});

const parsePayload = (eventBody: string | null, isBase64?: boolean) => {
  if (!eventBody) return {};
  const raw = isBase64 ? Buffer.from(eventBody, 'base64').toString('utf8') : eventBody;
  return JSON.parse(raw || '{}');
};

export const handler: Handler = async (event) => {
  if (!SITE_URL) {
    return {
      statusCode: 500,
      body: 'Missing SITE_URL.'
    };
  }

  if (event.httpMethod !== 'POST') {
    const html = renderFrame(buildHomeFrame());
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-store'
      },
      body: html
    };
  }

  let payload: any = {};
  try {
    payload = parsePayload(event.body || null, event.isBase64Encoded);
  } catch (err: any) {
    const html = renderFrame(buildErrorFrame('Invalid JSON payload.'));
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-store'
      },
      body: html
    };
  }

  const validation = await verifyFrameAction(payload);
  if (!validation.valid) {
    const html = renderFrame(buildErrorFrame(validation.error || 'Frame validation failed.'));
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-store'
      },
      body: html
    };
  }

  const action = validation.action || {};
  const fid = validation.fid || action?.interactor?.fid || payload?.untrustedData?.fid;
  const buttonIndex = Number(
    action?.tapped_button?.index ||
      action?.button_index ||
      action?.buttonIndex ||
      payload?.untrustedData?.buttonIndex ||
      payload?.untrustedData?.button_index ||
      0
  );
  const state = action?.state || payload?.untrustedData?.state || 'home';

  let nextFrame: FrameConfig = buildHomeFrame(fid);

  if (state === 'home') {
    if (buttonIndex === 1) nextFrame = buildChatFrame(fid);
    if (buttonIndex === 2) nextFrame = buildImageFrame(fid);
    if (buttonIndex === 3) nextFrame = buildSigninFrame(fid);
    if (buttonIndex === 4) nextFrame = buildPlanFrame(fid);
  } else if (state === 'chat' || state === 'image' || state === 'signin' || state === 'plan' || state === 'error') {
    if (buttonIndex === 2 || buttonIndex === 1) nextFrame = buildHomeFrame(fid);
  }

  const html = renderFrame(nextFrame);
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store'
    },
    body: html
  };
};
