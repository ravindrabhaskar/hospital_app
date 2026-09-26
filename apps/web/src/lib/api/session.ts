import type { AuthSession, Me } from "./types";

/** Tokens are held in memory, mirrored to sessionStorage so a reload keeps the tab signed in. */
export interface StoredSession {
  accessToken: string;
  refreshToken: string;
  /** epoch ms */
  expiresAt: number;
  user: Me;
  /**
   * The user chose "Skip for now" on the MFA step because the API does not enforce MFA
   * (MFA_ENFORCED=false, dev). Cleared by any 403 MFA_REQUIRED.
   */
  mfaSkipped?: boolean;
}

const STORAGE_KEY = "cc.session.v1";

type Listener = (session: StoredSession | null) => void;

export class TokenStore {
  private session: StoredSession | null = null;
  private listeners = new Set<Listener>();
  private hydrated = false;

  constructor(private readonly storage: Pick<Storage, "getItem" | "setItem" | "removeItem"> | null = safeSessionStorage()) {}

  private hydrate() {
    if (this.hydrated) return;
    this.hydrated = true;
    if (!this.storage) return;
    try {
      const raw = this.storage.getItem(STORAGE_KEY);
      if (raw) this.session = JSON.parse(raw) as StoredSession;
    } catch {
      this.session = null;
    }
  }

  get(): StoredSession | null {
    this.hydrate();
    return this.session;
  }

  setFromAuth(auth: AuthSession) {
    this.set({
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
      expiresAt: Date.now() + auth.expiresIn * 1000,
      user: auth.user,
    });
  }

  set(session: StoredSession | null) {
    this.hydrated = true;
    this.session = session;
    if (this.storage) {
      try {
        if (session) this.storage.setItem(STORAGE_KEY, JSON.stringify(session));
        else this.storage.removeItem(STORAGE_KEY);
      } catch {
        /* storage unavailable (private mode) – memory only */
      }
    }
    this.listeners.forEach((l) => l(session));
  }

  updateUser(user: Me) {
    const s = this.get();
    if (s) this.set({ ...s, user });
  }

  setMfaSkipped(value: boolean) {
    const s = this.get();
    if (s) this.set({ ...s, mfaSkipped: value });
  }

  clear() {
    this.set(null);
  }

  subscribe(listener: Listener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}

function safeSessionStorage(): Storage | null {
  try {
    return typeof window !== "undefined" ? window.sessionStorage : null;
  } catch {
    return null;
  }
}
