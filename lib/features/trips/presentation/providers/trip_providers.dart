import '../../domain/entities/timetable_suggestion.dart';
import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/providers/cache_lifetime.dart';
import '../../../timetables/domain/entities/service_entity.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../timetables/domain/entities/business_entity.dart';
import '../../data/repositories/firebase_trip_repository.dart';
import '../../domain/entities/trip_plan.dart';
import '../../domain/repositories/trip_repository.dart';

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => FirebaseTripRepository(
    ref.watch(firestoreProvider),
    cache: ref.watch(scheduleCacheProvider),
  ),
);

final ownerBusesProvider = StreamProvider.autoDispose
    .family<List<BusEntity>, String>((ref, businessId) {
      retainWhileIdle(ref, ref.watch(liveDataCacheDurationProvider));
      final owner = ref.watch(ownerIdProvider);
      return owner == null
          ? Stream.value(const <BusEntity>[])
          : ref.watch(tripRepositoryProvider).watchBuses(owner, businessId);
    });

final dailyAdjustmentsProvider = StreamProvider.autoDispose
    .family<List<DailyAdjustment>, String>((ref, date) {
      retainWhileIdle(ref, ref.watch(liveDataCacheDurationProvider));
      final owner = ref.watch(ownerIdProvider);
      return owner == null
          ? Stream.value(const <DailyAdjustment>[])
          : ref
                .watch(tripRepositoryProvider)
                .watchAdjustments(date, ownerId: owner);
    }, retry: (_, _) => null);

final selectedBusProvider = NotifierProvider.autoDispose
    .family<SelectedBus, String?, String>(SelectedBus.new);

class SelectedBus extends Notifier<String?> {
  SelectedBus(this.businessId);
  final String businessId;
  @override
  String? build() {
    retainWhileIdle(ref, ref.watch(liveDataCacheDurationProvider));
    ref.watch(ownerIdProvider);
    return null;
  }

  void select(String id) => state = id;
}

class TripDraft {
  final TripPlan plan;
  final int step;
  final String? error;
  const TripDraft(this.plan, {this.step = 0, this.error});
}

typedef TripEditorKey = ({TripPlan plan, String ownerId});

final tripDraftProvider = NotifierProvider.autoDispose
    .family<TripDraftController, TripDraft, TripEditorKey>(
      TripDraftController.new,
    );

class TripDraftController extends Notifier<TripDraft> {
  TripDraftController(this.args);
  final TripEditorKey args;
  int _nextId = 0;
  @override
  TripDraft build() => TripDraft(args.plan);

  void _update(TripPlan Function() action) {
    try {
      state = TripDraft(action(), step: state.step);
    } catch (error) {
      state = TripDraft(state.plan, step: state.step, error: error.toString());
    }
  }

  void rename(int index, String name) => _update(() {
    final stops = [...state.plan.stops];
    stops[index] = stops[index].copyWith(name: name);
    return state.plan.copyWith(stops: stops);
  });

  void addStop() => _update(() {
    final stops = [...state.plan.stops];
    String id;
    do {
      id = 'stop-${_nextId++}';
    } while (stops.any((s) => s.id == id));
    stops.insert(stops.length - 1, TripStop(id, '', -1));
    return state.plan.copyWith(stops: stops);
  });

  void remove(int index) => _update(() {
    if (state.plan.stops.length <= 2) {
      throw const AppFailure('Keep an origin and destination.');
    }
    return state.plan.copyWith(stops: [...state.plan.stops]..removeAt(index));
  });

  void move(int from, int to) => _update(() {
    if (to < 0 || to >= state.plan.stops.length) return state.plan;
    final stops = [...state.plan.stops];
    stops.insert(to, stops.removeAt(from));
    return state.plan.copyWith(stops: stops);
  });

