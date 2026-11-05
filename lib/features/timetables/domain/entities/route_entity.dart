import 'package:equatable/equatable.dart';

class RouteEntity extends Equatable {
  final String id;
  final String ownerId;
  final String businessId;
  final String businessName;
  final String name;
  final String startStop;
  final String endStop;
  final List<String> stops;
  final bool isReturn;
  final String? returnOfRouteId;

  const RouteEntity({
    required this.id,
    required this.ownerId,
    required this.businessId,
    required this.businessName,
    required this.name,
    required this.startStop,
    required this.endStop,
    required this.stops,
    this.isReturn = false,
    this.returnOfRouteId,
  });

  @override
  List<Object?> get props => [
    id,
    ownerId,
    businessId,
    businessName,
    name,
    startStop,
    endStop,
    stops,
    isReturn,
    returnOfRouteId,
  ];
}
