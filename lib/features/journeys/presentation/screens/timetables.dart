part of 'passenger_app.dart';

Widget _save(
  BuildContext c,
  WidgetRef ref,
  SavedJourney item, {
  String? label,
  bool compact = false,
}) {
  final book = ref.watch(journeyBookProvider),
      saved = book.asData?.value.any((e) => e.key == item.key) ?? false;
  Future<void> toggle() async {
    try {
      await ref.read(journeyBookProvider.notifier).edit(item, remove: saved);
    } catch (_) {
      if (c.mounted) _message(c, 'Could not update saved items. Please retry.');
    }
  }

  final title = label ?? 'Save ${item.kind}';
  if (compact)
    return _round(
      saved ? 'Remove bookmark' : 'Bookmark trip',
      saved ? Icons.bookmark : Icons.bookmark_outline,
      toggle,
    );
  return _button(saved ? 'Saved ✓' : title, toggle, secondary: true);
}

class _Board extends ConsumerWidget {
  const _Board({this.stop});
  final String? stop;
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final date = _date(ref),
        s = stop ?? ref.watch(searchQueryProvider).from,
        q = _query(s, '', date);
    final feed = ref.watch(journeyFeedProvider(q)),
        data = feed.asData?.value,
        after = ref.watch(journeyFiltersProvider).after;
    final rows = (data?.rows ?? []).where(
      (r) =>
          r.stops.isNotEmpty &&
          r.stops.last.toLowerCase() != s.toLowerCase() &&
          (after == null ||
              (r.expectedTime(stopMatch(r, s, false)) ?? -1) >= after),
    );
    void change(String name) => _open(c, _Board(stop: name));
    Future<void> pick() async {
      final value = await _open<String>(c, _Stops(initial: s));
      if (c.mounted && value != null) change(value);
    }

    return _Frame(
      'Departures',
      [
        _ey('Departure board'),
        _title(s),
        _pair(
          _sub(
            '${_day(date)} · ${after == null ? 'all day' : 'after ${clock24(after)}'}',
          ),
          TextButton(onPressed: pick, child: const Text('Change stop')),
        ),
        _section('Upcoming buses'),
        if (feed.isLoading) _loading(),
        if (feed.hasError) _button('Retry departures', () => _retry(ref, q)),
        if (data?.sample == true) _sub('Sample timetable'),
        if (data?.stale == true) _sub('Cached timetable'),
        if (data?.updatesMissing == true && data?.sample != true)
          _notice(
            'Daily updates unavailable. Showing regular timetable times.',
          ),
        if (data != null && rows.isEmpty)
          _sub('No upcoming departures for this selection.'),
        if (rows.isNotEmpty)
          _card([
            for (final r in rows)
              _tile(
                Icons.departure_board_outlined,
                '${clock24(r.expectedTime(stopMatch(r, s, false)))}  ·  ${r.stops.last}',
                r.busName,
                () => _open(c, _Service(r, date, from: s, to: r.stops.last)),
                trailing: _pill(r.runningStatus.label),
              ),
          ]),
        if (data?.more == true)
          _button(
            'More departures',
            () => ref.read(pagedDeparturesProvider(q).notifier).next(),
            secondary: true,
          ),
        _save(
          c,
          ref,
          SavedJourney('stop', s, from: s),
          label: 'Save this stop',
        ),
      ],
      map: _MapPanel(
        _areaPins(s),
        select: change,
        locate: pick,
        ratio: 309 / 122,
      ),
      tab: 1,
      root: stop == null,
    );
  }
}

