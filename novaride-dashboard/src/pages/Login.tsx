import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { ShieldHalf } from 'lucide-react';
import { signIn } from '../lib/auth';

export function Login() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('ops@novaride.ph');
  const [password, setPassword] = useState('');

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    signIn(email);
    navigate('/', { replace: true });
  };

  const field =
    'w-full rounded-lg border border-line bg-ink px-3 py-2 text-sm text-txt placeholder:text-txtdim/60 focus:border-accent focus:outline-none';

  return (
    <div className="flex min-h-screen items-center justify-center bg-ink p-6">
      <div className="panel w-full max-w-[380px] p-8">
        <div className="mb-6 flex flex-col items-center gap-2 text-center">
          <ShieldHalf size={28} className="text-accent" aria-hidden="true" />
          <span className="text-xl font-bold tracking-tight text-txt">NovaRide</span>
          <span className="text-xs uppercase tracking-wider text-txtdim">
            TNVS Operations Console
          </span>
        </div>

        <form onSubmit={onSubmit} className="flex flex-col gap-4">
          <label className="flex flex-col gap-1.5">
            <span className="text-xs font-medium text-txtdim">Email</span>
            <input
              type="email"
              required
              autoComplete="username"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className={field}
              placeholder="ops@novaride.ph"
            />
          </label>

          <label className="flex flex-col gap-1.5">
            <span className="text-xs font-medium text-txtdim">Password</span>
            <input
              type="password"
              required
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className={field}
              placeholder="••••••••"
            />
          </label>

          <button
            type="submit"
            className="mt-1 rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-ink transition-colors hover:bg-accent/90"
          >
            Sign in
          </button>
        </form>

        <p className="mt-6 text-center text-[11px] leading-relaxed text-txtdim">
          Demo shell — any credentials sign you in.
          <br />
          Firebase Auth arrives in a later phase.
        </p>
      </div>
    </div>
  );
}
