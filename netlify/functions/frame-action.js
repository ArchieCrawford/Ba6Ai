const SITE_URL = process.env.SITE_URL || 'https://ba6ai.com';

exports.handler = async () => {
  const html = `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta property="og:title" content="BA6 AI — AI inside Farcaster" />
    <meta property="og:description" content="Chat and create with AI from Farcaster." />
    <meta property="og:image" content="${SITE_URL}/frame-thumbnail.png" />
    <meta property="og:type" content="website" />

    <meta name="fc:frame" content="1" />
    <meta name="fc:frame:image" content="${SITE_URL}/frame-thumbnail.png" />
    <meta name="fc:frame:post_url" content="${SITE_URL}/.netlify/functions/frame-action" />
    <meta name="fc:frame:button:1" content="Chat" />
    <meta name="fc:frame:button:2" content="Images" />
  </head>
  <body>BA6 AI Frame</body>
</html>`;

  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store'
    },
    body: html
  };
};
