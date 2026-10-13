import 'category.dart';

class Event {
  final String id;
  final String categoryId; // must match an EngagementCategory.id
  final String title;
  final String org;
  final String date; // display string, e.g. 'Thu, Sep 24 · 7:00 PM'
  final DateTime? startsAt; // for sorting/ranking; null for mock events
  final String? distance; // e.g. '0.4 mi'; null until we have geolocation
  final String? location; // street address / room, when the source has one
  final String action;
  final String description;
  final int? spots;
  final String? url; // source page for more details

  const Event({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.org,
    required this.date,
    this.startsAt,
    this.distance,
    this.location,
    required this.action,
    required this.description,
    this.spots,
    this.url,
  });

  // Display info comes from the category model, never duplicated on the event.
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

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatEventDate(DateTime d, {required bool hasTime}) {
  final day = '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
  if (!hasTime) return day;
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$day · $hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}
