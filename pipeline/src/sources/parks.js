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

export async function fetchParks({ now }) {
   const items = await fetchJson(URL_);
   if (!Array.isArray(items)) throw new Error("Parks: expected a JSON array");
   const c = new Collector("parks", now);
   for (const e of items) mapParks(e, c);
   return c;
}
