/**
 * Session shim for the shell. Real Firebase Auth replaces this later —
 * keep every consumer on these three functions so the swap is contained.
 */
const SESSION_KEY = 'novaride.session';

export interface OperatorSession {
  email: string;
  displayName: string;
}

export function getSession(): OperatorSession | null {
  const raw = sessionStorage.getItem(SESSION_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as OperatorSession;
  } catch {
    return null;
  }
}

export function signIn(email: string): OperatorSession {
  const session: OperatorSession = { email, displayName: 'Ops Admin' };
  sessionStorage.setItem(SESSION_KEY, JSON.stringify(session));
  return session;
}

export function signOut(): void {
  sessionStorage.removeItem(SESSION_KEY);
}

export function initials(name: string): string {
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase())
    .join('');
}
