import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Future<PermissionStatus> getLocationPermissionStatus() async {
    return Permission.locationWhenInUse.status;
  }

  Future<PermissionStatus> requestLocationPermission() async {
    return Permission.locationWhenInUse.request();
  }

  Future<bool> isLocationEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<Position?> getCurrentLocation() async {
    if (!await isLocationEnabled()) {
      return null;
    }

    final permissionStatus = await getLocationPermissionStatus();
    if (!permissionStatus.isGranted && !permissionStatus.isLimited) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> getLocationLabel() async {
    final position = await getCurrentLocation();
    if (position == null) {
      return null;
    }
    return '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
  }
}
