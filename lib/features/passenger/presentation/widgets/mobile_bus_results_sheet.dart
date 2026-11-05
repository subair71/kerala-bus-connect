import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/theme/home_theme.dart';
import '../providers/search_providers.dart';
import 'departure_results.dart';
import 'transit_advisory.dart';

Future<void> showMobileBusResults(BuildContext context) async {
  // The modal barrier and this route guard prevent duplicate sheets.
  if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
  FocusScope.of(context).unfocus();
  ProviderScope.containerOf(context, listen: false)
      .read(debouncedSearchProvider.notifier)
      .flush();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: HomeTheme.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => const MobileBusResultsSheet(),
  );
}

class MobileBusResultsSheet extends ConsumerWidget {
  const MobileBusResultsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(debouncedSearchProvider);
    final from = query.from.trim().isEmpty ? 'Any origin' : query.from;
    final to = query.to.trim().isEmpty ? 'Any destination' : query.to;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .86,
      minChildSize: .45,
      maxChildSize: .96,
      snap: true,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bus results',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: HomeTheme.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$from → $to',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: HomeTheme.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close bus results',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              key: const ValueKey('mobile-bus-results-list'),
              controller: scrollController,
              slivers: [
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(child: CatalogNotice()),
                ),
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  sliver: DeparturesSliver(),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: const SliverToBoxAdapter(child: TransitAdvisory()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
