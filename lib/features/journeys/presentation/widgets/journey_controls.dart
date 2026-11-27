import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../domain/journey_filters.dart';
import '../providers/journey_providers.dart';
import '../../../passenger/presentation/providers/search_providers.dart';
import '../../../places/presentation/widgets/place_text_field.dart';
import '../../../places/presentation/providers/places_providers.dart';

Future<void> openJourneyTime(BuildContext context, WidgetRef ref) async {
  final query = ref.read(searchQueryProvider);
  final today = ref.read(journeyTodayProvider);
  final filters = ref.read(journeyFiltersProvider);
  final choice = await Navigator.of(context).push<({DateTime date, int? time})>(
    MaterialPageRoute(
      builder: (_) => _JourneyTimePage(
        today: today,
        date: query.serviceDate ?? today,
        time: filters.after,
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  ref.read(searchQueryProvider.notifier).journeyDate(choice.date);
  ref
      .read(journeyFiltersProvider.notifier)
      .apply(
        JourneyFilters(
          after: choice.time,
          status: filters.status,
          hideCancelled: filters.hideCancelled,
        ),
      );
}

typedef _TimeChoice = ({DateTime date, int? time});

final _draftTimeProvider = NotifierProvider.autoDispose
    .family<_TimeDraft, _TimeChoice, _TimeChoice>(_TimeDraft.new);

class _TimeDraft extends Notifier<_TimeChoice> {
  final _TimeChoice initial;
  _TimeDraft(this.initial);
  @override
  _TimeChoice build() => initial;
  void day(DateTime value) => state = (date: value, time: state.time);
  void after(int? value) => state = (date: state.date, time: value);
}

class _JourneyTimePage extends ConsumerWidget {
  final DateTime today, date;
  final int? time;
  const _JourneyTimePage({
    required this.today,
    required this.date,
    required this.time,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = DateUtils.dateOnly(date.isBefore(today) ? today : date);
    final provider = _draftTimeProvider((date: initial, time: time));
    final draft = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final format = MaterialLocalizations.of(context);
    Future<void> chooseTime() async {
      final current = draft.time ?? 540;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
        helpText: 'Boarding time · IST',
      );
      if (time != null && context.mounted)
        controller.after(time.hour * 60 + time.minute);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Journey time')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'When are you leaving?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text('Choose a service date and boarding time.'),
            Card(
              child: CalendarDatePicker(
                initialDate: initial,
                firstDate: DateUtils.dateOnly(today),
                lastDate: DateTime(today.year + 1, today.month, today.day),
                currentDate: today,
                onDateChanged: controller.day,
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Boarding time'),
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Any time'),
                  selected: draft.time == null,
                  onSelected: (_) => controller.after(null),
                ),
                ChoiceChip(
                  label: Text(
                    draft.time == null
                        ? 'Leave after'
                        : 'After ${clock24(draft.time)} IST',
                  ),
                  selected: draft.time != null,
                  onSelected: (_) => chooseTime(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop((date: draft.date, time: draft.time)),
              child: Text(
                'Use ${format.formatShortDate(draft.date)} · ${draft.time == null ? 'any time' : clock24(draft.time)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> pickAfter(BuildContext context, WidgetRef ref) async {
  final filters = ref.read(journeyFiltersProvider);
  final m = filters.after ?? 540;
  final value = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    helpText: 'Leave after · Kerala time',
  );
  if (value != null && context.mounted)
    ref
        .read(journeyFiltersProvider.notifier)
        .apply(
          JourneyFilters(
            after: value.hour * 60 + value.minute,
            status: filters.status,
            hideCancelled: filters.hideCancelled,
          ),
        );
}

Future<String?> chooseStop(
  BuildContext context, {
  String title = 'Choose a stop',
  String initial = '',
}) => Navigator.of(context).push<String>(
  MaterialPageRoute(
    builder: (_) => StopChooser(title: title, initial: initial),
  ),
);

class StopChooser extends HookConsumerWidget {
  final String title, initial;
  const StopChooser({super.key, required this.title, this.initial = ''});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = useTextEditingController(text: initial);
    useListenable(text);
    final options = ref.watch(stopLabelsProvider).matching(text.text);
    final book = ref.watch(journeyBookProvider).asData?.value ?? [];
    final recent = book.where((e) => e.kind == 'recent').toList();
    final saved = book.where((e) => e.kind == 'stop').toList();
    final closed = useRef(false);
    void choose(String value) {
      final name = value.trim();
      if (name.isEmpty || closed.value) return;
      closed.value = true;
      ref
          .read(journeyBookProvider.notifier)
          .edit(SavedJourney('recent', name, from: name))
          .ignore();
      Navigator.pop(context, name);
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              title == 'Choose destination' ? 'Where to?' : 'Choose a stop',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            PlaceTextField(
              controller: text,
              onSelected: choose,
              onSubmitted: choose,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search a stop or place',
              ),
            ),
            if (text.text.trim().isNotEmpty)
              TextButton(
                onPressed: () => choose(text.text),
                child: Text('Use ${text.text.trim()}'),
              ),
            if (options.isNotEmpty)
              const ListTile(title: Text('Timetable stops')),
            for (final stop in options)
              ListTile(
                leading: const Icon(Icons.directions_bus_outlined),
                title: Text(stop),
                onTap: () => choose(stop),
              ),
            for (final group in [
              (title: 'Recent', rows: recent),
              (title: 'Saved stops', rows: saved),
            ])
              if (group.rows.isNotEmpty) ...[
                ListTile(title: Text(group.title)),
                for (final item in group.rows.take(6))
                  ListTile(
                    leading: Icon(
                      item.kind == 'stop'
                          ? Icons.bookmark_outline
                          : Icons.history,
                    ),
                    title: Text(item.name),
                    onTap: () => choose(item.from),
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(journeyFiltersProvider);
    void apply({TimetableStatus? status, bool? hide, bool resetTime = false}) =>
        ref
            .read(journeyFiltersProvider.notifier)
            .apply(
              JourneyFilters(
                status: status ?? f.status,
                after: resetTime ? null : f.after,
                hideCancelled: hide ?? f.hideCancelled,
              ),
            );
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            'Filter buses',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          ListTile(
            title: const Text('Leave after'),
            subtitle: Text(f.after == null ? 'Any time' : clock24(f.after)),
            onTap: () => pickAfter(context, ref),
            trailing: IconButton(
              tooltip: 'Clear time',
              icon: const Icon(Icons.clear),
              onPressed: () => apply(resetTime: true),
            ),
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final item in TimetableStatus.values)
                ChoiceChip(
                  label: Text(
                    ['All services', 'Owner updated', 'Scheduled'][item.index],
                  ),
                  selected: f.status == item,
                  onSelected: (_) => apply(status: item),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hide cancelled trips'),
            value: f.hideCancelled,
            onChanged: (v) => apply(hide: v),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Show buses'),
          ),
          TextButton(
            onPressed: () => ref
                .read(journeyFiltersProvider.notifier)
                .apply(const JourneyFilters()),
            child: const Text('Reset filters'),
          ),
        ],
      ),
    );
  }
}

class SaveButton extends ConsumerWidget {
  final SavedJourney item;
  const SaveButton(this.item, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved =
        ref
            .watch(journeyBookProvider)
            .asData
            ?.value
            .any((e) => e.key == item.key) ??
        false;
    return OutlinedButton.icon(
      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_outline),
      label: Text(saved ? 'Saved' : 'Save ${item.kind}'),
      onPressed: () async {
        try {
          await ref
              .read(journeyBookProvider.notifier)
              .edit(item, remove: saved);
        } catch (_) {
          if (context.mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not save on this device. Please retry.'),
              ),
            );
        }
      },
    );
  }
}
