part of 'passenger_app.dart';

class _Home extends ConsumerWidget {
  const _Home();
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final q = ref.watch(searchQueryProvider),
        date = _date(ref),
        after = ref.watch(journeyFiltersProvider).after;
    final ads = ref.watch(sponsorsProvider).asData?.value;
    final ad = ads?.records.firstOrNull;
    Future<void> choose(bool origin) async {
      final name = await _open<String>(
        c,
        _Stops(origin: origin, initial: origin ? q.from : q.to),
      );
      if (name == null || !c.mounted) return;
      final change = ref.read(searchQueryProvider.notifier);
      origin ? change.from(name) : change.to(name);
    }

    Widget endpoint(bool origin) => InkWell(
      onTap: () => choose(origin),
      child: Row(
        children: [
          Icon(
            origin ? Icons.radio_button_unchecked : Icons.crop_square,
            color: origin ? _teal : _orange,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sub(origin ? 'Leaving from' : 'Going to'),
                  _text(
                    (origin ? q.from : q.to).isEmpty
                        ? 'Choose a stop'
                        : origin
                        ? q.from
                        : q.to,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    void board(String name) => _open(c, _Board(stop: name));
    return _Frame(
      'Find a bus',
      [
        _title('Find a bus'),
        Container(
          decoration: _box(_wash),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    endpoint(true),
                    const Divider(height: 1),
                    endpoint(false),
                  ],
                ),
              ),
              _round(
                'Swap stops',
                Icons.swap_vert,
                ref.read(searchQueryProvider.notifier).swap,
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => _open(c, const _JourneyTime()),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: _pair(
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16),
                  const SizedBox(width: 7),
                  Flexible(child: _sub(_day(date))),
                ],
              ),
              _sub(after == null ? 'Any time ◷' : 'After ${clock24(after)} ◷'),
            ),
          ),
        ),
        _button('Search buses', () async {
          if (q.from.isEmpty) {
            await choose(true);
            return;
          }
          if (q.to.isEmpty) {
            await choose(false);
            return;
          }
          await _open(c, const _Results());
        }),
        _tile(
          Icons.signpost_outlined,
          'Stops near me',
          'Choose a stop for departures',
          () => _open(c, const _Nearby()),
        ),
        if (ad != null)
          _card([
            _ey('Sponsored · ${q.from}'),
            InkWell(
              onTap: isSampleId(ad.id)
                  ? null
                  : () => ref.read(openSponsorProvider)(ad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _text(ads!.isDemo ? 'Local sponsor' : ad.title),
                  _sub(
                    ads.isDemo ? 'Selected by boarding area' : ad.advertiser,
                  ),
                ],
              ),
            ),
          ], color: _wash),
      ],
      root: true,
      map: _MapPanel(
        _areaPins(q.from),
        select: board,
        locate: () => _open(c, const _Nearby()),
      ),
      action: _round(
        'Service updates',
        Icons.notifications_none,
        () => _open(c, const _Updates()),
      ),
    );
  }
}

class _Stops extends HookConsumerWidget {
  final bool origin;
  final String initial;
  const _Stops({this.origin = true, this.initial = ''});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final tab = _choice(ref), text = useTextEditingController(text: initial);
    useListenable(text);
    final options = ref.watch(stopLabelsProvider).matching(text.text);
    final book = ref.watch(journeyBookProvider).asData?.value ?? [];
    final returning = useRef(false);
    void choose(String value) {
      if (value.trim().isEmpty || returning.value) return;
      returning.value = true;
      ref
          .read(journeyBookProvider.notifier)
          .edit(SavedJourney('recent', value.trim(), from: value.trim()))
          .ignore();
      Navigator.pop(c, value.trim());
    }

