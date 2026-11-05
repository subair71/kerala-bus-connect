import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/providers/cache_lifetime.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/transit_remote_data_source.dart';
import '../../data/repositories/transit_repository_impl.dart';
import '../../domain/entities/business_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../../domain/entities/service_entity.dart';
import '../../domain/repositories/transit_repository.dart';
import '../../domain/usecases/watch_timetables.dart';

final transitRepositoryProvider = Provider<TransitRepository>(
  (ref) => TransitRepositoryImpl(
    TransitRemoteDataSourceImpl(ref.watch(firestoreProvider)),
  ),
);
final watchTimetablesProvider = Provider<WatchTimetables>(
  (ref) => WatchTimetables(ref.watch(transitRepositoryProvider)),
);
final catalogCacheDurationProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 30),
);

final publishedServicesProvider =
    StreamProvider.autoDispose<List<ServiceEntity>>((ref) {
      retainWhileIdle(ref, ref.watch(catalogCacheDurationProvider));
      return ref.watch(watchTimetablesProvider).published();
    });
final ownerBusinessesProvider =
    StreamProvider.autoDispose<List<BusinessEntity>>((ref) {
      final owner = ref.watch(ownerIdProvider);
      return owner == null
          ? Stream.value(const [])
          : ref.watch(watchTimetablesProvider).businesses(owner);
    });
final businessRoutesProvider = StreamProvider.autoDispose
    .family<List<RouteEntity>, String>((ref, businessId) {
      final owner = ref.watch(ownerIdProvider);
      return owner == null
          ? Stream.value(const [])
          : ref.watch(watchTimetablesProvider).routes(businessId);
    });
final ownerServicesProvider = StreamProvider.autoDispose<List<ServiceEntity>>((
  ref,
) {
  final owner = ref.watch(ownerIdProvider);
  return owner == null
      ? Stream.value(const [])
      : ref.watch(watchTimetablesProvider).ownerServices(owner);
});
