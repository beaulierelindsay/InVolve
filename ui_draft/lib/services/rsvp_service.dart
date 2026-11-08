import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/events.dart';
import '../models/rsvp.dart';
import 'auth_service.dart';

/// Contact details collected only for events whose organizer receives RSVPs
/// (see kOrganizerForwardingEnabled). Stored with the exact consent wording
/// the user agreed to.
class OrganizerDetails {
  final String givenName;
  final String familyName;
  final String email;
  final String phone; // may be empty
  final String postalCode;
  final String consentText;

  const OrganizerDetails({
    required this.givenName,
    required this.familyName,
    required this.email,
    required this.phone,
    required this.postalCode,
    required this.consentText,
  });
}

/// Reads and writes the signed-in user's RSVPs in the `rsvps` collection.
/// One document per user per event, with the id "<uid>_<eventId>".
class RsvpService {
  RsvpService._();
  static final RsvpService instance = RsvpService._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('rsvps');

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
  /// the organizer receives the RSVP; without it, nothing personal is stored.
  /// Throws [StateError] if nobody is signed in.
  Future<void> rsvp(Event event, {OrganizerDetails? details}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in required');

    final share = details != null;
    final data = <String, dynamic>{
      'uid': uid,
      'eventId': _cleanEventId(event.id),
      'eventTitle': event.title,
      'categoryId': event.categoryId,
      'source': eventSource(event),
      if (event.startsAt != null) 'startsAt': Timestamp.fromDate(event.startsAt!),
      'shareWithOrganizer': share,
      // Only the backend ever moves this to 'sent' or 'failed'.
      'forwardStatus': share ? 'queued' : 'none',
      'createdAt': FieldValue.serverTimestamp(),
      if (share) ...{
        'contact': {
          'givenName': details.givenName.trim(),
          'familyName': details.familyName.trim(),
          'email': details.email.trim(),
          'phone': details.phone.trim(),
          'postalCode': details.postalCode.trim(),
        },
        'consentText': details.consentText,
      },
    };

    // Offline, Firestore writes wait forever; fail so the user is told.
    await _col.doc(_docId(uid, event)).set(data).timeout(const Duration(seconds: 12));
  }

  /// Removes the user's RSVP. If details were already sent to an organizer,
  /// this can't recall them (the UI says so).
  Future<void> cancel(Event event) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in required');
    await _col.doc(_docId(uid, event)).delete().timeout(const Duration(seconds: 12));
  }

  /// Deletes every RSVP the signed-in user made. Used by account deletion.
  Future<void> deleteAllMine() async {
    final uid = _uid;
    if (uid == null) return;
    final db = FirebaseFirestore.instance;
    final snap = await _col.where('uid', isEqualTo: uid).get().timeout(const Duration(seconds: 15));

    const chunk = 400; // Firestore batches hold up to 500 writes
    for (var i = 0; i < snap.docs.length; i += chunk) {
      final batch = db.batch();
      for (final doc in snap.docs.skip(i).take(chunk)) {
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
      );
}
