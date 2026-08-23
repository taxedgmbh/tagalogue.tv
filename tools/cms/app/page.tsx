// The public face of the channel: tagalogue.tv.
//
// A server component that reads the same catalog the televisions read, so the
// site cannot advertise a line-up the channel does not have. Every count and
// every card below is the live catalog, gated exactly as the app gates it.

import { readCatalog } from '@/lib/store'
import { publicCatalog, type Episode } from '@/lib/catalog'

export const dynamic = 'force-dynamic'

export const metadata = {
  metadataBase: new URL('https://tagalogue.tv'),
  title: 'Tagalogue TV — Filipino–Swiss stories on Apple TV',
  description:
    'A Filipino–Swiss channel from Biel/Bienne. Interviews, vlogs and stories sent in by the '
    + 'community, in Tagalog and English, free on Apple TV. Published by Taxed GmbH.',
  alternates: { canonical: '/' },
  openGraph: {
    title: 'Tagalogue TV',
    description:
      'Filipino–Swiss interviews, vlogs and community stories. Free on Apple TV.',
    url: 'https://tagalogue.tv',
    siteName: 'Tagalogue TV',
    locale: 'en_CH',
    type: 'website',
  },
}

// Structured data. This is the part search engines actually read for entity
// and publisher relationships — `sameAs` ties the accounts to the channel and
// `parentOrganization` ties the channel to Taxed GmbH.
const ORGANISATION = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: 'Tagalogue TV',
  url: 'https://tagalogue.tv',
  logo: 'https://tagalogue.tv/brand/tagalogue-lockup.png',
  description:
    'A Filipino–Swiss channel: interviews, vlogs and community stories, free on Apple TV.',
  address: {
    '@type': 'PostalAddress',
    addressLocality: 'Biel/Bienne',
    addressCountry: 'CH',
  },
  sameAs: [
    'https://www.facebook.com/Tagaloguetv',
    'https://www.instagram.com/tagaloguetv/',
  ],
  parentOrganization: {
    '@type': 'Organization',
    name: 'Taxed GmbH',
    url: 'https://taxed.ch',
    address: {
      '@type': 'PostalAddress',
      addressLocality: 'Biel/Bienne',
      addressCountry: 'CH',
    },
    brand: { '@type': 'Brand', name: 'Skopa', url: 'https://skopa.ai' },
  },
}

/** Only a remote poster can be shown on the web; bundled names mean nothing here. */
function poster(e: Episode): string | null {
  const a = e.artworkResource
  return a && /^https?:\/\//.test(a) ? a : null
}

function runtime(seconds: number): string {
  if (!seconds) return ''
  const m = Math.round(seconds / 60)
  return m < 60 ? `${m} min` : `${Math.floor(m / 60)} h ${m % 60} min`
}

