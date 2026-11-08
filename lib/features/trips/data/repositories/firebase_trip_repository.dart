import 'dart:convert';
import '../../../timetables/data/datasources/schedule_cache.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/sample_ids.dart';
import '../../../timetables/domain/entities/business_entity.dart';
import '../../domain/entities/trip_plan.dart';
import '../../domain/repositories/trip_repository.dart';

class FirebaseTripRepository implements TripRepository {
  final FirebaseFirestore db;
  final ScheduleCache? cache;
  FirebaseTripRepository(this.db, {this.cache});

  void _owned(String owner, Map<String, dynamic>? data) {
    if (owner.isEmpty || data == null || data['ownerId'] != owner) {
      throw const AppFailure('You do not have access to this bus or trip.');
    }
  }

  Future<Map<String, dynamic>> _bus(
    Transaction tx,
    String owner,
    BusEntity bus,
  ) async {
    requireLiveIds([owner, bus.id, bus.businessId]);
    final data = (await tx.get(db.collection('buses').doc(bus.id))).data();
    _owned(owner, data);
    if (data!['businessId'] != bus.businessId || bus.ownerId != owner) {
      throw const AppFailure('Choose a bus belonging to your business.');
    }
    return data;
  }

  @override
  Stream<List<BusEntity>> watchBuses(String ownerId, String businessId) => db
      .collection('buses')
      .where('ownerId', isEqualTo: ownerId)
      .where('businessId', isEqualTo: businessId)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) {
        if (snapshot.docs.isEmpty && snapshot.metadata.isFromCache) {
          throw const AppFailure(
            'Bus data is unavailable. Reconnect to retry.',
          );
        }
        return [
          for (final doc in snapshot.docs)
            if (doc.data()['businessId'] == businessId)
              BusEntity(
                id: doc.id,
                ownerId: ownerId,
                businessId: businessId,
                name: doc.data()['name'] as String,
              ),
        ];
      });

  @override
  Stream<List<DailyAdjustment>> watchAdjustments(String date) => db
      .collection('trip_adjustments')
      .where('serviceDate', isEqualTo: date)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) {
        if (snapshot.metadata.isFromCache) {
          throw const AppFailure(
            'Daily updates are unavailable while offline.',
          );
        }
        return [
          for (final doc in snapshot.docs)
            DailyAdjustment(
              tripId: doc.data()['tripId'] as String,
              serviceDate: doc.data()['serviceDate'] as String,
              scheduleRevision: doc.data()['scheduleRevision'] as String,
              delays: Map<String, int>.from(doc.data()['delays'] as Map),
            ),
        ];
      });

  @override
  Future<void> saveBus(
    String ownerId,
    BusinessEntity business,
    String name, {
    BusEntity? bus,
  }) async {
    requireLiveIds([ownerId, business.id, bus?.id]);
    if (name.trim().isEmpty || name.trim().length > 100) {
      throw const AppFailure(
        'Enter a bus name or registration (up to 100 characters).',
      );
    }
    final target = db.collection('buses').doc(bus?.id);
    final related = bus == null
        ? null
        : await db
              .collection('services')
              .where('busId', isEqualTo: bus.id)
              .limit(401)
              .get();
    if ((related?.docs.length ?? 0) > 400) {
      throw const AppFailure('This bus has too many trips to rename together.');
    }
    await db.runTransaction((tx) async {
      final operator = await tx.get(
        db.collection('businesses').doc(business.id),
      );
      _owned(ownerId, operator.data());
      if (bus != null) await _bus(tx, ownerId, bus);
      final trips = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final doc
          in related?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
        final current = await tx.get(doc.reference);
        if (current.exists) {
          _owned(ownerId, current.data());
          trips.add(current);
        }
      }
      if (bus == null) {
        tx.set(target, {
          'ownerId': ownerId,
          'businessId': business.id,
          'name': name.trim(),
          'tripCount': 0,
        });
      } else {
        tx.update(target, {'name': name.trim()});
      }
      for (final trip in trips) {
        tx.update(trip.reference, {'busName': name.trim()});
      }
    });
    cache?.invalidate();
  }

  @override
  Future<void> deleteBus(String ownerId, BusEntity bus) async {
    await db.runTransaction((tx) async {
      final data = await _bus(tx, ownerId, bus);
      if (data['tripCount'] != 0) {
        throw const AppFailure(
          'Delete this bus’s trips before deleting the bus.',
        );
      }
      tx.delete(db.collection('buses').doc(bus.id));
    });
  }

  @override
  Future<String> saveTrip(
    String ownerId,
    BusinessEntity business,
    BusEntity bus,
    TripPlan trip,
  ) async {
    requireLiveIds([
      ownerId,
      business.id,
      bus.id,
      if (trip.id.isNotEmpty) trip.id,
    ]);
    trip.validate();
    if (bus.businessId != business.id || business.ownerId != ownerId) {
      throw const AppFailure('Choose a bus in your business.');
    }
    final target = db
        .collection('services')
        .doc(trip.id.isEmpty ? null : trip.id);
    // Every trip owns its stop snapshot. Shared legacy route templates are not mutated.
    final routeRef = db.collection('routes').doc();
    final revision = db.collection('services').doc().id;
    await db.runTransaction((tx) async {
      final busData = await _bus(tx, ownerId, bus);
      final operator = await tx.get(
        db.collection('businesses').doc(business.id),
      );
      _owned(ownerId, operator.data());
      Map<String, dynamic>? current;
      if (trip.id.isNotEmpty) {
        current = (await tx.get(target)).data();
        _owned(ownerId, current);
        if (current!['businessId'] != business.id ||
            ((current['busId'] ?? '') != '' && current['busId'] != bus.id)) {
          throw const AppFailure('This trip belongs to another bus.');
        }
        if ((current['scheduleRevision'] ?? '') != trip.revision) {
          throw const AppFailure(
            'The schedule changed. Reopen the trip before saving.',
          );
        }
      }
      final stops = trip.stops.map((s) => s.name.trim()).toList();
      final timings = {for (final s in trip.stops) s.name.trim(): s.minutes};
      final offDays = trip.offDays.toList()..sort();
      final unchanged =
          current != null &&
          jsonEncode(current['stops']) == jsonEncode(stops) &&
          jsonEncode([
                for (final name in stops)
                  (current['stopTimings'] as Map?)?[name],
              ]) ==
              jsonEncode(trip.stops.map((s) => s.minutes).toList()) &&
          jsonEncode(current['stopIds']) ==
              jsonEncode(trip.stops.map((s) => s.id).toList()) &&
          jsonEncode(current['offDays']) == jsonEncode(offDays);
      final routeId = current?['routeId'] as String? ?? routeRef.id;
      final name = '${stops.first} → ${stops.last}';
      if (current == null) {
        tx.set(routeRef, {
          'ownerId': ownerId,
          'businessId': business.id,
          'businessName': operator.data()!['name'],
          'name': name,
          'startStop': stops.first,
          'endStop': stops.last,
          'stops': stops,
          'isReturn': false,
        });
      }
      tx.set(target, {
        'ownerId': ownerId,
        'businessId': business.id,
        'busId': bus.id,
        'businessName': operator.data()!['name'],
        'busName': busData['name'],
        'routeId': routeId,
        'routeName': name,
        'stops': stops,
        'stopIds': trip.stops.map((s) => s.id).toList(),
        'departureMinutes': trip.stops.first.minutes,
        'stopTimings': timings,
        'offDays': offDays,
        'offTimingsNote': trip.note.trim(),
        'published': true,
        'scheduleRevision': unchanged ? trip.revision : revision,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (current == null || (current['busId'] ?? '') == '') {
        tx.update(db.collection('buses').doc(bus.id), {
          'tripCount': (busData['tripCount'] as int) + 1,
        });
      }
    });
    cache?.invalidate();
    return target.id;
  }

  @override
  Future<void> deleteTrip(String ownerId, BusEntity bus, TripPlan trip) async {
    await db.runTransaction((tx) async {
      final busData = await _bus(tx, ownerId, bus);
      final target = db.collection('services').doc(trip.id);
      final data = (await tx.get(target)).data();
      _owned(ownerId, data);
      if (data!['busId'] != bus.id) {
        throw const AppFailure('This trip belongs to another bus.');
      }
      tx.delete(target);
      tx.update(db.collection('buses').doc(bus.id), {
        'tripCount': (busData['tripCount'] as int) - 1,
      });
    });
    cache?.invalidate();
  }

  Future<void> _adjust(
    String ownerId,
    BusEntity bus,
    TripPlan trip,
    String date,
    DailyAdjustment? adjustment,
  ) async {
    final parsed = DateTime.tryParse(date);
    if (parsed == null || serviceDateKey(parsed) != date) {
      throw const AppFailure('Choose a valid service date.');
    }
    final expected = adjustment == null
        ? null
        : trip.expectedTimes(adjustment.delays);
    if (adjustment != null &&
        (adjustment.tripId != trip.id ||
            adjustment.scheduleRevision != trip.revision ||
            adjustment.serviceDate != date)) {
      throw const AppFailure(
        'These adjustments belong to another trip or date.',
      );
    }
    await db.runTransaction((tx) async {
      await _bus(tx, ownerId, bus);
      final data = (await tx.get(
        db.collection('services').doc(trip.id),
      )).data();
      _owned(ownerId, data);
      if (data!['busId'] != bus.id ||
          data['scheduleRevision'] != trip.revision) {
        throw const AppFailure(
          'The schedule changed. Reopen the trip before saving.',
        );
      }
      final target = db.collection('trip_adjustments').doc('${trip.id}_$date');
      if (adjustment == null) {
        tx.delete(target);
      } else {
        tx.set(target, {
          'ownerId': ownerId,
          'busId': bus.id,
          'tripId': trip.id,
          'serviceDate': date,
          'scheduleRevision': trip.revision,
          'delays': adjustment.delays,
          'expectedStopTimings': {
            for (var i = 0; i < trip.stops.length; i++)
              trip.stops[i].name.trim(): expected![i],
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  @override
  Future<void> saveAdjustment(
    String ownerId,
    BusEntity bus,
    TripPlan trip,
    DailyAdjustment adjustment,
  ) => _adjust(ownerId, bus, trip, adjustment.serviceDate, adjustment);

  @override
  Future<void> resetAdjustment(
    String ownerId,
    BusEntity bus,
    TripPlan trip,
    String date,
  ) => _adjust(ownerId, bus, trip, date, null);
}
