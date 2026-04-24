import React from 'react';
import { createRoot } from 'react-dom/client';
import { html } from './ui/html.js';
import { LandingPage } from './pages/LandingPage.js';

const container = document.getElementById('root');
createRoot(container).render(html`<${LandingPage} />`);
