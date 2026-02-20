import React from 'react';
import { html } from '../../ui/html.js';
import { Loader2, Menu } from 'lucide-react';

export const ImagesView = ({
  generations,
  sending,
  imagePrompt,
  setImagePrompt,
  onGenerate,
  onOpenSidebar,
  menuButtonRef,
  isSidebarOpen
}) => html`
  <div className="flex-1 min-h-0 overflow-y-auto p-4 md:p-8">
    <div className="max-w-4xl mx-auto">
      <div className="flex items-center gap-3 mb-4">
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
        <div>
          <h1 className="text-2xl md:text-3xl font-bold tracking-tighter mb-1">Image Generation</h1>
          <p className="text-neutral-500 text-sm md:text-base">Powered by Stable Diffusion XL via Venice.</p>
        </div>
      </div>

      <form onSubmit=${onGenerate} className="flex gap-2 bg-[#0a0a0a] border border-white/10 p-2 rounded-2xl mb-12 focus-within:border-white transition">
        <input
          className="flex-1 bg-transparent px-4 py-2 outline-none"
          placeholder="A hyper-realistic cyberpunk city in the rain..."
          value=${imagePrompt}
          onChange=${(e) => setImagePrompt(e.target.value)}
        />
        <button className="bg-white text-black px-6 py-2 rounded-xl font-bold hover:bg-neutral-200 transition flex items-center gap-2">
          ${sending && html`<${Loader2} className="animate-spin" size=${18} />`}
          Generate
        </button>
      </form>

      <div className="grid grid-cols-2 md:grid-cols-3 gap-6">
        ${generations.map(gen => html`
          <div className="group relative aspect-square rounded-2xl overflow-hidden border border-white/10 bg-[#0a0a0a]">
            <img src=${gen.image_url} className="w-full h-full object-cover transition duration-500 group-hover:scale-110" />
            <div className="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition p-4 flex flex-col justify-end">
              <p className="text-xs font-medium text-white line-clamp-2">${gen.prompt}</p>
            </div>
          </div>
        `)}
      </div>
    </div>
  </div>
`;