    final history = book.where(
      (e) => e.kind == (tab.index == 2 ? 'stop' : 'recent'),
    );
    return _Frame(origin ? 'Choose boarding stop' : 'Choose destination', [
      _ey(origin ? 'Boarding stop' : 'Destination'),
      _title(origin ? 'Where from?' : 'Where to?'),
      PlaceTextField(
        controller: text,
        autofocus: true,
        onSubmitted: choose,
        onSelected: choose,
        decoration: _input('Search a stop or place', icon: Icons.search),
      ),
      _segments(['Matches', 'Recent', 'Saved'], tab.index, tab.select),
      if (tab.index == 0) ...[
        _ey('Timetable stops'),
        for (final s in options)
          _tile(Icons.signpost_outlined, s, 'Timetable stop', () => choose(s)),
        if (text.text.trim().isNotEmpty && !options.contains(text.text.trim()))
          _tile(
            Icons.search,
            text.text.trim(),
            'Search this stop',
            () => choose(text.text),
          ),
        _tile(
          Icons.map_outlined,
          'Choose on map',
          'Select a mapped timetable stop',
          () async {
            final s = await _open<String>(c, const _Nearby(pick: true));
            if (s != null && c.mounted) choose(s);
          },
        ),
        _section('Recent'),
      ],
      for (final e in history.take(tab.index == 0 ? 2 : 12))
        _tile(
          Icons.place_outlined,
          e.name,
          'Timetable stop',
          () => choose(e.from),
        ),
      if (history.isEmpty && tab.index != 0)
        _sub(
          tab.index == 2
              ? 'No saved stops yet.'
              : 'No recently selected stops.',
        ),
    ]);
  }
}

class _Nearby extends ConsumerWidget {
  final bool pick;
  const _Nearby({this.pick = false});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final nearby = ref.watch(nearbyStopsProvider), state = nearby.asData?.value;
    final rows = state?.stops ?? [];
    final q = ref.watch(searchQueryProvider);
    final labels = rows.isNotEmpty
        ? rows.map((s) => s.name).toList()
        : ref.watch(stopLabelsProvider).matching('');
    void select(String s) {
      if (pick) {
        Navigator.pop(c, s);
      } else {
        _open(c, _Board(stop: s));
      }
    }

    return _Frame(
      'Nearby stops',
      [
        _ey('Around ${q.from.isEmpty ? 'your area' : q.from}'),
        _title('Nearby stops'),
        _tile(Icons.search, 'Search a stop manually', '', () async {
          final name = await _open<String>(c, const _Stops());
          if (name != null && c.mounted) select(name);
        }),
        if (nearby.isLoading) _loading(),
        if (state?.message != null) _notice(state!.message!),
        if (rows.isEmpty) _sub('Select a timetable stop or use your location.'),
        for (final s in rows)
          _tile(
            Icons.signpost_outlined,
            s.name,
            'Boarding stop',
            () => select(s.name),
            trailing: _sub('${(s.distanceKm * 1000).round()} m'),
          ),
        if (rows.isEmpty)
          for (final s in labels)
            _tile(
              Icons.signpost_outlined,
              s,
              'Timetable stop',
              () => select(s),
            ),
      ],
      tab: 1,
      map: _MapPanel(
        labels.take(3).toList(),
        ratio: 1.61,
        select: select,
        locate: ref.read(nearbyStopsProvider.notifier).refresh,
      ),
    );
  }
}

typedef _When = ({DateTime day, int? after});
final _when = NotifierProvider.autoDispose
    .family<_WhenController, _When, _When>(_WhenController.new);

class _WhenController extends Notifier<_When> {
  _WhenController(this.initial);
  final _When initial;
  @override
  _When build() => initial;
  void change(DateTime day, int? after) => state = (day: day, after: after);
}

class _JourneyTime extends HookConsumerWidget {
  const _JourneyTime();
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final initial = useMemoized<_When>(
      () => (
        day:
            ref.read(searchQueryProvider).serviceDate ??
            ref.read(journeyTodayProvider),
        after: ref.read(journeyFiltersProvider).after,
      ),
    );
    final v = ref.watch(_when(initial)),
        controller = ref.read(_when(initial).notifier),
        first = ref.watch(journeyTodayProvider);
    Future<void> time() async {
      final t = await _pickTime(c, v.after ?? 540);
      if (t != null && c.mounted) controller.change(v.day, t);
    }

