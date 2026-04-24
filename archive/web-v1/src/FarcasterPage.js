import React, { useEffect, useState } from 'react';
import { html } from '../ui/html.js';
import { ASSETS } from '../assets/index.js';

export const FarcasterPage = ({ onStart }) => {
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!copied) return;
    const timer = setTimeout(() => setCopied(false), 1500);
    return () => clearTimeout(timer);
  }, [copied]);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(`${window.location.origin}/frame`);
      setCopied(true);
    } catch (err) {
      setCopied(false);
    }
  };

  return html`
    <div className="min-h-[100dvh] bg-black flex flex-col items-center justify-center p-6 text-center">
      <div className="relative mb-8">
        <div className="absolute inset-0 bg-white/10 blur-2xl rounded-full" />
        <img src=${ASSETS.mascot} alt="BA6 AI" className="w-24 h-24 rounded-3xl relative z-10 ink-glow" />
      </div>
      <h1 className="text-4xl font-bold tracking-tighter mb-4">BA6 AI is here.</h1>
      <p className="text-neutral-400 text-lg mb-10 max-w-xs leading-snug">
        The intelligence layer for the on-chain generation.
      </p>

      <div className="space-y-4 w-full max-w-xs">
        <button onClick=${onStart} className="w-full bg-white text-black px-10 py-4 rounded-2xl text-xl font-bold hover:scale-105 transition active:scale-95 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/40 focus-visible:ring-offset-0">
          Open BA6 AI
        </button>

        <div className="pt-10">
          <h3 className="text-xs font-bold text-neutral-500 uppercase tracking-widest mb-4">Share the Frame</h3>
          <p className="text-neutral-500 text-xs mb-6">Cast this URL to start the BA6 AI Frame experience in Warpcast.</p>
          <div className="bg-[#0a0a0a] border border-white/5 p-4 rounded-xl flex items-center gap-3">
            <input
              readOnly
              value=${`${window.location.origin}/frame`}
              className="bg-transparent text-[10px] flex-1 text-neutral-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/30 focus-visible:ring-offset-0 rounded-lg px-2 py-1"
            />
            <button
              onClick=${handleCopy}
              className="text-[10px] font-bold text-white hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/40 focus-visible:ring-offset-0 rounded-md px-2 py-1"
            >
              ${copied ? 'Copied' : 'Copy'}
            </button>
          </div>
          <div className="text-[10px] text-neutral-500 mt-2" aria-live="polite">
            ${copied ? 'Copied to clipboard.' : ''}
          </div>
        </div>
      </div>
    </div>
  `;
};
