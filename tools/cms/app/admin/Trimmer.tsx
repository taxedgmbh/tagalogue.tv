'use client'

import { useEffect, useRef, useState } from 'react'

/**
 * Non-destructive trim.
 *
 * Nothing is re-encoded — the handles set an in and an out point that travel
 * with the episode, and the television starts and stops there. That keeps the
 * original upload intact, makes a cut adjustable afterwards, and avoids either
 * transcoding in the browser or an ffmpeg dependency on the server.
 */
export function Trimmer({
  src,
  crossOrigin,
  duration,
  start,
  end,
  onChange,
}: {
  src: string
  crossOrigin: boolean
  duration: number
  start: number
  end: number
  onChange: (start: number, end: number) => void
}) {
  const video = useRef<HTMLVideoElement>(null)
  const [playing, setPlaying] = useState(false)

  // While previewing, stop at the out point rather than running to the end of
  // the file — otherwise the handles tell you nothing about the result.
  useEffect(() => {
    const element = video.current
    if (!element) return
    const tick = () => {
      if (playing && element.currentTime >= end) {
        element.pause()
        setPlaying(false)
        element.currentTime = start
      }
    }
    element.addEventListener('timeupdate', tick)
    return () => element.removeEventListener('timeupdate', tick)
  }, [playing, start, end])

  function scrub(to: number) {
    if (video.current) video.current.currentTime = to
  }

  function preview() {
    const element = video.current
    if (!element) return
    if (playing) { element.pause(); setPlaying(false); return }
    element.currentTime = start
    element.play().then(() => setPlaying(true)).catch(() => {})
  }

  const kept = Math.max(0, end - start)
  const left = duration > 0 ? (start / duration) * 100 : 0
  const width = duration > 0 ? (kept / duration) * 100 : 100

  return (
    <div>
      <video
        ref={video}
        src={src}
        crossOrigin={crossOrigin ? 'anonymous' : undefined}
        muted
        playsInline
        style={{ width: '100%', maxHeight: 260, background: '#000', border: '2px solid var(--rule)' }}
      />

      {/* The kept region, drawn over the whole clip. */}
      <div className="trimtrack">
        <div className="trimkeep" style={{ left: `${left}%`, width: `${width}%` }} />
      </div>

      <div className="trimrow">
        <label className="label" style={{ margin: 0, minWidth: 34 }}>In</label>
        <input
          type="range" min={0} max={Math.max(0, duration - 1)} step={0.1} value={start}
          onChange={(e) => {
            const next = Math.min(Number(e.target.value), end - 1)
            onChange(next, end); scrub(next)
          }}
        />
        <span className="mono time">{clock(start)}</span>
      </div>

      <div className="trimrow">
        <label className="label" style={{ margin: 0, minWidth: 34 }}>Out</label>
        <input
          type="range" min={1} max={duration || 1} step={0.1} value={end}
          onChange={(e) => {
            const next = Math.max(Number(e.target.value), start + 1)
            onChange(start, next); scrub(next)
          }}
        />
        <span className="mono time">{clock(end)}</span>
      </div>

      <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginTop: 12 }}>
        <button type="button" className="ghost" onClick={preview} style={{ padding: '10px 18px', fontSize: 14 }}>
          {playing ? 'Stop' : 'Preview the cut'}
        </button>
        <button
          type="button" className="link"
          onClick={() => { onChange(0, duration); scrub(0) }}
        >
          Reset
        </button>
        <span style={{ color: 'var(--dimmer)', fontSize: 14, marginLeft: 'auto' }}>
          Keeping <b style={{ color: 'var(--paper)' }}>{clock(kept)}</b> of {clock(duration)}
        </span>
      </div>
    </div>
  )
}

export function clock(seconds: number): string {
  const s = Math.max(0, Math.round(seconds))
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`
}