  void time(int index, int minutes) => _update(() {
    if (index == 0) return state.plan.shiftDeparture(minutes);
    final stops = [...state.plan.stops];
    stops[index] = stops[index].copyWith(minutes: minutes);
    return state.plan.copyWith(stops: stops);
  });

  void offDay(String day) => _update(() {
    final days = {...state.plan.offDays};
    days.contains(day) ? days.remove(day) : days.add(day);
    return state.plan.copyWith(offDays: days);
  });

  void suggestions(TripPlan plan) => _update(() => plan);

  void note(String note) => _update(() => state.plan.copyWith(note: note));

  void step(int step) {
    try {
      if (step == 2) state.plan.validate();
      if (step > 0 && state.plan.stops.any((s) => s.name.trim().isEmpty)) {
        throw const AppFailure('Enter every stop name first.');
      }
      state = TripDraft(state.plan, step: step);
    } catch (error) {
      state = TripDraft(state.plan, step: state.step, error: error.toString());
    }
  }
}

typedef DelayEditorKey = ({
  TripPlan trip,
  DailyAdjustment? adjustment,
  String date,
});
final delayDraftProvider = NotifierProvider.autoDispose
    .family<DelayDraft, Map<String, int>, DelayEditorKey>(DelayDraft.new);

class DelayDraft extends Notifier<Map<String, int>> {
  DelayDraft(this.args);
  final DelayEditorKey args;
  @override
  Map<String, int> build() => Map.unmodifiable(
    args.adjustment?.scheduleRevision == args.trip.revision
        ? args.adjustment!.delays
        : <String, int>{},
  );
  void setDelay(String id, int value) {
    if (value < 0 || value > 1440) return;
    final next = {...state};
    if (value == 0) {
      next.remove(id);
    } else {
      next[id] = value;
    }
    state = Map.unmodifiable(next);
  }

  void reset() => state = const {};
}

final tripActionsProvider =
    AsyncNotifierProvider.autoDispose<TripActions, void>(TripActions.new);

class TripActions extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    ref.watch(ownerIdProvider);
  }

  Future<bool> run(Future<void> Function(String, TripRepository) action) async {
    if (state.isLoading) return false;
    final owner = ref.read(ownerIdProvider);
    final repository = ref.read(tripRepositoryProvider);
    if (owner == null) {
      state = AsyncError(
        const AppFailure('Please sign in.'),
        StackTrace.current,
      );
      return false;
    }
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => action(owner, repository));
    if (!ref.mounted || ref.read(ownerIdProvider) != owner) return false;
    state = result;
    return !result.hasError;
  }

  Future<bool> saveBus(
    BusinessEntity business,
    String name, {
    BusEntity? bus,
  }) => run((owner, repo) => repo.saveBus(owner, business, name, bus: bus));
  Future<bool> saveTrip(
    BusinessEntity business,
    BusEntity bus,
    TripPlan trip,
  ) => run((owner, repo) async {
    await repo.saveTrip(owner, business, bus, trip);
  });
  Future<bool> deleteTrip(BusEntity bus, TripPlan trip) =>
      run((owner, repo) => repo.deleteTrip(owner, bus, trip));
  Future<bool> deleteBus(BusEntity bus) =>
      run((owner, repo) => repo.deleteBus(owner, bus));
  Future<bool> saveDelay(
    BusEntity bus,
    TripPlan trip,
    DailyAdjustment adjustment,
  ) => run((owner, repo) => repo.saveAdjustment(owner, bus, trip, adjustment));
  Future<bool> resetDelay(BusEntity bus, TripPlan trip, String date) =>
      run((owner, repo) => repo.resetAdjustment(owner, bus, trip, date));
}

typedef BusTripsKey = ({String ownerId, String businessId, String busId});
typedef BusTrips = ({List<ServiceEntity> trips, List<ServiceEntity> legacy});