    return _Frame('Journey time', [
      _title('When are you leaving?'),
      _sub('Choose a service date and boarding time.'),
      _card([
        CalendarDatePicker(
          initialDate: v.day.isBefore(first) ? first : v.day,
          firstDate: first,
          lastDate: DateTime(first.year + 1, first.month, first.day),
          onDateChanged: (d) => controller.change(d, v.after),
        ),
      ]),
      _section('Boarding time'),
      _segments(
        ['Any time', 'Leave after'],
        v.after == null ? 0 : 1,
        (i) => controller.change(v.day, i == 0 ? null : v.after ?? 540),
      ),
      if (v.after != null)
        Center(
          child: TextButton(
            onPressed: time,
            child: _text('${clock24(v.after)}   IST', size: 23),
          ),
        ),
      _button(
        'Use ${_day(v.day)} · ${v.after == null ? 'Any time' : clock24(v.after)}',
        () {
          ref.read(searchQueryProvider.notifier).journeyDate(v.day);
          final old = ref.read(journeyFiltersProvider);
          ref
              .read(journeyFiltersProvider.notifier)
              .apply(
                JourneyFilters(
                  after: v.after,
                  status: old.status,
                  hideCancelled: old.hideCancelled,
                ),
              );
          Navigator.pop(c);
        },
      ),
    ]);
  }
}

Widget _resultCard(
  BuildContext c,
  ServiceEntity row,
  String from,
  String to,
  DateTime date, {
  bool featured = false,
  bool regular = false,
}) {
  final a = stopMatch(row, from, false), b = stopMatch(row, to, true);
  int? time(String s) => regular ? row.scheduledTime(s) : row.expectedTime(s);
  final delay = (time(a) ?? 0) - (row.scheduledTime(a) ?? 0);
  return InkWell(
    onTap: () => _open(c, _Service(row, date, from: a, to: b)),
    child: _card([
      _pair(
        _text('${row.busName} · $b'),
        _pill(
          regular
              ? 'Scheduled'
              : delay > 0
              ? 'Owner +$delay min'
              : row.runningStatus.label,
          accent: !regular && delay > 0,
        ),
      ),
      _gap(),
      LayoutBuilder(
        builder: (context, box) {
          final start = _text(
            clock24(time(a)),
            size: 25,
            weight: FontWeight.w800,
          );
          final finish = _text(
            clock24(time(b)),
            size: 25,
            weight: FontWeight.w800,
          );
          if (box.maxWidth < MediaQuery.textScalerOf(context).scale(230)) {
            return Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                start,
                const Icon(Icons.arrow_forward, size: 18, color: _muted),
                finish,
              ],
            );
          }
          return Row(
            children: [
              start,
              const Expanded(child: Divider(indent: 10, endIndent: 10)),
              finish,
            ],
          );
        },
      ),
      _pair(_sub('$a · board'), _sub('$b · alight')),
    ], color: featured ? const Color(0xfffffaf5) : Colors.white),
  );
}

