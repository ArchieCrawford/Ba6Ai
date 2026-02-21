import React, { useEffect, useMemo, useState } from 'react';
import { html } from '../../ui/html.js';
import { ASSETS } from '../../assets/index.js';
import { Plus, Loader2, Check, Menu, ExternalLink } from 'lucide-react';
import { supabase } from '../../api/supabaseClient.js';
import { resolvePlanFromSubscription } from '../../utils/billing.js';

const PLAN_LABELS = {
  free: 'Free',
  pro: 'Pro',
  team: 'Team'
};

export const SettingsView = ({ profile, session, onProfileUpdated, onOpenSidebar, menuButtonRef, isSidebarOpen }) => {
  const [form, setForm] = useState({ display_name: '', avatar_url: '' });
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(false);
  const [upgradeLoading, setUpgradeLoading] = useState(false);
  const [walletLoading, setWalletLoading] = useState(false);
  const [billingLoading, setBillingLoading] = useState(false);
  const [wallets, setWallets] = useState([]);
  const [subscription, setSubscription] = useState(null);
  const [error, setError] = useState('');
  const plan = (profile?.plan || 'free').toLowerCase();
  const currentPlan = resolvePlanFromSubscription(subscription, plan);

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

  const loadSubscription = async () => {
    if (!userId) return;
    try {
      const { data, error: err } = await supabase
        .from('subscription_status')
        .select('user_id, price_id, subscription_status, current_period_end')
        .eq('user_id', userId)
        .maybeSingle();
      if (err) return;
      setSubscription(data || null);
    } catch (err) {
      // Ignore missing view or sync engine not installed yet.
    }
  };

  useEffect(() => {
    if (userId) {
      loadProfile();
      loadWallets();
      loadSubscription();
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

  const handleBillingPortal = async () => {
    setBillingLoading(true);
    setError('');
    try {
      const token = await getAccessToken();
      if (!token) throw new Error('Not signed in.');
      const res = await fetch('/.netlify/functions/billing-portal', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.error || 'Billing portal failed.');
      if (body.url) window.location.href = body.url;
    } catch (err) {
      setError(err.message);
    } finally {
      setBillingLoading(false);
    }
  };

  const handleWalletConnect = async (chain) => {
    setWalletLoading(true);
    setError('');
    try {
      const { error: authError } = await supabase.auth.signInWithWeb3({ chain });
      if (authError) throw authError;
      await loadWallets();
    } catch (err) {
      setError(err.message);
    } finally {
      setWalletLoading(false);
    }
  };

  const handleWalletUnlink = async (address) => {
    if (!userId) return;
    setWalletLoading(true);
    setError('');
    try {
      const { error: err } = await supabase
        .from('wallets')
        .delete()
        .eq('user_id', userId)
        .eq('address', address);
      if (err) throw err;
      await loadWallets();
    } catch (err) {
      setError(err.message);
    } finally {
      setWalletLoading(false);
    }
  };

  const avatarPreview = useMemo(() => form.avatar_url || ASSETS.mascot, [form.avatar_url]);

  return html`
    <div className="flex-1 min-h-0 overflow-y-auto p-3 md:p-12 max-w-none md:max-w-2xl md:mx-auto w-full">
      <div className="flex items-center gap-3 mb-6 md:mb-8">
        <button
          ref=${menuButtonRef}
          className="md:hidden p-2 -ml-2 rounded-lg text-neutral-300 hover:text-white hover:bg-white/5 transition"
          onClick=${onOpenSidebar}
          aria-label="Open navigation"
          aria-controls="ba6-sidebar"
          aria-expanded=${isSidebarOpen ? 'true' : 'false'}
        >
          <${Menu} size=${20} />
        </button>
        <h1 className="text-2xl md:text-3xl font-bold tracking-tighter">Settings</h1>
      </div>

      ${error && html`<div className="mb-6 text-sm text-red-400">${error}</div>`}

      <div className="space-y-8 md:space-y-12">
        <section>
          <h3 className="text-xs font-bold text-neutral-500 uppercase tracking-widest mb-4 md:mb-6">Profile</h3>
          <div className="p-4 md:p-6 rounded-2xl border border-white/5 bg-[#0a0a0a] space-y-6">
            <div className="flex items-center gap-4 md:gap-6">
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
          <h3 className="text-xs font-bold text-neutral-500 uppercase tracking-widest mb-4 md:mb-6">Account Plan</h3>
          <div className="p-4 md:p-6 rounded-2xl border border-white/5 bg-[#0a0a0a] space-y-4">
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-2">
              <div>
                <div className="font-bold text-lg capitalize">${PLAN_LABELS[currentPlan] || 'Free'} Plan</div>
                <div className="text-neutral-500 text-sm">
                  ${subscription?.subscription_status ? `Status: ${subscription.subscription_status}` : 'Upgrade instantly with Stripe.'}
                </div>
              </div>
              <div className="text-xs text-neutral-500 uppercase tracking-widest">Current</div>
            </div>

            <div className="grid gap-3">
              ${['pro', 'team'].map((tier) => html`
                <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-3 border border-white/10 rounded-xl p-4">
                  <div>
                    <div className="font-semibold text-sm uppercase tracking-widest">${PLAN_LABELS[tier]} </div>
                    <div className="text-xs text-neutral-500">Unlock higher usage limits.</div>
                  </div>
                  <button
                    onClick=${() => handleUpgrade(tier)}
                    disabled=${upgradeLoading || currentPlan === tier}
                    className=${`px-4 py-2 rounded-xl font-bold text-sm transition ${currentPlan === tier ? 'bg-white/10 text-white' : 'bg-white text-black hover:bg-neutral-200'}`}
                  >
                    ${currentPlan === tier ? html`<span className="inline-flex items-center gap-2"><${Check} size=${14} /> Active</span>` : 'Upgrade'}
                  </button>
                </div>
              `)}
            </div>

            <button
              onClick=${handleBillingPortal}
              disabled=${billingLoading}
              className="mt-2 w-full md:w-auto px-4 py-2 rounded-xl border border-white/10 text-sm font-semibold text-neutral-300 hover:text-white hover:border-white transition inline-flex items-center gap-2"
            >
              ${billingLoading && html`<${Loader2} className="animate-spin" size=${14} />`}
              <${ExternalLink} size=${14} /> Manage Billing
            </button>
          </div>
        </section>

        <section>
          <h3 className="text-xs font-bold text-neutral-500 uppercase tracking-widest mb-4 md:mb-6">Linked Wallets</h3>
          <div className="space-y-4">
            ${wallets.length > 0 && html`
              <div className="space-y-2">
                ${wallets.map((wallet) => html`
                  <div className="px-4 py-3 rounded-xl border border-white/10 bg-[#0a0a0a] text-xs text-neutral-300 flex items-center justify-between gap-3">
                    <span className="truncate min-w-0">${wallet.address}</span>
                    <div className="flex items-center gap-3">
                      <span className="text-neutral-500 whitespace-nowrap">Chain ${wallet.chain_id || '-'}</span>
                      <button
                        onClick=${() => handleWalletUnlink(wallet.address)}
                        className="text-[10px] uppercase tracking-widest text-neutral-500 hover:text-white transition"
                      >
                        Unlink
                      </button>
                    </div>
                  </div>
                `)}
              </div>
            `}
            <button
              onClick=${() => handleWalletConnect('ethereum')}
              disabled=${walletLoading}
              className="w-full p-4 md:p-6 rounded-2xl border border-white/5 bg-[#0a0a0a] border-dashed flex items-center justify-center gap-2 text-neutral-500 hover:text-white hover:border-white transition"
            >
              ${walletLoading && html`<${Loader2} className="animate-spin" size=${16} />`}
              <${Plus} size=${18} /> Link Ethereum Wallet
            </button>
            <button
              onClick=${() => handleWalletConnect('solana')}
              disabled=${walletLoading}
              className="w-full p-4 md:p-6 rounded-2xl border border-white/5 bg-[#0a0a0a] border-dashed flex items-center justify-center gap-2 text-neutral-500 hover:text-white hover:border-white transition"
            >
              ${walletLoading && html`<${Loader2} className="animate-spin" size=${16} />`}
              <${Plus} size=${18} /> Link Solana Wallet
            </button>
          </div>
        </section>
      </div>
    </div>
  `;
};
