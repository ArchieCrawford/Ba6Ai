import React from 'react';
import { html } from '../ui/html.js';
import { ASSETS } from '../assets/index.js';
import { Zap } from 'lucide-react';

export const LandingPage = ({ onStart }) => html`
  <div className="min-h-[100dvh] bg-black text-white selection:bg-white selection:text-black">
    <a href="#main" className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-50 focus:bg-white focus:text-black focus:px-4 focus:py-2 focus:rounded-lg">
      Skip to content
    </a>
    <nav className="border-b border-white/5 px-4 md:px-6 py-3 md:py-4 flex justify-between items-center backdrop-blur-md sticky top-0 z-50">
      <div className="flex items-center gap-2 font-bold text-xl tracking-tight">
        <img src=${ASSETS.mascot} alt="BA6 AI" className="w-8 h-8 rounded-lg" />
        BA6 AI
      </div>
      <div className="flex items-center gap-4 md:gap-6">
        <a href="/docs" className="text-sm text-neutral-400 hover:text-white transition">Docs</a>
        <a href="#pricing" className="text-sm text-neutral-400 hover:text-white transition">Pricing</a>
        <button onClick=${onStart} className="bg-white text-black px-4 py-1.5 rounded-full text-sm font-semibold hover:bg-neutral-200 transition">Start</button>
      </div>
    </nav>

    <main id="main">
      <section className="px-4 md:px-6 pt-20 md:pt-32 pb-16 md:pb-20 text-center max-w-4xl mx-auto">
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full border border-white/10 text-[10px] font-bold tracking-widest uppercase mb-8 text-neutral-400">
          <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse" />
          V1.0 Live on Venice
        </div>

        <div className="flex justify-center mb-10">
           <div className="relative">
              <div className="absolute inset-0 bg-white/20 blur-3xl rounded-full" />
              <img src=${ASSETS.mascot} alt="" aria-hidden="true" className="w-32 h-32 md:w-48 md:h-48 rounded-[2rem] relative z-10 ink-glow" />
           </div>
        </div>

        <h1 className="text-4xl md:text-6xl lg:text-8xl font-bold tracking-tighter mb-6 md:mb-8 leading-[0.9]">
          Programmable <br/>intelligence.
        </h1>
        <p className="text-neutral-400 text-lg md:text-2xl mb-10 md:mb-12 max-w-2xl mx-auto font-light leading-relaxed">
          The minimal, hyper-fast interface for the world's most capable open-source models.
        </p>
        <div className="flex flex-col md:flex-row items-center justify-center gap-4">
          <button onClick=${onStart} className="w-full md:w-auto bg-white text-black px-8 py-4 rounded-xl text-base md:text-lg font-bold hover:scale-105 transition-transform">
            Get Started
          </button>
          <button className="w-full md:w-auto border border-white/10 px-8 py-4 rounded-xl text-base md:text-lg font-bold hover:bg-white/5 transition">
            View Documentation
          </button>
        </div>
      </section>

      <section id="pricing" className="px-4 md:px-6 py-16 md:py-20 bg-neutral-950">
        <div className="max-w-6xl mx-auto grid md:grid-cols-3 gap-8">
          ${[
            { name: 'Free', price: '$0', limits: '25 text / 5 images', features: ['Venice Basic', 'Community Support'] },
            { name: 'Pro', price: '$20', limits: '1000 text / 250 images', features: ['Venice Turbo', 'Priority Support', 'Early Access'], highlight: true },
            { name: 'Team', price: '$99', limits: '5000 text / 1000 images', features: ['Custom Models', 'Admin Tools', 'API Access'] }
          ].map(plan => html`
            <div className=${`p-6 md:p-8 rounded-2xl border ${plan.highlight ? 'border-white bg-white text-black' : 'border-white/10 bg-black text-white'}`}>
              <h3 className="text-lg font-bold mb-2 tracking-tight">${plan.name}</h3>
              <div className="text-3xl md:text-4xl font-bold mb-4 tracking-tighter">${plan.price}<span className="text-sm font-normal opacity-50">/mo</span></div>
              <p className="text-sm mb-8 opacity-70">${plan.limits} per month.</p>
              <ul className="space-y-4 mb-10">
                ${plan.features.map(f => html`
                  <li className="flex items-center gap-2 text-sm">
                    <${Zap} size=${14} /> ${f}
                  </li>
                `)}
              </ul>
              <button onClick=${onStart} className=${`w-full py-3 rounded-xl font-bold transition ${plan.highlight ? 'bg-black text-white hover:bg-neutral-800' : 'bg-white text-black hover:bg-neutral-200'}`}>
                Get Started
              </button>
            </div>
          `)}
        </div>
      </section>
    </main>
  </div>
`;
