'use client'

import { useState } from 'react'

/**
 * The page behind the QR code on the television. Public, no account, phone-first.
 *
 * Written for someone standing in their living room who has just seen a code on
 * screen: three fields, one button, and a plain statement of what happens next.
 * Nothing here publishes anything — every submission waits for a human.
 */
export default function Submit() {
  const [name, setName] = useState('')
  const [place, setPlace] = useState('')
  const [message, setMessage] = useState('')
  const [file, setFile] = useState<File | null>(null)
  const [progress, setProgress] = useState(0)
  const [stage, setStage] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle')
  const [problem, setProblem] = useState('')

  const tooLong = file !== null && file.size > 500 * 1024 * 1024
  const ready = name.trim() && message.trim() && file && !tooLong

  async function send() {
    if (!file) return
    setStage('sending'); setProblem(''); setProgress(0)
    try {
      const created = await post<{ id: string; uploadURL: string }>('/api/submit', {
        name, place, message, fileName: file.name,
      })
      await upload(created.uploadURL, file, setProgress)

      // The server resolves the playback URL itself — see the route comment.
      await post('/api/submit/complete', { id: created.id, fileName: file.name })

      setStage('sent')
    } catch (error) {
      setProblem((error as Error).message)
      setStage('error')
    }
  }

  if (stage === 'sent') {
    return (
      <main className="sub">
        <div className="mark" />
        <h1>Thank you</h1>
        <p className="lede">
          Your video is with the Tagalogue TV team. Someone reads every one, so it may be a
          few days before it appears on the channel.
        </p>
        <button className="action" onClick={() => window.location.reload()}>Send another</button>
      </main>
    )
  }

  return (
    <main className="sub">
      <div className="mark" />
      <p className="eyebrow">Tagalogue TV · Community</p>
      <h1>Share your thoughts</h1>
      <p className="lede">
        Record something on your phone and send it in. The best ones go out on the channel.
      </p>

      <label className="label" htmlFor="name">Your name</label>
      <input id="name" type="text" value={name} maxLength={60}
             placeholder="Maria" autoCapitalize="words"
             onChange={(e) => setName(e.target.value)} />

      <label className="label" htmlFor="place">Where are you? <span className="opt">optional</span></label>
      <input id="place" type="text" value={place} maxLength={60} placeholder="Basel"
             onChange={(e) => setPlace(e.target.value)} />

      <label className="label" htmlFor="message">Your message</label>
      <textarea id="message" value={message} maxLength={600}
                placeholder="What you want to say to the channel."
                onChange={(e) => setMessage(e.target.value)} />
      <div className="counter">{message.length} / 600</div>

      <label className="pick">
        {file ? `${file.name} · ${(file.size / 1048576).toFixed(1)} MB` : 'Choose a video'}
        <input type="file" accept="video/*" capture="user"
               onChange={(e) => { const f = e.target.files?.[0]; if (f) setFile(f) }} />
      </label>
      {tooLong && <p className="warn">That video is over 500 MB. Please send something shorter.</p>}

      {stage === 'sending' && (
        <>
          <div className="bar"><i style={{ width: `${Math.round(progress * 100)}%` }} /></div>
          <p className="status">Sending… {Math.round(progress * 100)}% — keep this page open.</p>
        </>
      )}

      {problem && <p className="warn">{problem}</p>}

      <button className="action" disabled={!ready || stage === 'sending'} onClick={send}>
        {stage === 'sending' ? 'Sending…' : 'Send to Tagalogue TV'}
      </button>

      <p className="small">
        By sending, you agree the channel may broadcast your video. Nothing appears on the
        channel until a person has watched it.
      </p>
    </main>
  )
}

async function post<T = Record<string, unknown>>(url: string, body: unknown): Promise<T> {
  const res = await fetch(url, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
  })
  const json = (await res.json().catch(() => ({}))) as T & { error?: string }
  if (!res.ok) throw new Error(json.error ?? 'Something went wrong. Please try again.')
  return json
}

/** XHR, not fetch: only XHR reports upload progress, and on a phone that matters. */
/** Straight to Cloudflare — a follower's video never passes through the Worker. */
function upload(url: string, file: File, onProgress: (f: number) => void) {
  return new Promise<void>((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    xhr.open('POST', url)
    const form = new FormData()
    form.append('file', file)
    wire(xhr, resolve, reject, onProgress)
    xhr.send(form)
  })
}

function wire(
  xhr: XMLHttpRequest, resolve: () => void, reject: (e: Error) => void, onProgress: (f: number) => void
) {
  xhr.upload.onprogress = (e) => { if (e.lengthComputable) onProgress(e.loaded / e.total) }
  xhr.onload = () => xhr.status >= 200 && xhr.status < 300
    ? resolve() : reject(new Error('The upload was refused. Please try again.'))
  xhr.onerror = () => reject(new Error('The connection dropped. Stay on this page while it sends.'))
}
