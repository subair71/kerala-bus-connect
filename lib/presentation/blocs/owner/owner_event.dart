import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class OwnerEvent extends Equatable {
  const OwnerEvent();

  @override
  List<Object?> get props => [];
}

class OwnerSelectBusiness extends OwnerEvent {
  final String businessId;

  const OwnerSelectBusiness(this.businessId);

  @override
  List<Object?> get props => [businessId];
}

class OwnerCreateBusiness extends OwnerEvent {
  final String ownerId;
  final String name;

  const OwnerCreateBusiness({required this.ownerId, required this.name});

  @override
  List<Object?> get props => [ownerId, name];
}

class OwnerUpdateBusiness extends OwnerEvent {
  final String businessId;
  final String ownerId;
  final String name;

  const OwnerUpdateBusiness({
    required this.businessId,
    required this.ownerId,
    required this.name,
  });

  @override
  List<Object?> get props => [businessId, ownerId, name];
}

class OwnerSelectRoute extends OwnerEvent {
  final String routeId;
  final List<String> stops;

  const OwnerSelectRoute(this.routeId, this.stops);

  @override
  List<Object?> get props => [routeId, stops];
}

class OwnerStartEditRoute extends OwnerEvent {
  final String routeId;
  final String name;
  final String startStop;
  final String endStop;
  final String stopsText;

  const OwnerStartEditRoute({
    required this.routeId,
    required this.name,
    required this.startStop,
    required this.endStop,
    required this.stopsText,
  });

  @override
  List<Object?> get props => [routeId, name, startStop, endStop, stopsText];
}

class OwnerCancelEditRoute extends OwnerEvent { const OwnerCancelEditRoute(); }

class OwnerSaveRoute extends OwnerEvent {
  final String ownerId;
  final String businessId;
  final String businessName;
  final String name;
  final String startStop;
  final String endStop;
  final String intermediateStopsText;
  final bool generateReturnRoute;

  const OwnerSaveRoute({
    required this.ownerId,
    required this.businessId,
    required this.businessName,
    required this.name,
    required this.startStop,
    required this.endStop,
    required this.intermediateStopsText,
    required this.generateReturnRoute,
  });

  @override
  List<Object?> get props => [
        ownerId,
        businessId,
        businessName,
        name,
        startStop,
        endStop,
        intermediateStopsText,
        generateReturnRoute,
      ];
}

class OwnerGenerateReturnRoute extends OwnerEvent {
  final String ownerId;
  final String businessId;
  final String businessName;
  final String originRouteId;
  final List<String> originalStops;

  const OwnerGenerateReturnRoute({
    required this.ownerId,
    required this.businessId,
    required this.businessName,
    required this.originRouteId,
    required this.originalStops,
  });

  @override
  List<Object?> get props => [
        ownerId,
        businessId,
        businessName,
        originRouteId,
        originalStops,
      ];
}

class OwnerDeleteRoute extends OwnerEvent {
  final String routeId;

  const OwnerDeleteRoute(this.routeId);

  @override
  List<Object?> get props => [routeId];
}

class OwnerChangeDepartureTime extends OwnerEvent {
  final TimeOfDay time;
  final List<String> routeStops;

  const OwnerChangeDepartureTime(this.time, this.routeStops);

  @override
  List<Object?> get props => [time, routeStops];
}

class OwnerToggleCustomizeStopTimings extends OwnerEvent {
  final bool enable;

  const OwnerToggleCustomizeStopTimings(this.enable);

  @override
  List<Object?> get props => [enable];
}

class OwnerChangeStopTiming extends OwnerEvent {
  final String stop;
  final TimeOfDay time;

  const OwnerChangeStopTiming(this.stop, this.time);

  @override
  List<Object?> get props => [stop, time];
}

class OwnerToggleOffDay extends OwnerEvent {
  final String day;

  const OwnerToggleOffDay(this.day);

  @override
  List<Object?> get props => [day];
}

class OwnerStartEditService extends OwnerEvent {
  final String serviceId;
  final String routeId;
  final String busName;
  final int departureMinutes;
  final Map<String, int> stopTimings;
  final List<String> offDays;
  final String offTimingsNote;
  final List<String> routeStops;

  const OwnerStartEditService({
    required this.serviceId,
    required this.routeId,
    required this.busName,
    required this.departureMinutes,
    required this.stopTimings,
    required this.offDays,
    required this.offTimingsNote,
    required this.routeStops,
  });

  @override
  List<Object?> get props => [
        serviceId,
        routeId,
        busName,
        departureMinutes,
        stopTimings,
        offDays,
        offTimingsNote,
        routeStops,
      ];
}

class OwnerCancelEditService extends OwnerEvent { const OwnerCancelEditService(); }

class OwnerPublishService extends OwnerEvent {
  final String ownerId;
  final String businessId;
  final String routeId;
  final String businessName;
  final String routeName;
  final String busName;
  final List<String> routeStops;
  final String offTimingsNote;

  const OwnerPublishService({
    required this.ownerId,
    required this.businessId,
    required this.routeId,
    required this.businessName,
    required this.routeName,
    required this.busName,
    required this.routeStops,
    required this.offTimingsNote,
  });

  @override
  List<Object?> get props => [
        ownerId,
        businessId,
        routeId,
        businessName,
        routeName,
        busName,
        routeStops,
        offTimingsNote,
      ];
}

class OwnerDeleteService extends OwnerEvent {
  final String serviceId;

  const OwnerDeleteService(this.serviceId);

  @override
  List<Object?> get props => [serviceId];
}

