import 'package:geolocator/geolocator.dart';
import '../domain/nearby_stops.dart';
class DeviceLocationGateway implements LocationGateway {
  StopPosition? _last;
  DateTime? _at;
  Future<StopPosition>? _pending;
  bool _requested = false;
  @override
  Future<StopPosition> locate({bool requestPermission = true}) {
    if (_last != null && DateTime.now().difference(_at!) < const Duration(minutes: 5)) return Future.value(_last);
    return _pending ??= _locate(requestPermission).whenComplete(() => _pending = null);
  }
  Future<StopPosition> _locate(bool ask) async {
    if (!await Geolocator.isLocationServiceEnabled()) throw StateError('Location is turned off. Search by stop name.');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && ask && !_requested) {
      _requested = true;
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw StateError('Location permission unavailable. Search by stop name.');
    }
    final position = await Geolocator.getCurrentPosition(locationSettings:
      const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)));
    _last = StopPosition(position.latitude, position.longitude);
    _at = DateTime.now();
    return _last!;
  }
}
