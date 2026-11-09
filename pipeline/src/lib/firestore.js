import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { ConfigError } from "./collector.js";

const PIPELINE_DIR = fileURLToPath(new URL("../../", import.meta.url));

/** A relative key path in .env means "relative to pipeline/", whatever the cwd is. */
function resolveKeyPath(p) {
   const abs = resolve(PIPELINE_DIR, p);
   if (!existsSync(abs))
      throw new ConfigError(
         `GOOGLE_APPLICATION_CREDENTIALS file not found: ${abs}`,
      );
   return abs;
}

const BATCH_SIZE = 400; // Firestore's limit is 500 writes per batch

/** True when some form of Admin credentials is configured (no network). */
export function hasCredentials(env = process.env) {
   return Boolean(
      env.FIREBASE_SERVICE_ACCOUNT || env.GOOGLE_APPLICATION_CREDENTIALS,
   );
}

/**
 * Initialises the Admin SDK from FIREBASE_SERVICE_ACCOUNT (the key's JSON) or,
 * failing that, GOOGLE_APPLICATION_CREDENTIALS (path to the key file).
 * firebase-admin is imported lazily so --dry-run never loads it.
 */
export async function getDb(env = process.env) {
   if (!hasCredentials(env)) {
      throw new ConfigError(
         "No Firebase credentials: set FIREBASE_SERVICE_ACCOUNT (JSON) or GOOGLE_APPLICATION_CREDENTIALS (file path)",
      );
   }
   const [
      { initializeApp, cert, applicationDefault, getApps },
      { getFirestore, Timestamp },
   ] = await Promise.all([
      import("firebase-admin/app"),
      import("firebase-admin/firestore"),
   ]);
   if (!getApps().length) {
      if (env.FIREBASE_SERVICE_ACCOUNT) {
         let key;
         try {
            key = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
         } catch {
            throw new ConfigError("FIREBASE_SERVICE_ACCOUNT is not valid JSON");
         }
         initializeApp({ credential: cert(key) });
      } else {
         process.env.GOOGLE_APPLICATION_CREDENTIALS = resolveKeyPath(
            env.GOOGLE_APPLICATION_CREDENTIALS,
         );
         initializeApp({ credential: applicationDefault() });
      }
   }
   return { db: getFirestore(), Timestamp };
}

/** Upserts docs into `events` with set(..., {merge: true}); returns the number written. */
export async function upsertEvents({ db, Timestamp }, docs) {
   let written = 0;
   for (let i = 0; i < docs.length; i += BATCH_SIZE) {
      const batch = db.batch();
      for (const { id, data } of docs.slice(i, i + BATCH_SIZE)) {
         const payload = {
            ...data,
            startsAt: Timestamp.fromDate(data.startsAt),
            endsAt: Timestamp.fromDate(data.endsAt),
            expiresAt: Timestamp.fromDate(data.expiresAt),
         };

         batch.set(db.collection("events").doc(id), payload, { merge: true });
      }
      await batch.commit();
      written += Math.min(BATCH_SIZE, docs.length - i);
   }
   return written;
}

export async function deleteExpiredEvents({ db, Timestamp }, now = new Date()) {
   const snapshot = await db
      .collection("events")
      .where("expiresAt", "<", Timestamp.fromDate(now))
      .get();

   let deleted = 0;

   for (let i = 0; i < snapshot.docs.length; i += BATCH_SIZE) {
      const batch = db.batch();

      for (const doc of snapshot.docs.slice(i, i + BATCH_SIZE)) {
         batch.delete(doc.ref);
      }

      await batch.commit();
      deleted += Math.min(BATCH_SIZE, snapshot.docs.length - i);
   }

   return deleted;
}

/**
 * Copies approved submissions into `events` (same document id). Existing
 * events are merged so the RSVP count is kept; new ones start at rsvpCount 0.
 * `map` is mapSubmission from sources/submissions.js.
 * @returns {{published: number, skips: {reason: string, ref: string}[]}}
 */
export async function publishApprovedSubmissions(
   { db, Timestamp },
   map,
   now = new Date(),
) {
   const snapshot = await db
      .collection("submissions")
      .where("status", "==", "approved")
      .get();

   const skips = [];
   const docs = [];
   for (const doc of snapshot.docs) {
      const out = map(doc.id, doc.data(), now);
      if (out.skip) skips.push({ reason: out.skip, ref: doc.id });
      else docs.push(out);
   }

   let published = 0;
   for (let i = 0; i < docs.length; i += BATCH_SIZE) {
      const chunk = docs.slice(i, i + BATCH_SIZE);
      const refs = chunk.map(({ id }) => db.collection("events").doc(id));
      const existing = await db.getAll(...refs);
      const batch = db.batch();
      chunk.forEach(({ data }, j) => {
         const payload = {
            ...data,
            startsAt: Timestamp.fromDate(data.startsAt),
            endsAt: Timestamp.fromDate(data.endsAt),
            expiresAt: Timestamp.fromDate(data.expiresAt),
         };
         if (!existing[j].exists) payload.rsvpCount = 0;
         batch.set(refs[j], payload, { merge: true });
      });
      await batch.commit();
      published += chunk.length;
   }
   return { published, skips };
}
