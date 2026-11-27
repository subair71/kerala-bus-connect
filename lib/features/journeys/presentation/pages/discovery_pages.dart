import '../../../timetables/domain/entities/service_entity.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../app/navigation_provider.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../passenger/presentation/providers/search_providers.dart';
import '../../../passenger/presentation/providers/paged_search_provider.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../../platform/presentation/providers/platform_providers.dart';
import '../../../places/presentation/providers/nearby_providers.dart';
import '../../../trips/domain/entities/trip_plan.dart';
import '../../domain/journey_filters.dart';
import '../widgets/stop_map.dart';
import '../widgets/journey_controls.dart';
import '../providers/journey_providers.dart';
import 'trip_pages.dart';

class BoardStop extends Notifier<String> {
  @override
  String build() => 'Aluva';
  void select(String value) => state = value;
}

final boardStopProvider = NotifierProvider<BoardStop, String>(BoardStop.new);
void showBoard(BuildContext context, WidgetRef ref, String stop) {
  ref.read(boardStopProvider.notifier).select(stop);
  Navigator.of(context).popUntil((r) => r.isFirst);
  ref.read(navigationProvider.notifier).select(AppTab.departures);
}

void openScreen(BuildContext context, String title, Widget content) =>
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(child: content),
        ),
      ),
    );

class NearbyPage extends ConsumerWidget {
  const NearbyPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(platformEnabledProvider);
    final nearby = enabled ? ref.watch(nearbyStopsProvider) : null;
    final known = nearby?.asData?.value;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StopMap(
          stops: known?.stops.take(3).map((s) => s.name).toList() ?? const [],
          onStop: (s) => showBoard(context, ref, s),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Nearby stops'),
          subtitle: Text(
            known?.message ?? 'Choose a boarding stop to see departures.',
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final s = await chooseStop(context);
            if (s != null && context.mounted) showBoard(context, ref, s);
          },
          icon: const Icon(Icons.search),
          label: const Text('Search a stop manually'),
        ),
        if (enabled)
          OutlinedButton.icon(
            onPressed: () => ref.read(nearbyStopsProvider.notifier).refresh(),
            icon: const Icon(Icons.my_location),
            label: const Text('Refresh nearby stops'),
          ),
        if (nearby?.isLoading == true) const LinearProgressIndicator(),
        if (!enabled ||
            nearby?.hasError == true ||
            (known != null && known.stops.isEmpty))
          const Text('Nearby location unavailable. Choose a stop by name.'),
        if (known != null)
          for (final s in known.stops)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(s.name),
              trailing: Text('${s.distanceKm.toStringAsFixed(1)} km'),
              onTap: () => showBoard(context, ref, s.name),
            ),
      ],
    );
  }
}

class DeparturesPage extends ConsumerWidget {
  const DeparturesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stop = ref.watch(boardStopProvider);
    final DateTime date =
        ref.watch(searchQueryProvider.select((q) => q.serviceDate)) ??
        ref.watch(journeyTodayProvider);
    final q = (
      from: stop,
      to: '',
      date: serviceDateKey(date),
      directory: false,
    );
    final feed = ref.watch(journeyFeedProvider(q));
    final now = ref.watch(clockProvider).asData?.value ?? keralaNow();
    final cutoff = serviceDateKey(now) == q.date
        ? now.hour * 60 + now.minute
        : 0;
    return ListView(
      children: [
        StopMap(
          stops: [stop],
          onLocate: () =>
              openScreen(context, 'Nearby stops', const NearbyPage()),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(stop, style: Theme.of(context).textTheme.headlineSmall),
              Wrap(
                spacing: 6,
                children: [
                  TextButton(
                    onPressed: () async {
                      final result = await chooseStop(context);
                      if (result != null && context.mounted)
                        ref.read(boardStopProvider.notifier).select(result);
                    },
                    child: const Text('Change stop'),
                  ),
                  TextButton(
                    onPressed: () => openJourneyTime(context, ref),
                    child: Text(q.date),
                  ),
                ],
              ),
              const Text(
                'Upcoming buses',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              feed.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => TextButton(
                  onPressed: () => retryFeed(ref, q),
                  child: const Text('Unable to load departures · Retry'),
                ),
                data: (data) {
                  final rows = data.rows.where((s) {
                    final board = stopMatch(s, stop, false);
                    final t = s.expectedTime(board);
                    return board.isNotEmpty &&
                        board != s.stops.lastOrNull &&
                        t != null &&
                        t >= cutoff;
                  }).toList();
                  return Column(
                    children: [
                      if (data.sample)
                        const Text(
                          'Sample timetable · not for travel planning.',
                        ),
                      if (data.updatesMissing)
                        TextButton(
                          onPressed: () => retryFeed(ref, q),
                          child: const Text(
                            'Daily updates unavailable · Retry',
                          ),
                        ),
                      if (rows.isEmpty)
                        const ListTile(
                          title: Text('No upcoming departures'),
                          subtitle: Text(
                            'Change the stop or choose another service date.',
                          ),
                        ),
                      for (final s in rows)
                        ListTile(
                          leading: const Icon(Icons.directions_bus_outlined),
                          title: Text(
                            '${clock24(s.expectedTime(stopMatch(s, stop, false)))}  ·  ${s.stops.lastOrNull ?? 'Destination unavailable'}',
                          ),
                          subtitle: Text(
                            '${s.busName} · ${s.runningStatus.label}',
                          ),
                          onTap: () => openTrip(
                            context,
                            s,
                            from: stop,
                            to: '',
                            date: date,
                          ),
                        ),
                      if (data.more)
                        TextButton(
                          onPressed: () => ref
                              .read(pagedDeparturesProvider(q).notifier)
                              .next(),
                          child: const Text('Load more departures'),
                        ),
                    ],
                  );
                },
              ),
              SaveButton(SavedJourney('stop', stop, from: stop)),
            ],
          ),
        ),
      ],
    );
  }
}