class _Routes extends HookConsumerWidget {
  const _Routes();
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final text = useTextEditingController();
    useListenable(text);
    final query = useTextEditingController();
    useListenable(query);
    useEffect(() {
      final timer = Timer(const Duration(milliseconds: 300), () {
        query.text = text.text.trim();
      });
      return timer.cancel;
    }, [text.text]);
    final t = _choice(ref),
        date = _date(ref),
        q = _query(query.text, '', date, directory: true);
    final feed = ref.watch(journeyFeedProvider(q)),
        data = feed.asData?.value,
        book = ref.watch(journeyBookProvider).asData?.value ?? [];
    final grouped = <String, ServiceEntity>{};
    for (final r in data?.rows ?? <ServiceEntity>[]) {
      if (r.stops.length >= 2)
        grouped.putIfAbsent(
          r.routeId.isEmpty ? r.routeName : r.routeId,
          () => r,
        );
    }
    return _Frame(
      'Routes',
      [
        _ey('Published timetables'),
        _title('Routes'),
        TextField(
          controller: text,
          decoration: _input('Search routes or stops', icon: Icons.search),
        ),
        _segments(['All routes', 'Saved routes'], t.index, t.select),
        if (t.index == 0) ...[
          _section('Published routes'),
          if (feed.isLoading) _loading(),
          if (feed.hasError) _button('Retry routes', () => _retry(ref, q)),
          if (data?.sample == true) _sub('Sample timetable'),
          if (grouped.isNotEmpty)
            _card([
              for (final r in grouped.values)
                _tile(
                  Icons.route_outlined,
                  r.routeName,
                  '${r.stops.length} stops',
                  () => _open(c, _Service(r, date, route: true)),
                ),
            ]),
          if (data != null && grouped.isEmpty) _sub('No matching routes.'),
          if (data?.more == true)
            _button(
              'More routes',
              () => ref.read(pagedDeparturesProvider(q).notifier).next(),
              secondary: true,
            ),
        ] else ...[
          for (final e in book.where(
            (a) =>
                a.kind == 'route' &&
                a.name.toLowerCase().contains(query.text.toLowerCase()),
          ))
            _tile(
              Icons.route_outlined,
              e.name,
              'Open timetable',
              () => _open(c, _Bookmark(e, date)),
            ),
          if (!book.any((e) => e.kind == 'route')) _sub('No saved routes yet.'),
        ],
        _sub('Select a route to see its stops and departure times.'),
      ],
      tab: 2,
      root: true,
    );
  }
}

