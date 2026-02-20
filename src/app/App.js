import React, { useEffect, useState } from 'react';
import { html } from '../ui/html.js';
import { authApi } from '../api/authApi.js';
import { dbApi } from '../api/dbApi.js';
import { aiApi } from '../api/aiApi.js';
import { isConfigured } from '../api/supabaseClient.js';
import { ASSETS } from '../assets/index.js';
import { LandingPage } from '../pages/LandingPage.js';
import { FarcasterPage } from '../pages/FarcasterPage.js';
import { AuthScreen } from '../auth/AuthScreen.js';
import { Sidebar } from '../components/Sidebar.js';
import { ChatView } from '../features/chat/ChatView.js';
import { ImagesView } from '../features/images/ImagesView.js';
import { SettingsView } from '../features/settings/SettingsView.js';
import { Loader2, X } from 'lucide-react';

export default function App() {
  const [view, setView] = useState('landing');
  const [session, setSession] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [errorState, setErrorState] = useState(null);
  const [activeTab, setActiveTab] = useState('chat');
  const [conversations, setConversations] = useState([]);
  const [activeConv, setActiveConv] = useState(null);
  const [messages, setMessages] = useState([]);
  const [messageInput, setMessageInput] = useState('');
  const [generations, setGenerations] = useState([]);
  const [imagePrompt, setImagePrompt] = useState('');
  const [sending, setSending] = useState(false);

  useEffect(() => {
    if (window.location.pathname === '/farcaster') setView('farcaster');

    if (!isConfigured) {
      setErrorState('Supabase is not configured. Run node scripts/generate-env.js (or set window.__ENV__) with SUPABASE_URL and SUPABASE_ANON_KEY.');
      setLoading(false);
      return;
    }

    authApi.getSession().then(({ data: { session: s } }) => {
      setSession(s);
      if (s) {
        setView('app');
        fetchInitialData(s.user.id);
      }
      setLoading(false);
    });

    const { data: { subscription } } = authApi.onAuthStateChange((_event, s) => {
      setSession(s);
      if (s) {
        setView('app');
        fetchInitialData(s.user.id);
      }
    });

    return () => subscription?.unsubscribe?.();
  }, []);

  const fetchInitialData = async (uid) => {
    try {
      const { data: p, error: profileErr } = await dbApi.getProfile(uid);
      if (profileErr) { setErrorState(profileErr); return; }
      setProfile(p);

      const { data: convs, error: convsErr } = await dbApi.getConversations();
      if (convsErr) { setErrorState(convsErr); return; }

      let nextConvs = convs;
      if (nextConvs.length === 0) {
        const newConv = await dbApi.createConversation('New Chat', 'venice-uncensored');
        nextConvs = [newConv];
      }
      setConversations(nextConvs);
      setActiveConv(nextConvs[0]);

      const { data: gens, error: gensErr } = await dbApi.getGenerations();
      if (gensErr) { setErrorState(gensErr); return; }
      setGenerations(gens);
    } catch (err) {
      console.error('Fetch error:', err);
      setErrorState(err.message);
    }
  };

  useEffect(() => {
    if (activeConv) {
      dbApi.getMessages(activeConv.id).then(({ data, error }) => {
        if (error) setErrorState(error);
        else setMessages(data || []);
      });
    }
  }, [activeConv]);

  const handleSendMessage = async (e) => {
    e.preventDefault();
    if (!messageInput.trim() || sending) return;
    const msg = messageInput;
    setMessageInput('');
    setSending(true);
    try {
      let conversation = activeConv;
      if (!conversation) {
        conversation = await handleNewConversation();
      }
      if (!conversation) throw new Error('No active conversation.');

      const response = await aiApi.chat(conversation.id, msg, conversation.model);
      setMessages(prev => [...prev, { role: 'user', content: msg }, response]);
    } catch (err) {
      alert(err.message);
    } finally {
      setSending(false);
    }
  };

  const handleGenerateImage = async (e) => {
    e.preventDefault();
    if (!imagePrompt.trim() || sending) return;
    setSending(true);
    try {
      const gen = await aiApi.generateImage(imagePrompt, 'sdxl');
      setGenerations(prev => [gen, ...prev]);
      setImagePrompt('');
    } catch (err) {
      alert(err.message);
    } finally {
      setSending(false);
    }
  };

  const handleNewConversation = async () => {
    try {
    const newConv = await dbApi.createConversation('New Chat', 'venice-uncensored');
      setConversations(prev => [newConv, ...prev]);
      setActiveConv(newConv);
      return newConv;
    } catch (err) {
      alert(err.message);
      return null;
    }
  };

  if (loading) return html`
    <div className="h-screen bg-black flex items-center justify-center">
      <${Loader2} className="animate-spin text-white" size=${40} />
    </div>
  `;

  if (errorState) return html`
    <div className="min-h-screen flex items-center justify-center bg-black p-4">
      <div className="bg-[#0a0a0a] border border-white/5 p-8 rounded-3xl shadow-xl w-full max-w-md text-center ink-glow">
        <div className="w-16 h-16 bg-red-950/30 text-red-500 rounded-2xl flex items-center justify-center mx-auto mb-4">
          <${X} size=${32} />
        </div>
        <h1 className="text-xl font-bold text-white mb-2 tracking-tight">Setup Required</h1>
        <p className="text-neutral-500 text-sm mb-6">${errorState}</p>
        <button
          onClick=${() => window.location.reload()}
          className="w-full bg-white text-black py-3 rounded-xl font-bold hover:bg-neutral-200 transition"
        >
          I've run the migrations, reload
        </button>
      </div>
    </div>
  `;

  if (!session && view === 'landing') return html`<${LandingPage} onStart=${() => setView('auth')} />`;
  if (!session && view === 'farcaster') return html`<${FarcasterPage} onStart=${() => setView('auth')} />`;
  if (!session) return html`<${AuthScreen} />`;

  return html`
    <div className="flex h-screen bg-black text-white relative overflow-hidden">
      <img
        src=${ASSETS.mascot}
        className="pointer-events-none select-none absolute right-[-8%] top-1/2 -translate-y-1/2 w-[520px] opacity-5 blur-[1px]"
        aria-hidden="true"
      />
      <${Sidebar}
        activeTab=${activeTab}
        setActiveTab=${setActiveTab}
        profile=${profile}
        conversations=${conversations}
        activeConv=${activeConv}
        setActiveConv=${setActiveConv}
        onNewConversation=${handleNewConversation}
        onSignOut=${() => authApi.signOut()}
      />

      <main className="flex-1 flex flex-col overflow-hidden relative">
        ${activeTab === 'chat' && html`
          <${ChatView}
            activeConv=${activeConv}
            messages=${messages}
            sending=${sending}
            messageInput=${messageInput}
            setMessageInput=${setMessageInput}
            onSend=${handleSendMessage}
          />
        `}

        ${activeTab === 'images' && html`
          <${ImagesView}
            generations=${generations}
            sending=${sending}
            imagePrompt=${imagePrompt}
            setImagePrompt=${setImagePrompt}
            onGenerate=${handleGenerateImage}
          />
        `}

        ${activeTab === 'settings' && html`
          <${SettingsView}
            profile=${profile}
            session=${session}
            onProfileUpdated=${(nextProfile) => setProfile(nextProfile)}
          />
        `}
      </main>
    </div>
  `;
}
