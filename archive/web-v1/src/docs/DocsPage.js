import React, { useEffect, useMemo, useRef, useState } from 'react';
import { html } from '../ui/html.js';
import { docsContent, modelFallbacks } from './docsContent.js';
import { DocsLayout } from './DocsLayout.js';

const fetchModelsByType = async (type) => {
  const response = await fetch(`/.netlify/functions/venice-models?type=${type}`);
  if (!response.ok) return null;
  const data = await response.json();
  if (!Array.isArray(data)) return null;
  return data.map((model) => model.name || model.id).filter(Boolean);
};

const useMeta = () => {
  useEffect(() => {
    const setMeta = (selector, attrs) => {
      let tag = document.querySelector(selector);
      if (!tag) {
        tag = document.createElement('meta');
        if (attrs.property) tag.setAttribute('property', attrs.property);
        if (attrs.name) tag.setAttribute('name', attrs.name);
        document.head.appendChild(tag);
      }
      Object.entries(attrs).forEach(([key, value]) => {
        if (value) tag.setAttribute(key, value);
      });
    };

    document.title = docsContent.title;
    setMeta('meta[name="description"]', { name: 'description', content: docsContent.description });
    setMeta('meta[property="og:title"]', { property: 'og:title', content: docsContent.title });
    setMeta('meta[property="og:description"]', { property: 'og:description', content: docsContent.description });
    setMeta('meta[property="og:type"]', { property: 'og:type', content: 'website' });
  }, []);
};

export const DocsPage = () => {
  const [activeSection, setActiveSection] = useState('overview');
  const [isNavOpen, setIsNavOpen] = useState(false);
  const [models, setModels] = useState({ text: [], image: [], video: [] });
  const navRef = useRef(null);
  const menuButtonRef = useRef(null);
  const wasOpen = useRef(false);

  useMeta();

  useEffect(() => {
    let isMounted = true;
    const loadModels = async () => {
      const [text, image, video] = await Promise.all([
        fetchModelsByType('text'),
        fetchModelsByType('image'),
        fetchModelsByType('video')
      ]);
      if (!isMounted) return;
      setModels({
        text: text && text.length ? text : modelFallbacks.text,
        image: image && image.length ? image : modelFallbacks.image,
        video: video && video.length ? video : modelFallbacks.video
      });
    };
    loadModels();
    return () => {
      isMounted = false;
    };
  }, []);

  useEffect(() => {
    const sectionIds = docsContent.sections.map((section) => section.id);
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setActiveSection(entry.target.id);
          }
        });
      },
      { rootMargin: '-30% 0px -60% 0px', threshold: 0.1 }
    );

    sectionIds.forEach((id) => {
      const el = document.getElementById(id);
      if (el) observer.observe(el);
    });

    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!isNavOpen) return;
    const isMobile = window.matchMedia('(max-width: 767px)').matches;
    if (!isMobile) return;
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prevOverflow;
    };
  }, [isNavOpen]);

  useEffect(() => {
    if (!isNavOpen) return;
    const nav = navRef.current;
    if (!nav) return;

    const focusableSelector = [
      'a[href]',
      'button:not([disabled])',
      'textarea',
      'input',
      'select',
      '[tabindex]:not([tabindex="-1"])'
    ].join(',');

    const getFocusable = () => Array.from(nav.querySelectorAll(focusableSelector))
      .filter((el) => el.offsetParent !== null);

    const focusInitial = () => {
      const items = getFocusable();
      if (items.length > 0) items[0].focus();
      else nav.focus();
    };

    const handleKeyDown = (event) => {
      if (event.key === 'Escape') {
        const isDesktop = window.matchMedia('(min-width: 768px)').matches;
        if (isDesktop) {
          setIsNavOpen(false);
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
  }, [isNavOpen]);

  useEffect(() => {
    if (wasOpen.current && !isNavOpen) {
      menuButtonRef.current?.focus?.();
    }
    wasOpen.current = isNavOpen;
  }, [isNavOpen]);

  const closeNav = () => setIsNavOpen(false);

  const scrollToSection = (id) => {
    const el = document.getElementById(id);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'start' });
      setActiveSection(id);
    }
    closeNav();
  };

  const modelGroups = useMemo(() => ([
    { label: 'Text Models', items: models.text },
    { label: 'Image Models', items: models.image },
    { label: 'Video Models', items: models.video }
  ]), [models]);

  return html`
    <${DocsLayout}
      sections=${docsContent.sections}
      activeSection=${activeSection}
      onNavigate=${scrollToSection}
      isNavOpen=${isNavOpen}
      setIsNavOpen=${setIsNavOpen}
      navRef=${navRef}
      menuButtonRef=${menuButtonRef}
    >
      ${docsContent.sections.map((section) => html`
        <section id=${section.id} className="scroll-mt-24">
          <h2 className="text-2xl md:text-3xl font-bold tracking-tight mb-4">${section.title}</h2>
          ${section.body && section.body.map((line) => html`
            <p className="text-neutral-300 leading-relaxed mb-4">${line}</p>
          `)}

          ${section.code && html`
            <pre className="bg-[#0a0a0a] border border-white/10 rounded-2xl p-6 text-sm text-neutral-200 overflow-auto">
${section.code}
            </pre>
          `}

          ${section.table && html`
            <div className="overflow-hidden border border-white/10 rounded-2xl">
              <table className="w-full text-sm">
                <thead className="bg-white/5 text-neutral-300">
                  <tr>
                    ${section.table.headers.map((header) => html`<th className="text-left px-4 py-3">${header}</th>`)}
                  </tr>
                </thead>
                <tbody>
                  ${section.table.rows.map((row) => html`
                    <tr className="border-t border-white/10">
                      ${row.map((cell) => html`<td className="px-4 py-3">${cell}</td>`)}
                    </tr>
                  `)}
                </tbody>
              </table>
            </div>
          `}

          ${section.timeline && html`
            <div className="space-y-4">
              ${section.timeline.map((item) => html`
                <div className="border border-white/10 rounded-2xl p-4">
                  <div className="text-xs uppercase tracking-widest text-neutral-500 mb-2">${item.quarter}</div>
                  <ul className="space-y-2 text-sm text-neutral-300">
                    ${item.items.map((entry) => html`<li>${entry}</li>`)}
                  </ul>
                </div>
              `)}
            </div>
          `}

          ${section.list && html`
            <ul className="space-y-2 text-sm text-neutral-300">
              ${section.list.map((item) => html`<li>${item}</li>`)}
            </ul>
          `}

          ${section.id === 'models' && html`
            <div className="mt-8 space-y-6">
              ${modelGroups.map((group) => html`
                <div className="border border-white/10 rounded-2xl p-4">
                  <div className="text-xs uppercase tracking-widest text-neutral-500 mb-3">${group.label}</div>
                  <div className="flex flex-wrap gap-2">
                    ${group.items.map((model) => html`
                      <span className="text-xs px-3 py-1 rounded-full bg-white/5 text-neutral-200">${model}</span>
                    `)}
                  </div>
                </div>
              `)}
            </div>
          `}
        </section>
      `)}
    </${DocsLayout}>
  `;
};
