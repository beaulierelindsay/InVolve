import 'category.dart';

/// The one event shape shared by the UI, Firestore,
/// and API converters / ranking.
///
/// [categoryId] must always be a valid EngagementCategory id (see CategoryIds).
class Event {
  final String id;
  final String categoryId;
  final String title;
  final String org;
  final String dateLabel; // display text, e.g. "Thu, Sep 24 · 7:00 PM"
  final DateTime? startsAt; // used for sorting when available
  final String location; // free-text place, e.g. "Prospect Park"
  final String? distanceLabel; // e.g. "0.4 mi" once we have coordinates
  final String description;
  final String action; // button text: "RSVP", "Sign up", ...
  final int? spots;

  const Event({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.dateLabel,
    required this.action,
    this.org = '',
    this.startsAt,
    this.location = '',
    this.distanceLabel,
    this.description = '',
    this.spots,
  });

  /// Display info (color, label, icon) always comes from the category model.
  EngagementCategory get category => categoryById(categoryId);

  /// Sensible button text when a Firestore document doesn't specify one.
  static String defaultActionFor(String categoryId) {
    switch (categoryId) {
      case CategoryIds.civic:
        return 'Add to calendar';
      case CategoryIds.directService:
        return 'Sign up';
      case CategoryIds.causeAction:
        return 'Join session';
      default:
        return 'RSVP';
    }
  }
}

/// "Thu, Sep 24 · 7:00 PM"
String formatEventDate(DateTime dt) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final d = dt.toLocal();
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day} · $hour12:$minute $ampm';
}