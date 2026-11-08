import 'events.dart';

/// Keep this FALSE until two things exist: (1) a backend endpoint that really
/// forwards RSVPs to the organizer's site, and (2) approval from that site
/// (Mobilize restricts its RSVP endpoint). While it is false, no screen says
/// the user's details were shared with anyone.
///
/// Flip it to true only on your own machine to preview the details form. The
/// "we're sending your details" message would not be true, so don't ship it.
const bool kOrganizerForwardingEnabled = false;

/// How an RSVP works for an event.
/// - internal:  InVolve only records that the user plans to go. Nothing
///              personal is collected, and nobody else is told.
/// - organizer: the user's details are collected and (later) forwarded to
///              the organizer so they can register the person.
enum RsvpMode { internal, organizer }

/// Which data source an event came from, read from its id prefix
/// ("mobilize-1051193" -> "mobilize", "legistar-123" -> "legistar").
/// It's a convention, not a guarantee. An explicit `source` field on each
/// event document would be sturdier.
String eventSource(Event event) {
  final i = event.id.indexOf('-');
  return i <= 0 ? 'unknown' : event.id.substring(0, i);
}

RsvpMode rsvpModeFor(Event event) {
  if (kOrganizerForwardingEnabled && eventSource(event) == 'mobilize') {
    return RsvpMode.organizer;
  }
  return RsvpMode.internal;
}

/// Button wording. Public meetings don't take RSVPs, so say "plan to attend".
String rsvpLabelFor(Event event) =>
    eventSource(event) == 'legistar' ? 'I plan to attend' : "I'm going";

/// Honest explanation shown under the button, so nobody thinks they've been
/// registered with an organizer when they haven't. Null when no note is needed.
String? rsvpNoteFor(Event event) {
  if (rsvpModeFor(event) == RsvpMode.organizer) return null;
  if (eventSource(event) == 'legistar') {
    return 'Public meetings are open to attend. This adds it to your plans in InVolve.';
  }
  return "This saves your plans in InVolve. It doesn't register you with the organizer.";
}

/// One of the signed-in user's RSVPs.
class Rsvp {
  final String eventId;
  final String eventTitle;
  final String categoryId;
  final String source;
  final DateTime? startsAt;

  /// True only when the user agreed to share their details with the organizer.
  final bool shareWithOrganizer;

  /// 'none' (nothing to forward), 'queued', and later 'sent' or 'failed'.
  /// Only the backend will ever set 'sent' or 'failed'.
  final String forwardStatus;

  const Rsvp({
    required this.eventId,
    required this.eventTitle,
    required this.categoryId,
    required this.source,
    required this.startsAt,
    required this.shareWithOrganizer,
    required this.forwardStatus,
  });
}
