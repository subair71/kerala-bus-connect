import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/transit_repository.dart';
import 'owner_event.dart';
import 'owner_state.dart';

class OwnerBloc extends Bloc<OwnerEvent, OwnerState> {
  final TransitRepository _transitRepository;

  OwnerBloc(this._transitRepository) : super(const OwnerState()) {
    on<OwnerSelectBusiness>(_onSelectBusiness);
    on<OwnerCreateBusiness>(_onCreateBusiness);
    on<OwnerUpdateBusiness>(_onUpdateBusiness);
    on<OwnerSelectRoute>(_onSelectRoute);
    on<OwnerStartEditRoute>(_onStartEditRoute);
    on<OwnerCancelEditRoute>(_onCancelEditRoute);
    on<OwnerSaveRoute>(_onSaveRoute);
    on<OwnerGenerateReturnRoute>(_onGenerateReturnRoute);
    on<OwnerDeleteRoute>(_onDeleteRoute);
    on<OwnerChangeDepartureTime>(_onChangeDepartureTime);
    on<OwnerToggleCustomizeStopTimings>(_onToggleCustomizeStopTimings);
    on<OwnerChangeStopTiming>(_onChangeStopTiming);
    on<OwnerToggleOffDay>(_onToggleOffDay);
    on<OwnerStartEditService>(_onStartEditService);
    on<OwnerCancelEditService>(_onCancelEditService);
    on<OwnerPublishService>(_onPublishService);
    on<OwnerDeleteService>(_onDeleteService);
  }

  void _onSelectBusiness(OwnerSelectBusiness event, Emitter<OwnerState> emit) {
    emit(state.copyWith(
      selectedBusinessId: event.businessId,
      selectedRouteId: null,
      clearRouteEdit: true,
      clearServiceEdit: true,
    ));
  }

  Future<void> _onCreateBusiness(
    OwnerCreateBusiness event,
    Emitter<OwnerState> emit,
  ) async {
    if (event.name.trim().isEmpty) {
      emit(state.copyWith(userMessage: 'Enter a business name', isError: true));
      return;
    }
    emit(state.copyWith(status: OwnerStatus.loading));
    try {
      final id = await _transitRepository.createBusiness(
        ownerId: event.ownerId,
        name: event.name.trim(),
      );
      emit(state.copyWith(
        status: OwnerStatus.success,
        selectedBusinessId: id,
        userMessage: 'Business created successfully',
        isError: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: OwnerStatus.failure,
        userMessage: e.toString().replaceAll('Exception: ', ''),
        isError: true,
      ));
    }
  }

  Future<void> _onUpdateBusiness(
    OwnerUpdateBusiness event,
    Emitter<OwnerState> emit,
  ) async {
    if (event.name.trim().isEmpty) return;
    try {
      await _transitRepository.updateBusiness(
        businessId: event.businessId,
        ownerId: event.ownerId,
        name: event.name.trim(),
      );
      emit(state.copyWith(
        userMessage: 'Business name updated',
        isError: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        userMessage: e.toString().replaceAll('Exception: ', ''),
        isError: true,
      ));
    }
  }

  void _onSelectRoute(OwnerSelectRoute event, Emitter<OwnerState> emit) {
    final Map<String, TimeOfDay> timings = {};
    int m = state.departure.hour * 60 + state.departure.minute;
    for (int i = 0; i < event.stops.length; i++) {
      final h = (m ~/ 60) % 24;
      final min = m % 60;
      timings[event.stops[i]] = TimeOfDay(hour: h, minute: min);
      m += 15;
    }

    emit(state.copyWith(
      selectedRouteId: event.routeId,
      stopTimeValues: timings,
    ));
  }

  void _onStartEditRoute(OwnerStartEditRoute event, Emitter<OwnerState> emit) {
    emit(state.copyWith(
      editingRouteId: event.routeId,
      routeEditName: event.name,
      routeEditStart: event.startStop,
      routeEditEnd: event.endStop,
      routeEditStops: event.stopsText,
      userMessage: 'Editing route: ${event.name}',
      isError: false,
    ));
  }

  void _onCancelEditRoute(OwnerCancelEditRoute event, Emitter<OwnerState> emit) {
    emit(state.copyWith(clearRouteEdit: true));
  }

