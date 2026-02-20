import React from 'react';
import { html } from '../ui/html.js';
import { ASSETS } from '../assets/index.js';
import { Menu, X, ExternalLink } from 'lucide-react';

export const DocsLayout = ({
  sections,
  activeSection,
  onNavigate,
  isNavOpen,
  setIsNavOpen,
  navRef,
  menuButtonRef,
  children
}) => html`
  <div className="min-h-screen bg-black text-white relative">
    ${isNavOpen && html`
      <div
        className="fixed inset-0 bg-black/60 z-30 md:hidden"
        onClick=${() => setIsNavOpen(false)}
        aria-hidden="true"
      ></div>
    `}

    <header className="border-b border-white/5 bg-black/80 backdrop-blur sticky top-0 z-20">
      <div className="max-w-6xl mx-auto flex items-center justify-between px-4 md:px-8 py-4">
        <div className="flex items-center gap-3">
          <button
            ref=${menuButtonRef}
            className="md:hidden p-2 -ml-2 rounded-lg text-neutral-300 hover:text-white hover:bg-white/5 transition"
            onClick=${() => setIsNavOpen(true)}
            aria-label="Open documentation navigation"
            aria-controls="ba6-docs-nav"
            aria-expanded=${isNavOpen ? 'true' : 'false'}
          >
            <${Menu} size=${20} />
          </button>
          <img src=${ASSETS.mascot} className="w-7 h-7 rounded-md" />
          <div className="font-semibold tracking-tight">BA6 AI Docs</div>
        </div>
        <a href="/" className="text-sm text-neutral-400 hover:text-white transition inline-flex items-center gap-2">
          Back to App <${ExternalLink} size=${14} />
        </a>
      </div>
    </header>

    <div className="max-w-6xl mx-auto px-4 md:px-8 py-8 md:py-12 grid md:grid-cols-[240px_minmax(0,1fr)] gap-8">
      <nav
        id="ba6-docs-nav"
        ref=${navRef}
        className=${`fixed md:static inset-y-0 left-0 z-40 bg-black md:bg-transparent w-[min(80vw,320px)] md:w-auto transform transition-transform duration-300 ${isNavOpen ? 'translate-x-0' : '-translate-x-full'} md:translate-x-0`}
        role="dialog"
        aria-modal=${isNavOpen ? 'true' : 'false'}
        aria-label="Documentation navigation"
        tabIndex="-1"
      >
        <div className="h-full md:h-auto md:sticky md:top-24 p-6 md:p-0 border-r border-white/5 md:border-none">
          <div className="flex items-center justify-between md:hidden mb-6">
            <div className="text-xs uppercase tracking-widest text-neutral-500">Docs</div>
            <button
              onClick=${() => setIsNavOpen(false)}
              className="text-neutral-400 hover:text-white transition"
              aria-label="Close documentation navigation"
            >
              <${X} size=${20} />
            </button>
          </div>
          <div className="space-y-1">
            ${sections.map((section) => html`
              <button
                onClick=${() => onNavigate(section.id)}
                className=${`w-full text-left px-3 py-2 rounded-lg text-sm transition ${activeSection === section.id ? 'bg-white/10 text-white' : 'text-neutral-500 hover:text-white hover:bg-white/5'}`}
              >
                ${section.title}
              </button>
            `)}
          </div>
        </div>
      </nav>

      <main className="space-y-16">
        ${children}
      </main>
    </div>
  </div>
`;
