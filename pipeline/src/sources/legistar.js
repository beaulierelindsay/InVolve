// NYC Council meetings via the Legistar Web API (https://webapi.legistar.com/Help).
// Port of LegistarService + Event.fromLegistar in ui_draft/lib. Same document ID
// (`legistar-<EventId>`), title, org, action and description rules.
import { Collector, ConfigError } from "../lib/collector.js";
import { fetchJson } from "../lib/http.js";
import { cleanText, truncate } from "../lib/text.js";
import { nyDateString, nyWallClockToDate, parseClock } from "../lib/time.js";
import geocode from "../lib/geocode.js";

// Council meets in a few buildings; map room names to an address the geocoder knows.
const KNOWN_PLACES = [
   [/250 broadway/i, "250 Broadway, New York, NY"],
   [/1 centre st/i, "1 Centre Street, New York, NY"],
   [/city hall/i, "260 Broadway, New York, NY"],
];

const CLIENT = "nyc";
const ORG = "NYC Council";

async function legistarCoords(location) {
   const loc = cleanText(location);
   if (!loc || /virtual|remote|zoom|online/i.test(loc)) return null;
   const known = KNOWN_PLACES.find(([re]) => re.test(loc));
   return geocode(known ? known[1] : `${loc}, New York, NY`);
}
/**
 * EventDate is "2026-10-06T00:00:00" (the day only) and EventTime a separate
 * "1:30 PM". Both are NYC wall-clock. The Dart version builds a device-local
 * DateTime; here we pin it to America/New_York.
 */
export function legistarStart(eventDate, eventTime) {
   const day = /^(\d{4})-(\d{2})-(\d{2})/.exec(eventDate ?? "");
   const clock = parseClock(eventTime);
   if (!day || !clock) return null; // no usable time: not a Timestamp-worthy start
   return nyWallClockToDate(+day[1], +day[2], +day[3], clock.h, clock.m);
}

export async function mapLegistar(e, collector) {
   if (e.EventAgendaStatusName === "Deferred") {
      return (
         collector.fetched++,
         collector.skip("deferred (postponed)", `legistar-${e.EventId}`)
      );
   }
   const body = cleanText(e.EventBodyName) || "Public meeting";
   const comment = cleanText(e.EventComment);
   const geo = await legistarCoords(e.EventLocation);
   collector.add({
      id: `legistar-${e.EventId}`,
      categoryId: "civic",
      title: cleanText(e.EventBodyName),
      org: ORG,
      location: cleanText(e.EventLocation),
      description: truncate(
         comment || `Public meeting of the ${body}. Open to the public.`,
         600,
      ),
      startsAt: legistarStart(e.EventDate, e.EventTime),
      action: "View agenda",
      url: e.EventInSiteURL || undefined,
      latitude: geo?.latitude,
      longitude: geo?.longitude,
   });
}

export async function fetchLegistar({ now, days }) {
   const token = process.env.LEGISTAR_TOKEN;
   if (!token) throw new ConfigError("LEGISTAR_TOKEN is not set");

   const from = nyDateString(now);
   const to = nyDateString(new Date(now.getTime() + days * 86_400_000));
   const url = new URL(`https://webapi.legistar.com/v1/${CLIENT}/events`);
   url.searchParams.set("token", token);
   url.searchParams.set(
      "$filter",
      `EventDate ge datetime'${from}' and EventDate lt datetime'${to}'`,
   );
   url.searchParams.set("$orderby", "EventDate asc");

   const items = await fetchJson(url.toString());
   if (!Array.isArray(items))
      throw new Error("Legistar: expected a JSON array");

   const c = new Collector("legistar", now);
   for (const e of items) await mapLegistar(e, c);
   return c;
}