export default async function Home() {
  const catalog = publicCatalog(await readCatalog())
  const episodes = catalog.shows.flatMap((s) => s.episodes)
  const strands = catalog.shows.filter((s) => s.episodes.length > 0)
  const latest = [...episodes]
    .sort((a, b) => (b.publishedAt ?? '').localeCompare(a.publishedAt ?? ''))
    .slice(0, 6)

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(ORGANISATION) }}
      />
      <nav className="topbar">
        <div className="topbar-inner">
        <a className="topbar-brand" href="/">
          <img src="/brand/tagalogue-lockup.png" alt="" width={40} height={40} />
          <span>Tagalogue TV</span>
        </a>
        <div className="topbar-links">
          <a href="#whats-on">What&rsquo;s on</a>
          <a href="#how-to-watch">How to watch</a>
          <a href="#community">Submit a video</a>
          <a href="#follow">Follow</a>
          {/* The way in for the team. It goes to /admin, which bounces through
              the login and back, so there is one door and one place to sign in. */}
          <a className="topbar-signin" href="/admin">Editor sign-in</a>
        </div>
        </div>
      </nav>

      <main className="site">
        <header className="site-hero">
          <p className="eyebrow">Filipino–Swiss · Biel/Bienne</p>
          <h1 className="site-title">Stories from the Filipino community in Switzerland</h1>
          <p className="site-lede">
            Sit-down interviews, vlogs from around the country, and pieces sent in by the
            people who watch. In Tagalog and English, free to watch on Apple TV.
          </p>
          <div className="site-actions">
            {/* Not a link: there is no App Store listing yet, and a dead
                Download button is worse than an honest label. */}
            <span className="pill">Coming to Apple TV</span>
            <a className="ghost" href="/submit">Send us your story</a>
          </div>
          <dl className="facts">
            <div><dt>Episodes</dt><dd>{episodes.length || '—'}</dd></div>
            <div><dt>Watch on</dt><dd>Apple TV</dd></div>
            <div><dt>Languages</dt><dd>Tagalog · English</dd></div>
            <div><dt>Price</dt><dd>Free</dd></div>
          </dl>
        </header>

        <section className="site-section" id="whats-on">
          <h2 className="site-h2">What&rsquo;s on</h2>
          {strands.length === 0 ? (
            <p className="site-empty">
              The first episodes are on their way. Nothing is published yet — this page
              fills itself in the moment something goes live.
            </p>
          ) : (
            <div className="strands">
              {strands.map((show) => (
                <article key={show.id} className="strand">
                  <h3 className="strand-name">{show.title}</h3>
                  <p className="strand-sub">{show.subtitle}</p>
                  <p className="strand-count">
                    {show.episodes.length} {show.episodes.length === 1 ? 'episode' : 'episodes'}
                  </p>
                </article>
              ))}
            </div>
          )}
        </section>

        {latest.length > 0 && (
          <section className="site-section">
            <h2 className="site-h2">Latest</h2>
            <div className="cards">
              {latest.map((e) => (
                <article key={e.id} className="card">
                  <div className="card-art">
                    {poster(e) ? <img src={poster(e)!} alt="" loading="lazy" /> : <span className="card-hatch" />}
                  </div>
                  <h3 className="card-title">{e.title}</h3>
                  <p className="card-meta">
                    {e.showTitle}
                    {e.number > 0 ? ` · EP ${e.number}` : ''}
                    {runtime(e.duration) ? ` · ${runtime(e.duration)}` : ''}
                  </p>
                </article>
              ))}
            </div>
          </section>
        )}

        <section className="site-section" id="how-to-watch">
          <h2 className="site-h2">How to watch</h2>
          <ol className="steps">
            <li>
              <span className="step-n">01</span>
              <span>
                <strong>On Apple TV.</strong> The channel is an app for the television, not a
                website — built for the room, the remote and the big screen.
              </span>
            </li>
            <li>
              <span className="step-n">02</span>
              <span>
                <strong>Free, no account.</strong> Every episode published here plays without
                signing in or paying.
              </span>
            </li>
            <li>
              <span className="step-n">03</span>
              <span>
                <strong>Pick up where you left off.</strong> The app remembers how far into an
                episode you got, on that television.
              </span>
            </li>
          </ol>
        </section>

        <section className="site-section" id="community">
          <h2 className="site-h2">Community</h2>
          <div className="panel">
            <h3 className="panel-title">Your story belongs on the channel</h3>
            <p className="panel-body">
              Anyone can send in a video from a phone — a few minutes of your life here, a
              trip home, something you want the community to see. An editor watches
              everything before it goes anywhere: <strong>nothing reaches a television
              without a person approving it first</strong>.
            </p>
            <a className="solid" href="/submit">Submit a video</a>
          </div>
        </section>

        <section className="site-section" id="follow">
          <h2 className="site-h2">Follow</h2>
          <div className="socials">
            <a className="social" href="https://www.facebook.com/Tagaloguetv"
               target="_blank" rel="noreferrer me">
              <span className="social-net">Facebook</span>
              <span className="social-handle">/Tagaloguetv</span>
              <span className="social-note">The channel — news, clips and what is coming</span>
            </a>
            <a className="social" href="https://www.instagram.com/tagaloguetv/"
               target="_blank" rel="noreferrer me">
              <span className="social-net">Instagram</span>
              <span className="social-handle">@tagaloguetv</span>
              <span className="social-note">Behind the episodes, day to day</span>
            </a>
            <a className="social" href="https://www.instagram.com/travelynstyle/"
               target="_blank" rel="noreferrer">
              <span className="social-net">Instagram</span>
              <span className="social-handle">@travelynstyle</span>
              <span className="social-note">The host</span>
            </a>
          </div>
        </section>

        <section className="site-section" id="about">
          <h2 className="site-h2">About</h2>
          <p className="prose">
            Tagalogue TV is a Filipino–Swiss channel run by Taxed GmbH in Biel/Bienne. It
            exists because the Filipino community in Switzerland has plenty to say and few
            places to say it — so the channel films conversations, collects vlogs from around
            the country, and puts what viewers send in alongside them.
          </p>
        </section>

        <footer className="site-foot">
          <div>
            <strong>Tagalogue TV</strong>
            <br />
            Taxed GmbH · Biel/Bienne, Switzerland
          </div>
          <div className="site-foot-links">
            <a href="https://www.facebook.com/Tagaloguetv" target="_blank" rel="noreferrer">Facebook</a>
            <a href="https://www.instagram.com/tagaloguetv/" target="_blank" rel="noreferrer">Instagram</a>
            <a href="/submit">Submit a video</a>
            <a href="/support">Support</a>
            <a href="/privacy">Privacy</a>
            <a href="/terms">Terms</a>
            <a href="/report">Report content</a>
            <a href="/admin">Editor sign-in</a>
          </div>
          <div className="site-foot-colophon">
            Apple TV app published by{' '}
            <a href="https://taxed.ch" target="_blank" rel="noreferrer">Taxed GmbH</a>, who also
            make{' '}
            <a href="https://skopa.ai" target="_blank" rel="noreferrer">Skopa</a> — finance
            software for Swiss SMEs.
          </div>
          <div className="site-foot-meta">
            {episodes.length > 0
              ? `${episodes.length} ${episodes.length === 1 ? 'episode' : 'episodes'} published`
              : 'Launching soon'}
          </div>
        </footer>
      </main>
    </>
  )
}
