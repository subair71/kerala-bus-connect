import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_model.dart';
import '../models/route_model.dart';
import '../models/service_model.dart';

abstract class TransitRemoteDataSource {
  Stream<List<ServiceModel>> getPublishedServices();
  Stream<List<BusinessModel>> getOwnerBusinesses(String ownerId);
  Stream<List<RouteModel>> getBusinessRoutes(String businessId);
  Stream<List<ServiceModel>> getOwnerServices(String ownerId);

  Future<String> addBusiness(Map<String, dynamic> data);
  Future<void> updateBusiness(String businessId, Map<String, dynamic> data);

  Future<String> addRoute(Map<String, dynamic> data);
  Future<void> updateRoute(String routeId, Map<String, dynamic> data);
  Future<void> deleteRoute(String routeId);

  Future<String> addService(Map<String, dynamic> data);
  Future<void> updateService(String serviceId, Map<String, dynamic> data);
  Future<void> deleteService(String serviceId);
}

class TransitRemoteDataSourceImpl implements TransitRemoteDataSource {
  final FirebaseFirestore _firestore;

  TransitRemoteDataSourceImpl(this._firestore);

  @override
  Stream<List<ServiceModel>> getPublishedServices() {
    return _firestore
        .collection('services')
        .where('published', isEqualTo: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          if (snap.docs.isEmpty && snap.metadata.isFromCache)
            throw StateError('Live timetable data is unavailable.');
          final list = snap.docs
              .map((d) => ServiceModel.fromSnapshot(d))
              .toList();
          return List<ServiceModel>.unmodifiable(list);
        });
  }

  @override
  Stream<List<BusinessModel>> getOwnerBusinesses(String ownerId) {
    return _firestore
        .collection('businesses')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          if (snap.docs.isEmpty && snap.metadata.isFromCache)
            throw StateError('Live data is unavailable.');
          return snap.docs.map((d) => BusinessModel.fromSnapshot(d)).toList();
        });
  }

  @override
  Stream<List<RouteModel>> getBusinessRoutes(String businessId) {
    return _firestore
        .collection('routes')
        .where('businessId', isEqualTo: businessId)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          if (snap.docs.isEmpty && snap.metadata.isFromCache)
            throw StateError('Live data is unavailable.');
          return snap.docs.map((d) => RouteModel.fromSnapshot(d)).toList();
        });
  }

  @override
  Stream<List<ServiceModel>> getOwnerServices(String ownerId) {
    return _firestore
        .collection('services')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          if (snap.docs.isEmpty && snap.metadata.isFromCache)
            throw StateError('Live data is unavailable.');
          return snap.docs.map((d) => ServiceModel.fromSnapshot(d)).toList();
        });
  }

  @override
  Future<String> addBusiness(Map<String, dynamic> data) async {
    final ref = await _firestore.collection('businesses').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> updateBusiness(String businessId, Map<String, dynamic> data) {
    return _firestore.collection('businesses').doc(businessId).update(data);
  }

  @override
  Future<String> addRoute(Map<String, dynamic> data) async {
    final ref = await _firestore.collection('routes').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> updateRoute(String routeId, Map<String, dynamic> data) async {
    await _firestore.collection('routes').doc(routeId).update(data);
    // Published trips own their stop snapshots; editing a template must not
    // invalidate their times or change an independently edited return trip.
  }

  @override
  Future<void> deleteRoute(String routeId) async {
    await _firestore.collection('routes').doc(routeId).delete();
  }

  @override
  Future<String> addService(Map<String, dynamic> data) async {
    final ref = await _firestore.collection('services').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> updateService(String serviceId, Map<String, dynamic> data) {
    return _firestore.collection('services').doc(serviceId).update(data);
  }

  @override
  Future<void> deleteService(String serviceId) {
    return _firestore.collection('services').doc(serviceId).delete();
  }
}
