import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/events.dart';
import '../models/rsvp.dart';
import 'auth_service.dart';

/// Contact details collected for events whose organizer or host receives
/// RSVPs. Stored with the exact consent wording the user agreed to.
class OrganizerDetails {
  final String givenName;
  final String familyName;
  final String email;
  final String phone; // may be empty
  final String postalCode; // empty for hosted events (not asked)
  final String consentText;

  /// Answers to the host's custom questions, in the order they were asked.
  final List<({String question, String answer})> answers;

  const OrganizerDetails({
    required this.givenName,
    required this.familyName,
    required this.email,
    required this.phone,
    required this.postalCode,
    required this.consentText,
    this.answers = const [],
  });
}

/// Thrown when a hosted event has no spots left.
class RsvpFullException implements Exception {
  const RsvpFullException();
}

/// Thrown when a hosted event no longer takes RSVPs in the app.
class RsvpClosedException implements Exception {
  const RsvpClosedException();
}

/// Reads and writes the signed-in user's RSVPs in the `rsvps` collection.
/// One document per user per event, with the id "<uid>_<eventId>".
class RsvpService {
  RsvpService._();
  static final RsvpService instance = RsvpService._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('rsvps');

  CollectionReference<Map<String, dynamic>> get _events =>
      FirebaseFirestore.instance.collection('events');

  static const _timeout = Duration(seconds: 12);

  /// Document ids can't contain "/", so event ids are cleaned the same way
  /// everywhere (stored, looked up, and checked by the security rules).
  static String _cleanEventId(String id) => id.replaceAll('/', '_');

  String? get _uid {
    final u = AuthService.instance.currentUser;
    return (u == null || u.isAnonymous) ? null : u.uid;
  }

  String _docId(String uid, Event e) => '${uid}_${_cleanEventId(e.id)}';

  /// Emits the user's RSVP for this event, or null if they haven't RSVP'd.
  Stream<Rsvp?> watch(Event event) {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _col.doc(_docId(uid, event)).snapshots().map((snap) {
      final data = snap.data();
      return (snap.exists && data != null) ? _fromMap(data) : null;
    });
  }

