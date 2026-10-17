import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Collector } from '../src/lib/collector.js';
import { cleanText, stripMarkdown, truncate, unshout } from '../src/lib/text.js';
import { nyWallClockToDate, parseClock, parseNyLocalIso } from '../src/lib/time.js';
import { mapLegistar } from '../src/sources/legistar.js';
import { isNycZip, mapMobilize } from '../src/sources/mobilize.js';
import { mapParks } from '../src/sources/parks.js';
import { mapPermit, permitDocId } from '../src/sources/permits.js';
import { LEGISTAR, MOBILIZE, PARK, PERMIT } from './fixtures.js';

const NOW = new Date('2026-10-12T12:00:00Z');
const run = (fn, rec, ...rest) => {
  const c = new Collector('t', NOW);
  fn(rec, c, ...rest);
  return c;
};

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

test('legistar maps like Event.fromLegistar', () => {
  const c = new Collector('legistar', new Date('2026-10-01T12:00:00Z'));
  mapLegistar(LEGISTAR, c);
  const [{ id, data }] = c.docs.values();
  assert.equal(id, 'legistar-22615');
  assert.equal(data.categoryId, 'civic');
  assert.equal(data.title, 'Subcommittee on Zoning and Franchises');
  assert.equal(data.startsAt.toISOString(), '2026-10-06T17:30:00.000Z');
  assert.equal(data.action, 'View agenda');
  assert.equal(data.description, 'VOTE');
  assert.equal(data.url, LEGISTAR.EventInSiteURL);
});

test('legistar: fallback description, deferred, missing time', () => {
  const future = { ...LEGISTAR, EventDate: '2026-10-20T00:00:00', EventComment: null };
  const ok = run(mapLegistar, future);
  assert.match([...ok.docs.values()][0].data.description, /^Public meeting of the Subcommittee/);
  assert.equal(run(mapLegistar, { ...future, EventAgendaStatusName: 'Deferred' }).skips[0].reason, 'deferred (postponed)');
  assert.equal(run(mapLegistar, { ...future, EventTime: null }).skips[0].reason, 'missing/invalid start time');
  assert.equal(run(mapLegistar, { ...LEGISTAR }).skips[0].reason, 'past event');
});

test('parks: entities decoded, volunteer => neighborhood, https url', () => {
  const [{ id, data }] = run(mapParks, PARK).docs.values();
  assert.equal(id, 'parks-2235141');
  assert.equal(data.title, 'NYC Parks’ Pitch In & Pick Up');
  assert.equal(data.categoryId, 'neighborhood');
  assert.equal(data.startsAt.toISOString(), '2026-10-13T15:00:00.000Z');
  assert.equal(data.description, 'Hike with the Rangers. Bring water.');
  assert.match(data.url, /^https:\/\//);
  assert.equal(data.action, undefined);
});

test('parks: cancelled, past, and registration action', () => {
  assert.equal(run(mapParks, { ...PARK, title: 'CANCELED: Zumba' }).skips[0].reason, 'cancelled');
  assert.equal(run(mapParks, { ...PARK, startdate: '2026-10-01', enddate: '2026-10-01' }).skips[0].reason, 'past event');
  const [{ data }] = run(mapParks, { ...PARK, registration_url: 'https://x.y', categories: 'Yoga' }).docs.values();
  assert.equal(data.action, 'Register');
  assert.equal(data.categoryId, 'local-culture');
});

test('mobilize: next slot, markdown stripped, location', () => {
  const [{ id, data }] = run(mapMobilize, MOBILIZE, NOW).docs.values();
  assert.equal(id, 'mobilize-1057268');
  assert.equal(data.categoryId, 'cause-action');
  assert.equal(data.startsAt.getTime(), 1792256400 * 1000);
  assert.equal(data.org, 'No Kings');
  assert.equal(data.description, 'Join us in Chelsea to get out the vote!');
  assert.equal(data.location, 'Moynihan Station, New York, NY');
  assert.equal(data.url, MOBILIZE.browser_url);
});

test('mobilize: filters and private addresses', () => {
  const nj = { ...MOBILIZE, location: { ...MOBILIZE.location, region: 'NJ', postal_code: '07030' } };
  assert.equal(run(mapMobilize, nj, NOW).skips[0].reason, 'outside NYC');
  assert.equal(run(mapMobilize, { ...MOBILIZE, is_virtual: true }, NOW).skips[0].reason, 'virtual / no location');
  const priv = { ...MOBILIZE, address_visibility: 'PRIVATE', location: { ...MOBILIZE.location, venue: 'This event’s address is private. Sign up for more details' } };
  const [{ data }] = run(mapMobilize, priv, NOW).docs.values();
  assert.equal(data.location, 'Address shared after sign-up (New York, NY 10001)');
  const noSlots = { ...MOBILIZE, timeslots: [{ start_date: 1, end_date: 2, is_full: false }] };
  assert.equal(run(mapMobilize, noSlots, NOW).skips[0].reason, 'missing/invalid start time');
});

test('NYC zip ranges', () => {
  for (const z of ['10001', '11215', '10301', '10458', '11375', '11694']) assert.ok(isNycZip(z), z);
  for (const z of ['07030', '11550', '10601', '11001', '', undefined]) assert.ok(!isNycZip(z), String(z));
});

test('permits: id includes start (event_id repeats), mapping', () => {
  assert.equal(permitDocId(PERMIT), 'permit-911516-20261013T0800');
  const [{ data }] = run(mapPermit, PERMIT).docs.values();
  assert.equal(data.categoryId, 'local-culture');
  assert.equal(data.startsAt.toISOString(), '2026-10-13T12:00:00.000Z');
  assert.equal(data.location, 'East 149 Street between Morris Avenue and Park Avenue, Bronx');
  assert.equal(data.url, undefined);
  assert.equal(run(mapPermit, { ...PERMIT, event_type: 'Special Event' }).skips[0].reason, 'event_type not allowlisted (Special Event)');
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
    data: { categoryId: 'local-culture', title: 't', startsAt: new Date('2026-10-13T15:00:00Z') },
  }));
  const written = await upsertEvents({ db, Timestamp }, docs);
  assert.equal(written, 850);
  assert.equal(commits, 3);
  assert.deepEqual(calls[0].opts, { merge: true });
  assert.equal(calls[0].ref.name, 'events');
  assert.deepEqual(calls[0].data.startsAt, { ts: '2026-10-13T15:00:00.000Z' });
});

test('getDb rejects missing / malformed credentials without touching the network', async () => {
  const { getDb, hasCredentials } = await import('../src/lib/firestore.js');
  assert.equal(hasCredentials({}), false);
  await assert.rejects(getDb({}), /No Firebase credentials/);
  await assert.rejects(getDb({ FIREBASE_SERVICE_ACCOUNT: '{nope' }), /not valid JSON/);
});
