import '../../../../core/data/data_set.dart';
import '../../../../core/providers/sample_fallback.dart';
import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../timetables/domain/entities/business_entity.dart';
import '../../../timetables/domain/entities/route_entity.dart';
import '../../../timetables/domain/entities/service_entity.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../domain/usecases/manage_transit.dart';

final manageTransitProvider = Provider<ManageTransit>(
  (ref) => ManageTransit(ref.watch(transitRepositoryProvider)),
);

final selectedBusinessIdProvider = NotifierProvider<SelectedBusiness, String?>(
  SelectedBusiness.new,
);

class SelectedBusiness extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(ownerIdProvider);
    return null;
  }

  void select(String id) => state = id;
}

final selectedBusinessProvider = Provider.autoDispose<BusinessEntity?>((ref) {
  final list =
      ref.watch(ownerBusinessesProvider).asData?.value ??
      const <BusinessEntity>[];
  final selected = ref.watch(selectedBusinessIdProvider);
  if (list.isEmpty) return null;
  return list.firstWhere((b) => b.id == selected, orElse: () => list.first);
});

final ownerActionsProvider =
    AsyncNotifierProvider.autoDispose<OwnerActions, void>(OwnerActions.new);

class OwnerActions extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    ref.watch(ownerIdProvider);
  }

  Future<bool> _run(Future<void> Function(String owner) action) async {
    if (state.isLoading) return false;
    final owner = ref.read(ownerIdProvider);
    if (owner == null) {
      state = AsyncError(
        const AppFailure('Please sign in.'),
        StackTrace.current,
      );
      return false;
    }
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => action(owner));
    if (!ref.mounted || ref.read(ownerIdProvider) != owner) return false;
    state = result;
    return !result.hasError;
  }

  Future<bool> saveBusiness(String name, {String? id}) {
    final useCase = ref.read(manageTransitProvider);
    return _run((owner) async {
      final saved = await useCase.saveBusiness(owner, name, id: id);
      if (ref.mounted && ref.read(ownerIdProvider) == owner) {
        ref.read(selectedBusinessIdProvider.notifier).select(saved);
      }
    });
  }

  Future<bool> saveRoute({
    required BusinessEntity business,
    required String name,
    required String from,
    required String to,
    required String stops,
    required bool returnRoute,
    String? id,
  }) {
    final useCase = ref.read(manageTransitProvider);
    return _run((owner) async {
      await useCase.saveRoute(
        ownerId: owner,
        business: business,
        name: name,
        from: from,
        to: to,
        intermediateStops: stops,
        returnRoute: returnRoute,
        routeId: id,
      );
    });
  }

  Future<bool> generateReturn(RouteEntity route) {
    final useCase = ref.read(manageTransitProvider);
    return _run((owner) => useCase.generateReturn(route, owner));
  }

  Future<bool> deleteRoute(String id) {
    final useCase = ref.read(manageTransitProvider);
    return _run((owner) async {
      final existing = await ref.read(ownerServicesProvider.future);
      if (!ref.mounted || ref.read(ownerIdProvider) != owner) {
        throw const AppFailure('Your account changed. Please try again.');
      }
      await useCase.deleteRoute(id, existing);
    });
  }

  Future<bool> deleteService(String id) {
    final useCase = ref.read(manageTransitProvider);
    return _run((owner) => useCase.deleteService(id));
  }

  Future<bool> saveService({
    required BusinessEntity business,
    required RouteEntity route,
    required String busName,
    required ServiceDraft draft,
    required String note,
    String? id,
  }) {
    final useCase = ref.read(manageTransitProvider);
    return _run((owner) async {
      final existing = await ref.read(ownerServicesProvider.future);
      if (!ref.mounted || ref.read(ownerIdProvider) != owner) {
        throw const AppFailure('Your account changed. Please try again.');
      }
      await useCase.saveService(
        ownerId: owner,
        business: business,
        route: route,
        busName: busName,
        departure: draft.departure,
        timings: draft.timings,
        offDays: draft.offDays,
        note: note,
        existing: existing,
        serviceId: id,
      );
    });
  }
}

final returnRouteProvider = NotifierProvider.autoDispose
    .family<ReturnRouteChoice, bool, String>(ReturnRouteChoice.new);

class ReturnRouteChoice extends Notifier<bool> {
  ReturnRouteChoice(this.key);
  final String key;
  @override
  bool build() => true;
  void update(bool value) => state = value;
}

typedef ServiceEditorArgs = ({RouteEntity route, ServiceEntity? service});

class ServiceDraft {
  final int departure;
  final Map<String, int> timings;
  final Set<String> offDays;
  ServiceDraft({
    required this.departure,
    required Map<String, int> timings,
    required Set<String> offDays,
  }) : timings = Map.unmodifiable(timings),
       offDays = Set.unmodifiable(offDays);
}

final serviceDraftProvider = NotifierProvider.autoDispose
    .family<ServiceDraftController, ServiceDraft, ServiceEditorArgs>(
      ServiceDraftController.new,
    );

class ServiceDraftController extends Notifier<ServiceDraft> {
  ServiceDraftController(this.args);
  final ServiceEditorArgs args;
  @override
  ServiceDraft build() {
    final service = args.service;
    final departure = service?.departureMinutes ?? 480;
    return ServiceDraft(
      departure: departure,
      timings: {
        for (var i = 0; i < args.route.stops.length; i++)
          args.route.stops[i]:
              service == null ? departure + i * 15 : (service.stopTimings[args.route.stops[i]] ?? -1),
      },
      offDays: service?.offDays.toSet() ?? {},
    );
  }

  void departure(int minutes) => state = ServiceDraft(
    departure: minutes,
    timings: {
      for (var i = 0; i < args.route.stops.length; i++)
        args.route.stops[i]: minutes + i * 15,
    },
    offDays: state.offDays,
  );
  void stopTime(String stop, int minutes) {
    if (stop == args.route.stops.first) {
      departure(minutes);
      return;
    }
    state = ServiceDraft(
      departure: state.departure,
      timings: {...state.timings, stop: minutes},
      offDays: state.offDays,
    );
  }

  void toggleDay(String day) {
    final days = {...state.offDays};
    days.contains(day) ? days.remove(day) : days.add(day);
    state = ServiceDraft(
      departure: state.departure,
      timings: state.timings,
      offDays: days,
    );
  }
}

final businessServicesProvider = Provider.autoDispose
    .family<AsyncValue<List<ServiceEntity>>, String>(
      (ref, id) => ref.watch(ownerServicesProvider).whenData((services) {
        final list =
            services.where((service) => service.businessId == id).toList()
              ..sort(
                (a, b) => a.departureMinutes.compareTo(b.departureMinutes),
              );
        return List<ServiceEntity>.unmodifiable(list);
      }),
    );

final ownerBusinessDisplayProvider = Provider.autoDispose<AsyncValue<DataSet<BusinessEntity>>>(
  (ref) => sampleFallback(ref.watch(ownerBusinessesProvider), ref.watch(sampleBusinessesProvider)));

final ownerRoutesDisplayProvider = Provider.autoDispose.family<AsyncValue<DataSet<RouteEntity>>, String>(
  (ref, id) => sampleFallback(ref.watch(businessRoutesProvider(id)), ref.watch(sampleRoutesProvider)));

final ownerServicesDisplayProvider = Provider.autoDispose.family<AsyncValue<DataSet<ServiceEntity>>, String>(
  (ref, id) => sampleFallback(ref.watch(businessServicesProvider(id)), ref.watch(sampleServicesProvider)));
