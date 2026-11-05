import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/route_entity.dart';

class RouteModel extends RouteEntity {
  const RouteModel({
    required super.id,
    required super.ownerId,
    required super.businessId,
    required super.businessName,
    required super.name,
    required super.startStop,
    required super.endStop,
    required super.stops,
    super.isReturn,
    super.returnOfRouteId,
  });

  factory RouteModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? {};
    return RouteModel(
      id: snap.id,
      ownerId: data['ownerId']?.toString() ?? '',
      businessId: data['businessId']?.toString() ?? '',
      businessName: data['businessName']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      startStop: data['startStop']?.toString() ?? '',
      endStop: data['endStop']?.toString() ?? '',
      stops: (data['stops'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      isReturn: data['isReturn'] == true,
      returnOfRouteId: data['returnOfRouteId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'ownerId': ownerId,
    'businessId': businessId,
    'businessName': businessName,
    'name': name,
    'startStop': startStop,
    'endStop': endStop,
    'stops': stops,
    'isReturn': isReturn,
    if (returnOfRouteId != null) 'returnOfRouteId': returnOfRouteId,
  };
}
