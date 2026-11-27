import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/core/widgets/shimmer_loading.dart';
import 'package:kerala_bus_connect/core/widgets/loading_skeletons.dart';

Widget shimmerHarness(
  Widget child, {
  bool reduced = false,
  bool ticking = true,
  Brightness brightness = Brightness.light,
}) => ProviderScope(
  child: MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: brightness,
      ),
    ),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: TickerMode(
          enabled: ticking,
          child: Scaffold(body: child),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'quick loading region cancels its delay without a flash or ticker',
    (tester) async {
      await tester.pumpWidget(
        shimmerHarness(
          const AppShimmer(child: SkeletonBox(width: 160, height: 24)),
        ),
      );
      expect(
        tester
            .widget<Opacity>(
              find.descendant(
                of: find.byType(AppShimmer),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        0,
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'animation stops in background, reduced motion and disabled ticker mode',
    (tester) async {
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
    },
  );

  testWidgets('offscreen shimmer stops and restarts when scrolled into view', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      shimmerHarness(
        SingleChildScrollView(
          controller: scroll,
          child: const Column(
            children: [
              AppShimmer(child: SkeletonBox(width: 200, height: 100)),
              SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
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

  testWidgets(
    'skeleton semantics expose one announcement and hide decoration',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        shimmerHarness(
          const AppShimmer(
            label: 'Loading bus results',
            child: Column(
              children: [
                Text('Decorative placeholder'),
                SkeletonBox(width: 200, height: 40),
              ],
            ),
          ),
          reduced: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.bySemanticsLabel('Loading bus results'), findsOneWidget);
      expect(find.bySemanticsLabel('Decorative placeholder'), findsNothing);
      semantics.dispose();
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('all skeleton layouts fit narrow large-text $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final layout in SkeletonLayout.values) {
        await tester.pumpWidget(
          shimmerHarness(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: SingleChildScrollView(
                  child: AppShimmer(child: SkeletonCard(layout: layout)),
                ),
              ),
            ),
            reduced: true,
            brightness: brightness,
          ),
        );
        await tester.pump(const Duration(milliseconds: 150));
        expect(tester.takeException(), isNull, reason: layout.name);
      }
      await tester.pumpWidget(
        shimmerHarness(
          const SponsorSkeleton(),
          reduced: true,
          brightness: brightness,
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
