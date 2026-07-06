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

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    return ClassificationLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      source: ClassificationLocationSource.gps,
    );
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await permissions.openAppSettings();
  }
}
