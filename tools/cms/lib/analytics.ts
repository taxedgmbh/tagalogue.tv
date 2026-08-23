// What the channel actually watched, without watching anybody.
//
// The Apple TV keeps viewing to itself — /privacy says so, and the app means
// it: watch progress lives in SwiftData on the television and is never sent
// anywhere. So a "most watched" chart cannot be built from the app, and adding
// telemetry to get one would break a published promise.
//
// Cloudflare already counts playback at the edge, per video, as an aggregate.
// There is no viewer in it: no identity, no session, no device, nothing that
// could be tied back to a person. Reading those totals is the one way to rank
// episodes honestly, and it happens here on the server — never on a television.

import { env } from './store'

const GRAPHQL = 'https://api.cloudflare.com/client/v4/graphql'

/**
 * Minutes viewed per Stream video over a window, highest first.
 *
 * Minutes rather than play count on purpose: a play is registered the moment
 * somebody lands on a video, so counting plays rewards whatever sits in the
 * hero. Minutes viewed measures what people actually sat through.
 *
 * Returns an empty map rather than throwing. A chart is a nice-to-have; it
 * must never be the reason publishing or the catalog fails.
 */
export async function minutesViewedByVideo(
  hours = 24
): Promise<{ views: Map<string, number>; error?: string }> {
  const until = new Date()
  const since = new Date(until.getTime() - hours * 3600 * 1000)

  const query = `
    query StreamTop($account: String!, $since: Time!, $until: Time!) {
      viewer {
        accounts(filter: { accountTag: $account }) {
          streamMinutesViewedAdaptiveGroups(
            filter: { datetime_geq: $since, datetime_lt: $until }
            limit: 1000
            orderBy: [sum_minutesViewed_DESC]
          ) {
            sum { minutesViewed }
            dimensions { uid }
          }
        }
      }
    }`

  try {
    const res = await fetch(GRAPHQL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env('CF_API_TOKEN')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        query,
        variables: {
          account: env('STREAM_ACCOUNT_ID'),
          since: since.toISOString(),
          until: until.toISOString(),
        },
      }),
    })

    const json = (await res.json()) as {
      data?: {
        viewer?: {
          accounts?: {
            streamMinutesViewedAdaptiveGroups?: {
              sum?: { minutesViewed?: number }
              dimensions?: { uid?: string }
            }[]
          }[]
        }
      }
      errors?: { message: string }[]
    }

    if (json.errors?.length) {
      // Overwhelmingly the reason this fails: the Stream token carries
      // Stream:Edit and nothing else, and the GraphQL analytics dataset needs
      // Account Analytics:Read as well. Said plainly so it is not mistaken for
      // "nobody watched anything".
      return { views: new Map(), error: json.errors.map((e) => e.message).join(', ') }
    }

    const rows = json.data?.viewer?.accounts?.[0]?.streamMinutesViewedAdaptiveGroups ?? []
    const views = new Map<string, number>()
    for (const row of rows) {
      const uid = row.dimensions?.uid
      const minutes = row.sum?.minutesViewed
      if (uid && typeof minutes === 'number') views.set(uid, minutes)
    }
    return { views }
  } catch (error) {
    return { views: new Map(), error: (error as Error).message }
  }
}

/**
 * The episode ids of the most-watched episodes, highest first.
 *
 * Published episodes carry `cf-<uid>` as their id, which is the only join
 * between a Stream video and a catalog entry. Anything in the analytics that
 * no longer has an episode — a deleted clip, a rejected submission — falls out
 * here rather than becoming a rank pointing at nothing.
 */
export function rankEpisodeIDs(
  views: Map<string, number>,
  existingIDs: Set<string>,
  limit = 10
): string[] {
  return [...views.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([uid]) => `cf-${uid}`)
    .filter((id) => existingIDs.has(id))
    .slice(0, limit)
}
