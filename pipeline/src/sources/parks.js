// NYC Parks public events. Data dictionary: https://data.cityofnewyork.us/d/w3wp-dpdi
// Feed: one JSON array, ~2 weeks of events, one element per occurrence.
import { Collector } from "../lib/collector.js";
import { fetchJson } from "../lib/http.js";
import { cleanText, truncate } from "../lib/text.js";
import { nyWallClockToDate, parseClock } from "../lib/time.js";

const URL_ = "https://www.nycgovparks.org/xml/events_300_rss.json";

/** Parks' own "Volunteer" tag = stewardship work (cleanups, plantings). Everything else is programming. */
function categoryFor(categories) {
   return /(^|\|)\s*Volunteer\s*(\||$)/i.test(categories ?? "")
      ? "neighborhood"
      : "local-culture";
}

function toDate(dateStr, clockStr) {
   const d = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateStr ?? "");
   const t = parseClock(clockStr);
   if (!d || !t) return null;
   return nyWallClockToDate(+d[1], +d[2], +d[3], t.h, t.m);
}

export function mapParks(e, collector) {
   const id = `parks-${e.guid}`;
   const title = cleanText(e.title);
   if (/^cancel+ed\b/i.test(title)) {
      return (
         collector.fetched++,
         collector.skip("cancelled", `${id} ${title}`)
      );
   }
   const tags = cleanText(e.categories)
      .split("|")
      .map((s) => s.trim())
      .filter(Boolean);
   const description =
      cleanText(e.description) ||
      (tags.length
         ? `Free NYC Parks event: ${tags.join(", ")}.`
         : "Free NYC Parks event.");
   const link = e.link
      ? String(e.link).replace(/^http:\/\//, "https://")
      : undefined;
   const [lat, lng] = String(e.coordinates ?? "")
      .split(",")
      .map((s) => parseFloat(s));
   collector.add({
      id,
      categoryId: categoryFor(e.categories),
      title,
      org: "NYC Parks",
      location: cleanText(e.location) || cleanText(e.parknames),
      description: truncate(description, 600),
      startsAt: toDate(e.startdate, e.starttime),
      endsAt: toDate(e.enddate || e.startdate, e.endtime),
      action: e.registration_url ? "Register" : undefined,
      url: link,
      latitude: lat,
      longitude: lng,
   });
}

const DIAG_HEADERS = [
   "server", "via", "x-cache", "x-amz-cf-id", "x-amz-cf-pop",
   "content-type", "allow", "location",
];

/** Temporary diagnostics for the Parks 405 seen only on GitHub Actions. Logs on non-OK responses only. */
async function logParksHttpError(res, { attempt, url }) {
   const headers = Object.fromEntries(
      DIAG_HEADERS.filter((h) => res.headers.has(h)).map((h) => [h, res.headers.get(h)]),
   );
   let body = "";
   try {
      body = (await res.text()).slice(0, 500).replace(/\s+/g, " ").trim();
   } catch (err) {
      body = `<unreadable: ${err.message}>`;
   }
   console.error(
      `[parks-diag] attempt=${attempt + 1} status=${res.status} statusText=${JSON.stringify(res.statusText)} ` +
         `requested=${url} finalUrl=${res.url ? new URL(res.url).origin + new URL(res.url).pathname : ""} ` +
         `redirected=${res.redirected}\n[parks-diag] headers=${JSON.stringify(headers)}\n[parks-diag] body=${JSON.stringify(body)}`,
   );
}

export async function fetchParks({ now }) {
   const items = await fetchJson(URL_, { onHttpError: logParksHttpError });
   if (!Array.isArray(items)) throw new Error("Parks: expected a JSON array");
   const c = new Collector("parks", now);
   for (const e of items) mapParks(e, c);
   return c;
}
