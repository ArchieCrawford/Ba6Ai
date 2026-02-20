import React from 'react';
import { html } from '../ui/html.js';
import { ASSETS } from '../assets/index.js';

export const FarcasterPage = ({ onStart }) => html`
  <div className="min-h-screen bg-black flex flex-col items-center justify-center p-6 text-center">
    <div className="relative mb-8">
      <div className="absolute inset-0 bg-white/10 blur-2xl rounded-full" />
      <img src=${ASSETS.mascot} className="w-24 h-24 rounded-3xl relative z-10 ink-glow" />
    </div>
    <h1 className="text-4xl font-bold tracking-tighter mb-4">BA6 AI is here.</h1>
    <p className="text-neutral-400 text-lg mb-10 max-w-xs leading-snug">
      The intelligence layer for the on-chain generation.
    </p>

    <div className="space-y-4 w-full max-w-xs">
      <button onClick=${onStart} className="w-full bg-white text-black px-10 py-4 rounded-2xl text-xl font-bold hover:scale-105 transition active:scale-95">
        Open BA6 AI
      </button>

      <div className="pt-10">
        <h3 className="text-xs font-bold text-neutral-500 uppercase tracking-widest mb-4">Share the Frame</h3>
        <p className="text-neutral-500 text-xs mb-6">Cast this URL to start the BA6 AI Frame experience in Warpcast.</p>
        <div className="bg-[#0a0a0a] border border-white/5 p-4 rounded-xl flex items-center gap-3">
          <input readOnly value=${window.location.origin} className="bg-transparent text-[10px] flex-1 outline-none text-neutral-400" />
          <button
            onClick=${() => {
              navigator.clipboard.writeText(window.location.origin);
              alert('Copied Frame URL!');
            }}
            className="text-[10px] font-bold text-white hover:underline"
          >
            Copy
          </button>
        </div>
      </div>
    </div>
  </div>
`;
