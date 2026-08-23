'use client'

import { useCallback, useEffect, useState } from 'react'
import {
  Caption, Catalog, Episode, LANGUAGES, MATURITIES, Maturity, STRANDS, VISIBILITIES,
  Visibility, allEpisodes, daysRemaining, durationLabel, emptyCatalog, isExpired,
  isScheduled, playingSeconds, statusOf, visibilityOf,
} from '@/lib/catalog'
import { Trimmer, clock } from './Trimmer'
import type { Submission } from '@/lib/submissions'

type Frame = { seconds: number; dataURL: string; blob: Blob }
type Stage = 'idle' | 'uploading' | 'encoding' | 'thumbnail' | 'cataloguing' | 'done' | 'error'

const STEPS = ['Uploading', 'Encoding', 'Thumbnail', 'Catalog', 'Live']
/** The four that do work; 'Live' is the finish line, not a step. */
const WORKING = 4
/**
 * Which stages can report a real fraction. Upload has XHR progress and Stream
 * reports `pctComplete` while encoding; storing the thumbnail and writing the
 * catalog are single quick calls with nothing to measure, so they say so
 * rather than showing a bar that is secretly made up.
 */
const MEASURED: Record<string, boolean> = { uploading: true, encoding: true }

export default function Page() {
  const [catalog, setCatalog] = useState<Catalog>(emptyCatalog)
  const [mode, setMode] = useState('…')

  // A draft is either a new file or an episode being edited — never both.
  const [file, setFile] = useState<File | null>(null)
  const [editing, setEditing] = useState<Episode | null>(null)
  const [source, setSource] = useState('')          // what the preview plays
  const [sourceIsRemote, setSourceIsRemote] = useState(false)

  const [duration, setDuration] = useState(0)
  const [trim, setTrim] = useState<[number, number]>([0, 0])
  const [frames, setFrames] = useState<Frame[]>([])
  const [chosen, setChosen] = useState(0)
  const [custom, setCustom] = useState<{ dataURL: string; blob: Blob } | null>(null)
  const [keepArtwork, setKeepArtwork] = useState<string | null>(null)

  const [title, setTitle] = useState('')
  const [synopsis, setSynopsis] = useState('')
  const [strand, setStrand] = useState<string>(STRANDS[0].id)
  const [isNew, setIsNew] = useState(true)
  const [releaseAt, setReleaseAt] = useState(localNow())
  const [visibility, setVisibility] = useState<Visibility>('public')
  const [expiresAt, setExpiresAt] = useState('')      // empty means no end
  const [tags, setTags] = useState('')
  const [maturity, setMaturity] = useState<Maturity>('general')
  const [series, setSeries] = useState('')
  const [captions, setCaptions] = useState<Caption[]>([])
  const [confirming, setConfirming] = useState<string | null>(null)
  /** Community submissions waiting for a person to look at them. */
  const [queue, setQueue] = useState<Submission[]>([])
  /** The submission currently loaded into the editor, if any. */
  const [reviewing, setReviewing] = useState<Submission | null>(null)

  /** Result of the last "Refresh Top 10", or 'working' while it runs. */
  const [chart, setChart] = useState<string | null>(null)
  const [stage, setStage] = useState<Stage>('idle')
  const [progress, setProgress] = useState(0)
  const [problem, setProblem] = useState('')
  const [over, setOver] = useState(false)

  const refresh = useCallback(async () => {
    // The editor sees scheduled items too; the television does not.
    const res = await fetch('/api/catalog?all=1', { cache: 'no-store' })
    if (res.ok) setCatalog(await res.json())
    const inbox = await fetch('/api/submissions', { cache: 'no-store' })
    if (inbox.ok) setQueue(await inbox.json())
  }, [])

  useEffect(() => {
    refresh()
    fetch('/api/storage')
      .then((r) => r.json() as Promise<{ mode?: string }>).then((d) => setMode(d.mode ?? 'unknown')).catch(() => setMode('unknown'))
  }, [refresh])

  const open = file !== null || editing !== null || reviewing !== null

  // ── Starting a draft ──────────────────────────────────────────────────

  async function choose(picked: File) {
    reset()
    setFile(picked)
    const url = URL.createObjectURL(picked)
    setSource(url); setSourceIsRemote(false)
    const stem = picked.name.replace(/\.[^.]+$/, '').replace(/[_-]+/g, ' ').trim()
    if (!/^(video|movie|image|file|img[\s.]?\d*)$/i.test(stem)) setTitle(stem)
    const grabbed = await grabFrames(url, false)
    setDuration(grabbed.duration)
    setTrim([0, grabbed.duration])
    setFrames(grabbed.frames)
  }

  async function edit(episode: Episode) {
    reset()
    setEditing(episode)
    setTitle(episode.title)
    setSynopsis(episode.synopsis)
    setStrand(episode.showID)
    setIsNew(episode.isNew)
    setReleaseAt(toLocalInput(episode.publishedAt))
    setVisibility(visibilityOf(episode))
    setExpiresAt(episode.expiresAt ? toLocalInput(episode.expiresAt) : '')
    setTags((episode.tags ?? []).join(', '))
    setMaturity(episode.maturity ?? 'general')
    setSeries(episode.seriesTitle ?? '')
    setCaptions(episode.captions ?? [])
    setDuration(episode.duration)
    setTrim([episode.trimStart ?? 0, episode.trimEnd ?? episode.duration])
    setKeepArtwork(episode.artworkResource ?? null)
    setSource(episode.streamURL); setSourceIsRemote(true)
    window.scrollTo({ top: 0, behavior: 'smooth' })

    // Frames need the file readable by canvas; the media route sends CORS
    // headers so an anonymous request keeps the canvas clean. If the host
    // refuses, the existing thumbnail simply stays.
    const grabbed = await grabFrames(episode.streamURL, true)
    if (grabbed.frames.length) setFrames(grabbed.frames)
    if (grabbed.duration > 0 && !episode.duration) setDuration(grabbed.duration)
  }

  /**
   * Opens a submission in the editor. Approving is not a one-click act: the
   * reviewer gets the same title, description, thumbnail, trim and scheduling
   * tools as anything else, because a phone video from a stranger needs them
   * more than a finished episode does.
   */
  async function review(submission: Submission) {
    reset()
    setReviewing(submission)
    setTitle(submission.place ? `${submission.name}, ${submission.place}` : submission.name)
    setSynopsis(submission.message)
    setStrand('community')
    setIsNew(true)
    setVisibility('public')
    setSource(submission.videoURL); setSourceIsRemote(true)
    window.scrollTo({ top: 0, behavior: 'smooth' })

    const grabbed = await grabFrames(submission.videoURL, true)
    if (grabbed.duration > 0) { setDuration(grabbed.duration); setTrim([0, grabbed.duration]) }
    setFrames(grabbed.frames)
  }

  async function decline(submission: Submission) {
    await fetch('/api/submissions', {
      method: 'PATCH', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id: submission.id, state: 'rejected' }),
    })
    if (reviewing?.id === submission.id) reset()
    await refresh()
  }

  /** Publishes a reviewed submission and closes it out of the queue. */
  async function approve() {
    if (!reviewing) return
    setProblem('')
    try {
      setStage('cataloguing')
      const uid = reviewing.id.replace(/^sub-/, '')
      const artwork = await storeThumbnail(uid, custom?.blob ?? frames[chosen]?.blob)
      const id = `community-${uid}`
      await postJSON('/api/catalog', describe(reviewing.videoURL, id, artwork))
      await fetch('/api/submissions', {
        method: 'PATCH', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: reviewing.id, state: 'approved', publishedEpisodeID: id }),
      })
      setStage('done')
      await refresh()
      reset()
    } catch (error) {
      setProblem((error as Error).message); setStage('error')
    }
  }

  function reset() {
    setFile(null); setEditing(null); setReviewing(null); setSource(''); setSourceIsRemote(false)
    setFrames([]); setChosen(0); setCustom(null); setKeepArtwork(null)
    setDuration(0); setTrim([0, 0])
    setTitle(''); setSynopsis(''); setStrand(STRANDS[0].id); setIsNew(true)
    setReleaseAt(localNow())
    setVisibility('public'); setExpiresAt('')
    setTags(''); setMaturity('general'); setSeries(''); setCaptions([])
    setConfirming(null)
    setStage('idle'); setProgress(0); setProblem('')
  }

  // ── Saving ────────────────────────────────────────────────────────────

  /** Editing touches only the record — the video is already where it lives. */
  async function saveEdit() {
    if (!editing) return
    setProblem('')
    try {
      setStage('cataloguing')
      let artwork = keepArtwork
      const replacement = custom?.blob ?? (frames.length ? frames[chosen]?.blob : undefined)
      if (replacement && (custom || frames.length)) {
        const uid = editing.id.replace(/^(cf|local)-/, '')
        artwork = (await storeThumbnail(uid, replacement)) ?? artwork
      }
      await postJSON('/api/catalog', describe(editing.streamURL, editing.id, artwork))
      setStage('done')
      await refresh()
      reset()
    } catch (error) {
      setProblem((error as Error).message); setStage('error')
    }
  }

  async function publish() {
    if (!file) return
    setProblem('')
    try {
      setStage('uploading'); setProgress(0)
      const created = await postJSON<{ uid: string; uploadURL: string }>(
        '/api/upload-url', { name: file.name }
      )
      await uploadFile(created.uploadURL, file, setProgress)

      setStage('encoding'); setProgress(0)
      const at = custom ? trim[0] + 10 : (frames[chosen]?.seconds ?? 10)
      const ready = await waitUntilReady(created.uid, at, setProgress)

      setStage('thumbnail'); setProgress(0)
      const artwork =
        (await storeThumbnail(created.uid, custom?.blob ?? frames[chosen]?.blob)) ??
        ready.thumbnailURL ?? null

      setStage('cataloguing'); setProgress(0)
      const id = `cf-${created.uid}`
      await postJSON('/api/catalog', describe(ready.streamURL, id, artwork))

      setStage('done')
      await refresh()
      // The chart is a nice-to-have on top of a successful publish, so it is
      // deliberately not awaited and its failure deliberately ignored.
      void fetch('/api/top', { method: 'POST' }).catch(() => {})
    } catch (error) {
      setProblem((error as Error).message); setStage('error')
    }
  }

  function describe(streamURL: string, id: string, artwork: string | null): Episode {
    const strandInfo = STRANDS.find((s) => s.id === strand)
    const trimmed = trim[0] > 0 || trim[1] < duration
    return {
      id,
      showID: strand,
      showTitle: strandInfo?.title ?? 'Uploads',
      number: 0,
      title: title.trim() || 'Untitled clip',
      synopsis: synopsis.trim() || 'No description yet.',
      // The length viewers get is the trimmed length, not the file's.
      duration: Math.max(1, Math.round(trim[1] - trim[0])) || Math.round(duration),
      streamURL,
      isNew,
      chapters: [],
      artworkResource: artwork,
      publishedAt: new Date(releaseAt).toISOString(),
      expiresAt: expiresAt ? new Date(expiresAt).toISOString() : null,
      trimStart: trimmed ? Math.round(trim[0]) : null,
      trimEnd: trimmed ? Math.round(trim[1]) : null,
      visibility,
      tags: tags.split(',').map((t) => t.trim()).filter(Boolean),
      maturity,
      seriesID: series.trim() ? slug(series) : null,
      seriesTitle: series.trim() || null,
      captions,
      // The card advertises whichever languages actually have a track.
      subtitles: captions.map((c) => c.lang),
    }
  }

  /**
   * Recounts the chart from Cloudflare's aggregate Stream totals.
   *
   * Says what happened either way. The usual failure is a token carrying
   * Stream:Edit and nothing else, and silently showing no chart would look
   * identical to "nobody watched anything" — a different claim entirely.
   */
  async function refreshChart() {
    setChart('working')
    try {
      const res = await fetch('/api/top', { method: 'POST' })
      const body = (await res.json()) as { ok?: boolean; top?: string[]; error?: string; hint?: string }
      if (res.ok && body.ok) {
        setChart(
          body.top?.length
            ? `Top 10 rebuilt — ${body.top.length} ranked.`
            : 'Nothing watched in the last 24 hours, so the chart stays off.'
        )
        await refresh()
      } else {
        setChart(`${body.error ?? 'That did not work.'}${body.hint ? ` ${body.hint}` : ''}`)
      }
    } catch (error) {
      setChart((error as Error).message)
    }
  }

  /** Unpublish without destroying anything — the episode drops back to a draft. */
  async function archive(episode: Episode) {
    await postJSON('/api/catalog', { ...episode, visibility: 'draft' as Visibility })
    await refresh()
  }

  async function addCaption(file: File, lang: string, label: string) {
    const uid = (editing?.id ?? '').replace(/^(cf|local)-/, '') || 'pending'
    if (uid === 'pending') {
      setProblem('Publish the episode first, then add captions to it.')
      return
    }
    try {
      const res = await fetch(`/api/caption?uid=${uid}&lang=${lang}`, {
        method: 'POST', headers: { 'Content-Type': 'text/vtt' }, body: await file.text(),
      })
      const json = (await res.json()) as { url?: string; error?: string }
      if (!res.ok || !json.url) throw new Error(json.error ?? 'The caption was refused.')
      setCaptions([...captions.filter((c) => c.lang !== lang), { lang, label, url: json.url }])
      setProblem('')
    } catch (error) {
      setProblem((error as Error).message)
    }
  }

  async function remove(id: string) {
    await fetch(`/api/catalog?id=${encodeURIComponent(id)}`, { method: 'DELETE' })
    if (editing?.id === id) reset()
    await refresh()
  }

  const episodes = allEpisodes(catalog)
  const pending = queue.filter((s) => s.state === 'pending' && s.videoURL)
  const stageIndex = { uploading: 0, encoding: 1, thumbnail: 2, cataloguing: 3, done: 4 }[stage as string] ?? -1
  const busy = stage !== 'idle' && stage !== 'done' && stage !== 'error'
  const measured = MEASURED[stage] ?? false
  // One bar for the whole run: completed steps plus however far into the
  // current one we are. It used to be the upload's bar alone, which sat at
  // 100% and then vanished while the longest step — encoding — ran silently.
  const overall =
    stage === 'done' ? 1
    : stageIndex < 0 ? 0
    : Math.min(1, (stageIndex + (measured ? progress : 0)) / WORKING)
  const scheduled = new Date(releaseAt).getTime() > Date.now()
  const endsBeforeItStarts =
    expiresAt !== '' && new Date(expiresAt).getTime() <= new Date(releaseAt).getTime()
  const alreadyOver = expiresAt !== '' && new Date(expiresAt).getTime() <= Date.now()

  const windowNote =
    visibility === 'draft'
      ? 'Drafts have no availability window. Change the visibility to schedule one.'
      : endsBeforeItStarts
        ? 'The end date is before the release. Nobody would ever see this.'
        : alreadyOver
          ? 'That end date has already passed — this will not appear on the television.'
          : scheduled && expiresAt
            ? `Appears ${new Date(releaseAt).toLocaleString()}, gone ${new Date(expiresAt).toLocaleString()}.`
            : scheduled
              ? `Hidden until ${new Date(releaseAt).toLocaleString()}.`
              : expiresAt
                ? `Live now, and gone ${new Date(expiresAt).toLocaleString()}.`
                : 'Live as soon as you save, and stays up.'

  return (
    <main className="wrap">
      <header className="masthead">
        {/* The channel's own lockup, lifted from the Top Shelf artwork in the
            design package rather than redrawn. */}
        <img className="lockup" src="/brand/tagalogue-lockup.png" alt="Tagalogue TV" />
        <div className="titles">
          <span className="name">Tagalogue TV</span>
          <span className="role">Content</span>
        </div>
        <div className="mode">
          Storage
          <b><span className="dot" />{mode}</b>
        </div>
        <div className="masthead-actions">
            <a className="masthead-link" href="/" target="_blank" rel="noreferrer">View site</a>
            {/* The session cookie lasts a fortnight on a shared password.
                Without this there is no way to end it from a borrowed screen. */}
            <button
              type="button"
              className="masthead-link"
              onClick={async () => {
                await fetch('/api/login', { method: 'DELETE' })
                window.location.href = '/'
              }}
            >
              Sign out
            </button>
          </div>
        </header>

      <section className="panel">
        <h2>{reviewing ? 'Review a submission' : editing ? 'Edit episode' : open ? 'Describe it' : 'Add a video'}</h2>
        <p className="sub">
          {reviewing
            ? `Sent in by ${reviewing.name}${reviewing.place ? ` from ${reviewing.place}` : ''} on ${new Date(reviewing.submittedAt).toLocaleDateString()}. Nothing has gone out yet.`
            : editing
            ? 'Changes take effect the moment you save. The video itself is untouched.'
            : open
              ? 'This is what viewers see on the television. Everything can be changed later.'
              : 'Pick a file to begin. Nothing is uploaded until you publish.'}
        </p>

        {!open && (
          <label
            className={`drop${over ? ' over' : ''}`}
            onDragOver={(e) => { e.preventDefault(); setOver(true) }}
            onDragLeave={() => setOver(false)}
            onDrop={(e) => {
              e.preventDefault(); setOver(false)
              const dropped = e.dataTransfer.files?.[0]; if (dropped) choose(dropped)
            }}
          >
            <div className="big">Choose a video, or drop one here</div>
            <div className="small">MP4, MOV or M4V</div>
            <input type="file" accept="video/*"
                   onChange={(e) => { const f = e.target.files?.[0]; if (f) choose(f) }} />
          </label>
        )}

        {open && (
          <>
            <div className="grid">
              <div>
                <div className="field">
                  <label className="label" htmlFor="title">Title</label>
                  <input id="title" type="text" value={title} placeholder="Dinner in Bern"
                         onChange={(e) => setTitle(e.target.value)} />
                </div>
                <div className="field">
                  <label className="label" htmlFor="synopsis">Description</label>
                  <textarea id="synopsis" value={synopsis} placeholder="What happens in this clip."
                            onChange={(e) => setSynopsis(e.target.value)} />
                </div>
                <div className="field">
                  <span className="label">Strand</span>
                  <div className="choices">
                    {STRANDS.map((s) => (
                      <button key={s.id} type="button" className="choice"
                              aria-pressed={strand === s.id} onClick={() => setStrand(s.id)}>
                        {s.title}
                      </button>
                    ))}
                    <button type="button" className="choice" aria-pressed={isNew}
                            onClick={() => setIsNew(!isNew)}>NEW badge</button>
                  </div>
                </div>
                <div className="field">
                  <span className="label">Visibility</span>
                  <div className="choices">
                    {VISIBILITIES.map((v) => (
                      <button key={v.id} type="button" className="choice"
                              aria-pressed={visibility === v.id} onClick={() => setVisibility(v.id)}>
                        {v.title}
                      </button>
                    ))}
                  </div>
                  <p className="hint">{VISIBILITIES.find((v) => v.id === visibility)?.note}</p>
                </div>

                <div className="field">
                  <span className="label">Availability</span>
                  <div className="window">
                    <div>
                      <label className="sublabel" htmlFor="release">From</label>
                      <input id="release" type="datetime-local" value={releaseAt}
                             onChange={(e) => setReleaseAt(e.target.value)}
                             disabled={visibility === 'draft'} />
                    </div>
                    <div>
                      <label className="sublabel" htmlFor="expires">Until</label>
                      <input id="expires" type="datetime-local" value={expiresAt}
                             min={releaseAt}
                             onChange={(e) => setExpiresAt(e.target.value)}
                             disabled={visibility === 'draft'} />
                    </div>
                  </div>
                  <div style={{ display: 'flex', gap: 14, alignItems: 'center', marginTop: 8 }}>
                    <p className="hint" style={{ margin: 0 }}>{windowNote}</p>
                    {expiresAt && (
                      <button type="button" className="link" style={{ marginLeft: 'auto' }}
                              onClick={() => setExpiresAt('')}>
                        No end date
                      </button>
                    )}
                  </div>
                </div>

                <div className="field">
                  <label className="label" htmlFor="tags">Tags</label>
                  <input id="tags" type="text" value={tags} placeholder="bern, president, dinner"
                         onChange={(e) => setTags(e.target.value)} />
                  <p className="hint">Comma separated. The television searches these along with
                  the title, description and chapter names.</p>
                </div>

                <div className="field">
                  <label className="label" htmlFor="series">Collection</label>
                  <input id="series" type="text" value={series} placeholder="Distinguished Guests"
                         onChange={(e) => setSeries(e.target.value)} />
                  <p className="hint">Optional. Groups episodes across strands.</p>
                </div>

                <div className="field">
                  <span className="label">Audience</span>
                  <div className="choices">
                    {MATURITIES.map((m) => (
                      <button key={m.id} type="button" className="choice"
                              aria-pressed={maturity === m.id} onClick={() => setMaturity(m.id)}>
                        {m.title}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="field">
                  <span className="label">Captions</span>
                  {captions.length > 0 && (
                    <ul className="tracks">
                      {captions.map((c) => (
                        <li key={c.lang}>
                          <span className="tag">{c.lang.toUpperCase()}</span> {c.label}
                          <button type="button" className="link"
                                  onClick={() => setCaptions(captions.filter((x) => x.lang !== c.lang))}>
                            Remove
                          </button>
                        </li>
                      ))}
                    </ul>
                  )}
                  <div className="choices" style={{ marginTop: 8 }}>
                    {LANGUAGES.map((language) => (
                      <label key={language.code} className="choice" style={{ cursor: 'pointer' }}>
                        + {language.label}
                        <input type="file" accept=".vtt,text/vtt" style={{ display: 'none' }}
                               onChange={(e) => {
                                 const track = e.target.files?.[0]
                                 if (track) addCaption(track, language.code, language.label)
                               }} />
                      </label>
                    ))}
                  </div>
                  <p className="hint">WebVTT files. On Cloudflare these join the stream itself, so
                  the television&rsquo;s own subtitle menu picks them up.</p>
                </div>
              </div>

              <div>
                <span className="label">Thumbnail</span>
                {frames.length > 0 ? (
                  <div className="frames">
                    {frames.map((frame, index) => (
                      <button key={index} type="button" className="frame"
                              aria-pressed={!custom && chosen === index}
                              onClick={() => { setChosen(index); setCustom(null) }}>
                        <img src={frame.dataURL} alt={`Frame at ${clock(frame.seconds)}`} />
                        <span className="time">{clock(frame.seconds)}</span>
                      </button>
                    ))}
                  </div>
                ) : keepArtwork ? (
                  <img src={keepArtwork} alt="" style={{ width: 220, border: '2px solid var(--rule)' }} />
                ) : (
                  <p style={{ color: 'var(--dimmer)' }}>Reading frames…</p>
                )}

                <div style={{ marginTop: 14, display: 'flex', gap: 12, alignItems: 'center' }}>
                  <label className="choice" style={{ cursor: 'pointer' }} aria-pressed={!!custom}>
                    Upload an image
                    <input type="file" accept="image/*" style={{ display: 'none' }}
                           onChange={(e) => {
                             const image = e.target.files?.[0]; if (!image) return
                             setCustom({ dataURL: URL.createObjectURL(image), blob: image })
                           }} />
                  </label>
                  {custom && (
                    <>
                      <img src={custom.dataURL} alt="" style={{ height: 52, border: '2px solid var(--accent)' }} />
                      <button type="button" className="link" onClick={() => setCustom(null)}>Use a frame</button>
                    </>
                  )}
                </div>

                {source && duration > 0 && (
                  <div style={{ marginTop: 26 }}>
                    <span className="label">Trim</span>
                    <Trimmer
                      src={source} crossOrigin={sourceIsRemote} duration={duration}
                      start={trim[0]} end={trim[1]}
                      onChange={(a, b) => setTrim([a, b])}
                    />
                    <p className="hint">
                      Nothing is re-encoded. The television starts and stops at these points, so a
                      cut can be changed or undone later.
                    </p>
                  </div>
                )}
              </div>
            </div>

            {busy || stage === 'done' ? (
              <>
                <div className="run">
                  <div className="run-head">
                    <span>
                      {stage === 'done'
                        ? 'Published'
                        : `Step ${stageIndex + 1} of ${WORKING} · ${STEPS[stageIndex]}`}
                    </span>
                    <b className="run-pct">{Math.round(overall * 100)}%</b>
                  </div>
                  <div className={measured ? 'bar' : 'bar working'}>
                    <i style={{ width: `${Math.round(overall * 100)}%` }} />
                  </div>
                  <ol className="steps">
                    {STEPS.map((name, index) => (
                      <li
                        key={name}
                        className={index < stageIndex ? 'done' : index === stageIndex ? 'now' : ''}
                      >
                        <span className="dot" />{name}
                        <span className="step-note">
                          {index < stageIndex ? 'Done'
                            : index !== stageIndex ? 'Waiting'
                            : stage === 'done' ? 'Done'
                            : measured ? `${Math.round(progress * 100)}%`
                            : 'Working'}
                        </span>
                      </li>
                    ))}
                  </ol>
                </div>
                {stage === 'done' && (
                  <div style={{ marginTop: 24 }}>
                    <button className="action" onClick={reset}>Add another</button>
                  </div>
                )}
              </>
            ) : (
              <div style={{ marginTop: 26, display: 'flex', gap: 12 }}>
                <button className="action"
                        onClick={reviewing ? approve : editing ? saveEdit : publish}
                        disabled={endsBeforeItStarts}>
                  {reviewing
                    ? 'Approve and publish'
                    : editing ? 'Save changes' : scheduled ? 'Schedule it' : 'Publish to the channel'}
                </button>
                <button className="ghost" onClick={reset}>
                  {reviewing || editing ? 'Cancel' : 'Discard'}
                </button>
                {reviewing && (
                  <button className="ghost" onClick={() => decline(reviewing)}
                          style={{ marginLeft: 'auto' }}>
                    Decline this submission
                  </button>
                )}
              </div>
            )}

            {problem && (
              <div className="notice">
                <div className="head">{editing ? 'Not saved' : 'Not published'}</div>
                <p>{problem}</p>
              </div>
            )}
          </>
        )}
      </section>

      {pending.length > 0 && (
        <section style={{ marginBottom: 48 }}>
          <div className="sectionhead">
            <h2>From the community</h2>
            <span className="count">
              {pending.length} waiting
            </span>
          </div>
          <p className="sub" style={{ marginTop: 16 }}>
            Sent in through the code on the television. Nothing here has been seen by anyone else.
          </p>
          <ul className="queue">
            {pending.map((submission) => (
              <li key={submission.id} className={reviewing?.id === submission.id ? 'reviewing' : ''}>
                <video src={submission.videoURL} muted playsInline preload="metadata" />
                <div className="who">
                  <div className="title">
                    {submission.name}
                    {submission.place && <span className="place"> · {submission.place}</span>}
                  </div>
                  <p className="said">{submission.message}</p>
                  <div className="meta">{new Date(submission.submittedAt).toLocaleString()}</div>
                </div>
                <div className="actions">
                  <button className="link" onClick={() => review(submission)}>Review</button>
                  <button className="link danger" onClick={() => decline(submission)}>Decline</button>
                </div>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section>
        <div className="sectionhead">
          <h2>On the channel</h2>
          <button className="link" onClick={refreshChart} disabled={chart === 'working'}>
            {chart === 'working' ? 'Counting…' : 'Refresh Top 10'}
          </button>
          <span className="count">
            {episodes.length} {episodes.length === 1 ? 'episode' : 'episodes'}
            {episodes.some((e) => isScheduled(e)) &&
              ` · ${episodes.filter((e) => isScheduled(e)).length} scheduled`}
          </span>
        </div>
        {chart && chart !== 'working' && <p className="hint">{chart}</p>}
        {episodes.length === 0 ? (
          <p className="empty">Nothing published yet. Anything you add here appears on every Apple TV.</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th style={{ width: 168 }}>Thumbnail</th>
                <th>Episode</th>
                <th style={{ width: 120 }}>Strand</th>
                <th style={{ width: 100 }}>Length</th>
                <th style={{ width: 190 }}>Release</th>
                <th style={{ width: 130 }} />
              </tr>
            </thead>
            <tbody>
              {episodes.map((episode) => {
                const status = statusOf(episode)
                return (
                  <tr key={episode.id} className={editing?.id === episode.id ? 'editing' : ''}>
                    <td className="thumb">
                      {episode.artworkResource
                        ? <img src={episode.artworkResource} alt="" />
                        : <div className="none" />}
                    </td>
                    <td>
                      <div className="title">
                        {episode.title} {episode.isNew && <span className="tag new">New</span>}
                      </div>
                      <div className="meta">
                        {episode.synopsis.slice(0, 96)}{episode.synopsis.length > 96 ? '…' : ''}
                      </div>
                    </td>
                    <td><span className="tag">{episode.showTitle}</span></td>
                    <td style={{ color: 'var(--dim)' }}>
                      {durationLabel(playingSeconds(episode))}
                      {episode.trimStart != null && (
                        <div className="meta">cut from {durationLabel(episode.duration)}</div>
                      )}
                    </td>
                    <td>
                      <span className={`tag ${status.tone}`}>{status.label}</span>
                      <div className="meta">
                        {episode.publishedAt ? new Date(episode.publishedAt).toLocaleString() : '—'}
                      </div>
                      {episode.expiresAt && (
                        <div className={`meta${leaving(episode) ? ' leaving' : ''}`}>
                          {isExpired(episode)
                            ? `ended ${new Date(episode.expiresAt).toLocaleDateString()}`
                            : `until ${new Date(episode.expiresAt).toLocaleDateString()}`}
                          {leaving(episode) && ` · ${daysRemaining(episode)}d left`}
                        </div>
                      )}
                      {(episode.tags?.length ?? 0) > 0 && (
                        <div className="meta">{episode.tags!.slice(0, 3).join(' · ')}</div>
                      )}
                    </td>
                    <td>
                      {confirming === episode.id ? (
                        <div className="actions">
                          <button className="link danger" onClick={() => remove(episode.id)}>
                            Delete for good
                          </button>
                          <button className="link" onClick={() => setConfirming(null)}>Keep</button>
                        </div>
                      ) : (
                        <div className="actions">
                          <button className="link" onClick={() => edit(episode)}>Edit</button>
                          {visibilityOf(episode) !== 'draft' && (
                            <button className="link" onClick={() => archive(episode)}>Unpublish</button>
                          )}
                          <button className="link" onClick={() => setConfirming(episode.id)}>Delete</button>
                        </div>
                      )}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </section>
    </main>
  )
}

// ── Helpers ───────────────────────────────────────────────────────────────

function localNow() { return toLocalInput(new Date().toISOString()) }

/** Inside a week of closing — worth drawing attention to in the list. */
function leaving(episode: Episode): boolean {
  const days = daysRemaining(episode)
  return days !== null && days >= 0 && days <= 7
}

/** A stable id for a collection, from what the editor typed. */
function slug(text: string): string {
  return text.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
}

/** `datetime-local` wants local wall-clock time, not an ISO instant. */
function toLocalInput(iso?: string | null): string {
  const date = iso ? new Date(iso) : new Date()
  const offset = date.getTimezoneOffset() * 60000
  return new Date(date.getTime() - offset).toISOString().slice(0, 16)
}

async function postJSON<T = Record<string, unknown>>(url: string, body: unknown): Promise<T> {
  const res = await fetch(url, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
  })
  const json = (await res.json().catch(() => ({}))) as T & { error?: string }
  if (!res.ok) throw new Error(json.error ?? `${url} returned ${res.status}`)
  return json
}

/**
 * Four frames spread through the clip, drawn in the browser by seeking a
 * <video> onto a <canvas>. Nothing is uploaded to do this, so choosing a
 * thumbnail costs nothing and a clip can be discarded without ever sending it.
 */
async function grabFrames(src: string, remote: boolean): Promise<{ duration: number; frames: Frame[] }> {
  const video = document.createElement('video')
  // Without this an already-published video taints the canvas and the frames
  // come back blank; the media route sends the matching CORS header.
  if (remote) video.crossOrigin = 'anonymous'
  video.src = src
  video.muted = true
  video.playsInline = true

  try {
    await new Promise<void>((resolve, reject) => {
      video.onloadedmetadata = () => resolve()
      video.onerror = () => reject(new Error('That file is not a video this browser can read.'))
      setTimeout(() => reject(new Error('timed out')), 20000)
    })
  } catch {
    return { duration: 0, frames: [] }
  }

  const duration = Number.isFinite(video.duration) ? video.duration : 0
  const canvas = document.createElement('canvas')
  const context = canvas.getContext('2d')!
  const frames: Frame[] = []

  for (let step = 0; step < 4; step++) {
    const at = duration > 0 ? (duration * (step + 0.5)) / 4 : 0
    try {
      await seek(video, at)
      canvas.width = video.videoWidth
      canvas.height = video.videoHeight
      context.drawImage(video, 0, 0)
      const blob = await new Promise<Blob | null>((r) => canvas.toBlob(r, 'image/jpeg', 0.85))
      if (blob) frames.push({ seconds: at, dataURL: canvas.toDataURL('image/jpeg', 0.7), blob })
    } catch {
      // A frame that will not decode is not worth failing the whole draft for.
    }
  }
  return { duration, frames }
}

function seek(video: HTMLVideoElement, to: number) {
  return new Promise<void>((resolve, reject) => {
    const done = () => { video.removeEventListener('seeked', done); resolve() }
    video.addEventListener('seeked', done)
    setTimeout(() => reject(new Error('seek timed out')), 8000)
    video.currentTime = to
  })
}

/** XHR, not fetch: only XHR reports upload progress. */
/** Straight to Cloudflare's one-time URL — the bytes never touch the Worker. */
function uploadFile(url: string, file: File, onProgress: (f: number) => void) {
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
    ? resolve()
    : reject(new Error(`The upload was refused (${xhr.status}). ${xhr.responseText.slice(0, 200)}`))
  xhr.onerror = () => reject(new Error('The connection dropped during the upload.'))
}

async function waitUntilReady(
  uid: string, seconds: number, onProgress: (fraction: number) => void
) {
  const deadline = Date.now() + 30 * 60 * 1000
  while (Date.now() < deadline) {
    const res = await fetch(`/api/video/${uid}?t=${Math.round(seconds)}`)
    const json = (await res.json()) as {
      status: string; streamURL: string; thumbnailURL: string | null
      pctComplete: number | null
    }
    if (json.pctComplete !== null) onProgress(json.pctComplete / 100)
    if (json.status === 'ready') return json
    if (json.status === 'error') throw new Error('Cloudflare could not encode that video.')
    await new Promise((r) => setTimeout(r, 4000))
  }
  throw new Error('Cloudflare is still encoding. It will appear once it finishes.')
}

async function storeThumbnail(uid: string, blob: Blob | undefined): Promise<string | null> {
  if (!blob) return null
  try {
    const res = await fetch(`/api/thumbnail?uid=${uid}`, {
      method: 'POST', headers: { 'Content-Type': 'image/jpeg' }, body: blob,
    })
    if (!res.ok) return null
    // Cache-bust so a replaced thumbnail actually shows.
    const url = ((await res.json()) as { url?: string }).url
    return url ? `${url}?v=${Date.now()}` : null
  } catch {
    return null
  }
}
