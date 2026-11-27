part of 'passenger_app.dart';

class _Prompt extends HookWidget {
  final String title, initial;
  final bool number;
  const _Prompt(this.title, {this.initial = '', this.number = false});
  @override
  Widget build(BuildContext c) {
    final text = useTextEditingController(text: initial);
    useListenable(text);
    final value = text.text.trim();
    final n = int.tryParse(value);
    final valid = number ? n != null && n >= 0 && n <= 1440 : value.isNotEmpty;
    return AlertDialog(
      title: Text(title),
      content: TextField(
        autofocus: true,
        controller: text,
        maxLength: number ? 4 : 100,
        keyboardType: number ? TextInputType.number : null,
        decoration: _input(title),
        onSubmitted: (_) {
          if (valid) Navigator.pop(c, value);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: valid ? () => Navigator.pop(c, value) : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<String?> _prompt(
  BuildContext c,
  String label, {
  String initial = '',
  bool number = false,
}) => showDialog<String>(
  context: c,
  builder: (_) => _Prompt(label, initial: initial, number: number),
);
Widget _select<T>(
  String label,
  T? value,
  Map<T, String> values,
  ValueChanged<T> change,
) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: DropdownButtonFormField<T>(
    key: ValueKey((label, value)),
    initialValue: value,
    isExpanded: true,
    decoration: _input(label),
    items: [
      for (final e in values.entries)
        DropdownMenuItem<T>(
          value: e.key,
          child: Text(e.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: values.isEmpty
        ? null
        : (v) {
            if (v != null) change(v);
          },
  ),
);

class _Owner extends HookConsumerWidget {
  const _Owner();
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final auth = ref.watch(authUserProvider);
    final email = useTextEditingController(),
        pass = useTextEditingController(),
        action = ref.watch(authActionProvider);
    if (auth.isLoading)
      return _Frame('Owner access', [_loading()], staff: true);
    if (auth.hasError)
      return _Frame('Owner access', [
        _notice('Unable to check your account.'),
        _button('Retry', () => ref.invalidate(authUserProvider)),
      ], staff: true);
    if (auth.asData?.value != null) return const _Dashboard();
    final register = ref.watch(authModeProvider);
    return _Frame('Owner access', [
      _ey('Operator workspace'),
      _title(register ? 'Create owner account' : 'Owner sign in'),
      _sub('Manage your buses, timetables and daily updates.'),
      _gap(14),
      TextField(
        controller: email,
        autofillHints: const [AutofillHints.email],
        keyboardType: TextInputType.emailAddress,
        decoration: _input('Email address'),
      ),
      _gap(),
      TextField(
        controller: pass,
        obscureText: true,
        autofillHints: [
          register ? AutofillHints.newPassword : AutofillHints.password,
        ],
        decoration: _input('Password'),
      ),
      if (action.hasError) _notice(action.error.toString()),
      _button(
        register ? 'Create account' : 'Sign in',
        action.isLoading
            ? null
            : () => ref
                  .read(authActionProvider.notifier)
                  .submit(email.text.trim(), pass.text, register: register),
      ),
      _button(
        register ? 'Already have an account? Sign in' : 'Create owner account',
        action.isLoading ? null : ref.read(authModeProvider.notifier).toggle,
        secondary: true,
      ),
      _gap(),
      _tile(
        Icons.map_outlined,
        'Continue as passenger',
        'Return to Find bus',
        () => _tab(c, 0),
      ),
    ], staff: true);
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard();
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final owner = ref.watch(ownerIdProvider);
    if (owner == null) return const _Owner();
    final businesses = ref.watch(ownerBusinessesProvider),
        business = ref.watch(selectedBusinessProvider);
    final buses = business == null
        ? null
        : ref.watch(ownerBusesProvider(business.id));
    final list = buses?.asData?.value ?? [];
    final selected = business == null
        ? null
        : ref.watch(selectedBusProvider(business.id));
    final bus =
        list.where((b) => b.id == selected).firstOrNull ?? list.firstOrNull;
    final trips = business == null || bus == null
        ? null
        : ref.watch(
            busTripsProvider((
              ownerId: owner,
              businessId: business.id,
              busId: bus.id,
            )),
          );
    final action = ref.watch(tripActionsProvider),
        businessAction = ref.watch(ownerActionsProvider);
    Future<void> addBusiness() async {
      final name = await _prompt(c, 'Business name');
      if (name != null && c.mounted)
        await ref.read(ownerActionsProvider.notifier).saveBusiness(name);
    }

    Future<void> addBus() async {
      final name = await _prompt(c, 'Bus name');
      if (name != null && c.mounted && business != null)
        await ref.read(tripActionsProvider.notifier).saveBus(business, name);
    }

    void edit(TripPlan p) {
      if (business != null && bus != null)
        _open(c, _TripEditor(business, bus, p));
    }

    return _Frame(
      'Owner dashboard',
      [
        _ey('Operator workspace'),
        _title('Buses & trips'),
        if (businesses.isLoading || buses?.isLoading == true) _loading(),
        if (businesses.hasError || buses?.hasError == true)
          _button('Retry workspace', () {
            ref.invalidate(ownerBusinessesProvider);
            ref.invalidate(ownerBusesProvider);
          }),
        if (businessAction.hasError) _notice(businessAction.error.toString()),
        if (action.hasError) _notice(action.error.toString()),
        if (business != null)
          _select('Business', business.id, {
            for (final b in businesses.asData?.value ?? <BusinessEntity>[])
              b.id: b.name,
          }, ref.read(selectedBusinessIdProvider.notifier).select)
        else if (businesses.hasValue)
          _button('Add business', addBusiness),
        if (business != null) ...[
          _select('Selected bus', bus?.id, {
            for (final b in list) b.id: b.name,
          }, ref.read(selectedBusProvider(business.id).notifier).select),
          _pair(
            TextButton(
              onPressed: action.isLoading ? null : addBus,
              child: const Text('+ Add bus'),
            ),
            TextButton(
              onPressed: bus == null
                  ? null
                  : () => edit(
                      TripPlan(
                        stops: const [
                          TripStop('origin', '', -1),
                          TripStop('destination', '', -1),
                        ],
                      ),
                    ),
              child: const Text('+ Create trip'),
            ),
          ),
          _section('Regular trips'),
          if (trips?.isLoading == true) _loading(),
          if (trips?.hasError == true)
            _button('Retry trips', () => ref.invalidate(ownerServicesProvider)),
          if (trips?.asData?.value.trips.isEmpty == true)
            _sub('Create a trip for this bus.'),
          for (final r in trips?.asData?.value.trips ?? <ServiceEntity>[])
            _card([
              _pill(r.published ? 'Published' : 'Inactive'),
              _section(r.routeName),
              _sub(
                '${clock24(r.departureMinutes)} · ${r.stops.length} stops · ${_days(r.offDays)}',
              ),
              _tile(
                Icons.edit_outlined,
                'Edit regular trip',
                'Route, timings and review',
                () => edit(TripPlan.fromService(r)),
              ),
              _tile(
                Icons.swap_horiz,
                'Create return trip',
                'Start an independent draft',
                () async {
                  final t = await _pickTime(c, r.departureMinutes);
                  if (t != null && c.mounted) {
                    try {
                      edit(TripPlan.fromService(r).returnTrip(t));
                    } catch (e) {
                      _message(c, e.toString());
                    }
                  }
                },
              ),
              _tile(
                Icons.calendar_today_outlined,
                'Daily update',
                _day(_date(ref)),
                () => _open(c, _Daily(bus!, TripPlan.fromService(r))),
              ),
            ]),
          for (final r in trips?.asData?.value.legacy ?? <ServiceEntity>[])
            _tile(
              Icons.link,
              'Associate ${r.routeName}',
              'Add this existing timetable to ${bus?.name}',
              () => edit(TripPlan.fromService(r)),
            ),
        ],
      ],
      staff: true,
      action: _round(
        'Sign out',
        Icons.logout,
        ref.read(authActionProvider.notifier).signOut,
      ),
    );
  }
}

class _TripEditor extends ConsumerWidget {
  final BusinessEntity business;
  final BusEntity bus;
  final TripPlan initial;
  const _TripEditor(this.business, this.bus, this.initial);
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final owner = ref.watch(ownerIdProvider);
    if (owner != bus.ownerId) return const _Owner();
    final args = (plan: initial, ownerId: owner!),
        draft = ref.watch(tripDraftProvider(args)),
        ctl = ref.read(tripDraftProvider(args).notifier),
        action = ref.watch(tripActionsProvider);
    final step = draft.step, p = draft.plan;
    final routeName = p.routeName.isEmpty
        ? '${p.stops.first.name} → ${p.stops.last.name}'
        : p.routeName;
    Future<void> setTime(int i) async {
      final old = p.stops[i].minutes;
      final val = await _pickTime(c, old < 0 ? 540 : old);
      if (val == null || !c.mounted) return;
      final day = old < 0 ? 0 : old ~/ 1440;
      ctl.time(i, val + day * 1440);
    }

    Future<void> publish() async {
      final success = await ref
          .read(tripActionsProvider.notifier)
          .saveTrip(business, bus, p.copyWith(active: true));
      if (success && c.mounted) Navigator.pop(c);
    }

    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && step > 0) ctl.step(step - 1);
      },
      child: _Frame('Edit regular trip', [
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.only(top: 5, bottom: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: i <= step ? _orange : _line,
                        width: 3,
                      ),
                    ),
                  ),
                  child: _sub('${i + 1} ${['Route', 'Timings', 'Review'][i]}'),
                ),
              ),
          ],
        ),
        _title(['Route & stops', 'Regular timings', 'Review trip'][step]),
        if (draft.error != null) _notice(draft.error!),
        if (action.hasError) _notice(action.error.toString()),
        if (step == 0) ...[
          _tile(Icons.edit_outlined, 'Route name', routeName, () async {
            final n = await _prompt(c, 'Route name', initial: routeName);
            if (n != null && c.mounted) ctl.routeName(n);
          }),
          _section('Travel order'),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: p.stops.length,
            onReorderItem: ctl.move,
            itemBuilder: (c, i) {
              final s = p.stops[i];
              return Row(
                key: ValueKey(s.id),
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.drag_indicator, color: _teal, size: 20),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final result = await showDialog<(String, bool)>(
                          context: c,
                          builder: (_) => _EditStop(
                            s.name,
                            allowDelete: p.stops.length > 2,
                          ),
                        );
                        if (result == null || !c.mounted) return;
                        if (result.$2) {
                          ctl.remove(i);
                        } else {
                          ctl.rename(i, result.$1);
                        }
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 49),
                        alignment: Alignment.centerLeft,
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: _line)),
                        ),
                        child: _pair(
                          _text(s.name.isEmpty ? 'Enter stop name' : s.name),
                          _sub((i + 1).toString().padLeft(2, '0')),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          _pair(
            TextButton(
              onPressed: p.stops.length < 100 ? ctl.addStop : null,
              child: const Text('+ Add stop'),
            ),
            _sub('Drag to reorder'),
          ),
          _button('Continue to timings', () => ctl.step(1)),
        ] else if (step == 1) ...[
          _section('Operating days'),
          Wrap(
            spacing: 4,
            children: [
              for (final (i, d) in weekDays.indexed)
                FilterChip(
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  label: Text(['M', 'Tu', 'W', 'Th', 'F', 'Sa', 'Su'][i]),
                  selected: !p.offDays.contains(d),
                  onSelected: (_) => ctl.offDay(d),
                ),
            ],
          ),
          _card([
            for (var i = 0; i < p.stops.length; i++)
              _tile(
                Icons.schedule,
                p.stops[i].name,
                '',
                () => setTime(i),
                trailing: _text(
                  p.stops[i].minutes < 0
                      ? 'Set time'
                      : clock24(p.stops[i].minutes),
                ),
              ),
          ]),
          for (var i = 1; i < p.stops.length; i++)
            if (p.stops[i].minutes >= 0 &&
                (p.stops[i].minutes >= 1440 ||
                    p.stops[i].minutes <= p.stops[i - 1].minutes))
              _select(
                'Service day · ${p.stops[i].name}',
                p.stops[i].minutes ~/ 1440,
                {0: 'Service date', 1: 'Next day'},
                (v) => ctl.time(i, p.stops[i].minutes % 1440 + v * 1440),
              ),
          _button('Review trip', () => ctl.step(2)),
        ] else ...[
          _sub('${bus.name} · regular service'),
          _card([
            _section(routeName),
            _pair(
              _sub('${p.stops.length} stops'),
              _pill(_days(p.offDays.toList())),
            ),
            const Divider(),
            _pair(
              _text('First departure'),
              _text(clock24(p.stops.first.minutes)),
            ),
            _pair(_text('Final arrival'), _text(clock24(p.stops.last.minutes))),
            const Divider(),
            for (final s in [p.stops.first, p.stops.last])
              _tile(
                Icons.signpost_outlined,
                s.name,
                s == p.stops.first ? 'Board here' : 'Alight here',
                null,
                trailing: _text(clock24(s.minutes)),
              ),
          ]),
          _button('Publish timetable', action.isLoading ? null : publish),
          _button(
            'Back to timings',
            action.isLoading ? null : () => ctl.step(1),
            secondary: true,
          ),
        ],
      ], staff: true),
    );
  }
}

