'use client'

// The one door into the tool.
//
// Sign-in is a single password — there are no accounts and no usernames, so
// there is nothing to type but the secret set with `wrangler secret put
// CMS_PASSWORD`. `next` carries whatever page bounced you here, so signing in
// returns you to it rather than always dumping you on /admin.
//
// Ink, like /admin: this is the tool, not the channel. The way back to the
// channel is the last thing on the page, because somebody who cannot sign in
// still needs a way out that is not the back button.

import { useState } from 'react'

export default function Login() {
  const [password, setPassword] = useState('')
  const [problem, setProblem] = useState('')
  const [busy, setBusy] = useState(false)

  async function signIn() {
    setBusy(true); setProblem('')
    const res = await fetch('/api/login', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ password }),
    })
    if (res.ok) {
      const next = new URLSearchParams(window.location.search).get('next')
      window.location.href = next && next.startsWith('/') ? next : '/admin'
      return
    }
    const json = (await res.json().catch(() => ({}))) as { error?: string }
    setProblem(json.error ?? 'That is not the password.')
    setBusy(false)
  }

  return (
    <main className="signin">
      <div className="signin-card">
        <a className="signin-brand" href="/">
          <img
            src="/brand/mark-40.png"
            srcSet="/brand/mark-40.png 1x, /brand/mark-40@2x.png 2x, /brand/mark-40@3x.png 3x"
            alt=""
            width={62}
            height={51}
          />
        </a>
        <p className="eyebrow">Tagalogue TV · Content</p>
        <h1 className="signin-title">Sign in</h1>
        <p className="signin-lede">This tool publishes to every Apple TV.</p>

        <div className="signin-rule" />

        <label className="label" htmlFor="password">Password</label>
        <input
          id="password"
          type="password"
          value={password}
          autoFocus
          autoComplete="current-password"
          aria-invalid={problem ? true : undefined}
          aria-describedby={problem ? 'signin-problem' : undefined}
          onChange={(e) => setPassword(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter' && password) signIn() }}
        />

        {problem && <p className="signin-problem" id="signin-problem" role="alert">{problem}</p>}

        <button className="action signin-go" disabled={!password || busy} onClick={signIn}>
          {busy ? 'Checking…' : 'Sign in'}
        </button>

        <div className="signin-foot">
          <a href="/">← Back to the channel</a>
          <span>Editors only</span>
        </div>
      </div>
    </main>
  )
}
