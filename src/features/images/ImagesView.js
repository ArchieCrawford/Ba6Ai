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
  isSidebarOpen
}) => {
  const formatAlt = (prompt) => {
    if (!prompt) return 'Generated image';
    const trimmed = String(prompt).trim();
    const short = trimmed.length > 80 ? `${trimmed.slice(0, 77)}...` : trimmed;
    return `Generated image: ${short}`;
  };

  return html`
  <div className="flex-1 min-h-0 overflow-y-auto p-3 md:p-8">
    <div className="max-w-none md:max-w-4xl md:mx-auto">
      <div className="flex items-center gap-3 mb-4">
        <button
          className="md:hidden p-2 -ml-2 rounded-lg text-neutral-300 hover:text-white hover:bg-white/5 transition"
          onClick=${onOpenSidebar}
          aria-label="Open navigation"
          aria-controls="ba6-sidebar"
          aria-expanded=${isSidebarOpen ? 'true' : 'false'}
        >
          <${Menu} size=${20} />
        </button>
        <div>
          <h1 className="text-xl md:text-3xl font-bold tracking-tighter mb-1">Image Generation</h1>
          <p className="text-neutral-500 text-sm md:text-base">Powered by Stable Diffusion XL via Venice.</p>
        </div>
      </div>

      <form onSubmit=${onGenerate} className="flex gap-2 bg-[#0a0a0a] border border-white/10 p-2 rounded-2xl mb-8 md:mb-12 focus-within:border-white transition">
        <label className="sr-only" htmlFor="imagePrompt">Image prompt</label>
        <input
          id="imagePrompt"
          name="imagePrompt"
          className="flex-1 bg-transparent px-4 py-2 rounded-xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/30 focus-visible:ring-offset-0"
          placeholder="A hyper-realistic cyberpunk city in the rain..."
          value=${imagePrompt}
          onChange=${(e) => setImagePrompt(e.target.value)}
        />
        <button className="bg-white text-black px-4 md:px-6 py-2 rounded-xl font-bold hover:bg-neutral-200 transition flex items-center gap-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/40 focus-visible:ring-offset-0">
          ${sending && html`<${Loader2} className="animate-spin" size=${18} />`}
          Generate
        </button>
      </form>

      <div className="grid grid-cols-2 md:grid-cols-3 gap-6">
        ${generations.map(gen => html`
          <div className="group relative aspect-square rounded-2xl overflow-hidden border border-white/10 bg-[#0a0a0a]">
            <img src=${gen.image_url} alt=${formatAlt(gen.prompt)} loading="lazy" className="w-full h-full object-cover transition duration-500 group-hover:scale-110" />
            <div className="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition p-4 flex flex-col justify-end">
              <p className="text-xs font-medium text-white line-clamp-2">${gen.prompt}</p>
            </div>
          </div>
        `)}
      </div>
    </div>
  </div>
`;
};
