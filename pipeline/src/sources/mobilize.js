// Mobilize (cause-action). Docs: https://github.com/mobilizeamerica/api
//
// GET /v1/events is marked DEPRECATED in the docs ("will soon function as an
// alias for List Organization Events with organization_id=1"), so we call the
// live equivalent, /v1/organizations/1/events, which returns the same data today.
// `zipcode` + `max_dist` are documented request params (they trigger Mobilize's
// search backend, which caps results at 1000: `results_limited_to`).
import { Collector } from '../lib/collector.js';
import { fetchJson, sleep } from '../lib/http.js';
import { cleanText, stripMarkdown, truncate } from '../lib/text.js';

const BASE = 'https://api.mobilize.us/v1/organizations/1/events';
const CENTER_ZIP = '10001'; // Midtown Manhattan
const RADIUS_MILES = 25; // covers all five boroughs (and parts of NJ/Nassau, filtered below)
const PER_PAGE = 100;
const MAX_PAGES = 30;
const PAGE_DELAY_MS = 150; // ~7 req/s, well under the documented 15 req/s

// ZIP ranges that are inside the five boroughs (the 25mi radius also catches NJ and Nassau).
const NYC_ZIP_RANGES = [
  [10001, 10292], // Manhattan
  [10301, 10314], // Staten Island
  [10451, 10475], // Bronx
  [11004, 11005], // Glen Oaks / Floral Park (Queens)
  [11101, 11109], [11120, 11120], // Long Island City / Queens
  [11201, 11256], // Brooklyn
  [11351, 11499], // Queens
  [11691, 11697], // Rockaways
];
export function isNycZip(zip) {
  const m = /^(\d{5})/.exec(zip ?? '');
  if (!m) return false;
  const n = +m[1];
  return NYC_ZIP_RANGES.some(([a, b]) => n >= a && n <= b);
}

const PRIVATE_ADDRESS = /address is private/i;

export function mapMobilize(e, collector, now) {
  const id = `mobilize-${e.id}`;
  const loc = e.location;
  if (e.is_virtual || !loc) {
    return collector.fetched++, collector.skip('virtual / no location', id);
  }
  // Some records have a ZIP but no region/locality, so only reject a *wrong* region.
  if ((loc.region && loc.region !== 'NY') || !isNycZip(loc.postal_code)) {
    return collector.fetched++, collector.skip('outside NYC', `${id} ${loc.locality ?? ''}, ${loc.region ?? ''} ${loc.postal_code ?? ''}`);
  }

  // One document per event => the soonest slot that hasn't ended. Timeslots are
  // Unix seconds (timezone-independent), so no tz conversion is needed here.
  const slots = (e.timeslots ?? [])
    .filter((t) => !t.is_full && t.end_date * 1000 >= now.getTime())
    .sort((a, b) => a.start_date - b.start_date);
  const slot = slots[0];

  const priv = e.address_visibility === 'PRIVATE' || PRIVATE_ADDRESS.test(loc.venue ?? '');
  const street = (loc.address_lines ?? []).map(cleanText).filter(Boolean).join(', ');
  const venue = cleanText(loc.venue);
  const streetNew = venue.toLowerCase().includes(street.toLowerCase()) ? '' : street; // venue often repeats the address
  const place = [venue, streetNew].filter(Boolean).join(', ');
  const city = [cleanText(loc.locality), loc.region].filter(Boolean).join(', ');
  const location = priv ? `Address shared after sign-up (${city} ${loc.postal_code})` : [place, city].filter(Boolean).join(', ');

  const description = cleanText(stripMarkdown(String(e.description ?? ''))) || cleanText(e.summary);
  collector.add({
    id,
    categoryId: 'cause-action',
    title: cleanText(e.title),
    org: cleanText(e.sponsor?.name),
    location,
    description: truncate(description, 600),
    startsAt: slot ? new Date(slot.start_date * 1000) : null,
    endsAt: slot ? new Date(slot.end_date * 1000) : null,
    url: e.browser_url,
  });
}

export async function fetchMobilize({ now, days, log }) {
  const horizon = Math.floor(now.getTime() / 1000) + days * 86_400;
  const first = new URL(BASE);
  first.searchParams.append('timeslot_start', 'gte_now');
  first.searchParams.append('timeslot_start', `lt_${horizon}`);
  first.searchParams.set('zipcode', CENTER_ZIP);
  first.searchParams.set('max_dist', String(RADIUS_MILES));
  first.searchParams.set('is_virtual', 'false');
  first.searchParams.set('exclude_full', 'true');
  first.searchParams.set('per_page', String(PER_PAGE));

  const c = new Collector('mobilize', now);
  let url = first.toString();
  for (let page = 1; url && page <= MAX_PAGES; page++) {
    const body = await fetchJson(url);
    if (page === 1 && body.results_limited_to && body.count >= body.results_limited_to) {
      log(`mobilize: result count hit the API cap of ${body.results_limited_to}; some events may be missing`);
    }
    for (const e of body.data ?? []) mapMobilize(e, c, now);
    // Only ever follow pagination links on the Mobilize API host.
    url = body.next && new URL(body.next).host === 'api.mobilize.us' ? body.next : null;
    if (url) await sleep(PAGE_DELAY_MS);
  }
  if (url) log(`mobilize: stopped after ${MAX_PAGES} pages; more results exist`);
  return c;
}
