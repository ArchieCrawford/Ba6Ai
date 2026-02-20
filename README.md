# BA6 AI - Programmable Intelligence

BA6 AI is a high-performance, dark-mode AI SaaS platform providing a minimal interface to world-class open-source models via Venice AI.

## Features
- **Dual Auth**: Login with Email/Password or Web3 Wallet (Sign message).
- **Inference**: Chat with LLMs (Llama 3) and Generate Images (SDXL) via Venice AI.
- **SaaS Logic**: Monthly usage tracking, tiered plans (Free, Pro, Team).
- **Mobile First**: Fully responsive "Ink" aesthetic, including a Farcaster-optimized launch page.
- **Real-time**: Real-time usage and message updates via Supabase.

## Farcaster Frame Support
BA6 AI is Frame-ready. 

### Initial Frame
- **URL**: `https://your-domain.com/`
- **Buttons**: Chat, Image, Sign In.

### testing
1. Go to the [Farcaster Frame Debugger](https://warpcast.com/~/developers/frames).
2. Enter your live site URL.
3. Verify the meta tags and interaction buttons.

### Action Endpoint (POST)
The frame expects a `POST` endpoint at `/api/frame/action`. 
- **Implementation**: The logic is available in `src/api/frameApi.js`. 
- **Validation**: Uses Neynar's `validateFrameAction` to ensure requests are authentic.

### Dynamic Images
Images for the frame are dynamically requested from `/api/frame/image`. For the MVP, we use `placehold.co` with branded parameters, which can be replaced by a dedicated image generation service.

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

## Usage Limits
- **Free**: 25 text / 5 images per month.
- **Pro**: 1000 text / 250 images per month.
- **Team**: 5000 text / 1000 images per month.

## Local Development
This project uses ESM and importmaps (no build step). Generate `env.js` for local static serving, then serve the root directory:
```bash
node scripts/generate-env.js
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
  - `VENICE_API_KEY` (server-only, for Netlify Functions)
  - `VENICE_BASE_URL` (optional, defaults to the Venice API base URL)
  - `VENICE_CHAT_MODEL` (optional)
  - `VENICE_IMAGE_MODEL` (optional)
  - `NEYNAR_API_KEY` (optional, used by `neynar-validate` function)
  - `NEYNAR_BASE_URL` (optional, used by `neynar-validate` function)

Notes:
- `env.js` is **not** generated during Netlify builds. The client fetches public config at runtime from `/.netlify/functions/public-config`.
- Do not expose private server keys (e.g., Venice API key) to the client.
