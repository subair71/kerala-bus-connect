import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/transit_constants.dart';
import '../../domain/entities/search_query.dart';
import '../providers/search_providers.dart';

class SearchPanel extends HookConsumerWidget {
  const SearchPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final from = useTextEditingController(text: query.from);
    final to = useTextEditingController(text: query.to);
    final controller = ref.read(searchQueryProvider.notifier);
    ref.listen<SearchQuery>(searchQueryProvider, (previous, next) {
      void sync(TextEditingController controller, String text) {
        if (controller.text == text) return;
        controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }

      sync(from, next.from);
      sync(to, next.to);
    });
    Widget stopField(bool origin) => TextField(
      key: ValueKey(origin ? 'search-from' : 'search-to'),
      controller: origin ? from : to,
      onChanged: origin ? controller.from : controller.to,
      textInputAction: origin ? TextInputAction.next : TextInputAction.search,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: origin ? 'From' : 'To',
        prefixIcon: Icon(
          origin ? Icons.trip_origin : Icons.place_outlined,
          size: 20,
        ),
        suffixIcon: IconButton(
          tooltip: origin ? 'Clear boarding stop' : 'Clear destination',
          onPressed: () => origin ? controller.from('') : controller.to(''),
          icon: const Icon(Icons.close, size: 18),
        ),
      ),
    );
    Widget swap(bool wide) => IconButton(
      key: const ValueKey('swap-stops'),
      tooltip: 'Swap stops',
      onPressed: controller.swap,
      color: Theme.of(context).colorScheme.primary,
      icon: Icon(wide ? Icons.swap_horiz : Icons.swap_vert),
    );
    Widget dayPicker() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: query.filterDay,
          icon: const Icon(Icons.expand_more, size: 18),
          items: [
            for (final day in ['All Days', ...weekDays])
              DropdownMenuItem(
                value: day,
                child: Text(day, style: const TextStyle(fontSize: 12)),
              ),
          ],
          onChanged: (day) {
            if (day != null) controller.day(day);
          },
        ),
      ),
    );
    Widget running() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Running today', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Switch(
          value: query.onlyRunningToday,
          onChanged: controller.runningToday,
        ),
      ],
    );
    final thrissur = query.from.toLowerCase().contains('thrissur');
    final stops = thrissur
        ? [
            'Thrissur Round',
            'Palakkad Stand',
            'Guruvayur',
            'Chalakudy',
            'Aluva',
          ]
        : [
            'Aluva',
            'Kaloor',
            'Infopark Kakkanad',
            'Edappally Toll',
            'Kalamassery',
            'Thrissur Round',
          ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide)
                  Row(
                    children: [
                      Expanded(child: stopField(true)),
                      swap(true),
                      Expanded(child: stopField(false)),
                      const SizedBox(width: 12),
                      dayPicker(),
                      const SizedBox(width: 12),
                      running(),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => FocusScope.of(context).unfocus(),
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Search'),
                      ),
                    ],
                  )
                else ...[
                  stopField(true),
                  Align(alignment: Alignment.centerRight, child: swap(false)),
                  stopField(false),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Frequent corridor stops',
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: stops.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final stop = stops[index];
                      return ActionChip(
                        label: Text(stop),
                        backgroundColor: stop == query.from
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        onPressed: () {
                          if (stop == 'Aluva' || stop == 'Thrissur Round') {
                            controller.from(stop);
                            controller.to(
                              stop == 'Aluva' ? 'Kaloor' : 'Palakkad Stand',
                            );
                          } else {
                            controller.to(stop);
                          }
                        },
                      );
                    },
                  ),
                ),
                if (!wide)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [dayPicker(), running()],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
