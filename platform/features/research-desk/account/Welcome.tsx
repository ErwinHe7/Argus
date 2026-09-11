import React, { useState } from 'react';
import { ArrowRight, LogOut, UserRound } from 'lucide-react';
import { useIdentity } from '../../strategy-lab/Identity';
import { signIn } from '../../strategy-lab/auth';
import './welcome.css';

export function AccountControl() {
  const { user, loading } = useIdentity();
  return <a className="desk-account" href="#/welcome" aria-label={user ? 'Your account' : 'Sign in'}><UserRound size={16}/><span>{loading ? 'Account' : user ? 'My account' : 'Sign in'}</span></a>;
}

// Operate: one Google sign-in action inside the existing Leo visual system.
// Research remains public; account state loads independently of market archives.
export function Welcome() {
  const identity = useIdentity();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const act = async (action: () => Promise<void>) => {
    setBusy(true); setError('');
    try { await action(); } catch (reason) { setError(reason instanceof Error ? reason.message : 'Sign-in could not finish. Try again.'); }
    finally { setBusy(false); }
  };
  return <section className="leo-welcome" aria-labelledby="welcome-heading">
    <div className="welcome-intro"><h1 id="welcome-heading">A clearer view<br/>of the market.</h1><p>Start with stock ideas and the reasons behind them. Explore the evidence, follow upcoming events, and build your own trade plan.</p><a className="text-button" href="#/home">Explore the stock shortlist<ArrowRight size={17}/></a><p className="welcome-public-note">You can browse the research without an account.</p></div>
    <div className="welcome-account">
      <img className="welcome-lion" src="/app/research-desk/lion.png" width="68" height="68" alt="Leo Lion"/>
      <h2>{identity.user ? 'You’re signed in.' : 'Welcome to Leo.'}</h2>
      <p>{identity.user ? 'Your account is ready. Start with Picks or open your strategy workspace.' : 'Sign in or create your account with Google. No extra password to remember.'}</p>
      {(error || identity.error) && <div className="welcome-error" role="alert"><p>{error || identity.error}</p>{!identity.auth && <button className="text-button" onClick={identity.retry}>Try again<ArrowRight size={15}/></button>}</div>}
      {identity.loading ? <p className="welcome-status" role="status">Restoring your account…</p> : identity.user ? <>
        <p className="welcome-email">{identity.user.email ?? 'Google account'}</p>
        <a className="gold-button welcome-primary" href="#/home">Go to Picks<ArrowRight size={17}/></a>
        <a className="welcome-strategies" href="#/strategies">Open strategy workspace<ArrowRight size={15}/></a>
        <button className="text-button welcome-signout" disabled={busy} onClick={() => { void act(async () => { const result = await identity.auth!.auth.signOut(); if (result.error) throw new Error('Sign-out could not finish. Try again.'); }); }}><LogOut size={15}/>{busy ? 'Signing out…' : 'Sign out'}</button>
      </> : identity.auth ? <><button className="welcome-google" aria-label={busy ? 'Opening Google…' : 'Sign in with Google'} disabled={busy} onClick={() => { void act(() => signIn(identity.auth!, '/#/home')); }}><img src="/app/research-desk/google-signin.png" width="216" height="48" alt=""/></button>{busy && <p className="welcome-status" role="status">Opening Google…</p>}</> : <p className="welcome-status">Google sign-in is temporarily unavailable. You can still explore Picks.</p>}
      <p className="welcome-privacy">Signing in does not connect a brokerage or start trading. <a href="/privacy">Privacy policy</a></p>
    </div>
  </section>;
}
