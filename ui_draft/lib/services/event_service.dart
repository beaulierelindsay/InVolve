import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/category.dart';
import '../models/events.dart';

/// Reads events from the Firestore `events` collection and converts each
/// document into a typed [Event].
///
/// Accepted document fields (all optional except a recognizable category):
///   title, categoryId (or legacy `category`), date (String or Timestamp),
///   startsAt (Timestamp), location, description, org, action, spots
class EventService {
  final CollectionReference<Map<String, dynamic>> _events =
      FirebaseFirestore.instance.collection('events');

  /// One-time fetch.
  Future<List<Event>> getEvents() async {
    final snapshot = await _events.get();
    return _parse(snapshot.docs);
  }

  /// Live updates: emits a new list whenever the collection changes.
  Stream<List<Event>> watchEvents() {
    return _events.snapshots().map((snapshot) => _parse(snapshot.docs));
  }

  List<Event> _parse(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final events = <Event>[];
    for (final doc in docs) {
      final event = _toEvent(doc.id, doc.data());
      if (event != null) events.add(event);
    }
    // Soonest first; events without a parseable date go last.
    events.sort((a, b) {
      final x = a.startsAt, y = b.startsAt;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    });
    return events;
  }

  Event? _toEvent(String id, Map<String, dynamic> d) {
    // Accept the new `categoryId` or the legacy `category`, and translate
    // free-text values ("Volunteer", "Civic") into canonical ids.
    final rawCategory = (d['categoryId'] ?? d['category'])?.toString();
    final categoryId = categoryIdFromRaw(rawCategory);
    if (categoryId == null) {
      debugPrint('EventService: skipping "$id" — unknown category "$rawCategory"');
      return null;
    }

    final startsAt = _asDateTime(d['startsAt'] ?? d['date']);
    final date = d['date'] is String
        ? d['date'] as String
        : (startsAt != null ? formatEventDate(startsAt, hasTime: true) : '');

    final title = d['title']?.toString() ?? '';

    return Event(
      id: id,
      categoryId: categoryId,
      title: title.isEmpty ? 'Untitled event' : title,
      org: d['org']?.toString() ?? '',
      date: date,
      startsAt: startsAt,
      location: d['location']?.toString() ?? '',
      description: d['description']?.toString() ?? '',
      action: d['action']?.toString() ?? Event.defaultActionFor(categoryId),
      spots: d['spots'] is num ? (d['spots'] as num).toInt() : null,
    );
  }

  DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value); // ISO strings only
    return null;
  }
}