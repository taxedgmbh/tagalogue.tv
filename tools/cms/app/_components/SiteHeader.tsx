// The masthead, shared by every public page.
//
// It used to exist only on `/`, which left /privacy, /terms, /support and
// /report as orphan pages with no way back to the channel and no chrome at
// all. `_components` is an App Router private folder — it is not routable, so
// this cannot accidentally become a page.
//
// Ink, because that is the ground the lockup was drawn on: the artwork carries
// its own black, which is invisible here and would be a hard square anywhere
// else.

/** Section links only make sense on the landing page, where the sections are. */
export default function SiteHeader({ sections = false }: { sections?: boolean }) {
  return (
    <nav className="topbar">
      <div className="topbar-inner">
        {/* The wordmark beside the mark is hidden below 720px, and the mark
            itself is decorative — so on a phone this link had no accessible
            name at all. Named here rather than by giving the image alt text,
            which would then be read twice on a wide screen. */}
        <a className="topbar-brand" href="/" aria-label="Tagalogue TV — home">
          <img
            src="/brand/mark-40.png"
            srcSet="/brand/mark-40.png 1x, /brand/mark-40@2x.png 2x, /brand/mark-40@3x.png 3x"
            alt=""
            width={44}
            height={36}
          />
          <span>Tagalogue TV</span>
        </a>
        <div className="topbar-links">
          {sections ? (
            <>
              <a href="#whats-on">What&rsquo;s on</a>
              <a href="#how-to-watch">How to watch</a>
              <a href="#community">Submit a video</a>
              <a href="#follow">Follow</a>
            </>
          ) : (
            <>
              <a href="/">Home</a>
              <a href="/submit">Submit a video</a>
              <a href="/support">Support</a>
            </>
          )}
        </div>
      </div>
    </nav>
  )
}
