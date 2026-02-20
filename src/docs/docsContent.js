export const docsContent = {
  title: 'BA6 AI Documentation',
  description: 'Architecture, models, roadmap and features of BA6 AI.',
  sections: [
    {
      id: 'overview',
      title: 'Overview',
      body: [
        'BA6 AI is a decentralized AI interface that routes requests to multiple providers and model families while enforcing plan-based usage limits.',
        'It combines Venice compute, image and video models, Supabase authentication, Stripe subscriptions, and Web3 identity to deliver a unified AI infrastructure layer.'
      ]
    },
    {
      id: 'architecture',
      title: 'Architecture',
      body: [
        'BA6 AI is designed as a thin, fast client with serverless orchestration and strict access controls.'
      ],
      code: `Frontend\n- React + HTM\n- Netlify hosting\n\nBackend\n- Netlify Functions\n- Supabase (Auth + DB)\n- Stripe (subscriptions)\n\nAI Layer\n- Venice API\n- Multiple LLM + Image models\n- Plan-based usage enforcement`
    },
    {
      id: 'models',
      title: 'Models',
      body: [
        'Models are pulled from the Venice model allowlist and grouped by modality. This list can expand as new providers are added.'
      ]
    },
    {
      id: 'features',
      title: 'Features',
      list: [
        'Multi-model AI routing',
        'Text generation',
        'Image generation',
        'Video generation',
        'Subscription plans',
        'Usage metering',
        'Web3 wallet linking',
        'Supabase authentication',
        'Stripe billing',
        'Model switching'
      ]
    },
    {
      id: 'plans',
      title: 'Plans & Usage Limits',
      body: [
        'Usage resets monthly based on the current calendar month. Limits are enforced server-side via Netlify Functions.'
      ],
      table: {
        headers: ['Plan', 'Text / month', 'Images / month'],
        rows: [
          ['Free', '25', '5'],
          ['Pro', '1000', '250'],
          ['Team', '5000', '1000']
        ]
      }
    },
    {
      id: 'roadmap',
      title: 'Roadmap',
      timeline: [
        { quarter: 'Q1', items: ['Subscription system', 'Wallet linking', 'Usage tracking'] },
        { quarter: 'Q2', items: ['API access', 'Team accounts', 'Model analytics'] },
        { quarter: 'Q3', items: ['Tokenized compute routing', 'Governance', 'On-chain usage proofs'] },
        { quarter: 'Q4', items: ['Enterprise integrations', 'Private model hosting'] }
      ]
    },
    {
      id: 'api',
      title: 'API (Coming Soon)',
      body: [
        'A developer API for programmatic access to BA6 AI will ship in a future release. Contact the team for early access.'
      ]
    },
    {
      id: 'web3',
      title: 'Web3 Integration',
      body: [
        'BA6 AI supports wallet signature verification for identity and account linking.',
        'Future releases will support token-based compute routing and on-chain metering.'
      ]
    },
    {
      id: 'security',
      title: 'Security',
      body: [
        'Supabase RLS ensures users only access their own data.',
        'Stripe webhooks are verified with signatures and processed server-side.',
        'Netlify Functions enforce JWT validation and signed wallet verification.'
      ]
    }
  ]
};

export const modelFallbacks = {
  text: [
    'Venice Uncensored',
    'Qwen 3 variants',
    'Mistral',
    'Llama',
    'Claude',
    'Gemini',
    'Grok',
    'DeepSeek'
  ],
  image: [
    'SD35',
    'Flux',
    'HiDream',
    'Qwen Image',
    'Z-Image Turbo'
  ],
  video: [
    'Wan',
    'Kling',
    'LTX',
    'Veo',
    'Sora'
  ]
};
