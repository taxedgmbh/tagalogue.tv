import type { Metadata } from 'next'

// `page.tsx` here is a client component, which cannot export metadata — so
// /submit inherited the root default and went out to the public under whatever
// that said. A layout is the only place to give it its own title.
export const metadata: Metadata = {
  title: 'Submit a video — Tagalogue TV',
  description:
    'Record something on your phone and send it to the channel. An editor watches '
    + 'everything before it goes anywhere.',
  alternates: { canonical: '/submit' },
}

export default function SubmitLayout({ children }: { children: React.ReactNode }) {
  return children
}
