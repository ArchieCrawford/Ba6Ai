# BA6 AI

Private intelligence layer for Apple devices.

This repo has two things in it:

- **`/ios`** — the native iOS app. SwiftUI + Liquid Glass, MLX on-device
  inference, Secure Enclave identity, local SQLite memory, Metal +
  AVFoundation video pipeline. This is the product.
- **`/` (root)** — a minimal informational landing page (this file
  and `index.html`, `src/`). React via import maps, Tailwind,
  zero backend. Points people at the iOS waitlist.
- **`/archive/web-v1`** — the original Supabase + Venice + Stripe +
  Farcaster web app, preserved for reference. No longer built or
  deployed.

## iOS app

See `/ios/README.md` for build + run instructions.

## Landing site

### Local

```bash
npm install
npm run build:css
npx serve .
```

Open <http://localhost:3000> and you should see the BA6 marketing page.

### Deploy (Netlify)

- Build command: `npm run build:css`
- Publish directory: `.`
- No environment variables required.
- `archive/` and `ios/` are blocked from public access by `_redirects`.

### Waitlist

The form in the hero submits via `mailto:` for now. Swap it for Formspree,
ConvertKit, or a Netlify native form when you're ready to collect emails
at scale.
