import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../models/events.dart';
 
/// App-wide list of bookmarked events.
///
/// Stores whole [Event]s (not just ids) because events from sources like
/// Legistar aren't kept anywhere else, so the Saved tab needs the full data
/// to show them. Persisted on the device with shared_preferences.
class SavedEventsStore extends ChangeNotifier {
  SavedEventsStore._();
  static final SavedEventsStore instance = SavedEventsStore._();
 
  static const _key = 'saved_events_v1';
 
  // Insertion-ordered: oldest save first.
  final Map<String, Event> _saved = {};
 
  /// Newest saves first.
  List<Event> get events => _saved.values.toList().reversed.toList();
  int get count => _saved.length;
  bool isSaved(String id) => _saved.containsKey(id);
 
  /// Call once in main() before runApp().
  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final validIds = allCategories.map((c) => c.id).toSet();
    for (final raw in sp.getStringList(_key) ?? const <String>[]) {
      try {
        final event = _fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (validIds.contains(event.categoryId)) _saved[event.id] = event;
      } catch (err) {
        debugPrint('SavedEventsStore: skipping unreadable entry ($err)');
      }
    }
    notifyListeners();
  }
 
  /// Save the event if it isn't saved, otherwise remove it.
  Future<void> toggle(Event event) async {
    if (_saved.remove(event.id) == null) _saved[event.id] = event;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(
      _key,
      _saved.values.map((e) => jsonEncode(_toJson(e))).toList(),
    );
  }
 
  static Map<String, dynamic> _toJson(Event e) => {
        'id': e.id,
        'categoryId': e.categoryId,
        'title': e.title,
        'org': e.org,
        'date': e.date,
        'startsAt': e.startsAt?.toIso8601String(),
        'distance': e.distance,
        'location': e.location,
        'action': e.action,
        'description': e.description,
        'spots': e.spots,
        'url': e.url,
        'duration': e.duration,
        'agenda': [
          for (final a in e.agenda) {'time': a.time, 'title': a.title, 'detail': a.detail},
        ],
      };
 
  static Event _fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] as String,
        categoryId: j['categoryId'] as String,
        title: j['title'] as String,
        org: j['org'] as String,
        date: j['date'] as String,
        startsAt: j['startsAt'] == null ? null : DateTime.tryParse(j['startsAt'] as String),
        distance: j['distance'] as String?,
        location: j['location'] as String?,
        action: j['action'] as String,
        description: j['description'] as String,
        spots: j['spots'] as int?,
        url: j['url'] as String?,
        duration: j['duration'] as String?,
        agenda: [
          for (final a in (j['agenda'] as List? ?? const []))
            AgendaItem(
              time: a['time'] as String,
              title: a['title'] as String,
              detail: a['detail'] as String,
            ),
        ],
      );
}
