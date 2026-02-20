import React, { useState } from 'react';
import { html } from '../ui/html.js';
import { ASSETS } from '../assets/index.js';
import { authApi } from '../api/authApi.js';
import { Loader2, Wallet } from 'lucide-react';
import { ethers } from 'ethers';

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

  const handleWalletAuth = async () => {
    if (!window.ethereum) return alert('No wallet found');
    setLoading(true);
    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const address = await signer.getAddress();
      const nonce = `Sign this message to login to BA6 AI: ${Math.random()}`;
      await signer.signMessage(nonce);
      alert(`Wallet ${address.substring(0, 6)}... authenticated! (Connecting to profile...)`);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return html`
    <div className="min-h-screen flex items-center justify-center bg-black p-4">
      <div className="w-full max-w-md bg-[#0a0a0a] border border-white/5 p-8 rounded-3xl ink-glow">
        <div className="text-center mb-10">
          <div className="relative w-16 h-16 mx-auto mb-4">
            <div className="absolute inset-0 bg-white/5 blur-xl rounded-full" />
            <img src=${ASSETS.mascot} className="w-16 h-16 rounded-2xl relative z-10" />
          </div>
          <h1 className="text-2xl font-bold tracking-tight">BA6 AI</h1>
        </div>

        <div className="space-y-4">
          <button onClick=${handleWalletAuth} className="w-full bg-white text-black py-3 rounded-xl font-bold flex items-center justify-center gap-2 hover:bg-neutral-200 transition">
            <${Wallet} size=${20} /> Continue with Wallet
          </button>

          <div className="flex items-center gap-4 my-6">
            <div className="flex-1 h-px bg-white/5"></div>
            <span className="text-neutral-500 text-[10px] font-bold tracking-widest uppercase">Or</span>
            <div className="flex-1 h-px bg-white/5"></div>
          </div>

          <form onSubmit=${handleEmailAuth} className="space-y-4">
            ${!isLogin && html`
              <input
                type="text" placeholder="Full Name" required
                className="w-full px-4 py-3 bg-black border border-white/10 rounded-xl outline-none focus:border-white transition"
                value=${name} onChange=${(e) => setName(e.target.value)}
              />
            `}
            <input
              type="email" placeholder="Email" required
              className="w-full px-4 py-3 bg-black border border-white/10 rounded-xl outline-none focus:border-white transition"
              value=${email} onChange=${(e) => setEmail(e.target.value)}
            />
            <input
              type="password" placeholder="Password" required
              className="w-full px-4 py-3 bg-black border border-white/10 rounded-xl outline-none focus:border-white transition"
              value=${password} onChange=${(e) => setPassword(e.target.value)}
            />
            ${error && html`<p className="text-red-500 text-xs">${error}</p>`}
            <button disabled=${loading} className="w-full border border-white/10 py-3 rounded-xl font-bold hover:bg-white/5 transition flex items-center justify-center gap-2">
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