class _Daily extends HookConsumerWidget {
  final BusEntity bus;
  final TripPlan trip;
  const _Daily(this.bus, this.trip);
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final selected = _choice(ref),
        date = ref.watch(operationDateProvider),
        key = serviceDateKey(date);
    if (ref.watch(ownerIdProvider) != bus.ownerId) return const _Owner();
    final changes = ref.watch(dailyAdjustmentIndexProvider(key));
    if (!changes.hasValue)
      return _Frame('Daily adjustments', [
        changes.hasError
            ? _button(
                'Retry daily changes',
                () => ref.invalidate(dailyAdjustmentsProvider(key)),
              )
            : _loading(),
      ], staff: true);
    final old = changes.requireValue[trip.id],
        args = (trip: trip, adjustment: old, date: key);
    final delays = ref.watch(delayDraftProvider(args)),
        ctl = ref.read(delayDraftProvider(args).notifier),
        status = ref.watch(runningStatusDraftProvider(args)),
        action = ref.watch(tripActionsProvider);
    final stop = trip.stops[selected.index], times = trip.expectedTimes(delays);
    Future<void> changeDate() async {
      final result = await showDatePicker(
        context: c,
        initialDate: date,
        firstDate: DateTime(date.year - 1),
        lastDate: DateTime(date.year + 2),
      );
      if (result != null && c.mounted)
        ref.read(operationDateProvider.notifier).select(result);
    }

