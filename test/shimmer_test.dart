import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/core/widgets/shimmer_loading.dart';
import 'package:kerala_bus_connect/core/widgets/loading_skeletons.dart';
import 'package:kerala_bus_connect/core/providers/sample_fallback.dart';
import 'package:kerala_bus_connect/features/auth/presentation/widgets/auth_panel.dart';
import 'package:kerala_bus_connect/features/auth/presentation/providers/auth_providers.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/widgets/departure_results.dart';
import 'package:kerala_bus_connect/features/timetables/domain/entities/service_entity.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/providers/timetable_providers.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/widgets/service_card.dart';
import 'support/fakes.dart';
import 'widgets_test.dart' show harness;

Widget shimmerHarness(Widget child, {bool reduced = false, bool ticking = true,
    Brightness brightness = Brightness.light}) => ProviderScope(
  child: MaterialApp(
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green,
      brightness: brightness)),
    home: Builder(builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: TickerMode(enabled: ticking, child: Scaffold(body: child)),
    )),
  ),
);

class SlowAuth extends FakeAuthRepository {
  final pending = Completer<void>();
  @override
  Future<void> signIn(String email, String password) async {
    signIns++;
    await pending.future;
  }
}

void main() {
  testWidgets('quick loading region cancels its delay without a flash or ticker', (tester) async {
    await tester.pumpWidget(shimmerHarness(
      const AppShimmer(child: SkeletonBox(width: 160, height: 24))));
    expect(tester.widget<Opacity>(find.descendant(of: find.byType(AppShimmer),
      matching: find.byType(Opacity))).opacity, 0);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('animation stops in background, reduced motion and disabled ticker mode', (tester) async {
    const shape = AppShimmer(child: SkeletonBox(width: 200, height: 40));
    await tester.pumpWidget(shimmerHarness(shape));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(shimmerHarness(shape, reduced: true));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(shimmerHarness(shape, ticking: false));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('offscreen shimmer stops and restarts when scrolled into view', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(shimmerHarness(SingleChildScrollView(
      controller: scroll,
      child: const Column(children: [
        AppShimmer(child: SkeletonBox(width: 200, height: 100)),
        SizedBox(height: 2000),
      ]),
    )));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    scroll.jumpTo(1000);
    await tester.pump();
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    scroll.jumpTo(0);
    await tester.pump();
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('skeleton semantics expose one announcement and hide decoration', (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pumpWidget(shimmerHarness(
      const AppShimmer(label: 'Loading bus results',
        child: Column(children: [Text('Decorative placeholder'),
          SkeletonBox(width: 200, height: 40)])), reduced: true));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.bySemanticsLabel('Loading bus results'), findsOneWidget);
    expect(find.bySemanticsLabel('Decorative placeholder'), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('all skeleton layouts fit narrow large-text $brightness', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final layout in SkeletonLayout.values) {
        await tester.pumpWidget(shimmerHarness(
          Builder(builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
            child: SingleChildScrollView(child: AppShimmer(
              child: SkeletonCard(layout: layout))),
          )), reduced: true, brightness: brightness));
        await tester.pump(const Duration(milliseconds: 150));
        expect(tester.takeException(), isNull, reason: layout.name);
      }
      await tester.pumpWidget(shimmerHarness(const SponsorSkeleton(),
        reduced: true, brightness: brightness));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('refresh keeps records and reload does not reveal a previous source', () {
    const prior = AsyncData<List<int>>([7]);
    final refresh = const AsyncLoading<List<int>>().copyWithPrevious(prior);
    expect(sampleFallback(refresh, [1]).requireValue.records, [7]);
    final reload = const AsyncLoading<List<int>>().copyWithPrevious(prior, isRefresh: false);
    expect(sampleFallback(reload, [1]).isLoading, isTrue);
  });

  testWidgets('refresh preserves bus cards, scroll position and request count', (tester) async {
    final auth = FakeAuthRepository();
    final stream = StreamController<List<ServiceEntity>>.broadcast();
    final repository = FakeTransitRepository()..publishedOverride = stream.stream;
    addTearDown(auth.changes.close);
    addTearDown(stream.close);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(harness(Scaffold(
      body: CustomScrollView(controller: scroll, slivers: const [DeparturesSliver()])),
      repository, auth));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(LoadingSliver), findsOneWidget);
    stream.add(List.generate(8, (i) => service('bus-$i')));
    await tester.pumpAndSettle();
    scroll.jumpTo(200);
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(DeparturesSliver)));
    container.invalidate(publishedServicesProvider);
    await tester.pump();
    expect(find.byType(LoadingSliver), findsNothing);
    expect(find.byType(ServiceCard), findsWidgets);
    expect(scroll.offset, 200);
    expect(repository.publishedRequests, 2);
    stream.add(List.generate(8, (i) => service('bus-$i')));
    await tester.pumpAndSettle();
    expect(scroll.offset, 200);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sign-in keeps input and label, blocks repeats, restores after failure', (tester) async {
    final auth = SlowAuth();
    addTearDown(auth.changes.close);
    await tester.pumpWidget(harness(const Scaffold(body: AuthPanel()),
      FakeTransitRepository(), auth));
    await tester.enterText(find.byKey(const ValueKey('auth-email')), 'owner@example.com');
    await tester.enterText(find.byKey(const ValueKey('auth-password')), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    final container = ProviderScope.containerOf(tester.element(find.byType(AuthPanel)));
    unawaited(container.read(authActionProvider.notifier).submit(
      'owner@example.com', 'password123', register: false));
    expect(auth.signIns, 1);
    expect(find.byType(AppShimmer), findsOneWidget);
    auth.pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShimmer), findsNothing);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('auth-email'))).controller!.text,
      'owner@example.com');
  });
}
