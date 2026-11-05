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

  // Fallback demo services for smooth experience when offline or rules pending
  static final List<ServiceModel> _fallbackServices = [
    const ServiceModel(
      id: 'demo-1',
      ownerId: 'demo-owner',
      businessId: 'demo-biz-1',
      businessName: 'Rajadhani Travels',
      routeId: 'route-1',
      routeName: 'Aluva - Kaloor Fast Passenger',
      busName: 'KL-07-CD-4512 (Rajadhani Express)',
      departureMinutes: 480, // 08:00 AM
      stops: ['Aluva', 'Companypady', 'Kalamassery', 'Edappally Toll', 'Palarivattom', 'Kaloor'],
      stopTimings: {
        'Aluva': 480,
        'Companypady': 492,
        'Kalamassery': 504,
        'Edappally Toll': 515,
        'Palarivattom': 525,
        'Kaloor': 535,
      },
      offDays: [],
      offTimingsNote: '',
      published: true,
    ),
    const ServiceModel(
      id: 'demo-2',
      ownerId: 'demo-owner',
      businessId: 'demo-biz-2',
      businessName: 'Kerala Bus Line',
      routeId: 'route-1',
      routeName: 'Aluva - Kaloor Metro Feeder',
      busName: 'KL-07-BV-8809 (Kerala Travels)',
      departureMinutes: 525, // 08:45 AM
      stops: ['Aluva', 'Companypady', 'Kalamassery', 'Edappally Toll', 'Palarivattom', 'Kaloor'],
      stopTimings: {
        'Aluva': 525,
        'Companypady': 535,
        'Kalamassery': 548,
        'Edappally Toll': 560,
        'Palarivattom': 570,
        'Kaloor': 580,
      },
      offDays: ['Sunday'],
      offTimingsNote: 'Sunday trip runs via bypass',
      published: true,
    ),
    const ServiceModel(
      id: 'demo-3',
      ownerId: 'demo-owner',
      businessId: 'demo-biz-3',
      businessName: 'Malabar Lines',
      routeId: 'route-2',
      routeName: 'Fort Kochi - Infopark Kakkanad Superfast',
      busName: 'KL-43-A-2101 (Malabar Queen)',
      departureMinutes: 540, // 09:00 AM
      stops: ['Fort Kochi', 'Thoppumpady', 'Menaka', 'Kaloor', 'Edappally Toll', 'Kakkanad', 'Infopark Kakkanad'],
      stopTimings: {
        'Fort Kochi': 540,
        'Thoppumpady': 555,
        'Menaka': 575,
        'Kaloor': 590,
        'Edappally Toll': 605,
        'Kakkanad': 620,
        'Infopark Kakkanad': 630,
      },
      offDays: [],
      offTimingsNote: '',
      published: true,
    ),
    const ServiceModel(
      id: 'demo-4',
      ownerId: 'demo-owner',
      businessId: 'demo-biz-4',
      businessName: 'St. Jude Express',
      routeId: 'route-3',
      routeName: 'Angamaly - Ernakulam South Direct',
      busName: 'KL-40-H-6710 (St. Jude Express)',
      departureMinutes: 570, // 09:30 AM
      stops: ['Angamaly', 'Aluva', 'Kalamassery', 'Edappally Toll', 'Kaloor', 'Menaka', 'Ernakulam South'],
      stopTimings: {
        'Angamaly': 570,
        'Aluva': 590,
        'Kalamassery': 605,
        'Edappally Toll': 618,
        'Kaloor': 632,
        'Menaka': 645,
        'Ernakulam South': 655,
      },
      offDays: ['Saturday', 'Sunday'],
      offTimingsNote: 'Weekdays rush hour special',
      published: true,
    ),
    const ServiceModel(
      id: 'demo-5',
      ownerId: 'demo-owner',
      businessId: 'demo-biz-5',
      businessName: 'Silver Transit',
      routeId: 'route-4',
      routeName: 'Thrissur - Kozhikode Limited Stop',
      busName: 'KL-08-BK-1122 (Silver Arrow)',
      departureMinutes: 600, // 10:00 AM
      stops: ['Thrissur', 'Kunnamkulam', 'Edappal', 'Kuttipuram', 'Valanchery', 'Kottakkal', 'Malappuram', 'Kozhikode'],
      stopTimings: {
        'Thrissur': 600,
        'Kunnamkulam': 635,
        'Edappal': 665,
        'Kuttipuram': 685,
        'Valanchery': 705,
        'Kottakkal': 725,
        'Malappuram': 750,
        'Kozhikode': 805,
      },
      offDays: [],
      offTimingsNote: '',
      published: true,
    ),
  ];

  @override
  Stream<List<ServiceModel>> getPublishedServices() {
    return _firestore
        .collection('services')
        .where('published', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => ServiceModel.fromSnapshot(d)).toList();
          return list.isEmpty ? _fallbackServices : list;
        })
        .handleError((dynamic error) {
          return _fallbackServices;
        });
  }

  @override
  Stream<List<BusinessModel>> getOwnerBusinesses(String ownerId) {
    return _firestore
        .collection('businesses')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => BusinessModel.fromSnapshot(d)).toList())
        .handleError((dynamic _) => <BusinessModel>[]);
  }

  @override
  Stream<List<RouteModel>> getBusinessRoutes(String businessId) {
    return _firestore
        .collection('routes')
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => RouteModel.fromSnapshot(d)).toList())
        .handleError((dynamic _) => <RouteModel>[]);
  }

  @override
  Stream<List<ServiceModel>> getOwnerServices(String ownerId) {
    return _firestore
        .collection('services')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ServiceModel.fromSnapshot(d)).toList())
        .handleError((dynamic _) => <ServiceModel>[]);
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
    if (data.containsKey('name') || data.containsKey('stops')) {
      final related = await _firestore
          .collection('services')
          .where('routeId', isEqualTo: routeId)
          .get();
      for (final doc in related.docs) {
        await doc.reference.update({
          if (data.containsKey('name')) 'routeName': data['name'],
          if (data.containsKey('stops')) 'stops': data['stops'],
        });
      }
    }
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