    Future<void> save(bool reset) async {
      final act = ref.read(tripActionsProvider.notifier);
      final ok = reset
          ? await act.resetDelay(bus, trip, key)
          : await act.saveDelay(
              bus,
              trip,
              DailyAdjustment(
                tripId: trip.id,
                serviceDate: key,
                scheduleRevision: trip.revision,
                delays: delays,
                status: status,
              ),
            );
      if (ok && c.mounted) Navigator.pop(c);
    }

    return _Frame('Daily adjustments', [
      _ey('${bus.name} · ${trip.stops.first.name} to ${trip.stops.last.name}'),
      _title('Daily update'),
      _tile(
        Icons.calendar_today_outlined,
        'Service date',
        '${_day(date, long: true)} ${date.year}',
        changeDate,
      ),
      _select('Owner-reported status', status, {
        for (final v in RunningStatus.values) v: v.label,
      }, ref.read(runningStatusDraftProvider(args).notifier).select),
      _select('Apply from stop', selected.index, {
        for (var i = 0; i < trip.stops.length; i++) i: trip.stops[i].name,
      }, selected.select),
      _tile(
        Icons.more_time,
        'Additional delay',
        '${delays[stop.id] ?? 0} minutes',
        () async {
          final n = await _prompt(
            c,
            'Additional delay (minutes)',
            initial: '${delays[stop.id] ?? 0}',
            number: true,
          );
          if (n != null && c.mounted) {
            ctl.setDelay(stop.id, int.parse(n));
            if (int.parse(n) > 0 && status == RunningStatus.scheduled)
              ref
                  .read(runningStatusDraftProvider(args).notifier)
                  .select(RunningStatus.delayed);
          }
        },
      ),
      _card([
        _ey('Passenger preview'),
        for (final i in {selected.index, trip.stops.length - 1})
          _pair(
            _text(trip.stops[i].name),
            _sub('${clock24(trip.stops[i].minutes)} → ${clock24(times[i])}'),
          ),
      ], color: _mint),
      if (action.hasError) _notice(action.error.toString()),
      _button('Save daily update', action.isLoading ? null : () => save(false)),
      _button(
        'Reset this date',
        old == null || action.isLoading ? null : () => save(true),
        secondary: true,
      ),
    ], staff: true);
  }
}