/// Filter and sort each owner snapshot once, independently of date or busy UI.
final busTripsProvider = Provider.autoDispose
    .family<AsyncValue<BusTrips>, BusTripsKey>(
      (ref, key) => ref.watch(ownerServicesProvider).whenData((all) {
        final trips = <ServiceEntity>[];
        final legacy = <ServiceEntity>[];
        for (final service in all) {
          if (service.ownerId != key.ownerId ||
              service.businessId != key.businessId)
            continue;
          if (service.busId == key.busId) {
            trips.add(service);
          } else if (service.busId.isEmpty) {
            legacy.add(service);
          }
        }
        trips.sort((a, b) => a.departureMinutes.compareTo(b.departureMinutes));
        return (
          trips: List.unmodifiable(trips),
          legacy: List.unmodifiable(legacy),
        );
      }),
    );

/// One lookup table per date, shared by the owner cards and passenger results.
final dailyAdjustmentIndexProvider = Provider.autoDispose
    .family<AsyncValue<Map<String, DailyAdjustment>>, String>(
      (ref, date) => ref
          .watch(dailyAdjustmentsProvider(date))
          .whenData(
            (items) =>
                Map.unmodifiable({for (final item in items) item.tripId: item}),
          ),
    );

final operationDateProvider =
    NotifierProvider.autoDispose<OperationDate, DateTime>(OperationDate.new);

class OperationDate extends Notifier<DateTime> {
  @override
  DateTime build() {
    retainWhileIdle(ref, ref.watch(liveDataCacheDurationProvider));
    ref.watch(ownerIdProvider);
    final now = keralaNow();
    return DateTime(now.year, now.month, now.day);
  }

  void select(DateTime date) =>
      state = DateTime(date.year, date.month, date.day);
}

final legacyTripsExpandedProvider = NotifierProvider.autoDispose
    .family<LegacyTripsExpanded, bool, String>(LegacyTripsExpanded.new);

class LegacyTripsExpanded extends Notifier<bool> {
  LegacyTripsExpanded(this.businessId);
  final String businessId;
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final tripEditorStructureProvider = Provider.autoDispose
    .family<TripEditorStructure, TripEditorKey>(
      (ref, args) => TripEditorStructure(ref.watch(tripDraftProvider(args))),
    );

/// Route typing rebuilds its own row. Note typing doesn't rebuild the timeline.
class TripEditorStructure extends Equatable {
  final TripDraft draft;
  const TripEditorStructure(this.draft);
  @override
  List<Object?> get props => [
    draft.step,
    draft.error,
    draft.step == 0
        ? draft.plan.stops.map((stop) => stop.id).toList()
        : draft.plan.stops,
    draft.plan.offDays,
    if (draft.step == 2) draft.plan.note,
  ];
}

final runningStatusDraftProvider = NotifierProvider.autoDispose
    .family<RunningStatusDraft, RunningStatus, DelayEditorKey>(
      RunningStatusDraft.new,
    );

class RunningStatusDraft extends Notifier<RunningStatus> {
  RunningStatusDraft(this.args);
  final DelayEditorKey args;
  @override
  RunningStatus build() =>
      args.adjustment?.scheduleRevision == args.trip.revision
      ? args.adjustment!.status
      : RunningStatus.scheduled;
  void select(RunningStatus status) => state = status;
}

typedef SuggestionState = ({TripPlan? plan, String? error});
final suggestionPreviewProvider = NotifierProvider.autoDispose
    .family<SuggestionPreview, SuggestionState, TripPlan>(
      SuggestionPreview.new,
    );

class SuggestionPreview extends Notifier<SuggestionState> {
  SuggestionPreview(this.plan);
  final TripPlan plan;
  @override
  SuggestionState build() => (plan: null, error: null);
  void calculate(List<int> minutes, double factor, int dwell) {
    try {
      state = (
        plan: suggestTimetable(
          plan,
          minutes,
          factor: factor,
          stopMinutes: dwell,
        ),
        error: null,
      );
    } catch (e) {
      state = (plan: null, error: e.toString());
    }
  }
}
