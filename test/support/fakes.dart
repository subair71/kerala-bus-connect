import 'dart:async';
import 'package:kerala_bus_connect/features/auth/domain/entities/auth_user.dart';
import 'package:kerala_bus_connect/features/auth/domain/repositories/auth_repository.dart';
import 'package:kerala_bus_connect/features/timetables/domain/entities/business_entity.dart';
import 'package:kerala_bus_connect/features/timetables/domain/entities/route_entity.dart';
import 'package:kerala_bus_connect/features/timetables/domain/entities/service_entity.dart';
import 'package:kerala_bus_connect/features/timetables/domain/repositories/transit_repository.dart';

const business = BusinessEntity(
  id: 'business',
  ownerId: 'owner',
  name: 'Test operator',
);
const route = RouteEntity(
  id: 'route',
  ownerId: 'owner',
  businessId: 'business',
  businessName: 'Test operator',
  name: 'Aluva - Kaloor',
  startStop: 'Aluva',
  endStop: 'Kaloor',
  stops: ['Aluva', 'Kalamassery', 'Kaloor'],
  isReturn: false,
);

ServiceEntity service(
  String id, {
  int departure = 480,
  List<String> off = const [],
  String bus = 'Test bus',
}) => ServiceEntity(
  id: id,
  ownerId: 'owner',
  businessId: 'business',
  routeId: 'route',
  businessName: 'Test operator',
  routeName: 'Aluva - Kaloor',
  busName: bus,
  stops: const ['Aluva', 'Kalamassery', 'Kaloor'],
  departureMinutes: departure,
  stopTimings: {
    'Aluva': departure,
    'Kalamassery': departure + 15,
    'Kaloor': departure + 30,
  },
  offDays: off,
);

class FakeAuthRepository implements AuthRepository {
  AuthUser? user;
  int signIns = 0, registrations = 0;
  final changes = StreamController<AuthUser?>.broadcast();
  FakeAuthRepository({this.user});
  @override
  AuthUser? get currentUser => user;
  @override
  Stream<AuthUser?> get authStateChanges async* {
    yield user;
    yield* changes.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    signIns++;
    user = AuthUser(id: 'owner', email: email);
    changes.add(user);
  }

  @override
  Future<void> register(String email, String password) async {
    registrations++;
    await signIn(email, password);
  }

  @override
  Future<void> signOut() async {
    user = null;
    changes.add(null);
  }
}

class FakeTransitRepository implements TransitRepository {
  final List<ServiceEntity> services;
  int publishedRequests = 0, cancellations = 0, writes = 0;
  Stream<List<ServiceEntity>>? publishedOverride;
  final List<Map<String, Object?>> routeWrites = [];
  Map<String, int>? savedTimings;
  bool updated = false;
  String? lastBusinessOwner;
  FakeTransitRepository({this.services = const []});

  @override
  Stream<List<ServiceEntity>> getPublishedServices() {
    publishedRequests++;
    return publishedOverride ?? Stream.value(services);
  }

  @override
  Stream<List<BusinessEntity>> getOwnerBusinesses(String ownerId) {
    lastBusinessOwner = ownerId;
    return Stream.value([
      BusinessEntity(id: 'business', ownerId: ownerId, name: 'Test operator'),
    ]);
  }

  @override
  Stream<List<RouteEntity>> getBusinessRoutes(String businessId) =>
      Stream.value([route]);
  @override
  Stream<List<ServiceEntity>> getOwnerServices(String ownerId) =>
      Stream.value(services);
  @override
  Future<String> createBusiness({
    required String ownerId,
    required String name,
  }) async {
    writes++;
    return 'new-business';
  }

  @override
  Future<void> updateBusiness({
    required String businessId,
    required String ownerId,
    required String name,
  }) async {
    writes++;
  }

  @override
  Future<String> createRoute({
    required String ownerId,
    required String businessId,
    required String businessName,
    required String name,
    required String startStop,
    required String endStop,
    required List<String> stops,
    bool isReturn = false,
    String? returnOfRouteId,
  }) async {
    routeWrites.add({
      'name': name,
      'stops': stops,
      'isReturn': isReturn,
      'returnOfRouteId': returnOfRouteId,
    });
    return 'created-route';
  }

  @override
  Future<void> updateRoute({
    required String routeId,
    required String ownerId,
    required String name,
    required String startStop,
    required String endStop,
    required List<String> stops,
  }) async {
    writes++;
  }

  @override
  Future<void> deleteRoute(String routeId) async {
    writes++;
  }

  @override
  Future<void> deleteService(String serviceId) async {
    writes++;
  }

  @override
  Future<void> publishService({
    required String ownerId,
    required String businessId,
    required String routeId,
    required String businessName,
    required String routeName,
    required String busName,
    required List<String> stops,
    required int departureMinutes,
    required Map<String, int> stopTimings,
    required List<String> offDays,
    required String offTimingsNote,
  }) async {
    writes++;
    savedTimings = stopTimings;
  }

  @override
  Future<void> updateService({
    required String serviceId,
    required String ownerId,
    required String businessId,
    required String routeId,
    required String businessName,
    required String routeName,
    required String busName,
    required List<String> stops,
    required int departureMinutes,
    required Map<String, int> stopTimings,
    required List<String> offDays,
    required String offTimingsNote,
  }) async {
    writes++;
    updated = true;
    savedTimings = stopTimings;
  }
}