  /// All of the user's RSVPs, soonest event first (no-date events last).
  Stream<List<Rsvp>> watchMine() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _col.where('uid', isEqualTo: uid).snapshots().map((snap) {
      final items = <Rsvp>[];
      for (final doc in snap.docs) {
        try {
          items.add(_fromMap(doc.data()));
        } catch (err) {
          debugPrint('RsvpService: skipping unreadable RSVP ${doc.id} ($err)');
        }
      }
      items.sort((a, b) {
        final x = a.startsAt, y = b.startsAt;
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return x.compareTo(y);
      });
      return items;
    });
  }

  /// Records that the user plans to go. Pass [details] only for events where
  /// the organizer or host receives the RSVP; without it, nothing personal is
  /// stored. Throws [StateError] if nobody is signed in, and for hosted
  /// events [RsvpFullException] or [RsvpClosedException].
  Future<void> rsvp(Event event, {OrganizerDetails? details}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in required');

    final hosted = rsvpModeFor(event) == RsvpMode.hosted;
    final share = details != null;
    final data = <String, dynamic>{
      'uid': uid,
      'eventId': _cleanEventId(event.id),
      'eventTitle': event.title,
      'categoryId': event.categoryId,
      'source': hosted ? 'hosted' : eventSource(event),
      if (event.startsAt != null) 'startsAt': Timestamp.fromDate(event.startsAt!),
      'shareWithOrganizer': share,
      // Hosted RSVPs are read in the app, so nothing is waiting to be sent.
      // Only the backend ever moves this to 'sent' or 'failed'.
      'forwardStatus': (share && !hosted) ? 'queued' : 'none',
      'createdAt': FieldValue.serverTimestamp(),
      if (share) ...{
        'contact': {
          'givenName': details.givenName.trim(),
          'familyName': details.familyName.trim(),
          'email': details.email.trim(),
          'phone': details.phone.trim(),
          if (details.postalCode.trim().isNotEmpty) 'postalCode': details.postalCode.trim(),
        },
        if (details.answers.isNotEmpty)
          'answers': [
            for (final a in details.answers) {'question': a.question, 'answer': a.answer.trim()},
          ],
        'consentText': details.consentText,
      },
    };

    final rsvpRef = _col.doc(_docId(uid, event));
    if (!hosted) {
      // Offline, Firestore writes wait forever; fail so the user is told.
      await rsvpRef.set(data).timeout(_timeout);
      return;
    }

    // Hosted: check capacity and bump the count in the same transaction, so
    // two people can't both take the last spot. The security rules only let
    // the count go up by one when this RSVP is created alongside it.
    final eventRef = _events.doc(event.id);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final existing = await tx.get(rsvpRef);
      if (existing.exists) return; // already going; nothing to do

      final snap = await tx.get(eventRef);
      final e = snap.data();
      final hostUid = e?['hostUid'];
      if (e == null || hostUid is! String || e['rsvpRequired'] != true) {
        throw const RsvpClosedException();
      }
      final count = (e['rsvpCount'] as num?)?.toInt() ?? 0;
      final capacity = (e['capacity'] as num?)?.toInt();
      if (capacity != null && capacity > 0 && count >= capacity) {
        throw const RsvpFullException();
      }

      tx.set(rsvpRef, {...data, 'hostUid': hostUid});
      tx.update(eventRef, {'rsvpCount': count + 1});
    }).timeout(_timeout);
  }

  /// Removes the user's RSVP. If details were already sent to an organizer,
  /// this can't recall them (the UI says so). For hosted events the spot is
  /// given back.
  Future<void> cancel(Event event) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in required');
    await _cancelDoc(_col.doc(_docId(uid, event)));
  }

  /// Deletes one RSVP, and gives its spot back if it was for a hosted event.
  Future<void> _cancelDoc(DocumentReference<Map<String, dynamic>> rsvpRef) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(rsvpRef);
      final d = snap.data();
      if (d == null) return;
      final hostUid = d['hostUid'];
      DocumentSnapshot<Map<String, dynamic>>? eventSnap;
      if (hostUid is String) {
        eventSnap = await tx.get(_events.doc(d['eventId'] as String));
      }
      tx.delete(rsvpRef);
      final count = (eventSnap?.data()?['rsvpCount'] as num?)?.toInt() ?? 0;
      if (eventSnap != null && eventSnap.exists && count > 0) {
        tx.update(eventSnap.reference, {'rsvpCount': count - 1});
      }
    }).timeout(_timeout);
  }

  /// People who RSVP'd to an event the signed-in user hosts, earliest first.
  /// [eventId] is the id of the event document (the same id as the approved
  /// submission).
  Stream<List<Attendee>> watchAttendees(String eventId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _col
        .where('hostUid', isEqualTo: uid)
        .where('eventId', isEqualTo: _cleanEventId(eventId))
        .snapshots()
        .map((snap) {
      final items = <Attendee>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final c = d['contact'] as Map<String, dynamic>? ?? const {};
        final name = '${c['givenName'] ?? ''} ${c['familyName'] ?? ''}'.trim();
        items.add(Attendee(
          name: name.isEmpty ? 'Unnamed guest' : name,
          email: c['email'] as String? ?? '',
          phone: c['phone'] as String? ?? '',
          answers: [
            for (final a in (d['answers'] as List? ?? const []))
              if (a is Map)
                (question: a['question']?.toString() ?? '', answer: a['answer']?.toString() ?? ''),
          ],
          rsvpAt: (d['createdAt'] as Timestamp?)?.toDate(),
        ));
      }
      items.sort((a, b) {
        final x = a.rsvpAt, y = b.rsvpAt;
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return x.compareTo(y);
      });
      return items;
    });
  }

  /// For a host deleting their account: deletes everyone's RSVPs to the
  /// events they host, and turns off in-app RSVPs on those events so nobody
  /// signs up for a host who can no longer read the list.
  Future<void> closeAllMyHostedEvents() async {
    final uid = _uid;
    if (uid == null) return;
    final db = FirebaseFirestore.instance;
    final rsvps = await _col.where('hostUid', isEqualTo: uid).get().timeout(const Duration(seconds: 15));
    final events = await _events.where('hostUid', isEqualTo: uid).get().timeout(const Duration(seconds: 15));

    final writes = <void Function(WriteBatch)>[
      for (final doc in rsvps.docs) (b) => b.delete(doc.reference),
      for (final doc in events.docs) (b) => b.update(doc.reference, {'rsvpRequired': false, 'rsvpCount': 0}),
    ];
    const chunk = 400; // Firestore batches hold up to 500 writes
    for (var i = 0; i < writes.length; i += chunk) {
      final batch = db.batch();
      for (final w in writes.skip(i).take(chunk)) {
        w(batch);
      }
      await batch.commit().timeout(const Duration(seconds: 15));
    }
  }

  /// Deletes every RSVP the signed-in user made. Used by account deletion.
  Future<void> deleteAllMine() async {
    final uid = _uid;
    if (uid == null) return;
    final db = FirebaseFirestore.instance;
    final snap = await _col.where('uid', isEqualTo: uid).get().timeout(const Duration(seconds: 15));

    // RSVPs to hosted events give their spot back, one transaction each.
    final hosted = snap.docs.where((d) => d.data()['hostUid'] is String).toList();
    for (final doc in hosted) {
      await _cancelDoc(doc.reference);
    }
    final plain = snap.docs.where((d) => d.data()['hostUid'] is! String).toList();

    const chunk = 400; // Firestore batches hold up to 500 writes
    for (var i = 0; i < plain.length; i += chunk) {
      final batch = db.batch();
      for (final doc in plain.skip(i).take(chunk)) {
        batch.delete(doc.reference);
      }
      await batch.commit().timeout(const Duration(seconds: 15));
    }
  }

  Rsvp _fromMap(Map<String, dynamic> d) => Rsvp(
        eventId: d['eventId'] as String,
        eventTitle: d['eventTitle'] as String? ?? 'Event',
        categoryId: d['categoryId'] as String? ?? '',
        source: d['source'] as String? ?? 'unknown',
        startsAt: (d['startsAt'] as Timestamp?)?.toDate(),
        shareWithOrganizer: d['shareWithOrganizer'] as bool? ?? false,
        forwardStatus: d['forwardStatus'] as String? ?? 'none',
        hostUid: d['hostUid'] as String?,
      );
}
