import 'package:cloud_firestore/cloud_firestore.dart';
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

  factory ServiceModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? {};
    final Map<String, int> timings = {};
    if (data['stopTimings'] is Map) {
      final rawMap = data['stopTimings'] as Map<String, dynamic>;
      for (final entry in rawMap.entries) {
        timings[entry.key] = (entry.value as num).toInt();
      }
    }

    return ServiceModel(
      id: snap.id,
      ownerId: data['ownerId']?.toString() ?? '',
      businessId: data['businessId']?.toString() ?? '',
      routeId: data['routeId']?.toString() ?? '',
      businessName: data['businessName']?.toString() ?? '',
      routeName: data['routeName']?.toString() ?? '',
      busName: data['busName']?.toString() ?? '',
      stops: (data['stops'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      departureMinutes: (data['departureMinutes'] as num?)?.toInt() ?? 0,
      stopTimings: timings,
      offDays: (data['offDays'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      offTimingsNote: data['offTimingsNote']?.toString(),
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
