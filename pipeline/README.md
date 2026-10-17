# InVolve event pipeline

Fetches events from four sources, normalizes them to the Firestore `events`
schema and upserts them with the Firebase Admin SDK (`set` with `merge: true`,
so re-runs update the same documents). Runs on a GitHub Actions cron and by hand.

| Source | Prefix | Category | Notes |
| --- | --- | --- | --- |
| NYC Council (Legistar) | `legistar-<EventId>` | civic | needs `LEGISTAR_TOKEN` |
| NYC Parks events | `parks-<guid>` | local-culture, or neighborhood for Parks' "Volunteer" tag | ~2 weeks, no key |
| Mobilize | `mobilize-<id>` | cause-action | NYC only, in-person only, next open timeslot |
| NYC permitted events | `permit-<event_id>-<start>` | local-culture / neighborhood | allowlist of public event types only |

Every document has `categoryId, title, org, location, description, startsAt`
(Firestore Timestamp), `url`, and `action` where the source has one.

## Run locally

Requires Node 20.12+.

```bash
cd pipeline
npm install
cp .env.example .env     # then fill it in (gitignored)
npm run sync             # fetch + write to Firestore
```

## Dry run (no credentials needed)

```bash
npm run dry-run                           # all sources, prints every normalized doc
node src/index.js --dry-run --source=parks --limit=5
node src/index.js --dry-run --verbose     # also list every skipped record
```

Dry-run never initializes Firebase and writes nothing. Legistar reports
"not configured" unless `LEGISTAR_TOKEN` is set.

Flags: `--source=legistar,parks,mobilize,permits`, `--days=30` (lookahead),
`--limit=N` (max docs per source), `--verbose`.

## Secrets

| Name | Where | What |
| --- | --- | --- |
| `FIREBASE_SERVICE_ACCOUNT` | GitHub repo secret / `.env` | Full service-account key JSON (Firebase console, Project settings, Service accounts, Generate new private key). |
| `GOOGLE_APPLICATION_CREDENTIALS` | `.env` only | Alternative for local use: path to the key file. |
| `LEGISTAR_TOKEN` | GitHub repo secret / `.env` | NYC Council Legistar API token. |

Set the GitHub ones under Settings, Secrets and variables, Actions. Never
commit keys or tokens; `.env` and service-account JSON files are gitignored.

## GitHub Actions

`.github/workflows/sync-events.yml` runs every 6 hours (UTC) and on manual
dispatch (with an optional dry-run checkbox). GitHub only runs scheduled
workflows from the default branch, so it starts firing once merged to `main`.
The job fails if any source fails or a write fails; other sources still run.

## Behavior to know about

- Times are interpreted as America/New_York and stored as UTC Timestamps.
- Skipped, and logged by reason: missing title, missing/invalid start time,
  already ended, cancelled (Parks), deferred (Legistar), outside NYC (Mobilize).
- The pipeline only upserts. It never deletes, so an event that disappears from
  a source (or is cancelled after it was written) stays in Firestore.
- Tests: `npm test`.
