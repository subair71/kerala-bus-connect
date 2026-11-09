import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PublicPageCache {
  final SharedPreferencesAsync preferences;
  final String namespace;
  Future<void> _writes = Future.value();
  int _generation = 0;
  PublicPageCache(this.namespace, {SharedPreferencesAsync? preferences})
    : preferences = preferences ?? SharedPreferencesAsync();
  String _key(String query) =>
      'findmybus.pages.v1.$namespace.${base64Url.encode(utf8.encode(query))}';
  Future<Map<String, dynamic>?> read(String query) async {
    try {
      await _writes;
      final generation = _generation;
      final raw = await preferences.getString(_key(query));
      if (generation != _generation) return null;
      if (raw == null || raw.length > 262144) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['records'] is! List ||
          (data['records'] as List).any(
            (r) =>
                r is! Map ||
                r['id'] is! String ||
                r['stops'] is! List ||
                r['stopTimings'] is! Map,
          ))
        return null;
      final at = DateTime.parse(data['at'] as String);
      final age = DateTime.now().difference(at);
      if (age.isNegative ||
          age > const Duration(days: 7) ||
          data['version'] != 1)
        return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> invalidate() {
    _generation++;
    _writes = _writes.then((_) async {
      try {
        final indexKey = 'findmybus.pages.v1.$namespace.index';
        for (final key
            in await preferences.getStringList(indexKey) ?? <String>[]) {
          await preferences.remove(key);
        }
        await preferences.remove(indexKey);
      } catch (_) {}
    });
    return _writes;
  }

  Future<void> write(String query, List<dynamic> records) {
    _writes = _writes.then((_) async {
      try {
        final raw = jsonEncode({
          'version': 1,
          'at': DateTime.now().toUtc().toIso8601String(),
          'records': records.map((record) {
            final safe = Map<String, dynamic>.from(record as Map);
            safe.remove('expectedStopTimings');
            safe.remove('runningStatus');
            return safe;
          }).toList(),
        });
        if (utf8.encode(raw).length > 262144) return;
        final indexKey = 'findmybus.pages.v1.$namespace.index';
        final keys = await preferences.getStringList(indexKey) ?? [];
        final key = _key(query);
        keys.remove(key);
        keys.add(key);
        while (keys.length > 20) {
          await preferences.remove(keys.removeAt(0));
        }
        await preferences.setString(key, raw);
        await preferences.setStringList(indexKey, keys);
      } catch (_) {
        /* A storage failure must not block live timetables. */
      }
    });
    return _writes;
  }
}
