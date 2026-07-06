import 'package:permission_handler/permission_handler.dart';

class CameraPermissionService {
  Future<CameraPermissionResult> requestCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) {
      return CameraPermissionResult.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraPermissionResult.permanentlyDenied;
    }
    return CameraPermissionResult.denied;
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
}

enum CameraPermissionResult {
  granted,
  denied,
  permanentlyDenied,
}
