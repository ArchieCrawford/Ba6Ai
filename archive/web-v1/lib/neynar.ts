export type NeynarResult<T> = {
  data?: T;
  error?: string;
  status?: number;
  raw?: unknown;
};

type VerifyResult = {
  valid: boolean;
  action?: any;
  fid?: number | string;
  error?: string;
  status?: number;
  raw?: unknown;
};

const DEFAULT_BASE = 'https://api.neynar.com';

const normalizeBase = (base: string) => base.replace(/\/+$/, '');

const getBaseUrl = () => normalizeBase(process.env.NEYNAR_BASE_URL || DEFAULT_BASE);

const buildUrl = (path: string) => {
  if (path.startsWith('http')) return path;
  const base = getBaseUrl();
  return `${base}${path.startsWith('/') ? path : `/${path}`}`;
};

const getFrameValidateUrl = () => {
  const base = getBaseUrl();
  if (base.includes('/frame/validate')) return base;
  if (base.endsWith('/v2')) return `${base}/farcaster/frame/validate`;
  return `${base}/v2/farcaster/frame/validate`;
};

const buildHeaders = () => {
  const apiKey = process.env.NEYNAR_API_KEY || '';
  const headers: Record<string, string> = {
    accept: 'application/json'
  };

  if (apiKey) {
    headers['x-api-key'] = apiKey;
    headers['api_key'] = apiKey;
    headers['Authorization'] = `Bearer ${apiKey}`;
  }

  return { apiKey, headers };
};

const fetchJson = async <T>(url: string, options: RequestInit): Promise<NeynarResult<T>> => {
  try {
    const response = await fetch(url, options);
    const raw = await response.json().catch(() => ({}));

    if (!response.ok) {
      return {
        error: raw?.error || raw?.message || 'Neynar request failed.',
        status: response.status,
        raw
      };
    }

    return { data: raw as T, status: response.status, raw };
  } catch (err: any) {
    return { error: err?.message || 'Neynar request failed.' };
  }
};

export const verifyFrameAction = async (payload: any): Promise<VerifyResult> => {
  const { apiKey, headers } = buildHeaders();
  if (!apiKey) return { valid: false, error: 'Missing NEYNAR_API_KEY.' };

  const messageBytes =
    payload?.trustedData?.messageBytes ||
    payload?.trustedData?.message_bytes ||
    payload?.message_bytes_in_hex ||
    payload?.messageBytesInHex;

  if (!messageBytes) {
    return { valid: false, error: 'Missing trustedData.messageBytes.' };
  }

  const result = await fetchJson<any>(getFrameValidateUrl(), {
    method: 'POST',
    headers: {
      ...headers,
      'content-type': 'application/json'
    },
    body: JSON.stringify({ message_bytes_in_hex: messageBytes })
  });

  if (result.error) {
    return { valid: false, error: result.error, status: result.status, raw: result.raw };
  }

  const data = result.data || {};
  if (data?.valid === false) {
    return { valid: false, error: 'Frame validation failed.', raw: data };
  }

  const action = data?.action || data?.data?.action || data?.validated?.action || data?.result?.action || data?.frame?.action;
  const fid = action?.interactor?.fid || action?.fid || data?.fid;

  return { valid: true, action, fid, raw: data };
};

export const fetchSigners = async (
  fid?: number | string,
  options: { message?: string; signature?: string } = {}
): Promise<NeynarResult<any>> => {
  const { apiKey, headers } = buildHeaders();
  if (!apiKey) return { error: 'Missing NEYNAR_API_KEY.' };
  if (!options.message || !options.signature) {
    return { error: 'Missing message or signature for Neynar signer list.' };
  }

  const params = new URLSearchParams();
  if (fid !== undefined && fid !== null) params.set('fid', String(fid));
  params.set('message', options.message);
  params.set('signature', options.signature);

  const url = buildUrl(`/v2/farcaster/signer/list/?${params.toString()}`);
  return fetchJson<any>(url, { method: 'GET', headers });
};

export const fetchProfile = async (fid: number | string): Promise<NeynarResult<any>> => {
  const { apiKey, headers } = buildHeaders();
  if (!apiKey) return { error: 'Missing NEYNAR_API_KEY.' };
  const url = buildUrl(`/v2/farcaster/user/bulk?fids=${encodeURIComponent(String(fid))}`);
  const result = await fetchJson<any>(url, { method: 'GET', headers });
  if (result.error) return result;

  const users = result.data?.users || result.data?.result?.users || [];
  return { data: Array.isArray(users) ? users[0] : users, raw: result.raw };
};

export const fetchCastHistory = async (fid: number | string): Promise<NeynarResult<any>> => {
  const { apiKey, headers } = buildHeaders();
  if (!apiKey) return { error: 'Missing NEYNAR_API_KEY.' };
  const url = buildUrl(`/v2/farcaster/feed/user/${encodeURIComponent(String(fid))}/replies_and_recasts`);
  return fetchJson<any>(url, { method: 'GET', headers });
};
