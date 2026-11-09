import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../platform/presentation/providers/platform_providers.dart';
import '../../data/device_location_gateway.dart';
import '../../domain/nearby_stops.dart';

final locationGatewayProvider = Provider<LocationGateway>((ref) => DeviceLocationGateway());
class NearbyState {
  final List<NearbyStop> stops;
  final bool stale;
  final String? message;
  const NearbyState(this.stops, {this.stale = false, this.message});
}
final nearbyStopsProvider = AsyncNotifierProvider<NearbyStops, NearbyState>(NearbyStops.new);
class NearbyStops extends AsyncNotifier<NearbyState> {
  StopPosition? _position;
  DateTime? _fetchedAt;
  bool _busy = false;
  final _preferences = SharedPreferencesAsync();
  String get _key => 'findmybus.nearby.v1.${firebaseOptions.projectId}';
  @override
  Future<NearbyState> build() async {
    if (!ref.watch(platformEnabledProvider)) return const NearbyState([]);
    try {
      final raw = await _preferences.getString(_key);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final at = DateTime.parse(data['at'] as String);
        final age = DateTime.now().difference(at);
        if (!age.isNegative && age < const Duration(days: 7)) {
          unawaited(Future(() => refresh()));
          return NearbyState(_decode(data['stops'] as List), stale: true,
            message: 'Previously nearby stops · refreshing location');
        }
      }
    } catch (_) {}
    return _fetch();
  }
  List<NearbyStop> _decode(List<dynamic> rows) => [for (final row in rows)
    NearbyStop(id: row['id'] as String, name: row['name'] as String,
      distanceKm: (row['distanceKm'] as num).toDouble(),
      routeIds: List<String>.from(row['routeIds'] as List? ?? []))];
  Future<NearbyState> _fetch() async {
    final point = await ref.read(locationGatewayProvider).locate();
    if (_position != null && _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < const Duration(minutes: 15)) {
      final dy = (point.latitude - _position!.latitude) * 111320;
      final dx = (point.longitude - _position!.longitude) * 111320 * cos(point.latitude * pi / 180);
      if (sqrt(dx * dx + dy * dy) < 250 && state.hasValue) return state.requireValue;
    }
    final data = await ref.read(platformRepositoryProvider).call('findNearbyStops',
      {'latitude': point.latitude, 'longitude': point.longitude});
    _position = point; _fetchedAt = DateTime.now();
    final stops = data['stops'] as List;
    // Only public stop data is persisted; the passenger's GPS coordinate is not.
    try { await _preferences.setString(_key, jsonEncode({'at': _fetchedAt!.toUtc().toIso8601String(), 'stops': stops})); }
    catch (_) {}
    return NearbyState(_decode(stops));
  }
  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    final previous = state.asData?.value;
    try {
      final next = await _fetch();
      if (ref.mounted) state = AsyncData(next);
    } catch (_) {
      if (ref.mounted) state = AsyncData(NearbyState(previous?.stops ?? [],
        stale: previous?.stops.isNotEmpty ?? false,
        message: 'Nearby location unavailable. Choose a stop or search manually.'));
    } finally { _busy = false; }
  }
}
