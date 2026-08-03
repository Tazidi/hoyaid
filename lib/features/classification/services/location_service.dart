import 'package:geolocator/geolocator.dart';
import 'package:hoyaid/features/classification/models/classification_models.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

class LocationService {
  Future<ClassificationLocation?> getCurrentLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    final position = await _requestHighAccuracyPosition();
    return ClassificationLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      source: ClassificationLocationSource.gps,
    );
  }

  /// Measures only the request-to-first-coordinate interval. Permission and
  /// service checks are excluded so user interaction does not affect the test.
  Future<LocationFixMeasurement?> measureFirstFix() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        !await Geolocator.isLocationServiceEnabled()) {
      return null;
    }

    final stopwatch = Stopwatch()..start();
    final position = await _requestHighAccuracyPosition();
    stopwatch.stop();
    return LocationFixMeasurement(
      location: ClassificationLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        source: ClassificationLocationSource.gps,
      ),
      elapsed: stopwatch.elapsed,
    );
  }

  Future<Position> _requestHighAccuracyPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await permissions.openAppSettings();
  }
}

class LocationFixMeasurement {
  final ClassificationLocation location;
  final Duration elapsed;

  const LocationFixMeasurement({
    required this.location,
    required this.elapsed,
  });
}
