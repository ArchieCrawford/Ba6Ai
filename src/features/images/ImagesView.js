import React from 'react';
import { html } from '../../ui/html.js';
import { Loader2 } from 'lucide-react';

export const ImagesView = ({
  generations,
  sending,
  imagePrompt,
  setImagePrompt,
  onGenerate
}) => html`
  <div className="flex-1 overflow-y-auto p-8">
    <div className="max-w-4xl mx-auto">
      <h1 className="text-3xl font-bold tracking-tighter mb-2">Image Generation</h1>
      <p className="text-neutral-500 mb-8">Powered by Stable Diffusion XL via Venice.</p>

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
