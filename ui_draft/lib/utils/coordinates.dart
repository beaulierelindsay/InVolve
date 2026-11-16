bool hasValidCoordinates(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return false;
  return latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
}
