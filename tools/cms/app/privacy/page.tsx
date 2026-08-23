import SiteHeader from '../_components/SiteHeader'
import SiteFooter from '../_components/SiteFooter'

export const metadata = {
  title: 'Privacy — Tagalogue TV',
  description: 'What Tagalogue TV collects, which is very little, and what happens to it.',
}

export default function Privacy() {
  return (
    <>
      <SiteHeader />
      <main className="site">
        <header className="band band--ink site-hero site-hero--compact">
          <div className="band-inner">
        <p className="eyebrow">Tagalogue TV</p>
        <h1 className="site-title">Privacy</h1>
        <p className="site-lede">
          The short version: the Apple TV app has no accounts, no analytics and no
          advertising, and what it remembers about your viewing never leaves your
          television.
        </p>
          </div>
        </header>
        <div className="site-hero-rule" />

        <section className="band band--paper site-section">
          <div className="band-inner">
            <div className="policy">
        <h2>Who is responsible</h2>
        <p>
          Tagalogue TV is operated by <strong>Taxed GmbH</strong>, Aegertenstrasse 10,
          2503 Biel/Bienne, Switzerland. For anything on this page, write to{' '}
          <a href="mailto:info@taxed.ch">info@taxed.ch</a>.
        </p>

        <h2>The Apple TV app</h2>
        <p>
          There is no sign-in and no account. We do not use analytics, advertising
          identifiers, or any third-party tracking, and the app asks for no permissions.
        </p>
        <p>Two things are stored, and both stay on the television:</p>
        <ul>
          <li>
            <strong>How far you got in an episode</strong>, so Continue Watching works.
          </li>
          <li><strong>My List</strong>, the episodes you saved.</li>
        </ul>
        <p>
          Neither is sent to us or to anyone else. Deleting the app deletes both.
        </p>

        <h2>What reaches our servers</h2>
        <p>
          To show the channel, the app fetches a list of episodes from{' '}
          <strong>cdn.tagalogue.tv</strong>, and video is streamed from Cloudflare
          Stream. Like any web request, those carry your IP address and are recorded in
          Cloudflare&rsquo;s standard server logs. We use those logs only to keep the
          service running and to understand load. We do not build profiles from them,
          and we cannot connect them to a person.
        </p>

        <h2>If you send us a video</h2>
        <p>
          Sending something in is entirely optional and happens on this website, not in
          the app. The form asks for a name, optionally where you are, a message, and
          the video itself. <strong>It does not ask for an email address</strong>, so
          unless you write one in your message we have no way to contact you.
        </p>
        <p>
          What you send is stored on Cloudflare (video on Stream, everything else in
          R2) and is read by an editor at Taxed GmbH. If it is published, the name,
          place and message you gave become part of the episode and are visible to
          anyone watching the channel — so please only put in what you are happy to
          have seen. If it is not published, it stays in a private queue that only the
          editor can open.
        </p>

        <h2>If you report something</h2>
        <p>
          The <a href="/report">report form</a> records the reason you chose and
          anything you typed. Giving us a way to reach you is optional, and used only
          to come back to you about that report.
        </p>

        <h2>How long things are kept</h2>
        <p>
          Published episodes stay until the channel takes them down. Submissions that
          are declined, and reports once they are dealt with, are kept while they are
          useful as a record and then deleted. Server logs follow Cloudflare&rsquo;s own
          retention.
        </p>

        <h2>Your rights</h2>
        <p>
          You can ask what we hold about you, ask for it to be corrected, or ask us to
          delete it — including a video you sent in, whether or not it was published.
          Write to <a href="mailto:info@taxed.ch">info@taxed.ch</a> and we will act on
          it. Because submissions carry no verified identity, we may need you to
          describe what you sent so we can find the right item.
        </p>

        <h2>Children</h2>
        <p>
          The channel is not directed at children and we do not knowingly collect
          anything from them.
        </p>

        <p className="updated">Last updated 23 August 2026</p>
            </div>
          </div>
        </section>
      </main>
      <SiteFooter />
    </>
  )
}
