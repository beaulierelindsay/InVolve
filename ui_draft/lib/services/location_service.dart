import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();

  static final instance = LocationService._();

  double? latitude;
  double? longitude;

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
