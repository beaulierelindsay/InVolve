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
// For mappers that geocode (Legistar, permits), which are async.
const runAsync = async (fn, rec, ...rest) => {
  const c = new Collector('t', NOW);
  await fn(rec, c, ...rest);
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
});

test('legistar: fallback description, deferred, missing time', async () => {
  const future = { ...LEGISTAR, EventDate: '2026-10-20T00:00:00', EventComment: null };
  const ok = await runAsync(mapLegistar, future);
  assert.match([...ok.docs.values()][0].data.description, /^Public meeting of the Subcommittee/);
  assert.equal((await runAsync(mapLegistar, { ...future, EventAgendaStatusName: 'Deferred' })).skips[0].reason, 'deferred (postponed)');
  assert.equal((await runAsync(mapLegistar, { ...future, EventTime: null })).skips[0].reason, 'missing/invalid start time');
  assert.equal((await runAsync(mapLegistar, { ...LEGISTAR })).skips[0].reason, 'past event');
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

test('permits: id includes start (event_id repeats), mapping', async () => {
  assert.equal(permitDocId(PERMIT), 'permit-911516-20261013T0800');
  const [{ data }] = (await runAsync(mapPermit, PERMIT)).docs.values();
  assert.equal(data.categoryId, 'local-culture');
  assert.equal(data.startsAt.toISOString(), '2026-10-13T12:00:00.000Z');
  assert.equal(data.location, 'East 149 Street between Morris Avenue and Park Avenue, Bronx');
  assert.equal(data.url, undefined);
  assert.equal((await runAsync(mapPermit, { ...PERMIT, event_type: 'Special Event' })).skips[0].reason, 'event_type not allowlisted (Special Event)');
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
      endsAt: new Date('2026-10-13T17:00:00Z'),
      expiresAt: new Date('2026-10-13T17:00:00Z'),
    },
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

// ── Approved submissions ────────────────────────────────────────────────────

const ts = (iso) => ({ toDate: () => new Date(iso) }); // Firestore Timestamp stand-in
const SUBMISSION = {
  title: '  Park cleanup ',
  categoryId: 'neighborhood',
  org: 'Friends of the Park',
  location: 'Central Park',
  description: 'Bring gloves.',
  url: '',
  startsAt: ts('2026-10-20T14:00:00Z'),
  hasTime: true,
  submissionType: 'hosted',
  submitterUid: 'host1',
  status: 'approved',
  rsvpRequired: true,
  capacity: 25,
  rsvpQuestions: ['Dietary needs?', '  ', 'T-shirt size?'],
};

test('submissions: approved hosted event maps with host and RSVP fields', async () => {
  const { mapSubmission } = await import('../src/sources/submissions.js');
  const { id, data } = mapSubmission('sub123', SUBMISSION, NOW);
  assert.equal(id, 'sub123'); // same id as the submission, so the guest list finds it
  assert.equal(data.title, 'Park cleanup');
  assert.equal(data.hostUid, 'host1');
  assert.equal(data.rsvpRequired, true);
  assert.equal(data.capacity, 25);
  assert.deepEqual(data.rsvpQuestions, ['Dietary needs?', 'T-shirt size?']);
  assert.equal(data.startsAt.toISOString(), '2026-10-20T14:00:00.000Z');
  assert.equal(data.expiresAt.toISOString(), '2026-10-20T17:00:00.000Z'); // +3h for timed
  assert.equal(data.url, undefined); // empty link left out
  assert.equal('rsvpCount' in data, false); // the writer decides, so re-syncs never reset it
  // never copied: review/personal fields
  for (const k of ['submitterUid', 'status', 'submittedAt', 'submissionType']) assert.equal(k in data, false);
});

test('submissions: found events have no host; RSVPs-off has no RSVP settings', async () => {
  const { mapSubmission } = await import('../src/sources/submissions.js');
  const found = mapSubmission('f1', { ...SUBMISSION, submissionType: 'found', url: 'https://x.org' }, NOW).data;
  assert.equal(found.hostUid, undefined);
  assert.equal(found.rsvpRequired, undefined);
  assert.equal(found.url, 'https://x.org');
  const off = mapSubmission('h2', { ...SUBMISSION, rsvpRequired: undefined, capacity: undefined, rsvpQuestions: undefined }, NOW).data;
  assert.equal(off.hostUid, 'host1');
  assert.equal(off.rsvpRequired, false);
  assert.equal(off.capacity, undefined);
  assert.equal(off.rsvpQuestions, undefined);
});

test('submissions: skips pending, bad, and past ones; date-only lasts the day', async () => {
  const { mapSubmission } = await import('../src/sources/submissions.js');
  assert.deepEqual(mapSubmission('a', { ...SUBMISSION, status: 'pending' }, NOW), { skip: 'not approved' });
  assert.deepEqual(mapSubmission('b', { ...SUBMISSION, categoryId: 'nope' }, NOW), { skip: 'bad category' });
  assert.deepEqual(mapSubmission('c', { ...SUBMISSION, title: '  ' }, NOW), { skip: 'missing title' });
  assert.deepEqual(mapSubmission('d', { ...SUBMISSION, startsAt: null }, NOW), { skip: 'missing/invalid start time' });
  assert.deepEqual(mapSubmission('e', { ...SUBMISSION, startsAt: ts('2026-10-12T08:00:00Z') }, NOW), { skip: 'past event' });
  // Date-only, started 10h before NOW: still listed until the day is over.
  const dateOnly = mapSubmission('f', { ...SUBMISSION, hasTime: false, startsAt: ts('2026-10-12T02:00:00Z') }, NOW);
  assert.equal(dateOnly.data.hasTime, false);
  assert.equal(dateOnly.data.expiresAt.toISOString(), '2026-10-13T02:00:00.000Z');
});

test('publishApprovedSubmissions: merges, adds rsvpCount only for new events', async () => {
  const { publishApprovedSubmissions } = await import('../src/lib/firestore.js');
  const { mapSubmission } = await import('../src/sources/submissions.js');
  const subs = {
    newOne: SUBMISSION,
    existing: { ...SUBMISSION, title: 'Renamed cleanup' },
    old: { ...SUBMISSION, startsAt: ts('2026-01-01T12:00:00Z') },
  };
  let queried;
  const sets = [];
  const db = {
    collection: (name) => ({
      where: (field, op, value) => {
        queried = { name, field, op, value };
        return {
          get: async () => ({
            docs: Object.entries(subs).map(([id, d]) => ({ id, data: () => d })),
          }),
        };
      },
      doc: (id) => ({ name, id }),
    }),
    getAll: async (...refs) => refs.map((r) => ({ exists: r.id === 'existing' })),
    batch: () => ({
      set: (ref, data, opts) => sets.push({ ref, data, opts }),
      commit: async () => {},
    }),
  };
  const Timestamp = { fromDate: (d) => ({ ts: d.toISOString() }) };
  const { published, skips } = await publishApprovedSubmissions({ db, Timestamp }, mapSubmission, NOW);

  assert.deepEqual(queried, { name: 'submissions', field: 'status', op: '==', value: 'approved' });
  assert.equal(published, 2);
  assert.deepEqual(skips, [{ reason: 'past event', ref: 'old' }]);
  const byId = Object.fromEntries(sets.map((s) => [s.ref.id, s]));
  assert.equal(byId.newOne.ref.name, 'events');
  assert.deepEqual(byId.newOne.opts, { merge: true });
  assert.equal(byId.newOne.data.rsvpCount, 0);
  assert.equal('rsvpCount' in byId.existing.data, false); // keeps the people already going
  assert.equal(byId.existing.data.title, 'Renamed cleanup');
  assert.deepEqual(byId.newOne.data.expiresAt, { ts: '2026-10-20T17:00:00.000Z' });
});
