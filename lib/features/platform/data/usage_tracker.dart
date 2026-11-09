import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/platform_repository.dart';

class UsageTracker {
  final PlatformRepository repository;
  late final SharedPreferencesAsync preferences = SharedPreferencesAsync();
  UsageTracker(this.repository);
  Future<String>? _installation;
  Future<String> _installationId() => _installation ??= () async {
    final saved = await preferences.getString('findmybus.analytics.installation');
    if (saved != null) return saved;
    final created = _random();
    await preferences.setString('findmybus.analytics.installation', created);
    return created;
  }();
  String _random() => List.generate(
    24,
    (_) => Random.secure().nextInt(16).toRadixString(16),
  ).join();
  Future<bool> consent() async {
    try {
      return await preferences.getBool('findmybus.analytics.optin') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setConsent(bool enabled) =>
      preferences.setBool('findmybus.analytics.optin', enabled);
  Future<void> record(
    String event, {
    String? adId,
    String? routeId,
    String? stopId,
    String? eventId,
  }) async {
    try {
      if (!await consent()) return;
      final installation = await _installationId();
      if (!await consent()) return;
      await repository.call('recordUsage', {
        'event': event,
        'eventId': eventId ?? _random(),
        'installationId': installation,
        'adId': adId,
        'routeId': routeId,
        'stopId': stopId,
      });
    } catch (_) {
      /* Optional metrics never block passenger tasks. */
    }
  }

  Future<Map<String, int>> exposures() async {
    try {
      final day = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 5, minutes: 30))
          .toIso8601String()
          .substring(0, 10);
      final raw = await preferences.getString('findmybus.ad.exposures');
      final saved = raw == null ? null : jsonDecode(raw) as Map;
      return saved?['day'] == day
          ? Map<String, int>.from(saved!['counts'] as Map)
          : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> saveExposures(Map<String, int> counts) async {
    try {
      final day = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 5, minutes: 30))
          .toIso8601String()
          .substring(0, 10);
      await preferences.setString(
        'findmybus.ad.exposures',
        jsonEncode({'day': day, 'counts': counts}),
      );
    } catch (_) {}
  }
}
