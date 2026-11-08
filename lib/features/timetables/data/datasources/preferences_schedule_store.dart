import 'package:shared_preferences/shared_preferences.dart';
import 'schedule_cache.dart';

class PreferencesScheduleStore implements ScheduleCacheStore {
  final String namespace;
  PreferencesScheduleStore(this.namespace);

  String get _key => 'findmybus.public-schedules.v1.$namespace';

  @override
  Future<String?> read() => SharedPreferencesAsync().getString(_key);

  @override
  Future<void> write(String value) =>
      SharedPreferencesAsync().setString(_key, value);

  @override
  Future<void> remove() => SharedPreferencesAsync().remove(_key);
}
