import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/data/display_fields.dart';
import '../../domain/entities/service_entity.dart';

class ServiceModel extends ServiceEntity {
  const ServiceModel({
    required super.id,
    required super.ownerId,
    required super.businessId,
    required super.routeId,
    required super.businessName,
    required super.routeName,
    required super.busName,
    required super.stops,
    required super.departureMinutes,
    required super.stopTimings,
    required super.offDays,
    super.offTimingsNote,
    super.published,
  });

  factory ServiceModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    return ServiceModel.fromMap(snap.id, snap.data() ?? {});
  }

  factory ServiceModel.fromMap(String id, Map<String, dynamic> data) {
    final timings = <String, int>{};
    final raw = data['stopTimings'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final time = scheduleMinutes(entry.value);
        if (entry.key is String && time != null) timings[entry.key as String] = time;
      }
    }
    return ServiceModel(
      id: id,
      ownerId: displayText(data['ownerId'], ''),
      businessId: displayText(data['businessId'], ''),
      routeId: displayText(data['routeId'], ''),
      businessName: displayText(data['businessName'], 'Operator unavailable'),
      routeName: displayText(data['routeName'], 'Route name unavailable'),
      busName: displayText(data['busName'], 'Bus name unavailable'),
      stops: stringList(data['stops']),
      departureMinutes: scheduleMinutes(data['departureMinutes']) ?? -1,
      stopTimings: Map.unmodifiable(timings),
      offDays: stringList(data['offDays']),
      offTimingsNote: data['offTimingsNote'] is String ? data['offTimingsNote'] as String : null,
      published: data['published'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'ownerId': ownerId,
    'businessId': businessId,
    'routeId': routeId,
    'businessName': businessName,
    'routeName': routeName,
    'busName': busName,
    'stops': stops,
    'departureMinutes': departureMinutes,
    'stopTimings': stopTimings,
    'offDays': offDays,
    'offTimingsNote': offTimingsNote,
    'published': published,
  };
}
