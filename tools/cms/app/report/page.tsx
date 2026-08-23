'use client'

import { useState } from 'react'
import { REPORT_REASONS } from '@/lib/reports'
import SiteHeader from '../_components/SiteHeader'
import SiteFooter from '../_components/SiteFooter'

export default function ReportPage() {
  const [reason, setReason] = useState('')
  const [episodeID, setEpisodeID] = useState('')
  const [detail, setDetail] = useState('')
  const [contact, setContact] = useState('')
  const [state, setState] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle')
  const [error, setError] = useState('')

  async function send(e: React.FormEvent) {
    e.preventDefault()
    setState('sending'); setError('')
    const res = await fetch('/api/report', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ reason, episodeID, detail, contact }),
    })
    if (res.ok) setState('sent')
    else {
      const b = (await res.json().catch(() => ({}))) as { error?: string }
      setError(b.error ?? 'That did not go through.'); setState('error')
    }
  }

  if (state === 'sent') {
    return (
      <>
        <SiteHeader />
        <main className="site">
          <header className="band band--ink site-hero site-hero--compact">
            <div className="band-inner">
          <p className="eyebrow">Report content</p>
          <h1 className="site-title">Thank you — we have it</h1>
          <p className="site-lede">
            An editor will look at this. If something breaks our rules it comes down,
            and nothing needs to happen on your side.
          </p>
          <div className="site-actions"><a className="ghost" href="/">Back to the channel</a></div>
            </div>
          </header>
          <div className="site-hero-rule" />
        </main>
        <SiteFooter />
      </>
    )
  }

  return (
    <>
      <SiteHeader />
      <main className="site">
        <header className="band band--ink site-hero site-hero--compact">
          <div className="band-inner">
        <p className="eyebrow">Report content</p>
        <h1 className="site-title">Tell us about something on the channel</h1>
        <p className="site-lede">
          Anyone can report a video, with no account and no sign-in. A person reads every
          report. You can leave a way to reach you, but you do not have to.
        </p>
          </div>
        </header>
        <div className="site-hero-rule" />

        <section className="band band--paper site-section">
          <div className="band-inner">
            <form className="form" onSubmit={send}>
          <label className="label" htmlFor="reason">What is wrong with it?</label>
          <select id="reason" required value={reason} onChange={(e) => setReason(e.target.value)}>
            <option value="">Choose one…</option>
            {REPORT_REASONS.map((r) => <option key={r} value={r}>{r}</option>)}
          </select>

          <label className="label" htmlFor="episode">Which episode? <span className="hint">optional</span></label>
          <input id="episode" value={episodeID} onChange={(e) => setEpisodeID(e.target.value)}
                 placeholder="The title, as it appears on screen" />

          <label className="label" htmlFor="detail">Anything else we should know? <span className="hint">optional</span></label>
          <textarea id="detail" rows={5} value={detail} onChange={(e) => setDetail(e.target.value)}
                    placeholder="What you saw, and roughly where in the video." />

          <label className="label" htmlFor="contact">How can we reach you? <span className="hint">optional</span></label>
          <input id="contact" value={contact} onChange={(e) => setContact(e.target.value)}
                 placeholder="Email, only if you want an answer" />

          {error && <p className="form-error">{error}</p>}
          <button className="solid" type="submit" disabled={state === 'sending'}>
            {state === 'sending' ? 'Sending…' : 'Send report'}
          </button>
            </form>
          </div>
        </section>
      </main>
      <SiteFooter />
    </>
  )
}
