import '../models/events.dart';
import 'distance.dart';

/// Each day of waiting adds this many miles to an event's ranking score.
const double dateWeight = 2.0;

bool _validCoordinates(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180;

/// Lower scores rank first. Incomplete events sort behind complete events.
/// Without a user location, rank dated events chronologically instead.
double eventRankingScore(
  Event event, {
  required double? userLatitude,
  required double? userLongitude,
  required DateTime now,
}) {
  final startsAt = event.startsAt;
  if (startsAt == null) return double.infinity;
  final days =
      startsAt.difference(now).inMilliseconds / Duration.millisecondsPerDay;
  final dateScore = (days < 0 ? 0 : days) * dateWeight;
  if (!_validCoordinates(userLatitude, userLongitude)) return dateScore;
  if (!_validCoordinates(event.latitude, event.longitude)) {
    return double.infinity;
  }
  final distance = distanceInMiles(
      userLatitude!, userLongitude!, event.latitude!, event.longitude!);
  return distance.isFinite ? distance + dateScore : double.infinity;
}

int compareEventsForRanking(
  Event a,
  Event b, {
  required double? userLatitude,
  required double? userLongitude,
  required DateTime now,
}) {
  final comparison = eventRankingScore(a,
          userLatitude: userLatitude, userLongitude: userLongitude, now: now)
      .compareTo(eventRankingScore(b,
          userLatitude: userLatitude, userLongitude: userLongitude, now: now));
  // A deterministic tie-breaker also handles two incomplete events.
  return comparison != 0 ? comparison : a.id.compareTo(b.id);
}
