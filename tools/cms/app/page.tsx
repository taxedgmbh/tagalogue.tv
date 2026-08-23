// The public face of the channel: tagalogue.tv.
//
// A server component that reads the same catalog the televisions read, so the
// site cannot advertise a line-up the channel does not have. Every count and
// every card below is the live catalog, gated exactly as the app gates it.
//
// The page is built as a run of full-bleed bands — ink, paper, ink — rather
// than one 960px column on black. See the "public site" block in globals.css
// for why.

import { readCatalog } from '@/lib/store'
import { publicCatalog, STRANDS, type Episode } from '@/lib/catalog'
import { COMMUNITY_STRAND } from '@/lib/submissions'
import SiteHeader from './_components/SiteHeader'
import SiteFooter from './_components/SiteFooter'

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
  image: 'https://tagalogue.tv/opengraph-image.png',
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

/**
 * The three strands the channel is made of, in running order.
 *
 * Taken from the same constants the content tool publishes against, so this
 * board describes the shape of the channel whether or not anything is in it.
 * The counts below are still the live catalog — the board never claims an
 * episode that does not exist.
 */
const BOARD = [...STRANDS, COMMUNITY_STRAND]

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
  const countFor = (id: string) =>
    catalog.shows.find((s) => s.id === id)?.episodes.length ?? 0
  const latest = [...episodes]
    .sort((a, b) => (b.publishedAt ?? '').localeCompare(a.publishedAt ?? ''))
    .slice(0, 6)

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(ORGANISATION) }}
      />
      <SiteHeader sections />

      <main className="site">
        <header className="band band--ink site-hero">
          <div className="band-inner">
            <p className="eyebrow">Filipino–Swiss · Biel/Bienne</p>
            <h1 className="site-title">Stories from the Filipino community in Switzerland</h1>
            <p className="site-lede">
              Sit-down interviews, vlogs from around the country, and pieces sent in by the
              people who watch. In Tagalog and English, free to watch on Apple TV.
            </p>
            <div className="site-actions">
              <a className="solid" href="/submit">Send us your story</a>
              {/* Not a link: there is no App Store listing yet, and a dead
                  Download button is worse than an honest label. */}
              <span className="status-chip">Coming to Apple TV</span>
            </div>
          </div>
        </header>
        <div className="site-hero-rule" />

        <section className="band band--surface">
          <div className="band-inner">
            <dl className="facts">
              <div><dt>Episodes</dt><dd>{episodes.length || '—'}</dd></div>
              <div><dt>Watch on</dt><dd>Apple TV</dd></div>
              <div><dt>Languages</dt><dd>Tagalog · English</dd></div>
              <div><dt>Price</dt><dd>Free</dd></div>
            </dl>
          </div>
        </section>

        <section className="band band--paper site-section" id="whats-on">
          <div className="band-inner">
            <p className="site-h2">What&rsquo;s on</p>
            <h2 className="site-head">Three strands, one channel</h2>
            <div className="strands">
              {BOARD.map((strand) => {
                const n = countFor(strand.id)
                return (
                  <article key={strand.id} className="strand">
                    <div className="strand-art" />
                    <div className="strand-body">
                      <h3 className="strand-name">{strand.title}</h3>
                      <p className="strand-sub">{strand.subtitle}</p>
                      <p className="strand-count">
                        {n > 0
                          ? `${n} ${n === 1 ? 'episode' : 'episodes'}`
                          : 'Nothing published yet'}
                      </p>
                    </div>
                  </article>
                )
              })}
            </div>
          </div>
        </section>

        {latest.length > 0 && (
          <section className="band band--paper site-section">
            <div className="band-inner">
              <p className="site-h2">Latest</p>
              <h2 className="site-head">Newest on the channel</h2>
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
            </div>
          </section>
        )}

        <section className="band band--paper site-section" id="how-to-watch">
          <div className="band-inner">
            <p className="site-h2">How to watch</p>
            <h2 className="site-head">Built for the room, not the browser</h2>
            <ol className="site-steps">
              <li>
                <span className="step-n">01</span>
                <strong>On Apple TV.</strong>
                <p>
                  The channel is an app for the television, not a website — built for the
                  room, the remote and the big screen.
                </p>
              </li>
              <li>
                <span className="step-n">02</span>
                <strong>Free, no account.</strong>
                <p>
                  Every episode published here plays without signing in or paying.
                </p>
              </li>
              <li>
                <span className="step-n">03</span>
                <strong>Pick up where you left off.</strong>
                <p>
                  The app remembers how far into an episode you got, on that television.
                </p>
              </li>
            </ol>
          </div>
        </section>

        {/* The one full field of red the design system allows: "the landing's
            closing banner — where type stays display-grade and the accent
            carries the page". */}
        <section className="band band--accent site-panel" id="community">
          <div className="band-inner">
            <p className="site-h2">Community</p>
            <h2 className="panel-title">Your story belongs on the channel</h2>
            <p className="panel-body">
              Anyone can send in a video from a phone — a few minutes of your life here, a
              trip home, something you want the community to see. An editor watches
              everything before it goes anywhere: <strong>nothing reaches a television
              without a person approving it first</strong>.
            </p>
            <a className="ghost" href="/submit">Submit a video</a>
          </div>
        </section>

        <section className="band band--paper site-section" id="follow">
          <div className="band-inner">
            <p className="site-h2">Follow</p>
            <h2 className="site-head">Where the channel talks</h2>
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
          </div>
        </section>

        <section className="band band--surface site-section" id="about">
          <div className="band-inner">
            <p className="site-h2">About</p>
            <h2 className="site-head">A channel for a community that had none</h2>
            <p className="prose">
              Tagalogue TV is a Filipino–Swiss channel run by Taxed GmbH in Biel/Bienne. It
              exists because the Filipino community in Switzerland has plenty to say and few
              places to say it — so the channel films conversations, collects vlogs from around
              the country, and puts what viewers send in alongside them.
            </p>
          </div>
        </section>
      </main>

      <SiteFooter episodes={episodes.length} />
    </>
  )
}
