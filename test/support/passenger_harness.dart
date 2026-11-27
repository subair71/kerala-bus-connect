import 'package:kerala_bus_connect/features/trips/presentation/providers/trip_providers.dart';
import 'package:kerala_bus_connect/core/data/data_set.dart';
import 'package:kerala_bus_connect/features/sponsors/data/fixtures/sponsor_samples.dart';
import 'package:kerala_bus_connect/features/sponsors/domain/entities/sponsored_ad.dart';
import 'package:kerala_bus_connect/core/theme/app_theme.dart';
import 'package:kerala_bus_connect/features/sponsors/presentation/providers/sponsor_providers.dart';
import 'package:kerala_bus_connect/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:kerala_bus_connect/features/crew/presentation/providers/crew_providers.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kerala_bus_connect/core/providers/clock_provider.dart';
import 'package:kerala_bus_connect/features/auth/presentation/providers/auth_providers.dart';
import 'package:kerala_bus_connect/features/timetables/presentation/providers/timetable_providers.dart';
import 'fakes.dart';

Widget harness(
  Widget child,
  FakeTransitRepository repository,
  FakeAuthRepository auth, {
  Stream<List<SponsoredAd>>? sponsorStream,
  bool sampleSponsors = false,
  TextScaler? textScaler,
}) => ProviderScope(
  overrides: [
    ownerBusesProvider.overrideWith((ref, businessId) => Stream.value([])),
    sponsorRotationIntervalProvider.overrideWithValue(Duration.zero),
    if (!sampleSponsors && sponsorStream == null)
      sponsorsProvider.overrideWith(
        (ref) => AsyncData(DataSet<SponsoredAd>([])),
      ),
    if (sampleSponsors)
      sponsorsProvider.overrideWith(
        (ref) => AsyncData(
          DataSet(
            sponsorSamples(ref.watch(sponsorLocationProvider)),
            isDemo: true,
          ),
        ),
      ),
    liveSponsorsProvider.overrideWith(
      (ref, location) => sponsorStream ?? Stream.value([]),
    ),
    liveTrackingProvider.overrideWith((ref) => Stream.value([])),
    liveCrewProvider.overrideWith((ref) => Stream.value([])),
    transitRepositoryProvider.overrideWithValue(repository),
    authRepositoryProvider.overrideWithValue(auth),
    catalogCacheDurationProvider.overrideWithValue(Duration.zero),
    clockProvider.overrideWithValue(AsyncData(DateTime(2026, 11, 6, 8))),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    builder: textScaler == null
        ? null
        : (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
    home: child,
  ),
);