  Future<void> _onSaveRoute(
    OwnerSaveRoute event,
    Emitter<OwnerState> emit,
  ) async {
    final start = event.startStop.trim();
    final end = event.endStop.trim();
    if (start.isEmpty || end.isEmpty || start.toLowerCase() == end.toLowerCase()) {
      emit(state.copyWith(
        userMessage: 'Enter distinct starting and ending stops',
        isError: true,
      ));
      return;
    }

    final intermediate = event.intermediateStopsText
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final forwardStops = [start, ...intermediate, end];
    final routeTitle = event.name.trim().isEmpty ? '$start → $end' : event.name.trim();

    emit(state.copyWith(status: OwnerStatus.loading));
    try {
      if (state.isEditingRoute) {
        await _transitRepository.updateRoute(
          routeId: state.editingRouteId!,
          ownerId: event.ownerId,
          name: routeTitle,
          startStop: start,
          endStop: end,
          stops: forwardStops,
        );
        emit(state.copyWith(
          status: OwnerStatus.success,
          clearRouteEdit: true,
          userMessage: 'Route updated successfully!',
          isError: false,
        ));
      } else {
        final id = await _transitRepository.createRoute(
          ownerId: event.ownerId,
          businessId: event.businessId,
          businessName: event.businessName,
          name: routeTitle,
          startStop: start,
          endStop: end,
          stops: forwardStops,
        );

        if (event.generateReturnRoute) {
          final returnStops = forwardStops.reversed.toList();
          final returnTitle = '$end → $start (Return)';
          await _transitRepository.createRoute(
            ownerId: event.ownerId,
            businessId: event.businessId,
            businessName: event.businessName,
            name: returnTitle,
            startStop: end,
            endStop: start,
            stops: returnStops,
            isReturn: true,
            returnOfRouteId: id,
          );
        }

        emit(state.copyWith(
          status: OwnerStatus.success,
          selectedRouteId: id,
          clearRouteEdit: true,
          userMessage: event.generateReturnRoute
              ? 'Main & return routes created!'
              : 'Route created!',
          isError: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: OwnerStatus.failure,
        userMessage: e.toString().replaceAll('Exception: ', ''),
        isError: true,
      ));
    }
  }

  Future<void> _onGenerateReturnRoute(
    OwnerGenerateReturnRoute event,
    Emitter<OwnerState> emit,
  ) async {
    try {
      final revStops = event.originalStops.reversed.toList();
      await _transitRepository.createRoute(
        ownerId: event.ownerId,
        businessId: event.businessId,
        businessName: event.businessName,
        name: '${revStops.first} → ${revStops.last} (Return)',
        startStop: revStops.first,
        endStop: revStops.last,
        stops: revStops,
        isReturn: true,
        returnOfRouteId: event.originRouteId,
      );
      emit(state.copyWith(
        userMessage: 'Return route generated!',
        isError: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        userMessage: e.toString().replaceAll('Exception: ', ''),
        isError: true,
      ));
    }
  }

  Future<void> _onDeleteRoute(
    OwnerDeleteRoute event,
    Emitter<OwnerState> emit,
  ) async {
    try {
      await _transitRepository.deleteRoute(event.routeId);
      emit(state.copyWith(
        selectedRouteId: state.selectedRouteId == event.routeId ? null : state.selectedRouteId,
        clearRouteEdit: state.editingRouteId == event.routeId,
        userMessage: 'Route deleted',
        isError: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        userMessage: e.toString().replaceAll('Exception: ', ''),
        isError: true,
      ));
    }
  }

  void _onChangeDepartureTime(
    OwnerChangeDepartureTime event,
    Emitter<OwnerState> emit,
  ) {
    final Map<String, TimeOfDay> timings = {};
    int m = event.time.hour * 60 + event.time.minute;
    for (int i = 0; i < event.routeStops.length; i++) {
      final h = (m ~/ 60) % 24;
      final min = m % 60;
      timings[event.routeStops[i]] = TimeOfDay(hour: h, minute: min);
      m += 15;
    }

    emit(state.copyWith(
      departure: event.time,
      stopTimeValues: timings,
    ));
  }

  void _onToggleCustomizeStopTimings(
    OwnerToggleCustomizeStopTimings event,
    Emitter<OwnerState> emit,
  ) {
    emit(state.copyWith(customizeStopTimings: event.enable));
  }

  void _onChangeStopTiming(
    OwnerChangeStopTiming event,
    Emitter<OwnerState> emit,
  ) {
    final updated = Map<String, TimeOfDay>.from(state.stopTimeValues);
    updated[event.stop] = event.time;
    emit(state.copyWith(
      stopTimeValues: updated,
      customizeStopTimings: true,
    ));
  }

  void _onToggleOffDay(OwnerToggleOffDay event, Emitter<OwnerState> emit) {
    final updated = Set<String>.from(state.selectedOffDays);
    if (updated.contains(event.day)) {
      updated.remove(event.day);
    } else {
      updated.add(event.day);
    }
    emit(state.copyWith(selectedOffDays: updated));
  }

  void _onStartEditService(
    OwnerStartEditService event,
    Emitter<OwnerState> emit,
  ) {
    final Map<String, TimeOfDay> timings = {};
    if (event.stopTimings.isNotEmpty) {
      for (final entry in event.stopTimings.entries) {
        timings[entry.key] = TimeOfDay(
          hour: (entry.value ~/ 60) % 24,
          minute: entry.value % 60,
        );
      }
    } else {
      int m = event.departureMinutes;
      for (final s in event.routeStops) {
        timings[s] = TimeOfDay(hour: (m ~/ 60) % 24, minute: m % 60);
        m += 15;
      }
    }

    emit(state.copyWith(
      editingServiceId: event.serviceId,
      selectedRouteId: event.routeId,
      serviceEditBusName: event.busName,
      serviceEditNote: event.offTimingsNote,
      departure: TimeOfDay(
        hour: (event.departureMinutes ~/ 60) % 24,
        minute: event.departureMinutes % 60,
      ),
      customizeStopTimings: event.stopTimings.isNotEmpty,
      stopTimeValues: timings,
      selectedOffDays: Set<String>.from(event.offDays),
      userMessage: 'Editing timetable: ${event.busName}',
      isError: false,
    ));
  }

  void _onCancelEditService(
    OwnerCancelEditService event,
    Emitter<OwnerState> emit,
  ) {
    emit(state.copyWith(
      clearServiceEdit: true,
      departure: const TimeOfDay(hour: 8, minute: 0),
      customizeStopTimings: false,
      selectedOffDays: const {},
    ));
  }

  Future<void> _onPublishService(
    OwnerPublishService event,
    Emitter<OwnerState> emit,
  ) async {
    final name = event.busName.trim();
    if (name.isEmpty) {
      emit(state.copyWith(userMessage: 'Enter bus name', isError: true));
      return;
    }

    final depMinutes = state.departure.hour * 60 + state.departure.minute;

    emit(state.copyWith(status: OwnerStatus.loading));
    try {
      final Map<String, int> finalStopTimings = {};
      if (state.customizeStopTimings) {
        for (final stop in event.routeStops) {
          final t = state.stopTimeValues[stop] ?? state.departure;
          finalStopTimings[stop] = t.hour * 60 + t.minute;
        }
      } else {
        int m = depMinutes;
        for (final stop in event.routeStops) {
          finalStopTimings[stop] = m;
          m += 15;
        }
      }

      if (state.isEditingService) {
        await _transitRepository.updateService(
          serviceId: state.editingServiceId!,
          ownerId: event.ownerId,
          businessId: event.businessId,
          routeId: event.routeId,
          businessName: event.businessName,
          routeName: event.routeName,
          busName: name,
          stops: event.routeStops,
          departureMinutes: depMinutes,
          stopTimings: finalStopTimings,
          offDays: state.selectedOffDays.toList(),
          offTimingsNote: event.offTimingsNote.trim(),
        );

        emit(state.copyWith(
          status: OwnerStatus.success,
          clearServiceEdit: true,
          userMessage: 'Timetable updated successfully!',
          isError: false,
        ));
      } else {
        await _transitRepository.publishService(
          ownerId: event.ownerId,
          businessId: event.businessId,
          routeId: event.routeId,
          businessName: event.businessName,
          routeName: event.routeName,
          busName: name,
          stops: event.routeStops,
          departureMinutes: depMinutes,
          stopTimings: finalStopTimings,
          offDays: state.selectedOffDays.toList(),
          offTimingsNote: event.offTimingsNote.trim(),
        );

        emit(state.copyWith(
          status: OwnerStatus.success,
          clearServiceEdit: true,
          userMessage: 'Timetable published successfully!',
          isError: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: OwnerStatus.failure,
        userMessage: e.toString().replaceAll('Exception: ', ''),
        isError: true,
      ));
    }
  }

  Future<void> _onDeleteService(
    OwnerDeleteService event,
    Emitter<OwnerState> emit,
  ) async {
    try {
      await _transitRepository.deleteService(event.serviceId);
      emit(state.copyWith(
        clearServiceEdit: state.editingServiceId == event.serviceId,
        userMessage: 'Timetable deleted',
        isError: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        userMessage: e.toString().replaceAll('Exception: ', ''),
        isError: true,
      ));
    }
  }
}

