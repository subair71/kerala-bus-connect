import '../../../../core/data/data_set.dart';
import '../../../../core/config/firebase_config.dart';
import '../../data/datasources/schedule_cache.dart';
import '../../data/datasources/preferences_schedule_store.dart';
import '../../../../core/providers/sample_fallback.dart';
import '../../data/fixtures/transit_samples.dart';
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

final scheduleCacheProvider = Provider<ScheduleCache>(
  (ref) => ScheduleCache(PreferencesScheduleStore(firebaseOptions.projectId)),
);

final transitRepositoryProvider = Provider<TransitRepository>(
  (ref) => TransitRepositoryImpl(
    TransitRemoteDataSourceImpl(
      ref.watch(firestoreProvider),
      cache: ref.watch(scheduleCacheProvider),
    ),
  ),
);
final watchTimetablesProvider = Provider<WatchTimetables>(
  (ref) => WatchTimetables(ref.watch(transitRepositoryProvider)),
);
final catalogCacheDurationProvider = Provider<Duration>(
  (ref) => ref.watch(liveDataCacheDurationProvider),
);

final publishedServicesProvider =
    StreamProvider.autoDispose<List<ServiceEntity>>((ref) {
      retainWhileIdle(ref, ref.watch(catalogCacheDurationProvider));
      return ref.watch(watchTimetablesProvider).published();
    });
final ownerBusinessesProvider =
    StreamProvider.autoDispose<List<BusinessEntity>>((ref) {
      retainWhileIdle(ref, ref.watch(liveDataCacheDurationProvider));
      final owner = ref.watch(ownerIdProvider);
      return owner == null
          ? Stream.value(const [])
          : ref.watch(watchTimetablesProvider).businesses(owner);
    });
final businessRoutesProvider = StreamProvider.autoDispose
    .family<List<RouteEntity>, String>((ref, businessId) {
      retainWhileIdle(ref, ref.watch(liveDataCacheDurationProvider));
      final owner = ref.watch(ownerIdProvider);
      return owner == null
          ? Stream.value(const [])
          : ref.watch(watchTimetablesProvider).routes(businessId);
    });
final ownerServicesProvider = StreamProvider.autoDispose<List<ServiceEntity>>((
  ref,
) {
  retainWhileIdle(ref, ref.watch(liveDataCacheDurationProvider));
  final owner = ref.watch(ownerIdProvider);
  return owner == null
      ? Stream.value(const [])
      : ref.watch(watchTimetablesProvider).ownerServices(owner);
});

final serviceCatalogProvider =
    Provider.autoDispose<AsyncValue<DataSet<ServiceEntity>>>((ref) {
      final live = ref.watch(publishedServicesProvider);
      final records = live.asData?.value;
      if (records != null && records.any((row) => row.cachedAt != null)) {
        return AsyncData(DataSet(records, cached: true, unavailable: true));
      }
      return sampleFallback(live, TransitSamples.services);
    });
final sampleBusinessesProvider = Provider((ref) => TransitSamples.businesses);
final sampleRoutesProvider = Provider((ref) => TransitSamples.routes);
final sampleServicesProvider = Provider((ref) => TransitSamples.services);