Widget _timeline(
  ServiceEntity r,
  List<String> stops, {
  required bool expected,
  String? board,
  String? alight,
}) {
  return Column(
    children: [
      for (var i = 0; i < stops.length; i++)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 61,
                child: _text(
                  clock24(
                    expected
                        ? r.expectedTime(stops[i])
                        : r.scheduledTime(stops[i]),
                  ),
                  weight: FontWeight.w800,
                ),
              ),
              SizedBox(
                width: 19,
                child: Column(
                  children: [
                    Container(
                      width: 2,
                      height: 6,
                      color: i == 0 ? Colors.transparent : _line,
                    ),
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          width: 2,
                          color: i == 0 || i == stops.length - 1
                              ? _orange
                              : _teal,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: i == stops.length - 1
                            ? Colors.transparent
                            : _line,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _text(stops[i]),
                      _sub(
                        expected
                            ? 'Scheduled ${clock24(r.scheduledTime(stops[i]))}'
                            : stops[i] == board
                            ? 'Board here'
                            : stops[i] == alight
                            ? 'Alight here'
                            : 'Intermediate stop',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

String _days(List<String> off) {
  final days = weekDays.where((d) => !off.contains(d)).toList();
  if (days.length == 7) return 'Every day';
  if (days.length == 6 && off.contains('Sunday')) return 'Mon – Sat';
  return days.map((d) => d.substring(0, 3)).join(' · ');
}

class _Service extends ConsumerWidget {
  const _Service(
    this.initial,
    this.date, {
    this.from = '',
    this.to = '',
    this.route = false,
    this.inbound = false,
  });
  final ServiceEntity initial;
  final DateTime date;
  final String from, to;
  final bool route, inbound;
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final indexed =
        ref.watch(passengerPagingEnabledProvider) && !isSampleId(initial.id);
    final direct = indexed
        ? ref.watch(
            journeyTimetableProvider((
              id: initial.id,
              date: serviceDateKey(date),
              regular: route,
            )),
          )
        : null;
    final q = _query(
      route ? '' : from,
      route ? '' : to,
      date,
      directory: route,
    );
    final list = indexed ? null : ref.watch(journeyFeedProvider(q));
    final match =
        direct?.asData?.value ??
        list?.asData?.value.rows.where((s) => s.id == initial.id).firstOrNull;
    final missing =
        (indexed && direct?.asData != null && match == null) ||
        (!indexed &&
            list?.asData != null &&
            !list!.requireValue.more &&
            match == null &&
            !isSampleId(initial.id));
    final heading = route ? 'Route timetable' : 'Trip details';
    if (missing)
      return _Frame(heading, [
        _notice('This service is no longer available for the selected date.'),
      ], tab: route ? 2 : 0);
    final r = match ?? initial,
        a = stopMatch(r, from, false),
        b = stopMatch(r, to, true);
    final unavailable =
        direct?.hasError == true ||
        list?.hasError == true ||
        list?.asData?.value.updatesMissing == true &&
            list?.asData?.value.sample == false;
    final delay = (r.expectedTime(a) ?? 0) - (r.scheduledTime(a) ?? 0);
    final item = SavedJourney(
      route ? 'route' : 'trip',
      '$a → $b',
      from: a,
      to: b,
      serviceId: r.id,
      sampleCatalogue: isSampleId(r.id),
    );
    final reverseQuery = _query(b, '', date, directory: true);
    final returnFeed = route
        ? ref.watch(journeyFeedProvider(reverseQuery))
        : null;
    Future<void> reverse() async {
      final rows = returnFeed?.asData?.value;
      if (rows == null) {
        if (returnFeed?.hasError == true) _retry(ref, reverseQuery);
        _message(c, 'Loading the return timetable.');
        return;
      }
      final rev = rows.rows
          .where(
            (row) =>
                row.stops.isNotEmpty &&
                row.stops.first.toLowerCase() == b.toLowerCase() &&
                row.stops.last.toLowerCase() == a.toLowerCase() &&
                row.businessId == r.businessId,
          )
          .firstOrNull;
      if (rev != null) {
        await _open(c, _Service(rev, date, route: true, inbound: !inbound));
        return;
      }
      if (rows.more) {
        await ref.read(pagedDeparturesProvider(reverseQuery).notifier).next();
        if (c.mounted)
          _message(c, 'Additional routes loaded. Select Return to check.');
      } else {
        _message(c, 'No published return timetable.');
      }
    }

    return _Frame(
      heading,
      [
        _ey(
          route
              ? 'Published route · ${r.busName}'
              : '${_day(date)} · service ${r.busName}',
        ),
        _title('$a → $b'),
        if (isSampleId(r.id)) _sub('Sample timetable'),
        if (unavailable)
          _notice('Daily updates unavailable. Check regular times.'),
        if (route) ...[
          _segments(['Outward', 'Return'], inbound ? 1 : 0, (i) {
            if (i != (inbound ? 1 : 0)) reverse();
          }),
          _card([
            _pair(_text('Regular timetable'), _pill(_days(r.offDays))),
            _sub('Times shown in IST'),
          ], color: _wash),
          _card([_timeline(r, r.stops, expected: false, board: a, alight: b)]),
          _button('Find buses on this route', () {
            final n = ref.read(searchQueryProvider.notifier);
            n.from(a);
            n.to(b);
            _open(c, const _Results());
          }),
          _save(c, ref, item),
        ] else ...[
          _pair(
            _pill(
              delay > 0 ? 'Owner reported +$delay min' : r.runningStatus.label,
              accent: delay > 0,
            ),
            _sub(
              '${r.stops.length} stops${r.expectedTime(a) != null && r.expectedTime(b) != null ? ' · ${r.expectedTime(b)! - r.expectedTime(a)!} min' : ''}',
            ),
          ),
          _card([
            _timeline(r, [a, b], expected: !unavailable, board: a, alight: b),
          ]),
          _button(
            'View all ${r.stops.length} stops',
            () => _open(c, _Sequence(r, date)),
          ),
          _pair(
            _save(c, ref, item),
            _button(
              'Reminder',
              r.runningStatus == RunningStatus.cancelled ||
                      r.expectedTime(a) == null
                  ? null
                  : () => _open(c, _Reminder(r, date, a, b)),
              secondary: true,
            ),
          ),
        ],
      ],
      tab: route ? 2 : 0,
      action: route ? null : _save(c, ref, item, compact: true),
      map: route ? null : _MapPanel(r.stops, route: true, ratio: 309 / 144),
    );
  }
}

class _Sequence extends HookConsumerWidget {
  final ServiceEntity r;
  final DateTime date;
  const _Sequence(this.r, this.date);
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final t = _choice(ref);
    return _Frame('Stop timetable', [
      _ey('${r.busName} · ${_day(date, long: true)}'),
      _title('Stop sequence'),
      _segments(['Expected times', 'Regular times'], t.index, t.select),
      if (r.hasDailyAdjustment)
        _notice('Owner reported a timetable change for this service date.'),
      _card([
        _timeline(
          r,
          r.stops,
          expected: t.index == 0,
          board: r.stops.firstOrNull,
          alight: r.stops.lastOrNull,
        ),
      ]),
      _tile(
        Icons.location_on_outlined,
        'Route position preview',
        'View the reported stop, when available',
        () => _open(c, _Position(service: r, date: date)),
      ),
    ]);
  }
}

class _Position extends ConsumerWidget {
  final ServiceEntity? service;
  final DateTime? date;
  const _Position({this.service, this.date});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final data = ref.watch(trackingDataProvider).asData?.value;
    final r = service;
    final position = (data?.records ?? [])
        .where(
          (p) =>
              r == null ||
              p.vehicle == r.busName && listEquals(p.stops, r.stops),
        )
        .firstOrNull;
    final stops = r?.stops ?? position?.stops ?? <String>[];
    final pos = position?.currentStop;
    final valid = pos != null && pos >= 0 && pos < stops.length;
    return _Frame(
      'Tracking preview',
      [
        _ey('${r?.busName ?? position?.vehicle ?? 'Service'} · route position'),
        _title(valid ? stops[pos] : 'Route position preview'),
        if (valid) ...[
          _pill(data!.isDemo ? 'Example reported stop' : 'Reported stop'),
          _sub('Stop ${pos + 1} of ${stops.length} · towards ${stops.last}'),
        ],
        _notice(
          valid
              ? 'This marker shows a ${data!.isDemo ? 'sample ' : ''}reported stop. Live vehicle location is unavailable.'
              : 'No reported stop is available for this route.',
        ),
        if (valid && pos + 1 < stops.length)
          _tile(
            Icons.signpost_outlined,
            'Following stop',
            stops[pos + 1],
            null,
          ),
        _button(
          r == null ? 'Browse route timetables' : 'Open stop timetable',
          () => r == null ? _tab(c, 2) : _open(c, _Sequence(r, date!)),
        ),
      ],
      map: _MapPanel(
        stops,
        route: true,
        reported: valid ? pos : null,
        ratio: 309 / 175,
      ),
      tab: 2,
    );
  }
}

class _Reminder extends HookConsumerWidget {
  final ServiceEntity r;
  final DateTime date;
  final String a, b;
  const _Reminder(this.r, this.date, this.a, this.b);
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final t = _choice(ref);
    const leads = [10, 5, 15, 30];
    final lead = leads[t.index], minutes = r.expectedTime(a)!;
    final boarding = boardingUtc(date, minutes);
    final alarm = boarding
        .subtract(Duration(minutes: lead))
        .add(const Duration(hours: 5, minutes: 30));
    return _Frame('Reminder', [
      _ey(_day(date, long: true)),
      _title('Remind me'),
      _card([
        _text('${r.busName} · $a to $b'),
        _sub('Expected boarding ${clock24(minutes)} at $a'),
      ]),
      _section('Before boarding'),
      _segments(
        ['5 min', '10 min', '15 min', '30 min'],
        [5, 10, 15, 30].indexOf(lead),
        (i) => t.select(leads.indexOf([5, 10, 15, 30][i])),
      ),
      _card([
        _ey('Reminder time'),
        _text(clock24(alarm.hour * 60 + alarm.minute), size: 26),
        _sub('${_day(alarm)} · Kerala time'),
      ], color: _mint),
      _notice(
        kIsWeb
            ? 'Save the calendar event to receive your reminder.'
            : 'Allow notifications on this device to receive the reminder.',
      ),
      _button(
        'Set reminder for ${clock24(alarm.hour * 60 + alarm.minute)}',
        () async {
          try {
            final box = c.findRenderObject() as RenderBox?;
            final msg = await ref.read(scheduleReminderProvider)(
              serviceId: r.id,
              bus: r.busName,
              stop: a,
              boarding: boarding,
              lead: lead,
              origin: box == null
                  ? null
                  : box.localToGlobal(Offset.zero) & box.size,
            );
            if (c.mounted) _message(c, msg);
          } catch (e) {
            if (c.mounted) _message(c, e.toString());
          }
        },
      ),
    ], tab: 3);
  }
}

class _Saved extends HookConsumerWidget {
  const _Saved();
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final t = _choice(ref),
        edit = _choice(ref),
        date = _date(ref),
        book = ref.watch(journeyBookProvider);
    return _Frame(
      'Saved',
      [
        _ey('On this device'),
        _title('Saved'),
        _segments(['All', 'Trips', 'Stops', 'Routes'], t.index, t.select),
        if (book.isLoading) _loading(),
        if (book.hasError)
          _button(
            'Retry saved items',
            () => ref.invalidate(journeyBookProvider),
          ),
        for (final (i, kind, section) in [
          (1, 'trip', 'My journeys'),
          (2, 'stop', 'My stops'),
          (3, 'route', 'My routes'),
        ])
          if (t.index == 0 || t.index == i) ...[
            _pair(
              _section(section),
              ifEdit(i, t.index)
                  ? TextButton(
                      onPressed: () => edit.select(1 - edit.index),
                      child: Text(edit.index == 1 ? 'Done' : 'Edit'),
                    )
                  : const SizedBox(),
            ),
            if (book.hasValue)
              _card([
                if (!book.requireValue.any((e) => e.kind == kind))
                  _sub('No saved ${kind}s yet.'),
                for (final e in book.requireValue.where((e) => e.kind == kind))
                  _tile(
                    i == 2 ? Icons.signpost_outlined : Icons.route_outlined,
                    e.name,
                    i == 2
                        ? 'Open departures'
                        : i == 1
                        ? 'Open trip'
                        : 'Open timetable',
                    () => _open(
                      c,
                      i == 2 ? _Board(stop: e.from) : _Bookmark(e, date),
                    ),
                    trailing: edit.index == 0
                        ? null
                        : IconButton(
                            tooltip: 'Remove ${e.name}',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () async {
                              try {
                                await ref
                                    .read(journeyBookProvider.notifier)
                                    .edit(e, remove: true);
                              } catch (_) {
                                if (c.mounted)
                                  _message(c, 'Could not remove saved item.');
                              }
                            },
                          ),
                  ),
              ]),
          ],
        _sub('Open a saved item to check the latest published times.'),
      ],
      tab: 3,
      root: true,
    );
  }

  bool ifEdit(int section, int selected) => section == 1 || selected == section;
}

class _Bookmark extends ConsumerWidget {
  const _Bookmark(this.item, this.date);
  final SavedJourney item;
  final DateTime date;
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final route = item.kind == 'route';
    final direct =
        ref.watch(passengerPagingEnabledProvider) && !item.sampleCatalogue;
    final q = _query(item.from, route ? '' : item.to, date, directory: route);
    final byId = direct
        ? ref.watch(
            journeyTimetableProvider((
              id: item.serviceId,
              date: serviceDateKey(date),
              regular: route,
            )),
          )
        : null;
    final feed = direct ? null : ref.watch(journeyFeedProvider(q));
    final sample = item.sampleCatalogue
        ? ref.watch(sampleCatalogueProvider)
        : null;
    final r =
        byId?.asData?.value ??
        feed?.asData?.value.rows
            .where((r) => r.id == item.serviceId)
            .firstOrNull ??
        sample?.asData?.value.records
            .where((r) => r.id == item.serviceId)
            .firstOrNull;
    if (r != null)
      return _Service(r, date, from: item.from, to: item.to, route: route);
    return _Frame(route ? 'Route timetable' : 'Trip details', [
      (byId?.isLoading == true ||
              feed?.isLoading == true ||
              sample?.isLoading == true)
          ? _loading()
          : _notice('This saved service is unavailable for the selected date.'),
    ], tab: 3);
  }
}