class _Crew extends HookConsumerWidget {
  const _Crew();
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final filter = ref.watch(crewFilterProvider),
        text = useTextEditingController(text: filter.query),
        ctl = ref.read(crewFilterProvider.notifier),
        view = ref.watch(crewDataProvider),
        rows = ref.watch(filteredCrewProvider);
    const shifts = ['All', 'Morning', 'Evening', 'Standby'];
    return _Frame('Crew roster', [
      _ey('Operator workspace'),
      _title('Crew duty roster'),
      TextField(
        controller: text,
        onChanged: ctl.search,
        decoration: _input('Search crew or vehicle', icon: Icons.search),
      ),
      _segments(
        shifts,
        shifts.indexOf(filter.shift),
        (i) => ctl.shift(shifts[i]),
      ),
      if (view.isLoading) _loading(),
      if (view.hasError)
        _button('Retry roster', () => ref.invalidate(liveCrewProvider)),
      if (view.asData?.value.unavailable == true)
        _notice('Live assignments unavailable.'),
      for (final shift in shifts.skip(1))
        if (rows.any((r) => r.shift == shift)) ...[
          _section('$shift assignments'),
          for (final r in rows.where((r) => r.shift == shift))
            _card([
              if (view.asData?.value.isDemo == true) _ey('Example assignment'),
              _text(r.name, size: 18, weight: FontWeight.w800),
              _sub('${r.role} · ${r.vehicle}'),
              const Divider(),
              _pair(_sub('Duty'), _text(r.duty)),
              _pair(_sub('Shift'), _text(r.shift)),
            ]),
        ],
      if (view.hasValue && rows.isEmpty)
        _sub('No assignments match this selection.'),
    ], staff: true);
  }
}

class _EditStop extends HookWidget {
  final String name;
  final bool allowDelete;
  const _EditStop(this.name, {required this.allowDelete});
  @override
  Widget build(BuildContext c) {
    final text = useTextEditingController(text: name);
    useListenable(text);
    return AlertDialog(
      title: const Text('Edit stop'),
      content: TextField(
        controller: text,
        autofocus: true,
        maxLength: 100,
        decoration: _input('Stop name'),
      ),
      actions: [
        if (allowDelete)
          TextButton(
            onPressed: () => Navigator.pop(c, ('', true)),
            child: const Text('Remove stop'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: text.text.trim().isEmpty
              ? null
              : () => Navigator.pop(c, (text.text.trim(), false)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
