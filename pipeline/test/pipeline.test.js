import assert from 'node:assert/strict';
import { existsSync, readFileSync, unlinkSync, writeFileSync } from 'node:fs';
import { after, test } from 'node:test';
import { Collector } from '../src/lib/collector.js';
import { cleanText, stripMarkdown, truncate, unshout } from '../src/lib/text.js';
import { nyWallClockToDate, parseClock, parseNyLocalIso } from '../src/lib/time.js';
import { mapLegistar } from '../src/sources/legistar.js';
import { isNycZip, mapMobilize } from '../src/sources/mobilize.js';
import { mapParks } from '../src/sources/parks.js';
import { mapPermit, permitDocId } from '../src/sources/permits.js';
import { LEGISTAR, MOBILIZE, PARK, PERMIT } from './fixtures.js';

const NOW = new Date('2026-10-12T12:00:00Z');
// Mappers may be async (Legistar/Permits geocode), so always await them.
const run = async (fn, rec, ...rest) => {
  const c = new Collector('t', NOW);
  await fn(rec, c, ...rest);
  return c;
};

// Keep the suite offline and independent of the committed geocode cache: serve one canned
// geocoder answer (250 Broadway), fail everything else (-> null). geocode() persists hits to
// geocode-cache.json, so restore that file when the suite finishes.
const CACHE_FILE = new URL('../src/lib/geocode-cache.json', import.meta.url);
const cacheBefore = existsSync(CACHE_FILE) ? readFileSync(CACHE_FILE) : null;
after(() => {
  if (cacheBefore) writeFileSync(CACHE_FILE, cacheBefore);
  else if (existsSync(CACHE_FILE)) unlinkSync(CACHE_FILE);
});
globalThis.fetch = async (url) => {
  if (String(url).includes('250%20Broadway')) {
    return { ok: true, json: async () => ({ features: [{ geometry: { coordinates: [-74.007842, 40.712988] } }] }) };
  }
  throw new Error('network disabled in tests');
};
const inNyc = (d) => d.latitude > 40.4 && d.latitude < 41.0 && d.longitude > -74.4 && d.longitude < -73.6;

test('NY wall clock -> UTC across DST', () => {
  assert.equal(nyWallClockToDate(2026, 10, 6, 13, 30).toISOString(), '2026-10-06T17:30:00.000Z'); // EDT
  assert.equal(nyWallClockToDate(2026, 11, 3, 13, 30).toISOString(), '2026-11-03T18:30:00.000Z'); // EST
  assert.equal(nyWallClockToDate(2026, 3, 8, 12, 0).toISOString(), '2026-03-08T16:00:00.000Z'); // day DST starts
  assert.equal(parseNyLocalIso('2026-10-15T16:00:00.000').toISOString(), '2026-10-15T20:00:00.000Z');
});

test('clock parsing', () => {
  assert.deepEqual(parseClock('1:30 PM'), { h: 13, m: 30 });
  assert.deepEqual(parseClock('12:00 am'), { h: 0, m: 0 });
  assert.deepEqual(parseClock('0:00 am'), { h: 0, m: 0 });
  assert.deepEqual(parseClock('12:15 pm'), { h: 12, m: 15 });
  assert.equal(parseClock(null), null);
  assert.equal(parseClock('TBD'), null);
});

test('text helpers', () => {
  assert.equal(cleanText('NYC Parks&#8217; Pitch In &amp; Pick Up&nbsp;'), 'NYC Parks’ Pitch In & Pick Up');
  assert.equal(cleanText('&amp;#8217;'), '’');
  assert.equal(stripMarkdown('**Bold** [link](http://x.y)'), 'Bold link');
  assert.equal(unshout('EAST  149 STREET between MORRIS AVENUE'), 'East  149 Street between Morris Avenue');
  assert.equal(unshout('Union Square Greenmarket'), 'Union Square Greenmarket');
  assert.ok(truncate('word '.repeat(300), 100).length <= 100);
});