void retryFeed(WidgetRef ref, DepartureQuery q) {
  ref.invalidate(journeyUpdatesProvider);
  if (ref.read(passengerPagingEnabledProvider))
    ref.invalidate(pagedDeparturesProvider(q));
  else
    ref.invalidate(publishedServicesProvider);
}

class SavedPage extends ConsumerWidget {
  const SavedPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(journeyBookProvider);
    return book.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(journeyBookProvider),
          child: const Text('Unable to open saved items · Retry'),
        ),
      ),
      data: (data) {
        final rows = data.where((e) => e.kind != 'recent').toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Saved', style: Theme.of(context).textTheme.headlineSmall),
            const Text('On this device'),
            if (rows.isEmpty)
              const ListTile(
                leading: Icon(Icons.bookmark_outline),
                title: Text('No saved journeys yet'),
                subtitle: Text('Save a stop, route or trip to find it here.'),
              ),
            for (final item in rows)
              ListTile(
                leading: Icon(
                  item.kind == 'stop'
                      ? Icons.flag_outlined
                      : Icons.directions_bus_outlined,
                ),
                title: Text(item.name),
                subtitle: Text(item.kind),
                onTap: () {
                  if (item.kind == 'stop') {
                    showBoard(context, ref, item.from);
                    return;
                  }
                  openScreen(context, item.name, SavedServicePage(item));
                },
                trailing: IconButton(
                  tooltip: 'Remove from saved',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final controller = ref.read(journeyBookProvider.notifier);
                    try {
                      await controller.edit(item, remove: true);
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Removed from saved'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () => controller.edit(item).ignore(),
                            ),
                          ),
                        );
                    } catch (_) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Unable to remove this item.'),
                          ),
                        );
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class SavedServicePage extends ConsumerWidget {
  final SavedJourney item;
  const SavedServicePage(this.item, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime date =
        ref.watch(searchQueryProvider).serviceDate ??
        ref.watch(journeyTodayProvider);
    final q = (
      from: item.from,
      to: item.to,
      date: serviceDateKey(date),
      directory: item.kind == 'route',
    );
    if (item.sampleCatalogue) {
      final catalogue = ref.watch(sampleCatalogueProvider);
      return catalogue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(sampleCatalogueProvider),
            child: const Text('Unable to open sample timetable · Retry'),
          ),
        ),
        data: (data) {
          final service = data.records
              .where((r) => r.id == item.serviceId)
              .firstOrNull;
          if (service == null)
            return const Center(
              child: Text('This sample service is unavailable.'),
            );
          return ListTile(
            leading: const Icon(Icons.directions_bus_outlined),
            title: Text(service.busName),
            subtitle: Text('Sample timetable · ${service.routeName}'),
            onTap: () => openTrip(
              context,
              service,
              from: item.from,
              to: item.to,
              date: date,
              route: item.kind == 'route',
              sampleCatalogue: true,
            ),
          );
        },
      );
    }
    if (ref.watch(passengerPagingEnabledProvider)) {
      final key = (id: item.serviceId, date: q.date, regular: q.directory);
      return ref
          .watch(journeyTimetableProvider(key))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(journeyTimetableProvider(key)),
                child: const Text('Unable to open timetable · Retry'),
              ),
            ),
            data: (service) => service == null
                ? const Center(
                    child: Text('No published service for this date.'),
                  )
                : ListTile(
                    title: Text(service.busName),
                    subtitle: Text(service.routeName),
                    onTap: () => openTrip(
                      context,
                      service,
                      from: item.from,
                      to: item.to,
                      date: date,
                      route: q.directory,
                    ),
                  ),
          );
    }
    final result = ref.watch(journeyFeedProvider(q));
    return result.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: TextButton(
          onPressed: () => retryFeed(ref, q),
          child: const Text('Unable to load service · Retry'),
        ),
      ),
      data: (feed) {
        final s = feed.rows.where((r) => r.id == item.serviceId).firstOrNull;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextButton(
              onPressed: () => openJourneyTime(context, ref),
              child: Text(q.date),
            ),
            if (s != null)
              ListTile(
                leading: const Icon(Icons.directions_bus_outlined),
                title: Text(s.busName),
                subtitle: Text(s.routeName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openTrip(
                  context,
                  s,
                  from: item.from,
                  to: item.to,
                  date: date,
                  route: item.kind == 'route',
                ),
              )
            else
              const Text('No matching published service on this date.'),
            if (feed.more)
              TextButton(
                onPressed: () =>
                    ref.read(pagedDeparturesProvider(q).notifier).next(),
                child: const Text('Check more services'),
              ),
          ],
        );
      },
    );
  }
}

