import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/transit_constants.dart';
import '../../../../core/theme/home_theme.dart';
import '../providers/search_providers.dart';

/// The catalog contains recurring weekdays, not date-specific bookings.
class JourneyDateStrip extends ConsumerWidget {
  const JourneyDateStrip({super.key});
  static const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates = ref.watch(journeyDatesProvider);
    final filterDay = ref.watch(searchQueryProvider.select((query) => query.filterDay));
    final selected = dates.where((date) => weekDays[date.weekday - 1] == filterDay).firstOrNull;
    final month = selected ?? dates.first;
    final scaler = MediaQuery.textScalerOf(context);
    final itemHeight = 32 + scaler.scale(18) * 1.3 + scaler.scale(12) * 1.4;
    final width = 28 + scaler.scale(32);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Journey date', style: TextStyle(fontSize: 14, color: HomeTheme.muted)),
          const SizedBox(height: 10),
          SizedBox(
            height: itemHeight,
            child: Row(
              children: [
                SizedBox(
                  width: 42 + scaler.scale(34),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 21, color: HomeTheme.muted),
                      Text(months[month.month - 1], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('${month.year}', style: const TextStyle(fontSize: 12, color: HomeTheme.muted)),
                    ],
                  ),
                ),
                const VerticalDivider(width: 18, indent: 14, endIndent: 8, color: HomeTheme.border),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 16),
                    itemCount: dates.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final date = dates[index];
                      final day = weekDays[date.weekday - 1];
                      final active = day == filterDay;
                      return Semantics(
                        button: true,
                        selected: active,
                        label: '${date.day} ${months[date.month - 1]} ${date.year}, $day',
                        child: InkWell(
                          key: ValueKey('journey-date-$index'),
                          borderRadius: BorderRadius.circular(13),
                          onTap: () => ref.read(searchQueryProvider.notifier).journeyDate(date),
                          child: SizedBox(
                            width: width,
                            child: Column(
                              children: [
                                SizedBox(
                                  height: scaler.scale(12) * 1.4,
                                  child: Text(index == 0 ? 'Today' : '',
                                    style: const TextStyle(fontSize: 12, height: 1.3, color: HomeTheme.accentInk)),
                                ),
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: active ? HomeTheme.primary : HomeTheme.field,
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(date.day.toString().padLeft(2, '0'),
                                          style: TextStyle(fontSize: 18, height: 1.2, fontWeight: FontWeight.w700, color: active ? Colors.white : HomeTheme.text)),
                                        Text(day.substring(0, 3),
                                          style: TextStyle(fontSize: 12, height: 1.2, color: active ? Colors.white : HomeTheme.muted)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text('Weekly timetable • select an operating day',
            style: TextStyle(fontSize: 10, color: HomeTheme.muted)),
        ],
      ),
    );
  }
}
