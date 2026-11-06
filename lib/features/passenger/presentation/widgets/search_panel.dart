import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/theme/home_theme.dart';
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
          ],
        );
      },
    );
  }
}
