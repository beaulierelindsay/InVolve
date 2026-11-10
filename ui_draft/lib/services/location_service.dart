import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  LocationService._();

  static final instance = LocationService._();

  double? latitude;
  double? longitude;

  /// Resolve manual input without requesting device location permission.
  Future<void> setManualLocation(String address) async {
    final locations = await Geocoding().locationFromAddress(address.trim());
    if (locations.isEmpty) {
      throw StateError('No matching location found');
    }
    final location = locations.first;
    if (!location.latitude.isFinite ||
        !location.longitude.isFinite ||
        location.latitude.abs() > 90 ||
        location.longitude.abs() > 180) {
      throw StateError('Invalid location coordinates');
    }
    latitude = location.latitude;
    longitude = location.longitude;
  }

  Future<Position> getUserLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final position = await Geolocator.getCurrentPosition();

    latitude = position.latitude;
    longitude = position.longitude;

    return position;
  }
}
