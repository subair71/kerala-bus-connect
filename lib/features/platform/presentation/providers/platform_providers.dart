import 'dart:async';
import 'dart:math';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/providers/cache_lifetime.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../places/data/datasources/firebase_places_client.dart';
import '../../data/firebase_platform_repository.dart';
import '../../domain/platform_repository.dart';

final platformEnabledProvider = Provider<bool>((ref) =>
  const bool.fromEnvironment('PLATFORM_ENABLED'));
final platformRepositoryProvider = Provider<PlatformRepository>((ref) =>
  FirebasePlatformRepository(FirebasePlacesClient(region: 'asia-south1',
    webSiteKey: const String.fromEnvironment('FIREBASE_APP_CHECK_WEB_SITE_KEY'))));
final administratorProvider = FutureProvider.autoDispose<bool>((ref) async {
  final owner = ref.watch(ownerIdProvider);
  if (owner == null || !ref.watch(platformEnabledProvider)) return false;
  final token = await ref.watch(firebaseAuthProvider).currentUser?.getIdTokenResult();
  return token?.claims?['admin'] == true;
});
String operationId() {
  final random = Random.secure();
  return List.generate(24, (_) => random.nextInt(16).toRadixString(16)).join();
}
typedef PlatformListKey = ({String collection, String? cursor});
final platformRecordsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, PlatformListKey>((ref, key) {
  ref.watch(ownerIdProvider);
  retainWhileIdle(ref, const Duration(seconds: 30));
  return ref.watch(platformRepositoryProvider).call('listPlatformRecords',
    {'collection': key.collection, 'cursor': key.cursor});
});
final platformActionProvider = AsyncNotifierProvider.autoDispose<PlatformAction, void>(PlatformAction.new);
class PlatformAction extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() { ref.watch(ownerIdProvider); }
  Future<bool> run(String action, Map<String, Object?> data, String requestId) async {
    if (state.isLoading) return false;
    final owner = ref.read(ownerIdProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await ref.read(platformRepositoryProvider).call('managePlatform',
        {'action': action, 'data': data, 'requestId': requestId});
    });
    if (!ref.mounted || ref.read(ownerIdProvider) != owner) return false;
    state = result;
    if (!result.hasError) ref.invalidate(platformRecordsProvider);
    return !result.hasError;
  }
}
