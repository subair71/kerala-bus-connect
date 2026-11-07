import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../domain/services/stop_labels.dart';
import '../providers/places_providers.dart';

/// Native Flutter input and accessible keyboard/touch autocomplete on all targets.
class PlaceTextField extends HookConsumerWidget {
  final Key? fieldKey;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged, onSubmitted;
  final InputDecoration decoration;
  final TextStyle? style;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool enabled, commaSeparated;
  final int? minLines, maxLines;

  const PlaceTextField({
    super.key,
    this.fieldKey,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.decoration = const InputDecoration(),
    this.style,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.words,
    this.enabled = true,
    this.commaSeparated = false,
    this.minLines,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = useMemoized(Object.new);
    final focus = useFocusNode();
    final search = ref.watch(placeSearchProvider(identity));
    final notifier = ref.read(placeSearchProvider(identity).notifier);
    useEffect(() {
      void onFocus() {
        if (!focus.hasFocus) notifier.dismiss();
      }
      focus.addListener(onFocus);
      return () => focus.removeListener(onFocus);
    }, [focus, notifier]);
    return LayoutBuilder(builder: (context, constraints) {
      return RawAutocomplete<PlaceOption>(
        textEditingController: controller,
        focusNode: focus,
        displayStringForOption: (option) => option.value,
        optionsBuilder: (value) {
          if (!enabled || !focus.hasFocus || (value.composing.isValid && !value.composing.isCollapsed)) return const <PlaceOption>[];
          return notifier.search(StopInput(
            value.text,
            value.selection.baseOffset < 0 ? value.text.length : value.selection.baseOffset,
            multiple: commaSeparated,
          ));
        },
        onSelected: (option) {
          onChanged?.call(option.value);
          notifier.dismiss();
          focus.unfocus();
        },
        fieldViewBuilder: (context, text, node, submit) => TextField(
          key: fieldKey,
          controller: text,
          focusNode: node,
          enabled: enabled,
          onChanged: onChanged,
          onSubmitted: (value) {
            submit();
            onSubmitted?.call(controller.text);
          },
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          minLines: minLines,
          maxLines: maxLines,
          style: style,
          decoration: search.loading && decoration.suffixIcon == null
              ? decoration.copyWith(
                  suffixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18, child: AppShimmer(
                      label: 'Finding places',
                      child: SkeletonBox.circle(size: 18),
                    )),
                  ),
                )
              : decoration,
        ),
        optionsViewBuilder: (context, select, options) => Consumer(
          builder: (context, ref, _) {
            final current = ref.watch(placeSearchProvider(identity));
            // Do not allow selection of an older query while its replacement loads.
            if (current.loading || current.query.isEmpty) return const SizedBox.shrink();
            final items = options.toList(growable: false);
            final hasGoogle = items.any((o) => o.source == PlaceSource.google);
            final googleEnabled = ref.watch(googlePlacesEnabledProvider);
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 3,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: items.length + (googleEnabled ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == items.length) {
                          return _PlacesFooter(
                            unavailable: current.unavailable,
                            hasGoogle: hasGoogle,
                          );
                        }
                        final item = items[index];
                        return ListTile(
                          key: ValueKey('place-option-$index'),
                          selected: AutocompleteHighlightedOption.of(context) == index,
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          minVerticalPadding: 10,
                          title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => select(item),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

class _PlacesFooter extends StatelessWidget {
  final bool unavailable, hasGoogle;
  const _PlacesFooter({required this.unavailable, required this.hasGoogle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          unavailable
              ? 'Google places unavailable. Keep typing or choose a timetable stop.'
              : hasGoogle
                  ? 'Google Maps'
                  : 'No additional Google places. You can use the entered name.',
          style: TextStyle(
            fontSize: hasGoogle && !unavailable ? 14 : 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (hasGoogle)
          Wrap(
            spacing: 8,
            children: [
              _PolicyLink('Privacy', 'https://subair71.github.io/kerala-bus-connect/places-privacy.html'),
              _PolicyLink('Terms', 'https://subair71.github.io/kerala-bus-connect/places-terms.html'),
            ],
          ),
      ],
    ),
  );
}

class _PolicyLink extends StatelessWidget {
  final String label, url;
  const _PolicyLink(this.label, this.url);
  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      minimumSize: Size(math.max(48, MediaQuery.textScalerOf(context).scale(32)), 48),
    ),
    onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    child: Text(label),
  );
}
