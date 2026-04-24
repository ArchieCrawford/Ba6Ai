import React, { useState } from 'react';
import { html } from '../ui/html.js';
import { ASSETS } from '../assets/index.js';
import { Cpu, Shield, Brain, Film, Camera, Share2, Cloud, ArrowRight } from 'lucide-react';

const PILLARS = [
  {
    icon: Cpu,
    title: 'On-device inference',
    body: 'MLX-powered models run directly on Apple Silicon. Your prompts never leave the device.'
  },
  {
    icon: Shield,
    title: 'Secure Enclave identity',
    body: 'A device-bound keypair replaces accounts and passwords. The private key never leaves the chip.'
  },
  {
    icon: Brain,
    title: 'Memory you control',
    body: 'Remember, forget, and wipe — explicitly. Every fact is listable, pinnable, and revocable.'
  }
];

const FEATURES = [
  { icon: Brain, title: 'Chat', body: 'Streaming local LLMs tuned for speed on iPhone.' },
  { icon: Film, title: 'Video understanding', body: 'Ask questions about any clip. Frames are analyzed on-device by a VLM.' },
  { icon: Camera, title: 'Share & camera', body: 'Pipe any text, image, or video from anywhere in iOS straight into BA6.' },
  { icon: Cloud, title: 'Optional cloud boost', body: 'Off-load long prompts to a stateless backend, signed with your device key.' }
];

const PLANS = [
  {
    name: 'Free',
    price: '$0',
    cadence: '/mo',
    tagline: 'Everything on-device.',
    features: ['3B instruct model', 'Local memory', 'Secure Enclave identity', 'Community support']
  },
  {
    name: 'Pro',
    price: '$20',
    cadence: '/mo',
    tagline: 'Cloud boost + larger models.',
    features: ['Everything in Free', 'Cloud Boost', '7B / 14B models', 'Video understanding', 'Priority support'],
    highlight: true
  },
  {
    name: 'Team',
    price: '$99',
    cadence: '/mo',
    tagline: 'For crews building on BA6.',
    features: ['Everything in Pro', 'Device-to-device mesh', 'Admin + audit tools', 'Custom models', 'API access']
  }
];

