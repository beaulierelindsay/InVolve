import 'dart:math';

double distanceInMiles(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadiusMiles = 3958.8;

  double toRadians(double degrees) {
    return degrees * pi / 180;
  }

  final dLat = toRadians(lat2 - lat1);
  final dLon = toRadians(lon2 - lon1);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(toRadians(lat1)) *
          cos(toRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadiusMiles * c;
}
