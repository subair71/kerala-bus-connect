import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/features/sponsors/domain/entities/sponsored_ad.dart';
import 'package:kerala_bus_connect/features/sponsors/domain/repositories/sponsor_repository.dart';
import 'package:kerala_bus_connect/features/sponsors/presentation/providers/sponsor_providers.dart';
import 'package:kerala_bus_connect/features/sponsors/presentation/widgets/sponsored_carousel.dart';
import 'support/fakes.dart';

Widget carouselHarness(
  Stream<List<SponsoredAd>> stream, {
  bool reduceMotion = false,
}) => ProviderScope(
  overrides: [
    sponsorLocationProvider.overrideWithValue('Aluva'),
    liveSponsorsProvider.overrideWith((ref, location) => stream),
  ],
  child: MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const Scaffold(
        body: Column(children: [SponsoredCarousel(), Text('Search buses')]),
      ),
    ),
  ),
);

int currentPage(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(SponsoredCarousel)),
).read(sponsorPageProvider('Aluva'));

class TestSponsorRepository implements SponsorRepository {
  final StreamController<List<SponsoredAd>> changes;
  int watches = 0;
  TestSponsorRepository(this.changes);
  @override
  Stream<List<SponsoredAd>> watch(String location) {
    watches++;
    return changes.stream;
  }
}

void main() {
  testWidgets('pending, empty and failed ads use no space; live ads recover', (
    tester,
  ) async {
    final stream = StreamController<List<SponsoredAd>>();
    addTearDown(stream.close);
    await tester.pumpWidget(carouselHarness(stream.stream));
    await tester.pump(const Duration(seconds: 30));
    void expectHidden() {
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Local sponsors near'), findsNothing);
      expect(tester.getSize(find.byType(SponsoredCarousel)).height, 0);
      expect(find.text('Search buses'), findsOneWidget);
    }

    expectHidden();
    stream.add([]);
    await tester.pumpAndSettle();
    expectHidden();
    stream.addError(StateError('unavailable'));
    await tester.pumpAndSettle();
    expectHidden();
    stream.add([
      sponsor('inactive', active: false),
      sponsor('other', location: 'Kaloor'),
    ]);
    await tester.pumpAndSettle();
    expectHidden();
    stream.add([sponsor('live')]);
    await tester.pumpAndSettle();
    expect(find.text('Offer live'), findsOneWidget);
    expect(find.text('Sample advertisement'), findsNothing);
    stream.add([]);
    await tester.pumpAndSettle();
    expectHidden();
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiple ads rotate every five seconds and wrap', (
    tester,
  ) async {
    await tester.pumpWidget(
      carouselHarness(Stream.value([sponsor('first'), sponsor('second')])),
    );
    await tester.pumpAndSettle();
    expect(currentPage(tester), 0);
    await tester.pump(const Duration(seconds: 4));
    expect(currentPage(tester), 0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(currentPage(tester), 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(currentPage(tester), 0);
    await tester.tap(find.byTooltip('Next sponsor'));
    await tester.pumpAndSettle();
    expect(currentPage(tester), 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rotation pauses in background and resumes without leaking timers',
    (tester) async {
      await tester.pumpWidget(
        carouselHarness(Stream.value([sponsor('first'), sponsor('second')])),
      );
      await tester.pumpAndSettle();
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(const Duration(seconds: 15));
      expect(currentPage(tester), 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(currentPage(tester), 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 15));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'one ad stays still and reduced motion disables automatic rotation',
    (tester) async {
      await tester.pumpWidget(carouselHarness(Stream.value([sponsor('only')])));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Next sponsor'), findsNothing);
      expect(find.byTooltip('Previous sponsor'), findsNothing);
      await tester.pump(const Duration(seconds: 15));
      expect(currentPage(tester), 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        carouselHarness(
          Stream.value([sponsor('first'), sponsor('second')]),
          reduceMotion: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 15));
      expect(currentPage(tester), 0);
      await tester.tap(find.byTooltip('Next sponsor'));
      await tester.pumpAndSettle();
      expect(currentPage(tester), 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'sponsor listeners share a query, recover, and release idle resources',
    () async {
      var cancellations = 0;
      final stream = StreamController<List<SponsoredAd>>.broadcast(
        onCancel: () => cancellations++,
      );
      final repository = TestSponsorRepository(stream);
      final container = ProviderContainer(
        overrides: [
          sponsorRepositoryProvider.overrideWithValue(repository),
          sponsorLocationProvider.overrideWithValue('Aluva'),
          sponsorCacheDurationProvider.overrideWithValue(
            const Duration(milliseconds: 20),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await stream.close();
      });
      final first = container.listen(sponsorsProvider, (_, _) {});
      final second = container.listen(liveSponsorsProvider('Aluva'), (_, _) {});
      expect(repository.watches, 1);
      stream.add([]);
      await container.read(liveSponsorsProvider('Aluva').future);
      expect(container.read(sponsorsProvider).requireValue.records, isEmpty);
      stream.addError(StateError('permission-denied'));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(container.read(sponsorsProvider).hasError, isTrue);
      expect(repository.watches, 1);
      stream.add([sponsor('real')]);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(sponsorsProvider).requireValue.records.single.id,
        'real',
      );
      expect(container.read(sponsorsProvider).requireValue.isDemo, isFalse);
      first.close();
      await container.pump();
      expect(cancellations, 0);
      second.close();
      await container.pump();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await container.pump();
      expect(cancellations, 1);
    },
  );
}
