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
        controller.value = TextEditingValue(text: text,
          selection: TextSelection.collapsed(offset: text.length));
      }
      sync(from, next.from); sync(to, next.to);
    });
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(key: const ValueKey('search-from'), controller: from, onChanged: controller.from,
          decoration: InputDecoration(labelText: 'From', prefixIcon: const Icon(Icons.my_location),
            suffixIcon: IconButton(tooltip: 'Clear boarding stop', onPressed: () => controller.from(''), icon: const Icon(Icons.close)))),
        Align(alignment: Alignment.centerRight, child: IconButton(
          key: const ValueKey('swap-stops'), tooltip: 'Swap stops', onPressed: controller.swap,
          icon: const Icon(Icons.swap_vert))),
        TextField(key: const ValueKey('search-to'), controller: to, onChanged: controller.to,
          decoration: InputDecoration(labelText: 'To', prefixIcon: const Icon(Icons.place),
            suffixIcon: IconButton(tooltip: 'Clear destination', onPressed: () => controller.to(''), icon: const Icon(Icons.close)))),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final stop in popularKeralaStops.take(6))
            ActionChip(label: Text(stop), onPressed: () => controller.to(stop)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DropdownButton<String>(value: query.filterDay,
            items: [for (final day in ['All Days', ...weekDays]) DropdownMenuItem(value: day, child: Text(day))],
            onChanged: (day) { if (day != null) controller.day(day); }),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Running today'),
            Switch(value: query.onlyRunningToday, onChanged: controller.runningToday),
          ]),
        ]),
      ],
    )));
  }
}
