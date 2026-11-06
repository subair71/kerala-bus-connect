import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../timetables/domain/entities/business_entity.dart';
import '../../data/repositories/firebase_trip_repository.dart';
import '../../domain/entities/trip_plan.dart';
import '../../domain/repositories/trip_repository.dart';

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => FirebaseTripRepository(ref.watch(firestoreProvider)),
);

final ownerBusesProvider = StreamProvider.autoDispose
    .family<List<BusEntity>, String>((ref, businessId) {
  final owner = ref.watch(ownerIdProvider);
  return owner == null ? Stream.value(const <BusEntity>[]) :
      ref.watch(tripRepositoryProvider).watchBuses(owner, businessId);
});

final dailyAdjustmentsProvider = StreamProvider.autoDispose
    .family<List<DailyAdjustment>, String>((ref, date) =>
        ref.watch(tripRepositoryProvider).watchAdjustments(date));

final selectedBusProvider =
    NotifierProvider.autoDispose.family<SelectedBus, String?, String>(SelectedBus.new);

class SelectedBus extends Notifier<String?> {
  SelectedBus(this.businessId);
  final String businessId;
  @override
  String? build() {
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
    .family<TripDraftController, TripDraft, TripEditorKey>(TripDraftController.new);

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

typedef DelayEditorKey = ({TripPlan trip, DailyAdjustment? adjustment, String date});
final delayDraftProvider = NotifierProvider.autoDispose
    .family<DelayDraft, Map<String, int>, DelayEditorKey>(DelayDraft.new);
class DelayDraft extends Notifier<Map<String, int>> {
  DelayDraft(this.args);
  final DelayEditorKey args;
  @override
  Map<String, int> build() => Map.unmodifiable(
    args.adjustment?.scheduleRevision == args.trip.revision
        ? args.adjustment!.delays : <String, int>{},
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
  FutureOr<void> build() { ref.watch(ownerIdProvider); }

  Future<bool> run(Future<void> Function(String, TripRepository) action) async {
    if (state.isLoading) return false;
    final owner = ref.read(ownerIdProvider);
    final repository = ref.read(tripRepositoryProvider);
    if (owner == null) {
      state = AsyncError(const AppFailure('Please sign in.'), StackTrace.current);
      return false;
    }
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => action(owner, repository));
    if (!ref.mounted || ref.read(ownerIdProvider) != owner) return false;
    state = result;
    return !result.hasError;
  }

  Future<bool> saveBus(BusinessEntity business, String name, {BusEntity? bus}) =>
      run((owner, repo) => repo.saveBus(owner, business, name, bus: bus));
  Future<bool> saveTrip(BusinessEntity business, BusEntity bus, TripPlan trip) =>
      run((owner, repo) async { await repo.saveTrip(owner, business, bus, trip); });
  Future<bool> deleteTrip(BusEntity bus, TripPlan trip) =>
      run((owner, repo) => repo.deleteTrip(owner, bus, trip));
  Future<bool> deleteBus(BusEntity bus) =>
      run((owner, repo) => repo.deleteBus(owner, bus));
  Future<bool> saveDelay(BusEntity bus, TripPlan trip, DailyAdjustment adjustment) =>
      run((owner, repo) => repo.saveAdjustment(owner, bus, trip, adjustment));
  Future<bool> resetDelay(BusEntity bus, TripPlan trip, String date) =>
      run((owner, repo) => repo.resetAdjustment(owner, bus, trip, date));
}
