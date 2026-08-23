'use client'

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
    <main className="sub" style={{ maxWidth: 420, paddingTop: 120 }}>
      <img src="/brand/tagalogue-lockup.png" alt="Tagalogue TV"
           style={{ height: 96, width: 'auto', marginBottom: 26 }} />
      <p className="eyebrow">Tagalogue TV · Content</p>
      <h1>Sign in</h1>
      <p className="lede">This tool publishes to every Apple TV.</p>

      <label className="label" htmlFor="password">Password</label>
      <input id="password" type="password" value={password} autoFocus
             onChange={(e) => setPassword(e.target.value)}
             onKeyDown={(e) => { if (e.key === 'Enter' && password) signIn() }} />

      {problem && <p className="warn">{problem}</p>}

      <button className="action" disabled={!password || busy} onClick={signIn}>
        {busy ? 'Checking…' : 'Sign in'}
      </button>
    </main>
  )
}
