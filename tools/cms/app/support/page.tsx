export const metadata = {
  title: 'Support — Tagalogue TV',
  description: 'Help with the Tagalogue TV app on Apple TV, and how to reach a person.',
}

export default function Support() {
  return (
    <main className="site">
      <section className="site-hero">
        <p className="eyebrow">Tagalogue TV</p>
        <h1 className="site-title">Support</h1>
        <p className="site-lede">
          A real person reads what comes in. Write to{' '}
          <a className="ghost" href="mailto:info@taxed.ch" style={{ marginLeft: 6 }}>info@taxed.ch</a>
        </p>
      </section>

      <section className="site-section policy">
        <h2>The channel is empty</h2>
        <p>
          If the app says <strong>&ldquo;Nothing on air yet&rdquo;</strong>, there is
          genuinely nothing published — the app is working. New episodes appear on
          their own, without updating the app.
        </p>

        <h2>An episode will not play</h2>
        <p>
          Check the Apple TV&rsquo;s internet connection first. The app streams over
          HTTPS and needs no special network setup. If one episode fails while others
          play, tell us which one.
        </p>

        <h2>Continue Watching forgot where I was</h2>
        <p>
          Resume positions are stored on that television only — they do not follow you
          to another Apple TV, and deleting the app clears them.
        </p>

        <h2>I sent a video and nothing happened</h2>
        <p>
          Every submission is watched by an editor before it can appear, so there is a
          wait. We may also decide not to publish it. Because the form does not ask for
          an email address, we usually cannot write back — mention how to reach you in
          your message if you want an answer.
        </p>

        <h2>Something on the channel should not be there</h2>
        <p>
          Use the <a href="/report">report form</a>. No account, no sign-in. We aim to
          act within 24 hours. See the <a href="/terms">terms</a> for what is not
          allowed.
        </p>

        <h2>Privacy and your data</h2>
        <p>
          What we collect, and how to have it deleted, is on the{' '}
          <a href="/privacy">privacy page</a>.
        </p>

        <h2>Contact</h2>
        <p>
          Taxed GmbH, Aegertenstrasse 10, 2503 Biel/Bienne, Switzerland<br />
          <a href="mailto:info@taxed.ch">info@taxed.ch</a>
        </p>
      </section>
    </main>
  )
}
