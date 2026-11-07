import 'package:kerala_bus_connect/core/providers/clock_provider.dart';
import 'package:kerala_bus_connect/features/passenger/presentation/widgets/search_panel.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/core/theme/app_theme.dart';
import 'package:kerala_bus_connect/features/places/domain/entities/place_prediction.dart';
import 'package:kerala_bus_connect/features/places/domain/repositories/places_repository.dart';
import 'package:kerala_bus_connect/features/places/domain/services/stop_labels.dart';
import 'package:kerala_bus_connect/features/places/presentation/providers/places_providers.dart';
import 'package:kerala_bus_connect/features/places/presentation/widgets/place_text_field.dart';

class WidgetPlaces implements PlacesRepository {
  final bool fail;
  int calls = 0;
  WidgetPlaces({this.fail = false});
  @override
  Future<List<PlacePrediction>> suggest(String input) async {
    calls++;
    if (fail) throw StateError('offline');
    return const [
      PlacePrediction(
        id: 'p',
        name: 'Edappally',
        address: 'Kochi, Ernakulam district, Kerala, India',
      ),
    ];
  }
}

Widget placesHarness(
  TextEditingController text,
  PlacesRepository repo, {
  ValueChanged<String>? onChanged,
  double textScale = 1,
  Widget? child,
}) => ProviderScope(
  overrides: [
    clockProvider.overrideWithValue(AsyncData(DateTime(2026, 11, 7, 8))),
    googlePlacesEnabledProvider.overrideWithValue(true),
    placesRepositoryProvider.overrideWithValue(repo),
    stopLabelsProvider.overrideWithValue(StopLabels(['Aluva', 'Kaloor'])),
  ],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child ?? PlaceTextField(
            fieldKey: const ValueKey('place-input'),
            controller: text,
            onChanged: onChanged,
            decoration: const InputDecoration(labelText: 'Starting stop'),
          ),
        ),
      ),
    ),
  ),
);

class PendingPlaces implements PlacesRepository {
  final requests = <String, Completer<List<PlacePrediction>>>{};
  @override
  Future<List<PlacePrediction>> suggest(String input) =>
      (requests[input] = Completer<List<PlacePrediction>>()).future;
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('home loading and full-row suggestions fit $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.reset);
      final unused = TextEditingController();
      addTearDown(unused.dispose);
      final repo = PendingPlaces();
      await tester.pumpWidget(placesHarness(unused, repo, child: const SearchPanel()));
      await tester.enterText(find.byKey(const ValueKey('search-from')), 'Eda');
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      repo.requests['Eda']!.complete(const [PlacePrediction(id: 'p', name: 'Edappally')]);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const ValueKey('place-option-1'))).width, greaterThan(200));
      await tester.tap(find.text('Edappally'));
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(const ValueKey('search-from'))).controller!.text, 'Edappally');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('submit while loading never selects the previous query', (
    tester,
  ) async {
    final text = TextEditingController();
    addTearDown(text.dispose);
    final repo = PendingPlaces();
    await tester.pumpWidget(placesHarness(text, repo));
    await tester.enterText(find.byKey(const ValueKey('place-input')), 'Eda');
    await tester.pump(const Duration(milliseconds: 400));
    repo.requests['Eda']!.complete(const [
      PlacePrediction(id: 'p', name: 'Edappally'),
    ]);
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.enterText(find.byKey(const ValueKey('place-input')), 'Kala');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(text.text, 'Kala');
    repo.requests['Kala']!.complete(const [
      PlacePrediction(id: 'k', name: 'Kalamassery'),
    ]);
    await tester.pump();
    expect(text.text, 'Kala');
  });
  testWidgets('unfocused edits and composing input do not call Google', (
    tester,
  ) async {
    final text = TextEditingController(text: 'Aluva');
    addTearDown(text.dispose);
    final repo = WidgetPlaces();
    await tester.pumpWidget(placesHarness(text, repo));
    text.text = 'Kaloor';
    await tester.pump(const Duration(seconds: 1));
    expect(repo.calls, 0);
    await tester.enterText(find.byKey(const ValueKey('place-input')), 'Eda');
    await tester.pump(const Duration(milliseconds: 100));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Edap',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 0, end: 4),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(repo.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'touch selection sends the short name and keeps the editable field',
    (tester) async {
      final text = TextEditingController();
      addTearDown(text.dispose);
      String? selected;
      await tester.pumpWidget(
        placesHarness(text, WidgetPlaces(), onChanged: (v) => selected = v),
      );
      await tester.enterText(find.byKey(const ValueKey('place-input')), 'Eda');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Google Maps'), findsOneWidget);
      await tester.tap(find.text('Edappally'));
      await tester.pump();
      expect(text.text, 'Edappally');
      expect(selected, 'Edappally');
      await tester.enterText(
        find.byKey(const ValueKey('place-input')),
        'Owner entered stop',
      );
      expect(text.text, 'Owner entered stop');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );
  testWidgets(
    'keyboard selects suggestions without changing unrelated fields',
    (tester) async {
      final text = TextEditingController();
      addTearDown(text.dispose);
      await tester.pumpWidget(placesHarness(text, WidgetPlaces()));
      await tester.enterText(find.byKey(const ValueKey('place-input')), 'Eda');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('place-option-1')))
            .selected,
        isTrue,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(text.text, 'Edappally');
    },
  );
  testWidgets(
    'unavailable Google still permits manual entry and timetable stops',
    (tester) async {
      final text = TextEditingController();
      addTearDown(text.dispose);
      await tester.pumpWidget(placesHarness(text, WidgetPlaces(fail: true)));
      await tester.enterText(find.byKey(const ValueKey('place-input')), 'Alu');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Aluva'), findsOneWidget);
      expect(find.textContaining('Google places unavailable'), findsOneWidget);
      await tester.tap(find.text('Aluva'));
      await tester.pump();
      expect(text.text, 'Aluva');
    },
  );
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('place suggestions fit $width with keyboard and long text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      final text = TextEditingController();
      addTearDown(text.dispose);
      await tester.pumpWidget(
        placesHarness(text, WidgetPlaces(), textScale: 1.6),
      );
      await tester.enterText(find.byKey(const ValueKey('place-input')), 'Eda');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Edappally'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
