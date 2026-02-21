import React, { useEffect, useRef, useState } from 'react';
import { html } from '../ui/html.js';
import { authApi } from '../api/authApi.js';
import { supabase } from '../api/supabaseClient.js';
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
import { DocsPage } from '../docs/DocsPage.js';
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
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const drawerRef = useRef(null);
  const menuButtonRef = useRef(null);
  const wasSidebarOpen = useRef(false);
  const [usage, setUsage] = useState({ text_count: 0, image_count: 0, month_key: '' });

  const closeSidebar = () => setIsSidebarOpen(false);
  const openSidebar = () => setIsSidebarOpen(true);

  useEffect(() => {
    if (window.location.pathname === '/farcaster') setView('farcaster');
    if (window.location.pathname.startsWith('/docs')) {
      setView('docs');
      setLoading(false);
      return;
    }

    if (!isConfigured) {
      setErrorState('Supabase is not configured. Run node scripts/generate-env.js (or set window.__ENV__) with SUPABASE_URL and SUPABASE_ANON_KEY.');
      setLoading(false);
      return;
    }

    authApi.getSession().then(({ data: { session: s }, error }) => {
      if (error) {
        authApi.signOut();
        setSession(null);
        setLoading(false);
        return;
      }
      setSession(s);
      if (s) {
        setView('app');
        fetchInitialData(s.user.id);
        supabase?.auth?.startAutoRefresh?.();
      }
      setLoading(false);
    });

    const { data: { subscription } } = authApi.onAuthStateChange((event, s) => {
      if (event === 'SIGNED_OUT') {
        supabase?.auth?.stopAutoRefresh?.();
      }
      if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') {
        supabase?.auth?.startAutoRefresh?.();
      }
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

      const monthKey = new Date().toISOString().slice(0, 7);
      const { data: usageRow, error: usageErr } = await dbApi.getUsageMonthly(uid, monthKey);
      if (usageErr) { setErrorState(usageErr); return; }
      setUsage(usageRow || { text_count: 0, image_count: 0, month_key: monthKey });
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

  useEffect(() => {
    if (!isSidebarOpen) return;
    const isMobile = window.matchMedia('(max-width: 767px)').matches;
    if (!isMobile) return;
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prevOverflow;
    };
  }, [isSidebarOpen]);

  useEffect(() => {
    if (!isSidebarOpen) return;
    const drawer = drawerRef.current;
    if (!drawer) return;

    const focusableSelector = [
      'a[href]',
      'button:not([disabled])',
      'textarea',
      'input',
      'select',
      '[tabindex]:not([tabindex="-1"])'
    ].join(',');

    const getFocusable = () => Array.from(drawer.querySelectorAll(focusableSelector))
      .filter((el) => el.offsetParent !== null);

    const focusInitial = () => {
      const items = getFocusable();
      if (items.length > 0) items[0].focus();
      else drawer.focus();
    };

    const handleKeyDown = (event) => {
      if (event.key === 'Escape') {
        const isDesktop = window.matchMedia('(min-width: 768px)').matches;
        if (isDesktop) {
          closeSidebar();
        }
        return;
      }

      if (event.key === 'Tab') {
        const items = getFocusable();
        if (items.length === 0) {
          event.preventDefault();
          return;
        }
        const first = items[0];
        const last = items[items.length - 1];
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }
    };

    setTimeout(focusInitial, 0);
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [isSidebarOpen]);

  useEffect(() => {
    if (wasSidebarOpen.current && !isSidebarOpen) {
      menuButtonRef.current?.focus?.();
    }
    wasSidebarOpen.current = isSidebarOpen;
  }, [isSidebarOpen]);

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
    <div className="min-h-[100dvh] bg-black flex items-center justify-center">
      <${Loader2} className="animate-spin text-white" size=${40} />
    </div>
  `;

  if (errorState) return html`
    <div className="min-h-[100dvh] flex items-center justify-center bg-black p-4">
      <div className="bg-[#0a0a0a] border border-white/5 p-6 md:p-8 rounded-3xl shadow-xl w-full md:max-w-md text-center ink-glow">
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
  if (view === 'docs') return html`<${DocsPage} />`;
  if (!session) return html`<${AuthScreen} />`;

  return html`
    <div className="flex min-h-[100dvh] md:h-screen bg-black text-white relative overflow-hidden">
      <img
        src=${ASSETS.mascot}
        className="pointer-events-none select-none absolute right-[-8%] top-1/2 -translate-y-1/2 w-[520px] opacity-5 blur-[1px] hidden md:block"
        aria-hidden="true"
      />

      ${isSidebarOpen && html`
        <div
          className="fixed inset-0 bg-black/60 z-30 md:hidden"
          onClick=${closeSidebar}
          aria-hidden="true"
        ></div>
      `}

      <div
        ref=${drawerRef}
        className=${`fixed inset-y-0 left-0 z-40 transform transition-transform duration-300 bg-black w-[min(70vw,260px)] md:w-64 md:static md:translate-x-0 ${isSidebarOpen ? 'translate-x-0' : '-translate-x-full'}`}
        role="dialog"
        aria-modal=${isSidebarOpen ? 'true' : 'false'}
        aria-label="Main navigation"
        tabIndex="-1"
        id="ba6-sidebar"
      >
        <${Sidebar}
          activeTab=${activeTab}
          setActiveTab=${setActiveTab}
          profile=${profile}
          conversations=${conversations}
          activeConv=${activeConv}
          setActiveConv=${setActiveConv}
          onNewConversation=${handleNewConversation}
          onSignOut=${() => authApi.signOut()}
          onNavSelect=${closeSidebar}
          onClose=${closeSidebar}
          usage=${usage}
        />
      </div>

      <main className="flex-1 flex flex-col relative min-h-0 overflow-hidden">
        ${activeTab === 'chat' && html`
          <${ChatView}
            activeConv=${activeConv}
            messages=${messages}
            sending=${sending}
            messageInput=${messageInput}
            setMessageInput=${setMessageInput}
            onSend=${handleSendMessage}
            onOpenSidebar=${openSidebar}
            menuButtonRef=${menuButtonRef}
            isSidebarOpen=${isSidebarOpen}
          />
        `}

        ${activeTab === 'images' && html`
          <${ImagesView}
            generations=${generations}
            sending=${sending}
            imagePrompt=${imagePrompt}
            setImagePrompt=${setImagePrompt}
            onGenerate=${handleGenerateImage}
            onOpenSidebar=${openSidebar}
            menuButtonRef=${menuButtonRef}
            isSidebarOpen=${isSidebarOpen}
          />
        `}

        ${activeTab === 'settings' && html`
          <${SettingsView}
            profile=${profile}
            session=${session}
            onProfileUpdated=${(nextProfile) => setProfile(nextProfile)}
            onOpenSidebar=${openSidebar}
            menuButtonRef=${menuButtonRef}
            isSidebarOpen=${isSidebarOpen}
          />
        `}
      </main>
    </div>
  `;
}
