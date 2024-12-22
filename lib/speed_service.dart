import 'dart:async';
import 'package:geolocator/geolocator.dart';

class SpeedService {
  StreamController<double> _speedStreamController = StreamController<double>.broadcast();

  Stream<double> get speedStream => _speedStreamController.stream;

  SpeedService() {
    _startTrackingSpeed();
  }

  void _startTrackingSpeed() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("GPS-Dienst ist deaktiviert.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        throw Exception("Standortberechtigung abgelehnt.");
      }
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      double speedInKmh = (position.speed * 3.6).clamp(0, double.infinity); // m/s to km/h
      _speedStreamController.add(speedInKmh);
    });
  }

  void dispose() {
    _speedStreamController.close();
  }

  
}
