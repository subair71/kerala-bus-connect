import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/transit_constants.dart';
import '../../../../core/theme/home_theme.dart';
import '../../../timetables/presentation/widgets/stop_timings_sheet.dart';
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
    Widget stopField(bool origin) => Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: HomeTheme.field,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: origin
                ? Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: HomeTheme.primary.withValues(alpha: .10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.circle,
                      size: 15,
                      color: HomeTheme.primary,
                    ),
                  )
                : const Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: HomeTheme.primary,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  origin ? 'From Origin' : 'To Destination',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: HomeTheme.muted,
                  ),
                ),
                Semantics(
                  label: origin ? 'From Origin' : 'To Destination',
                  child: TextField(
                    key: ValueKey(origin ? 'search-from' : 'search-to'),
                    controller: origin ? from : to,
                    onChanged: origin ? controller.from : controller.to,
                    textInputAction: origin
                        ? TextInputAction.next
                        : TextInputAction.search,
                    onSubmitted: (_) => origin
                        ? FocusScope.of(context).nextFocus()
                        : FocusScope.of(context).unfocus(),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: HomeTheme.text,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: origin ? 'Clear boarding stop' : 'Clear destination',
            onPressed: () => origin ? controller.from('') : controller.to(''),
            color: HomeTheme.muted,
            icon: const Icon(Icons.cancel_outlined, size: 18),
          ),
        ],
      ),
    );
    Widget swap(bool wide) => IconButton(
      key: const ValueKey('swap-stops'),
      tooltip: 'Swap stops',
      onPressed: controller.swap,
      padding: EdgeInsets.zero,
      icon: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: HomeTheme.mint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          wide ? Icons.swap_horiz : Icons.swap_vert,
          size: 23,
          color: HomeTheme.primary,
        ),
      ),
    );
    final days = ['All Days', ...weekDays];
    Widget dayPicker() => SizedBox(
      height: 48,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 6,
            bottom: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: HomeTheme.field,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: query.filterDay,
                icon: const Icon(Icons.expand_more, size: 16),
                selectedItemBuilder: (context) => [
                  for (final day in days)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 17,
                          color: HomeTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          day,
                          style: const TextStyle(
                            fontSize: 12,
                            color: HomeTheme.text,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                ],
                items: [
                  for (final day in days)
                    DropdownMenuItem(
                      value: day,
                      child: Text(day, style: const TextStyle(fontSize: 13)),
                    ),
                ],
                onChanged: (day) {
                  if (day != null) controller.day(day);
                },
              ),
            ),
          ),
        ],
      ),
    );
    Widget running() => MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Flexible(
            child: Text(
              'Running today',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: HomeTheme.text,
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (query.onlyRunningToday)
            const Icon(Icons.circle, size: 7, color: HomeTheme.positive),
          SizedBox(
            width: 60,
            child: Transform.scale(
              scale: .85,
              child: Switch(
                value: query.onlyRunningToday,
                activeTrackColor: HomeTheme.primary,
                onChanged: controller.runningToday,
              ),
            ),
          ),
        ],
      ),
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
            final wide =
                constraints.maxWidth >= 700 &&
                MediaQuery.textScalerOf(context).scale(14) <= 18;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xffe4f4f1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.directions_bus_outlined,
                        size: 23,
                        color: HomeTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Find a bus',
                            style: TextStyle(
                              fontSize: 22,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.6,
                              color: HomeTheme.text,
                            ),
                          ),
                          Text(
                            'Kerala Transit Corridors',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: HomeTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!wide) swap(false),
                  ],
                ),
                const SizedBox(height: 22),
                if (wide)
                  Row(
                    children: [
                      Expanded(child: stopField(true)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: swap(true),
                      ),
                      Expanded(child: stopField(false)),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () => FocusScope.of(context).unfocus(),
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Search'),
                      ),
                    ],
                  )
                else ...[
                  stopField(true),
                  const SizedBox(
                    height: 10,
                    child: Align(
                      alignment: Alignment(-.88, 0),
                      child: SizedBox(
                        width: 1,
                        child: ColoredBox(color: HomeTheme.mint),
                      ),
                    ),
                  ),
                  stopField(false),
                ],
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [dayPicker(), running()],
                ),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    const Text(
                        'Frequent corridor stops',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: HomeTheme.muted,
                        ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: HomeTheme.primary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        final first = ref
                            .read(departureResultsProvider)
                            .asData
                            ?.value
                            .firstOrNull;
                        if (first == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No matching route is available for these stops.',
                              ),
                            ),
                          );
                          return;
                        }
                        showStopTimings(
                          context,
                          first,
                          from: query.from,
                          to: query.to,
                          day: query.filterDay,
                        );
                      },
                      child: const Text('View corridor stops'),
                    ),
                  ],
                ),
                SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(13) + 27,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: stops.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final stop = stops[index];
                      final selected = stop == query.from || stop == query.to;
                      return ActionChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selected) ...[
                              const Icon(
                                Icons.check,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(stop),
                          ],
                        ),
                        side: BorderSide.none,
                        backgroundColor: selected
                            ? HomeTheme.primary
                            : HomeTheme.field,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        labelStyle: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected ? Colors.white : HomeTheme.text,
                        ),
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
              ],
            );
          },
        ),
      ),
    );
  }
}
