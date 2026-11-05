import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/transit_constants.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/theme/home_theme.dart';
import '../../../timetables/presentation/widgets/stop_timings_sheet.dart';
import '../../domain/entities/search_query.dart';
import '../providers/search_providers.dart';
import 'journey_date_strip.dart';

class SearchPanel extends HookConsumerWidget {
  final VoidCallback? onSearch;
  const SearchPanel({super.key, this.onSearch});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void submit() {
      FocusScope.of(context).unfocus();
      ref.read(debouncedSearchProvider.notifier).flush();
      onSearch?.call();
    }

    ref.watch(
      departureResultsProvider.select(
        (result) => result.asData?.value.firstOrNull,
      ),
    );
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
    final rowHeight = (28 + MediaQuery.textScalerOf(context).scale(40)).clamp(
      72.0,
      double.infinity,
    );
    Widget stopField(bool origin, {required bool wide}) => SizedBox(
      height: rowHeight,
      child: Padding(
        // Keep a separate touch lane for the swap control on the divider.
        padding: EdgeInsets.fromLTRB(16, 8, wide ? 12 : 68, 8),
        child: Row(
          children: [
            Icon(
              origin ? Icons.navigation_outlined : Icons.location_on_outlined,
              size: 24,
              color: HomeTheme.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    origin ? 'Leaving From' : 'Going To',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
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
                          : submit(),
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                        color: HomeTheme.text,
                      ),
                      decoration: InputDecoration(
                        hintText: origin
                            ? 'Choose origin'
                            : 'Choose destination',
                        hintStyle: const TextStyle(
                          fontSize: 16,
                          color: HomeTheme.muted,
                        ),
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
              icon: const Icon(Icons.cancel_outlined, size: 17),
            ),
          ],
        ),
      ),
    );
    Widget swap(bool wide) => IconButton(
      key: const ValueKey('swap-stops'),
      tooltip: 'Swap stops',
      onPressed: controller.swap,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: HomeTheme.text,
        minimumSize: const Size(48, 48),
        shape: const CircleBorder(
          side: BorderSide(color: HomeTheme.border, width: 1.5),
        ),
      ),
      icon: Icon(wide ? Icons.swap_horiz : Icons.swap_vert, size: 27),
    );
    final days = ['All Days', ...weekDays];
    Widget dayPicker(double maxWidth) => SizedBox(
      width: (MediaQuery.textScalerOf(context).scale(72) + 64).clamp(
        0.0,
        maxWidth,
      ),
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
                isExpanded: true,
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
                        Expanded(
                          child: Text(
                            day,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: HomeTheme.text,
                            ),
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
                onChanged: (value) {
                  if (value) controller.day(ref.read(todayProvider));
                  controller.runningToday(value);
                },
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 700 &&
            MediaQuery.textScalerOf(context).scale(14) <= 18;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: HomeTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide)
                    Row(
                      children: [
                        Expanded(child: stopField(true, wide: true)),
                        swap(true),
                        Expanded(child: stopField(false, wide: true)),
                      ],
                    )
                  else
                    Stack(
                      children: [
                        Column(
                          children: [
                            stopField(true, wide: false),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: HomeTheme.border,
                            ),
                            stopField(false, wide: false),
                          ],
                        ),
                        Positioned(
                          top: rowHeight - 24,
                          right: 16,
                          child: swap(false),
                        ),
                      ],
                    ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: HomeTheme.border,
                  ),
                  const JourneyDateStrip(),
                  FilledButton(
                    key: const ValueKey('show-bus-results'),
                    onPressed: submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: HomeTheme.primary,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(),
                      minimumSize: const Size(48, 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    child: const Text(
                      'Search buses',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ExpansionTile(
              key: const PageStorageKey('passenger-search-filters'),
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const Icon(Icons.tune, size: 20),
              title: const Text(
                'Filters & frequent stops',
                style: TextStyle(fontSize: 13),
              ),
              children: [
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [dayPicker(constraints.maxWidth), running()],
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
                        ref.read(debouncedSearchProvider.notifier).flush();
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
                    key: const PageStorageKey('corridor-stops'),
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
            ),
          ],
        );
      },
    );
  }
}
