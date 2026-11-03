// Tiny API client — token persisted in localStorage ("mt_token").
// Vite dev proxy rewrites /api/* -> http://localhost:8787/*

export type User = {
  id: string;
  email: string;
  displayName: string;
  avatarUrl: string | null;
  createdAt: string;
};

const TOKEN_KEY = "mt_token";

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}
export function setToken(t: string | null) {
  if (t) localStorage.setItem(TOKEN_KEY, t);
  else localStorage.removeItem(TOKEN_KEY);
}

async function call<T>(method: string, path: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = {};
  if (body !== undefined) headers["Content-Type"] = "application/json";
  const token = getToken();
  if (token) headers["Authorization"] = `Bearer ${token}`;
  const res = await fetch(`/api${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (res.status === 204) return undefined as T;
  const data = (await res.json().catch(() => ({}))) as { error?: string } & T;
  if (!res.ok) throw new Error(data.error ?? `HTTP ${res.status}`);
  return data;
}

export const api = {
  register: (email: string, password: string, displayName: string) =>
    call<{ user: User; token: string }>("POST", "/v1/auth/register", { email, password, displayName }),
  login: (email: string, password: string) =>
    call<{ user: User; token: string }>("POST", "/v1/auth/login", { email, password }),
  logout: () => call<void>("POST", "/v1/auth/logout"),
  me: () => call<{ user: User }>("GET", "/v1/me"),
  updateMe: (patch: { displayName?: string; avatarUrl?: string | null }) =>
    call<{ user: User }>("PATCH", "/v1/me", patch),
};