class _Updates extends ConsumerWidget {
  const _Updates();
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final s = ref.watch(searchQueryProvider),
        date = _date(ref),
        q = _query(s.from, s.to, date),
        feed = ref.watch(journeyFeedProvider(q)),
        data = feed.asData?.value;
    final rows = (data?.rows ?? []).where(
      (r) => r.hasDailyAdjustment || r.runningStatus != RunningStatus.scheduled,
    );
    return _Frame('Updates', [
      _ey(_day(date, long: true)),
      _title('Service updates'),
      _section('For this journey'),
      if (feed.isLoading) _loading(),
      if (feed.hasError || data?.updatesMissing == true)
        _button('Retry daily updates', () => _retry(ref, q), secondary: true),
      if (data != null && rows.isEmpty)
        _sub('No owner updates for this journey.'),
      for (final r in rows)
        _card([
          _ey('Owner reported'),
          _text('${r.busName} · ${r.runningStatus.label}', size: 18),
          _sub('${r.routeName} · ${_day(date)}'),
          _gap(),
          _pair(
            _sub('${s.from} departure'),
            _text(
              '${clock24(r.scheduledTime(s.from))} → ${clock24(r.expectedTime(s.from))}',
            ),
          ),
          _button(
            'View affected trip',
            () => _open(c, _Service(r, date, from: s.from, to: s.to)),
            secondary: true,
          ),
        ]),
      if (data?.more == true)
        _button(
          'More updates',
          () => ref.read(pagedDeparturesProvider(q).notifier).next(),
          secondary: true,
        ),
      _section('Travel advice'),
      _card([
        _text('About timetable estimates'),
        _sub(
          'Traffic can affect actual arrival times. Check for a recent owner update before you travel.',
        ),
      ], color: _wash),
    ], tab: 4);
  }
}

class _More extends ConsumerWidget {
  const _More();
  @override
  Widget build(BuildContext c, WidgetRef ref) => _Frame(
    'More',
    [
      _title('More'),
      _section('Passenger tools'),
      _card([
        _tile(
          Icons.my_location,
          'Nearby stops',
          'Search around an area',
          () => _open(c, const _Nearby()),
        ),
        _tile(
          Icons.route_outlined,
          'Route position preview',
          'Reported stop on a route',
          () => _open(c, const _Position()),
        ),
        _tile(
          Icons.notifications_outlined,
          'Service updates',
          'Operator changes and guidance',
          () => _open(c, const _Updates()),
        ),
      ]),
      _section('Operator workspace'),
      _card([
        _tile(
          Icons.badge_outlined,
          ref.watch(ownerIdProvider) == null
              ? 'Owner sign in'
              : 'Owner dashboard',
          'Buses, trips and daily timings',
          () => _open(c, const _Owner()),
        ),
        _tile(
          Icons.groups_outlined,
          'Crew duty roster',
          'Authorised assignments',
          () => _open(c, const _Crew()),
        ),
      ]),
      _sub('FindMyBus · Kerala Transit'),
    ],
    tab: 4,
    root: true,
  );
}
