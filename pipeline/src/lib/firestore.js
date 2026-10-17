import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ConfigError } from './collector.js';

const PIPELINE_DIR = fileURLToPath(new URL('../../', import.meta.url));

/** A relative key path in .env means "relative to pipeline/", whatever the cwd is. */
function resolveKeyPath(p) {
  const abs = resolve(PIPELINE_DIR, p);
  if (!existsSync(abs)) throw new ConfigError(`GOOGLE_APPLICATION_CREDENTIALS file not found: ${abs}`);
  return abs;
}

const BATCH_SIZE = 400; // Firestore's limit is 500 writes per batch

/** True when some form of Admin credentials is configured (no network). */
export function hasCredentials(env = process.env) {
  return Boolean(env.FIREBASE_SERVICE_ACCOUNT || env.GOOGLE_APPLICATION_CREDENTIALS);
}

/**
 * Initialises the Admin SDK from FIREBASE_SERVICE_ACCOUNT (the key's JSON) or,
 * failing that, GOOGLE_APPLICATION_CREDENTIALS (path to the key file).
 * firebase-admin is imported lazily so --dry-run never loads it.
 */
export async function getDb(env = process.env) {
  if (!hasCredentials(env)) {
    throw new ConfigError('No Firebase credentials: set FIREBASE_SERVICE_ACCOUNT (JSON) or GOOGLE_APPLICATION_CREDENTIALS (file path)');
  }
  const [{ initializeApp, cert, applicationDefault, getApps }, { getFirestore, Timestamp }] = await Promise.all([
    import('firebase-admin/app'),
    import('firebase-admin/firestore'),
  ]);
  if (!getApps().length) {
    if (env.FIREBASE_SERVICE_ACCOUNT) {
      let key;
      try {
        key = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
      } catch {
        throw new ConfigError('FIREBASE_SERVICE_ACCOUNT is not valid JSON');
      }
      initializeApp({ credential: cert(key) });
    } else {
      process.env.GOOGLE_APPLICATION_CREDENTIALS = resolveKeyPath(env.GOOGLE_APPLICATION_CREDENTIALS);
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
      batch.set(
        db.collection('events').doc(id),
        { ...data, startsAt: Timestamp.fromDate(data.startsAt) },
        { merge: true },
      );
    }
    await batch.commit();
    written += Math.min(BATCH_SIZE, docs.length - i);
  }
  return written;
}
