import React from 'react';
import { html } from '../ui/html.js';
import { ASSETS } from '../assets/index.js';
import { Plus, MessageSquare, Image as ImageIcon, Settings, Shield, LogOut } from 'lucide-react';

export const Sidebar = ({
  activeTab,
  setActiveTab,
  profile,
  conversations,
  activeConv,
  setActiveConv,
  onNewConversation,
  onSignOut,
  onNavSelect,
  usage
}) => html`
  <aside className="w-full border-r border-white/5 bg-black flex flex-col h-full overflow-hidden">
    <div className="p-4 md:p-6 flex items-center justify-between gap-2 font-bold text-base md:text-lg mb-4 md:mb-6">
      <div className="flex items-center gap-2">
        <img src=${ASSETS.mascot} alt="BA6 AI" className="w-6 h-6 rounded-md" />
        BA6 AI
      </div>
    </div>

    <div className="px-3 md:px-4 space-y-1 overflow-y-auto flex-1">
      ${[
        { id: 'chat', name: 'Chat', icon: MessageSquare },
        { id: 'images', name: 'Images', icon: ImageIcon },
        { id: 'settings', name: 'Settings', icon: Settings },
        profile?.is_admin && { id: 'admin', name: 'Admin', icon: Shield }
      ].filter(Boolean).map(item => html`
        <button
          onClick=${() => {
            setActiveTab(item.id);
            onNavSelect?.();
          }}
          className=${`w-full flex items-center gap-3 px-3 py-2 md:py-2.5 rounded-xl transition ${activeTab === item.id ? 'bg-white text-black' : 'text-neutral-500 hover:text-white hover:bg-white/5'}`}
        >
          <${item.icon} size=${18} /> ${item.name}
        </button>
      `)}

      ${activeTab === 'chat' && html`
        <div className="mt-6 md:mt-10">
          <div className="flex items-center justify-between px-3 mb-3 md:mb-4">
            <span className="text-[10px] font-bold text-neutral-500 uppercase tracking-widest">History</span>
            <button
              onClick=${() => {
                onNewConversation();
                onNavSelect?.();
              }}
              className="p-1 hover:bg-white/5 rounded-md text-neutral-500 hover:text-white"
            >
              <${Plus} size=${14} />
            </button>
          </div>
          <div className="space-y-1">
            ${conversations.map(c => html`
              <button
                onClick=${() => {
                  setActiveConv(c);
                  onNavSelect?.();
                }}
                className=${`w-full text-left px-3 py-2 rounded-lg text-sm truncate ${activeConv?.id === c.id ? 'bg-white/5 text-white' : 'text-neutral-500 hover:text-white'}`}
              >
                ${c.title}
              </button>
            `)}
          </div>
        </div>
      `}
    </div>

    <div className="p-3 md:p-4 border-t border-white/5">
      ${(() => {
        const plan = (profile?.plan || 'free').toLowerCase();
        const limits = { free: { text: 25, image: 5 }, pro: { text: 1000, image: 250 }, team: { text: 5000, image: 1000 } };
        const limit = limits[plan] || limits.free;
        const textUsed = usage?.text_count || 0;
        const percent = Math.min(100, Math.round((textUsed / limit.text) * 100));
        return html`
          <div className="bg-white/5 rounded-xl p-2.5 md:p-3 mb-4">
            <div className="text-[9px] md:text-[10px] font-bold text-neutral-500 uppercase mb-2">Usage</div>
            <div className="h-1 bg-white/10 rounded-full overflow-hidden">
              <div className="h-full bg-white" style=${{ width: `${percent}%` }} />
            </div>
            <div className="text-[9px] md:text-[10px] text-neutral-500 mt-2">${textUsed} / ${limit.text} text this month</div>
          </div>
        `;
      })()}
      <button
        onClick=${() => {
          onSignOut();
          onNavSelect?.();
        }}
        className="w-full flex items-center gap-3 px-3 py-2 rounded-xl text-neutral-500 hover:text-red-500 transition"
      >
        <${LogOut} size=${18} /> Sign Out
      </button>
    </div>
  </aside>
`;
