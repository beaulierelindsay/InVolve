import 'category.dart';

/// One step in an event's "What to expect" timeline on the details page.
class AgendaItem {
  final String time; // e.g. '7:00 PM'
  final String title;
  final String detail;
  const AgendaItem(
      {required this.time, required this.title, required this.detail});
}

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
  final String? duration; // e.g. 'About 2 hours'; shown on the details page
  final List<AgendaItem> agenda; // timeline for the details page; may be empty
  final double? latitude;
  final double? longitude;

  /// Set only on events a user hosts through InVolve (copied from the
  /// submission's `submitterUid` when it's approved). The host reads RSVPs
  /// for the event inside the app.
  final String? hostUid;

  /// True when the host asked attendees to RSVP through InVolve.
  final bool rsvpRequired;

  /// Most RSVPs the host will accept, or null for no limit.
  final int? capacity;

  /// How many people have RSVP'd so far (kept up to date by [RsvpService]).
  final int rsvpCount;

  /// Extra short-answer questions the host asks on the RSVP form.
  final List<String> rsvpQuestions;

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
    this.duration,
    this.agenda = const [],
    this.latitude,
    this.longitude,
    this.hostUid,
    this.rsvpRequired = false,
    this.capacity,
    this.rsvpCount = 0,
    this.rsvpQuestions = const [],
  });

  /// True for events whose RSVPs are collected in the app and read by the host.
  bool get isHostedRsvp => hostUid != null && rsvpRequired;

  /// True when a capacity is set and every spot is taken.
  bool get isFull => capacity != null && rsvpCount >= capacity!;

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

  /// Maps one item from Legistar's `/v1/{client}/events` endpoint.
  /// Legistar "events" are public meetings and hearings of a legislative body.
  factory Event.fromLegistar(Map<String, dynamic> json, {required String org}) {
    final day = DateTime.parse(json['EventDate'] as String);
    final time = json['EventTime'] as String?;
    final startsAt = _combine(day, time);
    final comment = (json['EventComment'] as String?)?.trim();
    final body = json['EventBodyName'] as String? ?? 'Public meeting';

    return Event(
      id: 'legistar-${json['EventId']}',
      categoryId: CategoryIds.civic,
      title: body,
      org: org,
      date: formatEventDate(startsAt, hasTime: time != null),
      startsAt: startsAt,
      location: json['EventLocation'] as String?,
      action: 'View agenda',
      description: comment == null || comment.isEmpty
          ? 'Public meeting of the $body. Open to the public.'
          : comment,
      url: json['EventInSiteURL'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

/// Legistar sends the date and a separate "h:mm AM" string.
DateTime _combine(DateTime day, String? time) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})\s*([AP]M)$', caseSensitive: false)
      .firstMatch(time?.trim() ?? '');
  if (match == null) return day;
  var hour = int.parse(match[1]!) % 12;
  if (match[3]!.toUpperCase() == 'PM') hour += 12;
  return DateTime(day.year, day.month, day.day, hour, int.parse(match[2]!));
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatEventDate(DateTime d, {required bool hasTime}) {
  final day = '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
  if (!hasTime) return day;
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$day · $hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}