test('legistar maps like Event.fromLegistar', async () => {
  const c = new Collector('legistar', new Date('2026-10-01T12:00:00Z'));
  await mapLegistar(LEGISTAR, c);
  const [{ id, data }] = c.docs.values();
  assert.equal(id, 'legistar-22615');
  assert.equal(data.categoryId, 'civic');
  assert.equal(data.title, 'Subcommittee on Zoning and Franchises');
  assert.equal(data.startsAt.toISOString(), '2026-10-06T17:30:00.000Z');
  assert.equal(data.action, 'View agenda');
  assert.equal(data.description, 'VOTE');
  assert.equal(data.url, LEGISTAR.EventInSiteURL);
  // Legistar has no end time: Collector falls back to the start for endsAt/expiresAt.
  assert.deepEqual(data.endsAt, data.startsAt);
  assert.deepEqual(data.expiresAt, data.startsAt);
  // 250 Broadway is a known place: geocoded (stubbed here) and carried through as coordinates.
  assert.equal(data.latitude, 40.712988);
  assert.equal(data.longitude, -74.007842);
});

test('legistar: fallback description, deferred, missing time', async () => {
  const future = { ...LEGISTAR, EventDate: '2026-10-20T00:00:00', EventComment: null };
  const ok = await run(mapLegistar, future);
  assert.match([...ok.docs.values()][0].data.description, /^Public meeting of the Subcommittee/);
  assert.equal((await run(mapLegistar, { ...future, EventAgendaStatusName: 'Deferred' })).skips[0].reason, 'deferred (postponed)');
  assert.equal((await run(mapLegistar, { ...future, EventTime: null })).skips[0].reason, 'missing/invalid start time');
  assert.equal((await run(mapLegistar, { ...LEGISTAR })).skips[0].reason, 'past event');
});

test('parks: entities decoded, volunteer => neighborhood, https url', async () => {
  const [{ id, data }] = (await run(mapParks, PARK)).docs.values();
  assert.equal(id, 'parks-2235141');
  assert.equal(data.title, 'NYC Parks’ Pitch In & Pick Up');
  assert.equal(data.org, 'NYC Parks');
  assert.equal(data.categoryId, 'neighborhood');
  assert.equal(data.location, 'Bartow-Pell Mansion Museum (in Pelham Bay Park)');
  assert.equal(data.startsAt.toISOString(), '2026-10-13T15:00:00.000Z');
  assert.equal(data.endsAt.toISOString(), '2026-10-13T16:30:00.000Z');
  assert.deepEqual(data.expiresAt, data.endsAt);
  assert.equal(data.description, 'Hike with the Rangers. Bring water.');
  assert.equal(data.url, 'https://www.nycgovparks.org/events/2026/10/13/pitch-in');
  assert.equal(data.action, undefined);
  assert.equal(data.latitude, 40.87860095);
  assert.equal(data.longitude, -73.81100043);
});

test('parks: cancelled, past, and registration action', async () => {
  assert.equal((await run(mapParks, { ...PARK, title: 'CANCELED: Zumba' })).skips[0].reason, 'cancelled');
  const past = { ...PARK, starttime: '2026-10-01T11:00:00.000', endtime: '2026-10-01T12:30:00.000' };
  assert.equal((await run(mapParks, past)).skips[0].reason, 'past event');
  const reg = { ...PARK, registration_url: { url: 'https://x.y/register' }, categories: 'Yoga' };
  const [{ data }] = (await run(mapParks, reg)).docs.values();
  assert.equal(data.action, 'Register');
  assert.equal(data.categoryId, 'local-culture');
  const [{ data: none }] = (await run(mapParks, { ...PARK, registration_url: null })).docs.values();
  assert.equal(none.action, undefined);
});

