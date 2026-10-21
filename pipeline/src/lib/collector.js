export const CATEGORY_IDS = [
   "civic",
   "direct-service",
   "neighborhood",
   "cause-action",
   "local-culture",
   "mutual-aid",
];

/** Thrown when a source can't run because of missing configuration (e.g. a token). */
export class ConfigError extends Error {}

/**
 * Gathers the normalized documents and the skip log for one source.
 * `add` is the single place that enforces the schema rules, so every source
 * gets the same validation: category, title, start time, not already over.
 */
export class Collector {
   constructor(source, now) {
      this.source = source;
      this.now = now;
      this.fetched = 0;
      this.docs = new Map(); // id -> { id, data }
      this.skips = []; // { reason, ref }
   }

   skip(reason, ref = "") {
      this.skips.push({ reason, ref: String(ref) });
   }

   /** @returns {boolean} whether the document was accepted */
   add({
      id,
      categoryId,
      title,
      org,
      location,
      description,
      startsAt,
      endsAt,
      action,
      spots,
      url,
   }) {
      this.fetched++;
      const ref = `${id ?? "?"} ${title ?? ""}`.trim();
      if (!CATEGORY_IDS.includes(categoryId))
         throw new Error(`bad categoryId "${categoryId}" for ${ref}`);
      if (!title) return (this.skip("missing title", ref), false);
      if (!(startsAt instanceof Date) || Number.isNaN(startsAt.getTime())) {
         return (this.skip("missing/invalid start time", ref), false);
      }
      const end =
         endsAt instanceof Date && endsAt >= startsAt ? endsAt : startsAt;
      if (end < this.now) return (this.skip("past event", ref), false);
      if (this.docs.has(id))
         return (this.skip("duplicate id in feed", ref), false);

      const data = {
         categoryId,
         title,
         org: org ?? "",
         location: location ?? "",
         description: description ?? "",
         startsAt,
         endsAt: end,
         expiresAt: end,
      };
      if (action) data.action = action;
      if (Number.isFinite(spots)) data.spots = spots;
      if (url) data.url = url;
      this.docs.set(id, { id, data });
      return true;
   }

   /** Counts per reason, most common first. */
   skipSummary() {
      const m = new Map();
      for (const s of this.skips) m.set(s.reason, (m.get(s.reason) ?? 0) + 1);
      return [...m].sort((a, b) => b[1] - a[1]);
   }
}
