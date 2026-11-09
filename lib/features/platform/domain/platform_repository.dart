abstract interface class PlatformRepository {
  Future<Map<String, dynamic>> call(String name, Map<String, Object?> data);
}