test('parks: coordinates parsing, missing or invalid coordinates keep the event', async () => {
  for (const coordinates of [undefined, null, '', 'not, numbers', '0.0, 0.0', '34.0, -118.2']) {
    const c = await run(mapParks, { ...PARK, coordinates });
    assert.equal(c.docs.size, 1, String(coordinates));
    const [{ data }] = c.docs.values();
    assert.equal(data.latitude, undefined, String(coordinates));
    assert.equal(data.longitude, undefined, String(coordinates));
  }
  const multi = { ...PARK, coordinates: '40.7500, -73.9900; 40.8000, -73.9500' };
  const [{ data }] = (await run(mapParks, multi)).docs.values();
  assert.equal(data.latitude, 40.75);
  assert.equal(data.longitude, -73.99);
});

test('parks: missing start time is skipped, missing end falls back to start, missing link and location', async () => {
  assert.equal((await run(mapParks, { ...PARK, starttime: undefined })).skips[0].reason, 'missing/invalid start time');
  const [{ data }] = (await run(mapParks, { ...PARK, endtime: undefined, link: undefined, location: '' })).docs.values();
  assert.deepEqual(data.endsAt, data.startsAt);
  assert.deepEqual(data.expiresAt, data.startsAt);
  assert.equal(data.url, undefined);
  assert.equal(data.location, 'Pelham Bay Park');
});

test('mobilize: next slot, markdown stripped, location', async () => {
  const [{ id, data }] = (await run(mapMobilize, MOBILIZE, NOW)).docs.values();
  assert.equal(id, 'mobilize-1057268');
  assert.equal(data.categoryId, 'cause-action');
  assert.equal(data.startsAt.getTime(), 1792256400 * 1000);
  assert.equal(data.org, 'No Kings');
  assert.equal(data.description, 'Join us in Chelsea to get out the vote!');
  assert.equal(data.location, 'Moynihan Station, New York, NY');
  assert.equal(data.url, MOBILIZE.browser_url);
});

test('mobilize: filters and private addresses', async () => {
  const nj = { ...MOBILIZE, location: { ...MOBILIZE.location, region: 'NJ', postal_code: '07030' } };
  assert.equal((await run(mapMobilize, nj, NOW)).skips[0].reason, 'outside NYC');
  assert.equal((await run(mapMobilize, { ...MOBILIZE, is_virtual: true }, NOW)).skips[0].reason, 'virtual / no location');
  const priv = { ...MOBILIZE, address_visibility: 'PRIVATE', location: { ...MOBILIZE.location, venue: 'This event’s address is private. Sign up for more details' } };
  const [{ data }] = (await run(mapMobilize, priv, NOW)).docs.values();
  assert.equal(data.location, 'Address shared after sign-up (New York, NY 10001)');
  const noSlots = { ...MOBILIZE, timeslots: [{ start_date: 1, end_date: 2, is_full: false }] };
  assert.equal((await run(mapMobilize, noSlots, NOW)).skips[0].reason, 'missing/invalid start time');
});

test('NYC zip ranges', () => {
  for (const z of ['10001', '11215', '10301', '10458', '11375', '11694']) assert.ok(isNycZip(z), z);
  for (const z of ['07030', '11550', '10601', '11001', '', undefined]) assert.ok(!isNycZip(z), String(z));
});

