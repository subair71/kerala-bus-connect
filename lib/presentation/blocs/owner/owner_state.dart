import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum OwnerStatus { initial, loading, success, failure }

class OwnerState extends Equatable {
  final OwnerStatus status;
  final String? selectedBusinessId;
  final String? selectedRouteId;
  final String? editingRouteId;
  final String? editingServiceId;
  final String? routeEditName;
  final String? routeEditStart;
  final String? routeEditEnd;
  final String? routeEditStops;
  final String? serviceEditBusName;
  final String? serviceEditNote;
  final TimeOfDay departure;
  final bool customizeStopTimings;
  final Map<String, TimeOfDay> stopTimeValues;
  final Set<String> selectedOffDays;
  final String? userMessage;
  final bool isError;

  const OwnerState({
    this.status = OwnerStatus.initial,
    this.selectedBusinessId,
    this.selectedRouteId,
    this.editingRouteId,
    this.editingServiceId,
    this.routeEditName,
    this.routeEditStart,
    this.routeEditEnd,
    this.routeEditStops,
    this.serviceEditBusName,
    this.serviceEditNote,
    this.departure = const TimeOfDay(hour: 8, minute: 0),
    this.customizeStopTimings = false,
    this.stopTimeValues = const {},
    this.selectedOffDays = const {},
    this.userMessage,
    this.isError = false,
  });

  bool get isEditingRoute => editingRouteId != null;
  bool get isEditingService => editingServiceId != null;

  OwnerState copyWith({
    OwnerStatus? status,
    String? selectedBusinessId,
    String? selectedRouteId,
    String? editingRouteId,
    String? editingServiceId,
    String? routeEditName,
    String? routeEditStart,
    String? routeEditEnd,
    String? routeEditStops,
    String? serviceEditBusName,
    String? serviceEditNote,
    TimeOfDay? departure,
    bool? customizeStopTimings,
    Map<String, TimeOfDay>? stopTimeValues,
    Set<String>? selectedOffDays,
    String? userMessage,
    bool? isError,
    bool clearRouteEdit = false,
    bool clearServiceEdit = false,
  }) {
    return OwnerState(
      status: status ?? this.status,
      selectedBusinessId: selectedBusinessId ?? this.selectedBusinessId,
      selectedRouteId: selectedRouteId ?? this.selectedRouteId,
      editingRouteId: clearRouteEdit ? null : (editingRouteId ?? this.editingRouteId),
      editingServiceId: clearServiceEdit ? null : (editingServiceId ?? this.editingServiceId),
      routeEditName: clearRouteEdit ? null : (routeEditName ?? this.routeEditName),
      routeEditStart: clearRouteEdit ? null : (routeEditStart ?? this.routeEditStart),
      routeEditEnd: clearRouteEdit ? null : (routeEditEnd ?? this.routeEditEnd),
      routeEditStops: clearRouteEdit ? null : (routeEditStops ?? this.routeEditStops),
      serviceEditBusName: clearServiceEdit ? null : (serviceEditBusName ?? this.serviceEditBusName),
      serviceEditNote: clearServiceEdit ? null : (serviceEditNote ?? this.serviceEditNote),
      departure: departure ?? this.departure,
      customizeStopTimings: customizeStopTimings ?? this.customizeStopTimings,
      stopTimeValues: stopTimeValues ?? this.stopTimeValues,
      selectedOffDays: selectedOffDays ?? this.selectedOffDays,
      userMessage: userMessage,
      isError: isError ?? false,
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedBusinessId,
        selectedRouteId,
        editingRouteId,
        editingServiceId,
        routeEditName,
        routeEditStart,
        routeEditEnd,
        routeEditStops,
        serviceEditBusName,
        serviceEditNote,
        departure,
        customizeStopTimings,
        stopTimeValues,
        selectedOffDays,
        userMessage,
        isError,
      ];
}
