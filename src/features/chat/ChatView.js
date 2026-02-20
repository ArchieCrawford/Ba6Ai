import React from 'react';
import { html } from '../../ui/html.js';
import { ASSETS } from '../../assets/index.js';
import { Send } from 'lucide-react';

export const ChatView = ({
  activeConv,
  messages,
  sending,
  messageInput,
  setMessageInput,
  onSend
}) => html`
  <>
    <header className="px-6 h-16 border-b border-white/5 flex items-center justify-between">
      <div className="flex items-center gap-2">
        <span className="font-bold tracking-tight">${activeConv?.title || 'New Chat'}</span>
        <span className="text-[10px] font-bold bg-white/5 px-2 py-0.5 rounded uppercase tracking-widest text-neutral-500">Llama 3 8B</span>
      </div>
    </header>

    <div className="flex-1 overflow-y-auto p-6 space-y-8 scroll-smooth">
      ${messages.length === 0 && html`
        <div className="h-full flex flex-col items-center justify-center text-center opacity-30">
          <img src=${ASSETS.mascot} className="w-20 h-20 rounded-2xl mb-4 grayscale" />
          <h3 className="text-xl font-bold">How can I help you today?</h3>
        </div>
      `}
      ${messages.map(m => html`
        <div className=${`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'}`}>
          <div className=${`max-w-2xl px-6 py-4 rounded-3xl text-sm leading-relaxed ${m.role === 'user' ? 'bg-[#0a0a0a] border border-white/5 text-neutral-200' : 'text-neutral-300'}`}>
            ${m.content}
          </div>
        </div>
      `)}
      ${sending && html`
        <div className="flex justify-start">
          <div className="flex gap-1">
            <span className="w-1.5 h-1.5 rounded-full bg-neutral-600 animate-bounce" />
            <span className="w-1.5 h-1.5 rounded-full bg-neutral-600 animate-bounce [animation-delay:0.2s]" />
            <span className="w-1.5 h-1.5 rounded-full bg-neutral-600 animate-bounce [animation-delay:0.4s]" />
          </div>
        </div>
      `}
    </div>

    <footer className="p-6 bg-black border-t border-white/5">
      <form onSubmit=${onSend} className="max-w-3xl mx-auto flex items-center gap-2 bg-[#0a0a0a] border border-white/10 p-2 rounded-2xl focus-within:border-white transition">
        <input
          className="flex-1 bg-transparent px-4 py-2 outline-none"
          placeholder="Message BA6 AI..."
          value=${messageInput}
          onChange=${(e) => setMessageInput(e.target.value)}
        />
        <button className="p-2 bg-white text-black rounded-xl hover:bg-neutral-200 transition">
          <${Send} size=${20} />
        </button>
      </form>
    </footer>
  </>
`;