class _Results extends ConsumerWidget {
  const _Results();
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final date = _date(ref),
        s = ref.watch(searchQueryProvider),
        q = _query(s.from, s.to, date),
        feed = ref.watch(journeyFeedProvider(q)),
        f = ref.watch(journeyFiltersProvider);
    final data = feed.asData?.value;
    final rows =
        data?.rows.where((row) => f.accepts(row, q.from)).toList() ?? [];
    final unavailable =
        (data?.updatesMissing ?? false) && !(data?.sample ?? false);
    return _Frame(unavailable ? 'Timetable status' : 'Bus results', [
      _ey(
        '${_day(date)} · ${unavailable
            ? 'regular timetable'
            : f.after == null
            ? 'all day'
            : 'after ${clock24(f.after)}'}',
      ),
      _title('${q.from} → ${q.to}'),
      if (feed.isLoading) _loading(),
      if (feed.hasError) ...[
        _notice('Timetables could not be loaded.'),
        _button('Retry', () => _retry(ref, q)),
      ],
      if (data != null) ...[
        if (data.sample) _sub('Sample timetable'),
        if (unavailable)
          _notice(
            'Daily updates unavailable\nShowing regular timetable times. Check again for owner updates.',
          ),
        if (!unavailable &&
            (rows.isNotEmpty ||
                data.more ||
                f.status != TimetableStatus.all ||
                f.hideCancelled ||
                f.after != null))
          _pair(
            _sub('${rows.length} matching buses'),
            TextButton(
              onPressed: () => _open(c, const _Filters()),
              child: const Text('Filters'),
            ),
          ),
        if (rows.isEmpty) ...[
          _card([
            const Center(child: Icon(Icons.search, size: 35, color: _orange)),
            _gap(),
            Center(child: _text('No matching buses', size: 19)),
            _sub(
              'No published service matches these stops and this operating day.',
            ),
            _button(
              'Change journey date',
              () => _open(c, const _JourneyTime()),
            ),
            _button('Edit stops', () => _tab(c, 0), secondary: true),
          ]),
          _tile(
            Icons.route_outlined,
            'Browse published routes',
            'Search by route or stop',
            () => _tab(c, 2),
          ),
        ],
        for (var i = 0; i < rows.length; i++)
          _resultCard(
            c,
            rows[i],
            q.from,
            q.to,
            date,
            featured: i == 0 && !unavailable,
            regular: unavailable,
          ),
        if (data.more)
          _button(
            'More departures',
            () => ref.read(pagedDeparturesProvider(q).notifier).next(),
            secondary: true,
          ),
        if (unavailable)
          _button('Retry daily updates', () => _retry(ref, q), secondary: true)
        else if (rows.isNotEmpty)
          _sub('Sorted by earliest expected boarding time.'),
      ],
    ]);
  }
}

class _Filters extends ConsumerWidget {
  const _Filters();
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final q = ref.watch(searchQueryProvider),
        f = ref.watch(journeyFiltersProvider),
        feed = ref.watch(journeyFeedProvider(_query(q.from, q.to, _date(ref))));
    final choices = (feed.asData?.value.rows ?? [])
        .where((s) => f.accepts(s, q.from))
        .toList();
    void apply(int? t, TimetableStatus status, bool hide) => ref
        .read(journeyFiltersProvider.notifier)
        .apply(JourneyFilters(after: t, status: status, hideCancelled: hide));
    return _Frame('Search filters', [
      _ey('${q.from} → ${q.to}'),
      _title('Filter buses'),
      _section('Departure window'),
      _segments(
        [
          'All day',
          f.after == null ? 'Leave after' : 'After ${clock24(f.after)}',
        ],
        f.after == null ? 0 : 1,
        (i) async {
          if (i == 0) {
            apply(null, f.status, f.hideCancelled);
            return;
          }
          final t = await _pickTime(c, f.after ?? 540);
          if (t != null && c.mounted) apply(t, f.status, f.hideCancelled);
        },
      ),
      _section('Timetable status'),
      _segments(
        ['All services', 'Owner updated', 'Scheduled'],
        f.status.index,
        (i) => apply(f.after, TimetableStatus.values[i], f.hideCancelled),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: _text('Hide cancelled trips'),
        subtitle: _sub('Applies only to this search.'),
        value: f.hideCancelled,
        onChanged: (v) => apply(f.after, f.status, v),
      ),
      if (choices.isNotEmpty)
        _card([
          _ey('Matching service'),
          _text(
            '${choices.first.busName} · ${clock24(choices.first.expectedTime(stopMatch(choices.first, q.from, false)))} from ${q.from}',
          ),
        ], color: _mint),
      _button(
        'Show ${choices.length} ${choices.length == 1 ? 'bus' : 'buses'}',
        () => Navigator.pop(c),
      ),
      _button(
        'Reset filters',
        () => apply(null, TimetableStatus.all, false),
        secondary: true,
      ),
    ]);
  }
}
