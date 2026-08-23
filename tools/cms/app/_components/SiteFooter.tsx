// The footer, shared by every public page.
//
// Back on ink, so the page closes on the brand the way the Top Shelf artwork
// does. This is also the only place the editor's door appears: it used to sit
// in the masthead behind a border, which made an internal sign-in the most
// button-like thing on a page whose actual call to action is "send us your
// story".
//
// The publisher line — Taxed GmbH, and Skopa alongside it — moved to the
// "Who we are" section of /terms. It is company business, not something a
// viewer needs on every page, and the operator is still named (with the
// address) on /terms, /privacy and /support, which is what keeps it findable.

/**
 * `episodes` is the live published count, shown as the closing line. Only the
 * landing page reads the catalog, so the policy pages simply omit it rather
 * than each making their own R2 round-trip to print one sentence.
 */
export default function SiteFooter({ episodes }: { episodes?: number }) {
  return (
    <footer className="band band--ash site-foot">
      <div className="band-inner">
        <div>
          <strong>Tagalogue TV</strong>
          <br />
          Biel/Bienne, Switzerland
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
        {episodes !== undefined && (
          <div className="site-foot-meta">
            {episodes > 0
              ? `${episodes} ${episodes === 1 ? 'episode' : 'episodes'} published`
              : 'Launching soon'}
          </div>
        )}
      </div>
    </footer>
  )
}