export const LandingPage = () => {
  const [email, setEmail] = useState('');
  const mailtoHref = email
    ? `mailto:waitlist@ba6ai.com?subject=${encodeURIComponent('Join BA6 waitlist')}&body=${encodeURIComponent(`Please add ${email} to the waitlist.`)}`
    : 'mailto:waitlist@ba6ai.com?subject=Join%20BA6%20waitlist';

  return html`
    <div className="min-h-[100dvh] bg-black text-white selection:bg-white selection:text-black">
      <a href="#main" className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-50 focus:bg-white focus:text-black focus:px-4 focus:py-2 focus:rounded-lg">
        Skip to content
      </a>

      <nav className="border-b border-white/5 px-4 md:px-6 py-3 md:py-4 flex justify-between items-center backdrop-blur-md sticky top-0 z-50">
        <a href="/" className="flex items-center gap-2 font-bold text-xl tracking-tight">
          <img src=${ASSETS.mascot} alt="BA6 AI" className="w-8 h-8 rounded-lg" />
          BA6 AI
        </a>
        <div className="flex items-center gap-4 md:gap-6">
          <a href="#how" className="hidden md:inline text-sm text-neutral-400 hover:text-white transition">How it works</a>
          <a href="#features" className="hidden md:inline text-sm text-neutral-400 hover:text-white transition">Features</a>
          <a href="#pricing" className="hidden md:inline text-sm text-neutral-400 hover:text-white transition">Pricing</a>
          <a href="#waitlist" className="bg-white text-black px-4 py-1.5 rounded-full text-sm font-semibold hover:bg-neutral-200 transition">Join waitlist</a>
        </div>
      </nav>

      <main id="main">
        <section className="px-4 md:px-6 pt-20 md:pt-32 pb-20 md:pb-28 text-center max-w-4xl mx-auto">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full border border-white/10 text-[10px] font-bold tracking-widest uppercase mb-8 text-neutral-400">
            <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse" />
            Coming soon to iOS
          </div>

          <div className="flex justify-center mb-10">
            <div className="relative">
              <div className="absolute inset-0 bg-white/20 blur-3xl rounded-full" />
              <img src=${ASSETS.mascot} alt="" aria-hidden="true" className="w-32 h-32 md:w-48 md:h-48 rounded-[2rem] relative z-10 ink-glow" />
            </div>
          </div>

          <h1 className="text-4xl md:text-6xl lg:text-8xl font-bold tracking-tighter mb-6 md:mb-8 leading-[0.9]">
            Private intelligence <br/>for Apple devices.
          </h1>
          <p className="text-neutral-400 text-lg md:text-2xl mb-10 md:mb-12 max-w-2xl mx-auto font-light leading-relaxed">
            On-device AI. Encrypted identity. Memory you control.
          </p>

          <div className="flex flex-col md:flex-row items-center justify-center gap-4">
            <a href="#waitlist" className="w-full md:w-auto bg-white text-black px-8 py-4 rounded-xl text-base md:text-lg font-bold hover:scale-105 transition-transform">
              Join the iOS waitlist
            </a>
            <a href="#how" className="w-full md:w-auto border border-white/10 px-8 py-4 rounded-xl text-base md:text-lg font-bold hover:bg-white/5 transition">
              How it works
            </a>
          </div>
        </section>

        <section id="how" className="px-4 md:px-6 py-16 md:py-24 border-t border-white/5">
          <div className="max-w-6xl mx-auto">
            <div className="max-w-2xl mb-12">
              <p className="text-xs font-bold tracking-widest uppercase text-neutral-500 mb-3">How it works</p>
              <h2 className="text-3xl md:text-5xl font-bold tracking-tighter">Three layers. One device.</h2>
            </div>
            <div className="grid md:grid-cols-3 gap-6">
              ${PILLARS.map(p => html`
                <div key=${p.title} className="p-6 md:p-8 rounded-2xl border border-white/10 bg-neutral-950">
                  <div className="w-10 h-10 rounded-xl bg-white/5 border border-white/10 flex items-center justify-center mb-6">
                    <${p.icon} size=${18} />
                  </div>
                  <h3 className="text-lg font-semibold mb-2 tracking-tight">${p.title}</h3>
                  <p className="text-sm text-neutral-400 leading-relaxed">${p.body}</p>
                </div>
              `)}
            </div>
          </div>
        </section>

        <section id="features" className="px-4 md:px-6 py-16 md:py-24 border-t border-white/5 bg-neutral-950/50">
          <div className="max-w-6xl mx-auto">
            <div className="max-w-2xl mb-12">
              <p className="text-xs font-bold tracking-widest uppercase text-neutral-500 mb-3">Features</p>
              <h2 className="text-3xl md:text-5xl font-bold tracking-tighter">Built native. From the metal up.</h2>
            </div>
            <div className="grid md:grid-cols-2 gap-6">
              ${FEATURES.map(f => html`
                <div key=${f.title} className="p-6 md:p-8 rounded-2xl border border-white/10 bg-black flex gap-5">
                  <div className="shrink-0 w-10 h-10 rounded-xl bg-white/5 border border-white/10 flex items-center justify-center">
                    <${f.icon} size=${18} />
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold mb-1 tracking-tight">${f.title}</h3>
                    <p className="text-sm text-neutral-400 leading-relaxed">${f.body}</p>
                  </div>
                </div>
              `)}
            </div>
          </div>
        </section>

        <section id="pricing" className="px-4 md:px-6 py-16 md:py-24 border-t border-white/5">
          <div className="max-w-6xl mx-auto">
            <div className="max-w-2xl mb-12">
              <p className="text-xs font-bold tracking-widest uppercase text-neutral-500 mb-3">Pricing</p>
              <h2 className="text-3xl md:text-5xl font-bold tracking-tighter">Free forever on-device.</h2>
              <p className="text-neutral-400 mt-4 text-lg">Pay only when you want larger models or cloud boost.</p>
            </div>
            <div className="grid md:grid-cols-3 gap-6">
              ${PLANS.map(plan => html`
                <div key=${plan.name} className=${`p-6 md:p-8 rounded-2xl border ${plan.highlight ? 'border-white bg-white text-black' : 'border-white/10 bg-black text-white'}`}>
                  <h3 className="text-lg font-bold mb-1 tracking-tight">${plan.name}</h3>
                  <p className=${`text-sm mb-4 ${plan.highlight ? 'text-black/60' : 'text-neutral-400'}`}>${plan.tagline}</p>
                  <div className="text-3xl md:text-4xl font-bold mb-6 tracking-tighter">
                    ${plan.price}<span className=${`text-sm font-normal ${plan.highlight ? 'text-black/50' : 'text-white/50'}`}>${plan.cadence}</span>
                  </div>
                  <ul className="space-y-3 mb-8">
                    ${plan.features.map(f => html`
                      <li key=${f} className=${`flex items-start gap-2 text-sm ${plan.highlight ? 'text-black/80' : 'text-neutral-300'}`}>
                        <${ArrowRight} size=${14} className="mt-0.5 shrink-0" />
                        <span>${f}</span>
                      </li>
                    `)}
                  </ul>
                  <a href="#waitlist" className=${`block text-center w-full py-3 rounded-xl font-bold transition ${plan.highlight ? 'bg-black text-white hover:bg-neutral-800' : 'bg-white text-black hover:bg-neutral-200'}`}>
                    Join waitlist
                  </a>
                </div>
              `)}
            </div>
          </div>
        </section>

        <section id="waitlist" className="px-4 md:px-6 py-20 md:py-28 border-t border-white/5">
          <div className="max-w-xl mx-auto text-center">
            <p className="text-xs font-bold tracking-widest uppercase text-neutral-500 mb-3">Waitlist</p>
            <h2 className="text-3xl md:text-5xl font-bold tracking-tighter mb-4">Get early access.</h2>
            <p className="text-neutral-400 mb-8 text-lg">We'll email you when BA6 hits TestFlight.</p>
            <form
              className="flex flex-col sm:flex-row gap-3"
              onSubmit=${(e) => { e.preventDefault(); window.location.href = mailtoHref; }}
            >
              <input
                type="email"
                required
                placeholder="you@domain.com"
                value=${email}
                onChange=${(e) => setEmail(e.target.value)}
                className="flex-1 px-4 py-3 rounded-xl bg-neutral-950 border border-white/10 text-white placeholder:text-neutral-500 focus:outline-none focus:border-white/30"
              />
              <button type="submit" className="px-6 py-3 rounded-xl bg-white text-black font-semibold hover:bg-neutral-200 transition">
                Join
              </button>
            </form>
            <p className="text-xs text-neutral-500 mt-4">We'll only email you about the iOS launch. No newsletters.</p>
          </div>
        </section>
      </main>

      <footer className="px-4 md:px-6 py-10 border-t border-white/5 text-xs text-neutral-500">
        <div className="max-w-6xl mx-auto flex flex-col md:flex-row items-center justify-between gap-4">
          <div>© ${new Date().getFullYear()} BA6 AI. Private intelligence layer for Apple devices.</div>
          <div className="flex gap-5">
            <a href="mailto:hello@ba6ai.com" className="hover:text-white transition">Contact</a>
          </div>
        </div>
      </footer>
    </div>
  `;
};
