import '../../places/data/datasources/firebase_places_client.dart';
import '../domain/platform_repository.dart';

class FirebasePlatformRepository implements PlatformRepository {
  final FirebasePlacesClient client;
  FirebasePlatformRepository(this.client);
  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, Object?> data,
  ) async => Map<String, dynamic>.from(await client.call(name, data) as Map);
}
