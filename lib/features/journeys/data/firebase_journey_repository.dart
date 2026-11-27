import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../platform/domain/platform_repository.dart';
import '../../timetables/data/models/service_model.dart';
import '../../timetables/domain/entities/service_entity.dart';
import '../domain/journey_filters.dart';
import '../domain/journey_repository.dart';

class FirebaseJourneyRepository implements JourneyRepository {
  final FirebaseFirestore Function() firestore;
  final PlatformRepository platform;
  final SharedPreferencesAsync Function() openPreferences;
  late final preferences = openPreferences();
  FirebaseJourneyRepository(
    this.firestore,
    this.platform,
    this.openPreferences,
  );
  static const _bookmarkKey = 'findmybus.journeys.v1';

  @override
  Future<List<SavedJourney>> readBookmarks() async {
    final raw = await preferences.getString(_bookmarkKey);
    if (raw == null) return [];
    return [
      for (final row in jsonDecode(raw) as List)
        SavedJourney.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<void> writeBookmarks(List<SavedJourney> items) =>
      preferences.setString(
        _bookmarkKey,
        jsonEncode(items.map((r) => r.toJson()).toList()),
      );

  @override
  Future<SampleCatalogue> samples() async {
    try {
      final snapshot = await firestore()
          .collection('sample_services')
          .where('sample', isEqualTo: true)
          .limit(30)
          .get()
          .timeout(const Duration(seconds: 5));
      final rows = snapshot.docs
          .where((d) => d.id.startsWith('demo:'))
          .map(ServiceModel.fromSnapshot)
          .toList();
      if (rows.isNotEmpty) return (records: rows, cloud: true);
    } catch (_) {
      // The explicitly selected sample catalogue also works offline.
    }
    final rows =
        jsonDecode(await rootBundle.loadString('assets/samples/services.json'))
            as List;
    return (
      records: [
        for (final row in rows)
          ServiceModel.fromMap(
            row['id'] as String,
            Map<String, dynamic>.from(row as Map),
          ),
      ],
      cloud: false,
    );
  }

  @override
  Future<ServiceEntity?> timetable(
    String id,
    String date, {
    required bool regular,
  }) async {
    final data = await platform.call('getJourneyTimetable', {
      'id': id,
      'date': date,
      'regular': regular,
    });
    if (data['service'] == null) return null;
    final row = Map<String, dynamic>.from(data['service'] as Map);
    final service = ServiceModel.fromMap(id, row);
    if (regular) return service;
    return service.withExpected(
      Map<String, int>.from(row['expectedStopTimings'] as Map? ?? {}),
      date,
      status: RunningStatus.parse(row['runningStatus']),
    );
  }
}