test('permits: id includes start (event_id repeats), mapping', async () => {
  assert.equal(permitDocId(PERMIT), 'permit-911516-20261013T0800');
  const [{ data }] = (await run(mapPermit, PERMIT)).docs.values();
  assert.equal(data.categoryId, 'local-culture');
  assert.equal(data.startsAt.toISOString(), '2026-10-13T12:00:00.000Z');
  assert.equal(data.location, 'East 149 Street between Morris Avenue and Park Avenue, Bronx');
  assert.equal(data.url, undefined);
  assert.equal(data.endsAt.toISOString(), '2026-10-13T22:00:00.000Z');
  assert.deepEqual(data.expiresAt, data.endsAt);
  // This fixture's address has no geocode result (stub fails -> null): coordinates are omitted, not zeroed.
  assert.equal(data.latitude, undefined);
  assert.equal(data.longitude, undefined);
  assert.equal((await run(mapPermit, { ...PERMIT, event_type: 'Special Event' })).skips[0].reason, 'event_type not allowlisted (Special Event)');
  // Already ended (by end time, even though it started earlier): skipped before any geocoding.
  const ended = { ...PERMIT, start_date_time: '2026-10-12T06:00:00.000', end_date_time: '2026-10-12T07:00:00.000' };
  assert.equal((await run(mapPermit, ended)).skips[0].reason, 'event already ended');
});

test('collector: end clamped to start, expiresAt = endsAt, NYC-only coordinates', () => {
  const base = { id: 'x', categoryId: 'civic', title: 't', startsAt: new Date('2026-10-13T15:00:00Z') };
  const add = (extra) => {
    const c = new Collector('t', NOW);
    c.add({ ...base, ...extra });
    return c.docs.get('x').data;
  };
  const noEnd = add({});
  assert.deepEqual(noEnd.endsAt, base.startsAt);
  assert.deepEqual(noEnd.expiresAt, base.startsAt);
  const badEnd = add({ endsAt: new Date('2026-10-13T14:00:00Z') }); // before start
  assert.deepEqual(badEnd.endsAt, base.startsAt);
  const good = add({ endsAt: new Date('2026-10-13T17:00:00Z'), latitude: 40.7, longitude: -74.0 });
  assert.equal(good.endsAt.toISOString(), '2026-10-13T17:00:00.000Z');
  assert.deepEqual(good.expiresAt, good.endsAt);
  assert.equal(good.latitude, 40.7);
  const far = add({ latitude: 34.0, longitude: -118.2 }); // outside NYC
  assert.equal(far.latitude, undefined);
  assert.equal(far.longitude, undefined);
});

test('upsertEvents uses set(merge) with Timestamps, in batches', async () => {
  const { upsertEvents } = await import('../src/lib/firestore.js');
  const calls = [];
  let commits = 0;
  const db = {
    collection: (name) => ({ doc: (id) => ({ name, id }) }),
    batch: () => ({
      set: (ref, data, opts) => calls.push({ ref, data, opts }),
      commit: async () => { commits++; },
    }),
  };
  const Timestamp = { fromDate: (d) => ({ ts: d.toISOString() }) };
  const docs = Array.from({ length: 850 }, (_, i) => ({
    id: `parks-${i}`,
    data: {
      categoryId: 'local-culture',
      title: 't',
      startsAt: new Date('2026-10-13T15:00:00Z'),
      endsAt: new Date('2026-10-13T16:30:00Z'),
      expiresAt: new Date('2026-10-13T16:30:00Z'),
    },
  }));
  const written = await upsertEvents({ db, Timestamp }, docs);
  assert.equal(written, 850);
  assert.equal(commits, 3);
  assert.deepEqual(calls[0].opts, { merge: true });
  assert.equal(calls[0].ref.name, 'events');
  assert.deepEqual(calls[0].data.startsAt, { ts: '2026-10-13T15:00:00.000Z' });
  assert.deepEqual(calls[0].data.endsAt, { ts: '2026-10-13T16:30:00.000Z' });
  assert.deepEqual(calls[0].data.expiresAt, { ts: '2026-10-13T16:30:00.000Z' });
});

test('getDb rejects missing / malformed credentials without touching the network', async () => {
  const { getDb, hasCredentials } = await import('../src/lib/firestore.js');
  assert.equal(hasCredentials({}), false);
  await assert.rejects(getDb({}), /No Firebase credentials/);
  await assert.rejects(getDb({ FIREBASE_SERVICE_ACCOUNT: '{nope' }), /not valid JSON/);
});
