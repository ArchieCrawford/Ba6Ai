const readWindowEnv = () => {
  if (typeof window === 'undefined') return {};
  return window.__ENV__ || {};
};

const readImportMetaEnv = () => {
  if (typeof import.meta === 'undefined') return {};
  return import.meta.env || {};
};

const readProcessEnv = () => {
  if (typeof process === 'undefined') return {};
  return process.env || {};
};

const env = {
  ...readProcessEnv(),
  ...readImportMetaEnv(),
  ...readWindowEnv()
};

export const getEnv = (key, fallback = '') => {
  const value = env[key];
  return value !== undefined && value !== null && value !== '' ? value : fallback;
};
