import '../../../../app/navigation_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../domain/journey_filters.dart';
import '../providers/journey_providers.dart';
import '../widgets/journey_controls.dart';
import '../widgets/stop_map.dart';
import '../../../passenger/presentation/providers/search_providers.dart';
import '../../../timetables/domain/entities/service_entity.dart';
import '../../../timetables/presentation/widgets/stop_timings_sheet.dart';
import '../../../trips/domain/entities/trip_plan.dart';
import '../../../../core/constants/transit_constants.dart';
import '../../../../core/utils/sample_ids.dart';

void openTrip(
  BuildContext context,
  ServiceEntity service, {
  required String from,
  required String to,
  required DateTime date,
  bool route = false,
  bool sampleCatalogue = false,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TripPage(
        initial: service,
        from: from,
        to: to,
        date: date,
        route: route,
        sampleCatalogue: sampleCatalogue,
      ),
    ),
  );
}

class TripPage extends ConsumerWidget {
  final ServiceEntity initial;
  final String from, to;
  final DateTime date;
  final bool route, sampleCatalogue;
  const TripPage({
    super.key,
    required this.initial,
    required this.from,
    required this.to,
    required this.date,
    this.route = false,
    this.sampleCatalogue = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = sampleCatalogue
        ? null
        : ref.watch(
            journeyFeedProvider((
              from: from,
              to: to,
              date: serviceDateKey(date),
              directory: route,
            )),
          );
    final current = feed?.asData?.value;
    final match = current?.rows.where((s) => s.id == initial.id).firstOrNull;
    final missing = current != null && !current.more && match == null;
    if (missing) {
      return Scaffold(
        appBar: AppBar(title: Text(route ? 'Route timetable' : 'Trip details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '${initial.busName} is no longer available for this selection. Return to search to choose another service.',
            ),
          ),
        ),
      );
    }
    final s = match ?? initial;
    final a = stopMatch(s, from, false), b = stopMatch(s, to, true);
    final stamp = serviceDateKey(date);
    final expected = s.expectedTime(a), base = s.scheduledTime(a);
    final period = weekDays[date.weekday - 1];
    final item = SavedJourney(
      route ? 'route' : 'trip',
      '$a → $b',
      from: a,
      to: b,
      serviceId: s.id,
      sampleCatalogue: sampleCatalogue,
    );
    final reverse = route && !sampleCatalogue
        ? ref
              .watch(
                journeyFeedProvider((
                  from: b,
                  to: a,
                  date: stamp,
                  directory: false,
                )),
              )
              .asData
              ?.value
              .rows
              .firstOrNull
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(route ? 'Route timetable' : 'Trip details')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            StopMap(stops: s.stops),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('$stamp · ${s.busName}'),
                  const SizedBox(height: 5),
                  Text(
                    '$a → $b',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (isSampleId(s.id))
                    const Text('Sample timetable · not for travel planning.'),
                  if (current?.updatesMissing == true || feed?.hasError == true)
                    const Text(
                      'Daily updates unavailable. Check the regular timetable.',
                    ),
                  if (!route && s.runningStatus != RunningStatus.scheduled)
                    Text('${s.runningStatus.label} · owner reported'),
                  if (!route &&
                      expected != null &&
                      base != null &&
                      expected != base)
                    Text(
                      'Owner +${expected - base} min · scheduled ${clock24(base)}',
                    ),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.trip_origin,
                            color: Color(0xff176b5d),
                          ),
                          title: Text(a),
                          subtitle: const Text('Board here'),
                          trailing: Text(clock24(route ? base : expected)),
                        ),
                        ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(b),
                          subtitle: const Text('Alight here'),
                          trailing: Text(
                            clock24(
                              route ? s.scheduledTime(b) : s.expectedTime(b),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => showStopTimings(
                      context,
                      s,
                      from: a,
                      to: b,
                      day: period,
                    ),
                    child: Text('View all ${s.stops.length} stops'),
                  ),
                  SaveButton(item),
                  if (route) ...[
                    if (reverse != null)
                      OutlinedButton(
                        onPressed: () => openTrip(
                          context,
                          reverse,
                          from: b,
                          to: a,
                          date: date,
                          route: true,
                        ),
                        child: const Text('Open published return trip'),
                      ),
                    OutlinedButton(
                      onPressed: () {
                        final search = ref.read(searchQueryProvider.notifier);
                        search.from(a);
                        search.to(b);
                        ref.read(debouncedSearchProvider.notifier).flush();
                        Navigator.of(context).popUntil((r) => r.isFirst);
                        ref
                            .read(navigationProvider.notifier)
                            .select(AppTab.passenger);
                      },
                      child: const Text('Find buses on this route'),
                    ),
                  ],
                  if (!route &&
                      !sampleCatalogue &&
                      expected != null &&
                      s.runningStatus != RunningStatus.cancelled)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReminderPage(
                            service: s,
                            stop: a,
                            minutes: expected,
                            date: date,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.notifications_none),
                      label: const Text('Departure reminder'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final reminderLeadProvider = NotifierProvider.autoDispose<ReminderLead, int>(
  ReminderLead.new,
);

class ReminderLead extends Notifier<int> {
  @override
  int build() => 10;
  void select(int n) => state = n;
}

class ReminderPage extends HookConsumerWidget {
  final ServiceEntity service;
  final String stop;
  final int minutes;
  final DateTime date;
  const ReminderPage({
    super.key,
    required this.service,
    required this.stop,
    required this.minutes,
    required this.date,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lead = ref.watch(reminderLeadProvider);
    final busy = useRef(false);
    final boarding = boardingUtc(date, minutes);
    final alarm = boarding
        .subtract(Duration(minutes: lead))
        .add(const Duration(minutes: 330));
    return Scaffold(
      appBar: AppBar(title: const Text('Departure reminder')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('Remind me', style: Theme.of(context).textTheme.headlineSmall),
          ListTile(
            title: Text('${service.busName} · $stop'),
            subtitle: Text('Expected boarding ${clock24(minutes)} IST'),
          ),
          const Text('Before boarding'),
          Wrap(
            spacing: 6,
            children: [
              for (final n in [5, 10, 15, 30])
                ChoiceChip(
                  label: Text('$n min'),
                  selected: n == lead,
                  onSelected: (_) =>
                      ref.read(reminderLeadProvider.notifier).select(n),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: Text('${clock24(alarm.hour * 60 + alarm.minute)} IST'),
              subtitle: Text(serviceDateKey(alarm)),
            ),
          ),
          if (kIsWeb)
            const Text(
              'Save the calendar event on your device to receive the alert.',
            ),
          FilledButton(
            onPressed: () async {
              if (busy.value) return;
              busy.value = true;
              String message;
              try {
                final render = context.findRenderObject() as RenderBox?;
                message = await ref.read(scheduleReminderProvider)(
                  serviceId: service.id,
                  bus: service.busName,
                  stop: stop,
                  boarding: boarding,
                  lead: lead,
                  origin: render == null
                      ? null
                      : render.localToGlobal(Offset.zero) & render.size,
                );
              } catch (e) {
                message = e is StateError
                    ? e.message
                    : 'Could not set the reminder. Check device permissions and try again.';
              } finally {
                busy.value = false;
              }
              if (context.mounted)
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message)));
            },
            child: Text(kIsWeb ? 'Add to calendar' : 'Set reminder'),
          ),
        ],
      ),
    );
  }
}
