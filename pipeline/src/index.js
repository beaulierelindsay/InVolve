#!/usr/bin/env node
// Fetches events from every source, normalises them to the Firestore `events`
// schema and upserts them (or, with --dry-run, just prints them).
import { parseArgs } from "node:util";
import { ConfigError } from "./lib/collector.js";
import {
   getDb,
   hasCredentials,
   upsertEvents,
   deleteExpiredEvents,
} from "./lib/firestore.js";
import { formatNy } from "./lib/time.js";
import { fetchLegistar } from "./sources/legistar.js";
import { fetchMobilize } from "./sources/mobilize.js";
import { fetchParks } from "./sources/parks.js";
import { fetchPermits } from "./sources/permits.js";

// Optional local .env (Node >= 20.12). Real env vars win; missing file is fine.
try {
   process.loadEnvFile?.(new URL("../.env", import.meta.url));
} catch {}

// Permits last on purpose: it is the least clean source.
const SOURCES = {
   legistar: fetchLegistar,
   parks: fetchParks,
   mobilize: fetchMobilize,
   permits: fetchPermits,
};

const { values: args } = parseArgs({
   options: {
      "dry-run": { type: "boolean", default: false },
      source: { type: "string" }, // comma-separated subset
      days: { type: "string", default: "30" }, // lookahead window (Parks feed is fixed at ~14)
      limit: { type: "string" }, // max docs per source (testing)
      verbose: { type: "boolean", default: false }, // list every skipped record
      help: { type: "boolean", short: "h", default: false },
   },
});

if (args.help) {
   console.log(
      `Usage: node src/index.js [--dry-run] [--source=legistar,parks,mobilize,permits] [--days=30] [--limit=N] [--verbose]`,
   );
   process.exit(0);
}

const dryRun = args["dry-run"];
const days = Number(args.days);
const limit = args.limit ? Number(args.limit) : Infinity;
const names = args.source
   ? args.source.split(",").map((s) => s.trim())
   : Object.keys(SOURCES);
const unknown = names.filter((n) => !SOURCES[n]);
if (unknown.length || !(days > 0) || !(limit > 0)) {
   console.error(
      unknown.length
         ? `Unknown source(s): ${unknown.join(", ")}`
         : "Invalid --days / --limit",
   );
   process.exit(2);
}

const log = (m) => console.log(`[warn] ${m}`);
const now = new Date();
const results = []; // { name, status, error, collector, docs, written }

console.log(
   `${dryRun ? "DRY RUN (nothing is written)" : "SYNC"} at ${formatNy(now)}, window ${days}d`,
);

// Fail fast, before any network work, if we are going to write but cannot.
if (!dryRun && !hasCredentials()) {
   console.error(
      "No Firebase credentials: set FIREBASE_SERVICE_ACCOUNT (JSON) or GOOGLE_APPLICATION_CREDENTIALS (file path). Use --dry-run to run without them.",
   );
   process.exit(1);
}

// 1. Fetch + normalise. One source throwing never stops the others.
for (const name of names) {
   const r = { name, status: "ok", docs: [], written: 0 };
   results.push(r);
   try {
      r.collector = await SOURCES[name]({ now, days, log });
      r.docs = [...r.collector.docs.values()].slice(0, limit);
   } catch (err) {
      r.status =
         err instanceof ConfigError && dryRun ? "not configured" : "FAILED";
      r.error = err.message;
      console.error(`[${name}] ${r.status}: ${err.message}`);
   }
}

// 2. Print (dry-run) or write.
if (dryRun) {
   for (const r of results) {
      for (const { id, data } of r.docs) {
         console.log(
            JSON.stringify(
               {
                  id,
                  ...data,
                  startsAt: data.startsAt.toISOString(),
                  _startsAtNY: formatNy(data.startsAt), // display only, not a field
               },
               null,
               2,
            ),
         );
      }
   }
} else {
   let client;
   try {
      client = await getDb();
   } catch (err) {
      console.error(`Firestore init failed: ${err.message}`);
      process.exit(1);
   }
   for (const r of results) {
      if (r.status !== "ok" || !r.docs.length) continue;
      try {
         r.written = await upsertEvents(client, r.docs);
      } catch (err) {
         r.status = "FAILED";
         r.error = `write failed: ${err.message}`;
         console.error(`[${r.name}] ${r.error}`);
      }
   }
   try {
      const deleted = await deleteExpiredEvents(client, now);
      console.log(`[cleanup] deleted ${deleted} expired event(s)`);
   } catch (err) {
      console.error(`[cleanup] failed: ${err.message}`);
   }
}

// 3. Summary.
console.log("\n=== Summary ===");
for (const r of results) {
   const c = r.collector;
   const verb = dryRun ? "would write" : "written";
   const count = dryRun ? r.docs.length : r.written;
   const skipped = c ? c.skips.length : 0;
   console.log(
      `${r.name.padEnd(9)} ${r.status.padEnd(14)} fetched=${c?.fetched ?? 0} ${verb}=${count} skipped=${skipped}${r.error ? `  (${r.error})` : ""}`,
   );
   for (const [reason, n] of c?.skipSummary() ?? []) {
      console.log(`            - ${n} × ${reason}`);
      if (args.verbose)
         c.skips
            .filter((s) => s.reason === reason)
            .forEach((s) => console.log(`                ${s.ref}`));
   }
}

// Non-zero exit when a source really failed, so the Actions run goes red.
process.exit(results.some((r) => r.status === "FAILED") ? 1 : 0);
