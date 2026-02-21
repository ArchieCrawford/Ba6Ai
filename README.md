# BA6 AI - Programmable Intelligence

BA6 AI is a high-performance, dark-mode AI SaaS platform providing a minimal interface to world-class open-source models via Venice AI.

## Features
- **Dual Auth**: Login with Email/Password or Supabase Web3 (Ethereum + Solana).
- **Inference**: Chat with LLMs (Llama 3) and Generate Images (SDXL) via Venice AI.
- **SaaS Logic**: Monthly usage tracking, tiered plans (Free, Pro, Team).
- **Mobile First**: Fully responsive "Ink" aesthetic, including a Farcaster-optimized launch page.
- **Real-time**: Real-time usage and message updates via Supabase.

## Farcaster Frame Support
BA6 AI ships a public Farcaster Frame at `/frame` with Neynar-validated actions.

### Initial Frame
- **URL**: `https://your-domain.com/frame`
- **Buttons**: Chat, Images, Sign In, Plan Status

### Testing
1. Go to the [Farcaster Frame Debugger](https://warpcast.com/~/developers/frames).
2. Enter your live `/frame` URL.
3. Verify the meta tags and interaction buttons.

### Action Endpoint (POST)
Frame interactions post to `/.netlify/functions/frame-action` which validates actions via Neynar before responding with the next frame.
Set `NEYNAR_API_KEY` to enable validation (required for production).

### Dynamic Images
- `/.netlify/functions/frame-image` renders dynamic frame states.
- `/.netlify/functions/plan-badge` renders plan + usage badges for frames and embeds.

## Tech Stack
- **Frontend**: React + Tailwind CSS + Lucide Icons + htm (no build step).
- **Backend/DB**: Supabase (Auth, PostgreSQL, Realtime).
- **Web3**: Ethers.js for wallet signatures.
- **AI**: Venice AI API integration.

## Setup Instructions

1. **Supabase Setup**:
   - Create a new project at [supabase.com](https://supabase.com).
   - Run the contents of `migrations.sql` in the SQL Editor.
   - Copy your `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

2. **Venice AI**:
   - Get your API key from [venice.ai](https://venice.ai).
   - *Note*: For security, move the Venice API calls to a server-side proxy or Supabase Edge Function before production.

3. **Environment Variables**:
   - Add your credentials to `.env`.
   - Generate `env.js` (client-safe env) before running locally.

4. **Web3 Auth (Supabase)**:
   - In Supabase Auth settings, enable **Sign in with Ethereum** and **Sign in with Solana**.
   - Add your site URL(s) to the redirect allowlist (ex: `http://localhost:8888` for `netlify dev`).

## Usage Limits
- **Free**: 25 text / 5 images per month.
- **Pro**: 1000 text / 250 images per month.
- **Team**: 5000 text / 1000 images per month.

## Local Development
This project uses ESM and importmaps. Build Tailwind CSS, then serve the root directory:
```bash
npm install
npm run build:css
npx serve .
```
To use Venice locally, run Netlify Functions with the Netlify CLI:
```bash
npx netlify dev
```
The app will fetch the model list from `/.netlify/functions/venice-models`.

## Netlify Build Settings
- **Build command**: `echo "no build"`
- **Publish directory**: `.`
- **Environment variables** (Site settings → Environment variables):
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY` (server-only, for webhooks + usage enforcement)
  - `VENICE_API_KEY` (server-only, for Netlify Functions)
  - `VENICE_BASE_URL` (optional, defaults to the Venice API base URL)
  - `VENICE_CHAT_MODEL` (optional)
  - `VENICE_IMAGE_MODEL` (optional)
  - `NEYNAR_API_KEY` (optional, used for Farcaster validation + profile lookups)
  - `NEYNAR_BASE_URL` (optional, defaults to https://api.neynar.com)
  - `STRIPE_SECRET_KEY`
  - `STRIPE_PRO_PRICE_ID`
  - `STRIPE_TEAM_PRICE_ID`
  - `SITE_URL`
  - `FRAME_POST_URL` (optional, override frame post URL)

Notes:
- `env.js` is **not** generated during Netlify builds. The client fetches public config at runtime from `/.netlify/functions/public-config`.
- Do not expose private server keys (e.g., Venice API key) to the client.
- Stripe webhooks are handled by the Supabase Stripe Sync Engine (stripe.* schema).
