import React, { useState } from 'react';
import { html } from '../ui/html.js';
import { ASSETS } from '../assets/index.js';
import { authApi } from '../api/authApi.js';
import { supabase } from '../api/supabaseClient.js';
import { Loader2, Wallet } from 'lucide-react';

export const AuthScreen = () => {
  const [isLogin, setIsLogin] = useState(true);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleEmailAuth = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      if (isLogin) {
        const { error: err } = await authApi.signIn(email, password);
        if (err) throw err;
      } else {
        const { error: err } = await authApi.signUp(email, password, name);
        if (err) throw err;
        alert('Check email for confirmation');
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleWalletAuth = async (chain) => {
    setLoading(true);
    setError('');
    try {
      if (!supabase) throw new Error('Supabase is not configured.');
      const { error: authError } = await supabase.auth.signInWithWeb3({ chain });
      if (authError) throw authError;
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return html`
    <div className="min-h-[100dvh] flex items-center justify-center bg-black p-4 relative overflow-hidden">
      <img
        src=${ASSETS.mascot}
        className="pointer-events-none select-none absolute right-[-6%] top-1/2 -translate-y-1/2 w-[360px] opacity-10 blur-[1px] hidden md:block"
        alt=""
        aria-hidden="true"
      />
      <div className="w-full md:max-w-md bg-[#0a0a0a] border border-white/5 p-6 md:p-8 rounded-3xl ink-glow relative z-10">
        <div className="text-center mb-8 md:mb-10">
          <div className="relative w-16 h-16 mx-auto mb-4">
            <div className="absolute inset-0 bg-white/5 blur-xl rounded-full" />
            <img src=${ASSETS.mascot} alt="BA6 AI" className="w-16 h-16 rounded-2xl relative z-10" />
          </div>
          <h1 className="text-2xl font-bold tracking-tight">BA6 AI</h1>
        </div>

        <div className="space-y-4">
          <div className="grid gap-3">
            <button onClick=${() => handleWalletAuth('ethereum')} className="w-full bg-white text-black py-3 rounded-xl font-bold flex items-center justify-center gap-2 hover:bg-neutral-200 transition">
              <${Wallet} size=${20} /> Continue with Ethereum
            </button>
            <button onClick=${() => handleWalletAuth('solana')} className="w-full border border-white/10 py-3 rounded-xl font-bold flex items-center justify-center gap-2 hover:bg-white/5 transition text-white">
              <${Wallet} size=${20} /> Continue with Solana
            </button>
          </div>

          <div className="flex items-center gap-4 my-6">
            <div className="flex-1 h-px bg-white/5"></div>
            <span className="text-neutral-500 text-[10px] font-bold tracking-widest uppercase">Or</span>
            <div className="flex-1 h-px bg-white/5"></div>
          </div>

          <form onSubmit=${handleEmailAuth} className="space-y-4">
            ${!isLogin && html`
              <div className="space-y-2">
                <label htmlFor="fullName" className="text-xs font-semibold text-neutral-400">Full name</label>
                <input
                  id="fullName"
                  name="fullName"
                  type="text"
                  placeholder="Full name"
                  autoComplete="name"
                  required
                  className="w-full px-4 py-3 bg-black border border-white/10 rounded-xl focus:border-white transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/30 focus-visible:ring-offset-0"
                  value=${name}
                  onChange=${(e) => setName(e.target.value)}
                />
              </div>
            `}
            <div className="space-y-2">
              <label htmlFor="email" className="text-xs font-semibold text-neutral-400">Email</label>
              <input
                id="email"
                name="email"
                type="email"
                placeholder="Email"
                autoComplete="email"
                required
                className="w-full px-4 py-3 bg-black border border-white/10 rounded-xl focus:border-white transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/30 focus-visible:ring-offset-0"
                value=${email}
                onChange=${(e) => setEmail(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <label htmlFor="password" className="text-xs font-semibold text-neutral-400">Password</label>
              <input
                id="password"
                name="password"
                type="password"
                placeholder="Password"
                autoComplete=${isLogin ? 'current-password' : 'new-password'}
                required
                className="w-full px-4 py-3 bg-black border border-white/10 rounded-xl focus:border-white transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/30 focus-visible:ring-offset-0"
                value=${password}
                onChange=${(e) => setPassword(e.target.value)}
              />
            </div>
            ${error && html`<p className="text-red-500 text-xs" role="alert">${error}</p>`}
            <button disabled=${loading} className="w-full border border-white/10 py-3 rounded-xl font-bold hover:bg-white/5 transition flex items-center justify-center gap-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/30 focus-visible:ring-offset-0">
              ${loading && html`<${Loader2} className="animate-spin" size=${18} />`}
              ${isLogin ? 'Sign In' : 'Sign Up'}
            </button>
          </form>

          <button onClick=${() => setIsLogin(!isLogin)} className="w-full text-center text-sm text-neutral-500 hover:text-white transition">
            ${isLogin ? 'No account? Sign up' : 'Have an account? Sign in'}
          </button>
        </div>
      </div>
    </div>
  `;
};
