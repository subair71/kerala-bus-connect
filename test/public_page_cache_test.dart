import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerala_bus_connect/features/passenger/data/public_page_cache.dart';

class MemoryPreferences extends Fake implements SharedPreferencesAsync {
  final values = <String, Object>{};
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<List<String>?> getStringList(String key) async =>
      (values[key] as List<String>?)?.toList();
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    values[key] = value.toList();
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

void main() {
  test(
    'offline pages persist regular timings and remove temporary status',
    () async {
      final preferences = MemoryPreferences();
      final cache = PublicPageCache('test', preferences: preferences);
      await cache.write('search', [
        {
          'id': 'bus',
          'stops': ['A', 'B'],
          'stopTimings': {'A': 600, 'B': 630},
          'runningStatus': 'delayed',
          'expectedStopTimings': {'A': 615, 'B': 645},
        },
      ]);
      final reopened = PublicPageCache('test', preferences: preferences);
      final saved = await reopened.read('search');
      final row = (saved!['records'] as List).single as Map;
      expect(row['stopTimings'], {'A': 600, 'B': 630});
      expect(row.containsKey('runningStatus'), false);
      expect(row.containsKey('expectedStopTimings'), false);
      await reopened.invalidate();
      expect(await reopened.read('search'), isNull);
    },
  );
  test(
    'cached first pages stay bounded and project namespaces stay isolated',
    () async {
      final preferences = MemoryPreferences();
      final first = PublicPageCache('first', preferences: preferences);
      final second = PublicPageCache('second', preferences: preferences);
      for (var i = 0; i < 21; i++) {
        await first.write('query-$i', []);
      }
      expect(await first.read('query-0'), isNull);
      expect(await first.read('query-20'), isNotNull);
      expect(await second.read('query-20'), isNull);
      await second.write('query-20', []);
      await first.invalidate();
      expect(await first.read('query-20'), isNull);
      expect(await second.read('query-20'), isNotNull);
    },
  );
}
