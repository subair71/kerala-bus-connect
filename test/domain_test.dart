import 'package:flutter_test/flutter_test.dart';
import 'package:kerala_bus_connect/core/errors/app_failure.dart';
import 'package:kerala_bus_connect/features/auth/domain/usecases/authenticate.dart';
import 'package:kerala_bus_connect/features/owner/domain/usecases/manage_transit.dart';
import 'package:kerala_bus_connect/features/passenger/domain/services/service_search_index.dart';
import 'support/fakes.dart';

void main() {
  test(
    'search preserves partial matches, direction, operating days and order',
    () {
      final index = ServiceSearchIndex([
        service('later', departure: 600),
        service('early', off: ['Monday']),
      ]);
      search(
        String from,
        String to, {
        String day = 'All Days',
        bool today = false,
      }) => index.search(
        from: from,
        to: to,
        filterDay: day,
        onlyRunningToday: today,
        today: 'Monday',
      );
      expect(search(' ALU ', 'kalo').map((s) => s.id), ['early', 'later']);
      expect(search('Kaloor', 'Aluva'), isEmpty);
      expect(search('Aluva', 'missing'), isEmpty);
      expect(search('', '', day: 'Monday').map((s) => s.id), ['later']);
      expect(search('', '', today: true).map((s) => s.id), ['later']);
      final list = index.directory('Kalamassery');
      expect(identical(list, index.directory(' KALAMASSERY ')), isTrue);
    },
  );

  test(
    'authentication validates input before contacting the repository',
    () async {
      final repository = FakeAuthRepository();
      addTearDown(repository.changes.close);
      final authenticate = Authenticate(repository);
      expect(
        () => authenticate(email: 'bad', password: '123456', register: false),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => authenticate(
          email: 'test@example.com',
          password: '123',
          register: true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(repository.signIns, 0);
      await authenticate(
        email: ' test@example.com ',
        password: '123456',
        register: false,
      );
      expect(repository.signIns, 1);
    },
  );

  test(
    'route creation preserves stop order and links the generated return',
    () async {
      final repository = FakeTransitRepository();
      await ManageTransit(repository).saveRoute(
        ownerId: 'owner',
        business: business,
        name: '',
        from: 'Aluva',
        to: 'Kaloor',
        intermediateStops: 'Kalamassery',
        returnRoute: true,
      );
      expect(repository.routeWrites, hasLength(2));
      expect(repository.routeWrites.first['stops'], [
        'Aluva',
        'Kalamassery',
        'Kaloor',
      ]);
      expect(repository.routeWrites.last['stops'], [
        'Kaloor',
        'Kalamassery',
        'Aluva',
      ]);
      expect(repository.routeWrites.last['returnOfRouteId'], 'created-route');
    },
  );

  test(
    'invalid routes cannot write and published routes cannot be orphaned',
    () async {
      final repository = FakeTransitRepository();
      final manage = ManageTransit(repository);
      await expectLater(
        manage.saveRoute(
          ownerId: 'owner',
          business: business,
          name: '',
          from: 'Aluva',
          to: 'Aluva',
          intermediateStops: '',
          returnRoute: false,
        ),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        manage.deleteRoute('route', [service('one')]),
        throwsA(isA<AppFailure>()),
      );
      expect(repository.writes, 0);
      expect(repository.routeWrites, isEmpty);
    },
  );

  test(
    'editing a timetable excludes itself from the duplicate check',
    () async {
      final repository = FakeTransitRepository();
      await ManageTransit(repository).saveService(
        ownerId: 'owner',
        business: business,
        route: route,
        busName: 'Test bus',
        departure: 480,
        timings: {'Kalamassery': 510, 'Kaloor': 530},
        offDays: {},
        note: '',
        existing: [service('same')],
        serviceId: 'same',
      );
      expect(repository.updated, isTrue);
    },
  );

  test(
    'same-bus clashes are rejected but different buses are allowed',
    () async {
      final repository = FakeTransitRepository();
      final manage = ManageTransit(repository);
      await expectLater(
        manage.saveService(
          ownerId: 'owner',
          business: business,
          route: route,
          busName: 'Test bus',
          departure: 490,
          timings: {'Kalamassery': 510, 'Kaloor': 530},
          offDays: {},
          note: '',
          existing: [service('one')],
        ),
        throwsA(isA<AppFailure>()),
      );
      await manage.saveService(
        ownerId: 'owner',
        business: business,
        route: route,
        busName: 'Another bus',
        departure: 490,
        timings: {'Kalamassery': 510, 'Kaloor': 530},
        offDays: {},
        note: '',
        existing: [service('one')],
      );
      expect(repository.writes, 1);
    },
  );

  test('overnight stop timings advance into the next day', () async {
    final repository = FakeTransitRepository();
    await ManageTransit(repository).saveService(
      ownerId: 'owner',
      business: business,
      route: route,
      busName: 'Night bus',
      departure: 1430,
      timings: {'Kalamassery': 5, 'Kaloor': 20},
      offDays: {},
      note: '',
      existing: [],
    );
    expect(repository.savedTimings, {
      'Aluva': 1430,
      'Kalamassery': 1445,
      'Kaloor': 1460,
    });
  });
}
