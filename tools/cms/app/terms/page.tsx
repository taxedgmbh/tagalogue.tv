import SiteHeader from '../_components/SiteHeader'
import SiteFooter from '../_components/SiteFooter'

export const metadata = {
  title: 'Terms — Tagalogue TV',
  description: 'The rules for watching Tagalogue TV and for sending a video to the channel.',
}

export default function Terms() {
  return (
    <>
      <SiteHeader />
      <main className="site">
        <header className="band band--ink site-hero site-hero--compact">
          <div className="band-inner">
        <p className="eyebrow">Tagalogue TV</p>
        <h1 className="site-title">Terms of use</h1>
        <p className="site-lede">
          Watching is free and needs no account. Sending something in comes with a few
          rules, and they are short.
        </p>
          </div>
        </header>
        <div className="site-hero-rule" />

        <section className="band band--paper site-section">
          <div className="band-inner">
            <div className="policy">
        <h2>Who we are</h2>
        <p>
          Tagalogue TV is run by <strong>Taxed GmbH</strong>, Aegertenstrasse 10,
          2503 Biel/Bienne, Switzerland — <a href="mailto:info@taxed.ch">info@taxed.ch</a>.
          Using the app or this website means accepting what is on this page.
        </p>

        <h2>Watching</h2>
        <p>
          The channel is free. Episodes may be added, changed or removed at any time,
          and some are only available for a period. The content belongs to Taxed GmbH
          or to the people who made it; you may watch it, and nothing more — no
          copying, re-uploading or redistribution.
        </p>

        <h2>Sending a video</h2>
        <p>When you send something to the channel, you are telling us that:</p>
        <ul>
          <li>You made it, or you have the right to give it to us.</li>
          <li>
            Everyone recognisable in it agreed to appear, and to it being shown
            publicly.
          </li>
          <li>It contains no music, footage or images belonging to someone else.</li>
          <li>
            You are happy for the name, place and message you gave to be shown
            alongside it.
          </li>
        </ul>
        <p>
          You keep ownership of your video. You give Taxed GmbH permission to show it
          on the channel and to use short extracts to promote the channel. You can
          withdraw that at any time by writing to us, and we will take it down.
        </p>

        <h2>What must not be sent</h2>
        <p>
          <strong>There is no tolerance for objectionable content.</strong> Do not send
          anything that is hateful, abusive or discriminatory; violent or graphic;
          sexual; harassing towards a person; that exposes someone&rsquo;s private
          information; or that is deliberately false.
        </p>

        <h2>How this is enforced</h2>
        <ul>
          <li>
            <strong>Nothing published without review.</strong> Every submission goes
            into a private queue and is watched by an editor. Nothing a stranger sends
            can reach a television by itself.
          </li>
          <li>
            <strong>Anyone can report anything.</strong> Use the{' '}
            <a href="/report">report form</a> — no account needed. We aim to look at
            every report and remove anything that breaks these rules{' '}
            <strong>within 24 hours</strong>.
          </li>
          <li>
            <strong>We can refuse anyone.</strong> We may decline a submission without
            giving a reason, remove something already published, and refuse further
            submissions from a person who abuses this.
          </li>
        </ul>

        <h2>No warranty</h2>
        <p>
          The channel is provided as it is. We do not promise it will always be
          available or free of faults, and to the extent Swiss law allows we are not
          liable for loss arising from using it.
        </p>

        <h2>Law</h2>
        <p>
          Swiss law applies, and the courts of Biel/Bienne have jurisdiction. If we
          change these terms the date below changes with them.
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
