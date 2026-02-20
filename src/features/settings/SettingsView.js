import React from 'react';
import { html } from '../../ui/html.js';
import { ASSETS } from '../../assets/index.js';
import { Plus } from 'lucide-react';

export const SettingsView = ({ profile, session }) => html`
  <div className="flex-1 p-12 max-w-2xl mx-auto w-full">
    <h1 className="text-3xl font-bold tracking-tighter mb-10">Settings</h1>

    <div className="space-y-12">
      <section>
        <h3 className="text-xs font-bold text-neutral-500 uppercase tracking-widest mb-6">Profile</h3>
        <div className="flex items-center gap-6 p-6 rounded-2xl border border-white/5 bg-[#0a0a0a]">
          <img src=${profile?.avatar_url || ASSETS.mascot} className="w-16 h-16 rounded-full" />
          <div>
            <div className="font-bold text-lg">${profile?.display_name || 'User'}</div>
            <div className="text-neutral-500 text-sm">${session?.user?.email || ''}</div>
          </div>
        </div>
      </section>

      <section>
        <h3 className="text-xs font-bold text-neutral-500 uppercase tracking-widest mb-6">Account Plan</h3>
        <div className="p-6 rounded-2xl border border-white/5 bg-[#0a0a0a] flex items-center justify-between">
          <div>
            <div className="font-bold text-lg capitalize">${profile?.plan || 'Free'} Plan</div>
            <div className="text-neutral-500 text-sm">Valid until next billing cycle.</div>
          </div>
          <button className="px-4 py-2 rounded-xl bg-white text-black font-bold text-sm hover:bg-neutral-200 transition">Upgrade</button>
        </div>
      </section>

      <section>
        <h3 className="text-xs font-bold text-neutral-500 uppercase tracking-widest mb-6">Linked Wallet</h3>
        <button className="w-full p-6 rounded-2xl border border-white/5 bg-[#0a0a0a] border-dashed flex items-center justify-center gap-2 text-neutral-500 hover:text-white hover:border-white transition">
          <${Plus} size=${18} /> Connect Wallet
        </button>
      </section>
    </div>
  </div>
`;
