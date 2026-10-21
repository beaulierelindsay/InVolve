// NYC Permitted Event Information (Socrata tvpp-9vvx).
// https://data.cityofnewyork.us/resource/tvpp-9vvx
//
// The dataset is mostly youth/adult sports field permits, film shoots and
// construction closures, plus private bookings. Only these event_type values
// are community-facing public events, so everything else is dropped at the
// query (an allowlist, not a blocklist: new types stay out until reviewed).
// Excluded on purpose: "Special Event" (mostly private Parks bookings and
// closures such as "Party"/"Picnic"/"closed"), "Religious Event" (includes
// private weddings), "Open Street/Plaza Partner Event" (recurring programming
// with no real title), sports, production, theater load-ins.
import { Collector } from "../lib/collector.js";
import { fetchJson } from "../lib/http.js";
import { cleanText, truncate, unshout } from "../lib/text.js";
import { parseNyLocalIso, nyDateString } from "../lib/time.js";

const ENDPOINT = "https://data.cityofnewyork.us/resource/tvpp-9vvx.json";
const PAGE = 5000;

const TYPE_TO_CATEGORY = {
   Parade: "local-culture",
   "Street Festival": "local-culture",
   "Single Block Festival": "local-culture",
   "Block Party": "local-culture",
   "Farmers Market": "local-culture",
   "Sidewalk Sale": "local-culture",
   "Plaza Event": "local-culture",
   "Athletic Race / Tour": "local-culture",
   "Health Fair": "neighborhood",
   "Clean-Up": "neighborhood",
};

/**
 * `event_id` is NOT unique: a recurring permit repeats the same id on every
 * date. The document ID therefore includes the NYC start time.
 */
export function permitDocId(e) {
   const t = String(e.start_date_time ?? "")
      .replace(/[-:]/g, "")
      .slice(0, 13); // 20261015T1600
   return `permit-${e.event_id}-${t}`;
}

/** event_location is a comma-joined list of street segments; show the first. */
export function permitLocation(e) {
   const segs = String(e.event_location ?? "")
      .split(/\s*,\s+(?=[A-Za-z0-9])/)
      .map(cleanText)
      .filter(Boolean);
   if (!segs.length) return e.event_borough ?? "";
   const uniq = [...new Set(segs.map((s) => s.toLowerCase()))].length;
   const first = truncate(unshout(segs[0]), 120);
   const more =
      uniq > 1 ? ` (+${uniq - 1} more block${uniq > 2 ? "s" : ""})` : "";
   return `${first}${more}${e.event_borough ? `, ${e.event_borough}` : ""}`;
}

export function mapPermit(e, collector) {
   const startsAt = parseNyLocalIso(e.start_date_time);
   const endsAt = parseNyLocalIso(e.end_date_time);

   const expirationTime = endsAt ?? startsAt;

   if (expirationTime <= collector.now) {
      collector.fetched++;
      return collector.skip("event already ended", id);
   }
   const category = TYPE_TO_CATEGORY[e.event_type];
   const id = permitDocId(e);
   if (!category)
      return (
         collector.fetched++,
         collector.skip(`event_type not allowlisted (${e.event_type})`, id)
      );
   const closure =
      e.street_closure_type && e.street_closure_type !== "N/A"
         ? ` Street closure: ${e.street_closure_type}.`
         : "";
   collector.add({
      id,
      categoryId: category,
      title: cleanText(e.event_name),
      org: cleanText(e.event_agency),
      location: permitLocation(e),
      description: truncate(
         `${e.event_type} permitted by ${cleanText(e.event_agency) || "the City"}${e.event_borough ? ` in ${e.event_borough}` : ""}.${closure}`,
         600,
      ),
      startsAt,
      endsAt,
      expiresAt: endsAt ?? startsAt,
   });
}

export async function fetchPermits({ now, days }) {
   const from = `${nyDateString(now)}T00:00:00`;
   const to = `${nyDateString(new Date(now.getTime() + days * 86_400_000))}T00:00:00`;
   const types = Object.keys(TYPE_TO_CATEGORY)
      .map((t) => `'${t}'`)
      .join(",");
   const where = `start_date_time >= '${from}' AND start_date_time < '${to}' AND event_type in(${types})`;

   const c = new Collector("permits", now);
   for (let offset = 0; ; offset += PAGE) {
      const u = new URL(ENDPOINT);
      u.searchParams.set("$where", where);
      u.searchParams.set("$order", "start_date_time, event_id");
      u.searchParams.set("$limit", String(PAGE));
      u.searchParams.set("$offset", String(offset));
      const rows = await fetchJson(u.toString());
      if (!Array.isArray(rows))
         throw new Error("Permits: expected a JSON array");
      for (const r of rows) mapPermit(r, c);
      if (rows.length < PAGE) break;
   }
   return c;
}
