import React, { useEffect, useMemo, useState } from 'react';
import { html } from '../../ui/html.js';
import { ASSETS } from '../../assets/index.js';
import { Plus, Loader2, Check } from 'lucide-react';
import { supabase } from '../../api/supabaseClient.js';
import { ethers } from 'ethers';

const PLAN_LABELS = {
  free: 'Free',
  pro: 'Pro',
  team: 'Team'
};

export const SettingsView = ({ profile, session, onProfileUpdated }) => {
  const [form, setForm] = useState({ display_name: '', avatar_url: '' });
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(false);
  const [upgradeLoading, setUpgradeLoading] = useState(false);
  const [walletLoading, setWalletLoading] = useState(false);
  const [wallets, setWallets] = useState([]);
  const [error, setError] = useState('');
  const plan = (profile?.plan || 'free').toLowerCase();

  useEffect(() => {
    if (profile) {
      setForm({
        display_name: profile.display_name || '',
        avatar_url: profile.avatar_url || ''
      });
    }
  }, [profile]);

  const userId = session?.user?.id;
  const email = session?.user?.email || '';

  const loadProfile = async () => {
    if (!userId) return;
    setLoading(true);
    setError('');
    try {
      const { data, error: err } = await supabase
        .from('profiles')
        .select('id, email, display_name, avatar_url, plan')
        .eq('id', userId)
        .maybeSingle();
      if (err) throw err;
      if (data) {
        setForm({
          display_name: data.display_name || '',
          avatar_url: data.avatar_url || ''
        });
        onProfileUpdated?.(data);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const loadWallets = async () => {
    if (!userId) return;
    try {
      const { data, error: err } = await supabase
        .from('wallets')
        .select('address, chain_id, created_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });
      if (err) throw err;
      setWallets(data || []);
    } catch (err) {
      setError(err.message);
    }
  };

  useEffect(() => {
    if (userId) {
      loadProfile();
      loadWallets();
    }
  }, [userId]);

  const handleSave = async () => {
    if (!userId) return;
    setSaving(true);
    setError('');
    try {
      const { data, error: err } = await supabase
        .from('profiles')
        .update({
          display_name: form.display_name,
          avatar_url: form.avatar_url,
          email
        })
        .eq('id', userId)
        .select('id, email, display_name, avatar_url, plan')
        .single();
      if (err) throw err;
      onProfileUpdated?.(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const getAccessToken = async () => {
    const { data: { session: current } } = await supabase.auth.getSession();
    return current?.access_token;
  };

  const handleUpgrade = async (nextPlan) => {
    setUpgradeLoading(true);
    setError('');
    try {
      const token = await getAccessToken();
      if (!token) throw new Error('Not signed in.');
      const res = await fetch('/.netlify/functions/create-checkout', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ plan: nextPlan })
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.error || 'Checkout failed.');
      if (body.url) window.location.href = body.url;
    } catch (err) {
      setError(err.message);
    } finally {
      setUpgradeLoading(false);
    }
  };

  const handleWalletConnect = async () => {
    setWalletLoading(true);
    setError('');
    try {
      const token = await getAccessToken();
      if (!token) throw new Error('Not signed in.');
      if (!window.ethereum) throw new Error('No wallet found.');

      const nonceRes = await fetch('/.netlify/functions/wallet-nonce', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const nonceBody = await nonceRes.json();
      if (!nonceRes.ok) throw new Error(nonceBody.error || 'Nonce request failed.');

      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const address = await signer.getAddress();
      const signature = await signer.signMessage(nonceBody.message);
      const network = await provider.getNetwork();

      const verifyRes = await fetch('/.netlify/functions/wallet-verify', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          address,
          signature,
          nonce: nonceBody.nonce,
          chain_id: Number(network.chainId)
        })
      });

      const verifyBody = await verifyRes.json();
      if (!verifyRes.ok) throw new Error(verifyBody.error || 'Wallet verification failed.');

      await loadWallets();
    } catch (err) {
      setError(err.message);
    } finally {
      setWalletLoading(false);
    }
  };

  const avatarPreview = useMemo(() => form.avatar_url || ASSETS.mascot, [form.avatar_url]);

  return html`
    <div className="flex-1 p-12 max-w-2xl mx-auto w-full">
      <h1 className="text-3xl font-bold tracking-tighter mb-10">Settings</h1>

      ${error && html`<div className="mb-6 text-sm text-red-400">${error}</div>`}

      <div className="space-y-12">
        <section>
          <h3 className="text-xs font-bold text-neutral-500 uppercase tracking-widest mb-6">Profile</h3>
          <div className="p-6 rounded-2xl border border-white/5 bg-[#0a0a0a] space-y-6">
            <div className="flex items-center gap-6">
              <img src=${avatarPreview} className="w-16 h-16 rounded-full" />
              <div>
                <div className="font-bold text-lg">${profile?.display_name || 'User'}</div>
                <div className="text-neutral-500 text-sm">${email}</div>
              </div>
            </div>

            <div className="grid gap-4">
              <input
                type="text"
                placeholder="Display name"
                className="w-full px-4 py-3 bg-black border border-white/10 rounded-xl outline-none focus:border-white transition"
                value=${form.display_name}
                onChange=${(e) => setForm({ ...form, display_name: e.target.value })}
              />
              <input
                type="text"
                placeholder="Avatar URL"
                className="w-full px-4 py-3 bg-black border border-white/10 rounded-xl outline-none focus:border-white transition"
                value=${form.avatar_url}
                onChange=${(e) => setForm({ ...form, avatar_url: e.target.value })}
              />
            </div>

            <button
              onClick=${handleSave}
              disabled=${saving || loading}
              className="px-4 py-2 rounded-xl bg-white text-black font-bold text-sm hover:bg-neutral-200 transition flex items-center gap-2"
            >
              ${(saving || loading) && html`<${Loader2} className="animate-spin" size=${16} />`}
              Save Profile
            </button>
          </div>
        </section>

        <section>
          <h3 className="text-xs font-bold text-neutral-500 uppercase tracking-widest mb-6">Account Plan</h3>
          <div className="p-6 rounded-2xl border border-white/5 bg-[#0a0a0a] space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <div className="font-bold text-lg capitalize">${PLAN_LABELS[plan] || 'Free'} Plan</div>
                <div className="text-neutral-500 text-sm">Upgrade instantly with Stripe.</div>
              </div>
              <div className="text-xs text-neutral-500 uppercase tracking-widest">Current</div>
            </div>

            <div className="grid gap-3">
              ${['pro', 'team'].map((tier) => html`
                <div className="flex items-center justify-between border border-white/10 rounded-xl p-4">
                  <div>
                    <div className="font-semibold text-sm uppercase tracking-widest">${PLAN_LABELS[tier]} </div>
                    <div className="text-xs text-neutral-500">Unlock higher usage limits.</div>
                  </div>
                  <button
                    onClick=${() => handleUpgrade(tier)}
                    disabled=${upgradeLoading || plan === tier}
                    className=${`px-4 py-2 rounded-xl font-bold text-sm transition ${plan === tier ? 'bg-white/10 text-white' : 'bg-white text-black hover:bg-neutral-200'}`}
                  >
                    ${plan === tier ? html`<span className="inline-flex items-center gap-2"><${Check} size=${14} /> Active</span>` : 'Upgrade'}
                  </button>
                </div>
              `)}
            </div>
          </div>
        </section>

        <section>
          <h3 className="text-xs font-bold text-neutral-500 uppercase tracking-widest mb-6">Linked Wallets</h3>
          <div className="space-y-4">
            ${wallets.length > 0 && html`
              <div className="space-y-2">
                ${wallets.map((wallet) => html`
                  <div className="px-4 py-3 rounded-xl border border-white/10 bg-[#0a0a0a] text-xs text-neutral-300 flex items-center justify-between">
                    <span>${wallet.address}</span>
                    <span className="text-neutral-500">Chain ${wallet.chain_id || '-'}</span>
                  </div>
                `)}
              </div>
            `}
            <button
              onClick=${handleWalletConnect}
              disabled=${walletLoading}
              className="w-full p-6 rounded-2xl border border-white/5 bg-[#0a0a0a] border-dashed flex items-center justify-center gap-2 text-neutral-500 hover:text-white hover:border-white transition"
            >
              ${walletLoading && html`<${Loader2} className="animate-spin" size=${16} />`}
              <${Plus} size=${18} /> Connect Wallet
            </button>
          </div>
        </section>
      </div>
    </div>
  `;
};
