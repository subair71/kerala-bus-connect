import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerala_bus_connect/domain/entities/service_entity.dart';
import 'package:kerala_bus_connect/domain/repositories/transit_repository.dart';
import 'package:kerala_bus_connect/domain/services/service_search_index.dart';
import 'package:kerala_bus_connect/presentation/blocs/passenger/published_services_cubit.dart';
import 'package:kerala_bus_connect/presentation/blocs/passenger/search_cubit.dart';
import 'package:kerala_bus_connect/presentation/screens/passenger_search_screen.dart';
import 'package:kerala_bus_connect/presentation/screens/routes_directory_screen.dart';
import 'package:kerala_bus_connect/presentation/widgets/debounced_builder.dart';
import 'package:kerala_bus_connect/presentation/widgets/query_stream_builder.dart';

ServiceEntity service(String id, {int departure = 480, List<String> off = const []}) =>
    ServiceEntity(
      id: id,
      ownerId: 'owner',
      businessId: 'business',
      routeId: 'route',
      businessName: 'Test operator',
      routeName: 'Aluva - Kaloor',
      busName: 'Bus $id',
      stops: const ['Aluva', 'Kalamassery', 'Kaloor'],
      departureMinutes: departure,
      stopTimings: {'Aluva': departure, 'Kaloor': departure + 45},
      offDays: off,
    );

class FakeTransitRepository implements TransitRepository {
  int requests = 0;
  int cancellations = 0;
  late final controller = StreamController<List<ServiceEntity>>.broadcast(
    onCancel: () => cancellations++,
  );

  @override
  Stream<List<ServiceEntity>> getPublishedServices() {
    requests++;
    return controller.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> nextEvent() => Future<void>.delayed(Duration.zero);

void main() {
  test('indexed search preserves direction, partial matches, days and order', () {
    final index = ServiceSearchIndex([
      service('later', departure: 600),
      service('early', off: ['Monday']),
    ]);
    List<ServiceEntity> search(String from, String to,
            {String day = 'All Days', bool todayOnly = false}) =>
        index.search(
          from: from, to: to, filterDay: day,
          onlyRunningToday: todayOnly, today: 'Monday',
        );

    expect(search(' ALU ', 'kalo').map((s) => s.id), ['early', 'later']);
    expect(search('Kaloor', 'Aluva'), isEmpty);
    expect(search('Aluva', 'missing'), isEmpty);
    expect(search('Aluva', ''), hasLength(2));
    expect(search('', 'Kaloor'), hasLength(2));
    expect(search('', '', day: 'Monday').map((s) => s.id), ['later']);
    expect(search('', '', todayOnly: true).map((s) => s.id), ['later']);
    expect(index.directory('KALAMASSERY'), hasLength(2));
    expect(index.directory('unknown'), isEmpty);
  });

  test('rebuilds reuse search results and a new snapshot invalidates them', () {
    final index = ServiceSearchIndex([service('first')]);
    final first = index.directory('Aluva');
    expect(identical(first, index.directory(' ALUVA ')), isTrue);
    expect(ServiceSearchIndex([service('second')]).directory('Aluva').single.id,
        'second');
  });

  test('catalog shares a subscription, exposes errors, retries and cancels', () async {
    final repo = FakeTransitRepository();
    final cubit = PublishedServicesCubit(repo);
    final first = cubit.stream.listen((_) {});
    final second = cubit.stream.listen((_) {});
    await nextEvent();
    expect(repo.requests, 1);
    repo.controller.add([service('one')]);
    await nextEvent();
    expect(cubit.state.index!.directory(''), hasLength(1));

    repo.controller.addError(StateError('offline'));
    await nextEvent();
    expect(cubit.state.hasError, isTrue);
    expect(cubit.state.loading, isFalse);
    await cubit.reload();
    expect(repo.requests, 2);
    expect(repo.cancellations, 1);
    repo.controller.add([service('two')]);
    await nextEvent();
    expect(cubit.state.hasError, isFalse);
    expect(cubit.state.index!.directory('').single.id, 'two');
    await first.cancel();
    await second.cancel();
    await cubit.close();
    expect(repo.cancellations, 2);
    await repo.controller.close();
  });

  testWidgets('rapid input is coalesced and timers are disposed', (tester) async {
    Widget build(String value) => Directionality(
      textDirection: TextDirection.ltr,
      child: DebouncedBuilder<String>(
        value: value,
        builder: (_, accepted) => Text(accepted),
      ),
    );
    await tester.pumpWidget(build('a'));
    await tester.pumpWidget(build('al'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(build('alu'));
    await tester.pump(const Duration(milliseconds: 199));
    expect(find.text('a'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('alu'), findsOneWidget);
    await tester.pumpWidget(build('aluva'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner query rebuilds do not restart streams or retain another query',
      (tester) async {
    final first = StreamController<String>();
    final second = StreamController<String>();
    int creates = 0;
    Widget build(String identity) => Directionality(
      textDirection: TextDirection.ltr,
      child: QueryStreamBuilder<String>(
        identity: identity,
        createStream: () {
          creates++;
          return identity == 'first' ? first.stream : second.stream;
        },
        builder: (_, snapshot) => Text(snapshot.data ?? 'loading'),
      ),
    );
    await tester.pumpWidget(build('first'));
    first.add('first owner');
    await tester.pump();
    await tester.pumpWidget(build('first'));
    expect(creates, 1);
    expect(find.text('first owner'), findsOneWidget);
    await tester.pumpWidget(build('second'));
    expect(creates, 2);
    expect(find.text('first owner'), findsNothing);
    second.add('second owner');
    await tester.pump();
    expect(find.text('second owner'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(first.hasListener, isFalse);
    expect(second.hasListener, isFalse);
    await first.close();
    await second.close();
  });

  testWidgets('passenger input retains its field and large lists build lazily',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeTransitRepository();
    final catalog = PublishedServicesCubit(repo);
    final search = SearchCubit();
    Widget app(Widget screen) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: catalog),
        BlocProvider.value(value: search),
      ],
      child: MaterialApp(home: Scaffold(body: screen)),
    );
    await tester.pumpWidget(app(const PassengerSearchScreen()));
    repo.controller.add(List.generate(200, (i) => service('$i', departure: 480 + i)));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('search-from'));
    final controller = tester.widget<TextFormField>(field).controller;
    await tester.enterText(field, 'Alu');
    await tester.pump();
    expect(identical(controller, tester.widget<TextFormField>(field).controller),
        isTrue);
    expect(controller!.text, 'Alu');
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('200 buses'), findsOneWidget);
    expect(find.text('Bus 199'), findsNothing);
    expect(repo.requests, 1);

    search.swapFromAndTo();
    await tester.pump();
    expect(controller.text, 'Kaloor');
    await tester.pumpWidget(app(const RoutesDirectoryScreen()));
    await tester.pumpAndSettle();
    expect(repo.requests, 1);
    expect(find.text('Bus: Bus 199'), findsNothing);
    // Check the same screen at a common phone width.
    tester.view.physicalSize = const Size(390, 844);
    search.swapFromAndTo();
    await tester.pumpWidget(app(const PassengerSearchScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await catalog.close();
    await search.close();
    await repo.controller.close();
    expect(tester.takeException(), isNull);
  });
}