class UpdatesPage extends ConsumerWidget {
  const UpdatesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(searchQueryProvider);
    final DateTime date = search.serviceDate ?? ref.watch(journeyTodayProvider);
    final q = (
      from: search.from,
      to: search.to,
      date: serviceDateKey(date),
      directory: false,
    );
    final feed = ref.watch(journeyFeedProvider(q));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Service updates',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text('${search.from} → ${search.to} · ${q.date}'),
        const SizedBox(height: 12),
        feed.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () => retryFeed(ref, q),
            child: const Text('Updates unavailable · Retry'),
          ),
          data: (data) {
            final changes = data.rows.where(
              (s) =>
                  s.runningStatus != RunningStatus.scheduled ||
                  s.hasDailyAdjustment,
            );
            return Column(
              children: [
                if (data.updatesMissing)
                  TextButton(
                    onPressed: () => retryFeed(ref, q),
                    child: const Text('Daily updates unavailable · Retry'),
                  )
                else if (changes.isEmpty)
                  const ListTile(
                    title: Text('No reported changes for this journey.'),
                  ),
                for (final s in changes)
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(s.busName),
                    subtitle: Text('${s.runningStatus.label} · Owner reported'),
                    onTap: () => openTrip(
                      context,
                      s,
                      from: search.from,
                      to: search.to,
                      date: date,
                    ),
                  ),
                if (data.more)
                  TextButton(
                    onPressed: () =>
                        ref.read(pagedDeparturesProvider(q).notifier).next(),
                    child: const Text('Check more services'),
                  ),
              ],
            );
          },
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Travel advice'),
            subtitle: Text(
              'Timetable estimates are scheduled departures, not live GPS tracking. Traffic can affect actual arrival times.',
            ),
          ),
        ),
      ],
    );
  }
}

class SampleServicesPage extends ConsumerWidget {
  const SampleServicesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(sampleCatalogueProvider);
    final DateTime date = ref.watch(journeyTodayProvider);
    return items.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(sampleCatalogueProvider),
          child: const Text('Unable to load sample routes · Retry'),
        ),
      ),
      data: (d) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Sample routes',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            d.cloud ? 'Firebase sample catalogue' : 'Bundled sample catalogue',
          ),
          const Text('Illustrative services · not for travel planning.'),
          for (final s in d.records)
            ListTile(
              leading: const Icon(Icons.directions_bus_outlined),
              title: Text('${s.busName} · ${s.routeName}'),
              subtitle: Text(
                '${clock24(s.departureMinutes)} · ${s.stops.length} stops',
              ),
              onTap: () => openTrip(
                context,
                s,
                from: '',
                to: '',
                date: date,
                sampleCatalogue: true,
              ),
            ),
        ],
      ),
    );
  }
}

class MorePage extends ConsumerWidget {
  const MorePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(AppTab t) => ref.read(navigationProvider.notifier).select(t);
    Widget link(IconData icon, String t, String sub, VoidCallback action) =>
        Semantics(
          identifier: 'more-${t.toLowerCase().replaceAll(" ", "-")}',
          child: ListTile(
            leading: Icon(icon),
            title: Text(t),
            subtitle: Text(sub),
            trailing: const Icon(Icons.chevron_right),
            onTap: action,
          ),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('More', style: Theme.of(context).textTheme.headlineSmall),
          const ListTile(title: Text('Passenger tools')),
          link(
            Icons.near_me_outlined,
            'Nearby stops',
            'Find a boarding stop',
            () => openScreen(context, 'Nearby stops', const NearbyPage()),
          ),
          link(
            Icons.map_outlined,
            'Route position preview',
            'Reported stop on a route',
            () => select(AppTab.tracking),
          ),
          link(
            Icons.notifications_none,
            'Service updates',
            'Owner changes and travel advice',
            () => openScreen(context, 'Service updates', const UpdatesPage()),
          ),
          link(
            Icons.directions_bus_outlined,
            'Sample routes',
            'Explore illustrative timetables',
            () => openScreen(
              context,
              'Sample routes',
              const SampleServicesPage(),
            ),
          ),
          const Divider(),
          const ListTile(title: Text('Operator workspace')),
          link(
            Icons.business_center_outlined,
            'Owner account',
            'Buses, trips and daily timings',
            () => select(AppTab.owner),
          ),
          link(
            Icons.badge_outlined,
            'Crew duty roster',
            'Assignments and shifts',
            () => select(AppTab.crew),
          ),
        ],
      ),
    );
  }
}
