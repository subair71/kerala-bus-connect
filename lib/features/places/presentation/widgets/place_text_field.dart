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
  final Widget Function(Widget field)? fieldBuilder;
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
    this.fieldBuilder,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<PlaceOption>(
          optionsViewOpenDirection: OptionsViewOpenDirection.mostSpace,
          textEditingController: controller,
          focusNode: focus,
          displayStringForOption: (option) => option.value,
          optionsBuilder: (value) {
            if (!enabled ||
                !focus.hasFocus ||
                (value.composing.isValid && !value.composing.isCollapsed)) {
              notifier.dismiss();
              return const <PlaceOption>[];
            }
            return notifier.search(
              StopInput(
                value.text,
                value.selection.baseOffset < 0
                    ? value.text.length
                    : value.selection.baseOffset,
                multiple: commaSeparated,
              ),
            );
          },
          onSelected: (option) {
            onChanged?.call(option.value);
            notifier.dismiss();
          },
          fieldViewBuilder: (context, text, node, submit) {
            final field = TextField(
            key: fieldKey,
            controller: text,
            focusNode: node,
            enabled: enabled,
            onChanged: onChanged,
            onEditingComplete: () {},
            onTapOutside: (_) => focus.unfocus(),
            onSubmitted: (value) {
              final state = ref.read(placeSearchProvider(identity));
              if (!state.loading && state.query.isNotEmpty) submit();
              if (onSubmitted != null) {
                onSubmitted!(controller.text);
              } else {
                focus.unfocus();
              }
            },
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            minLines: minLines,
            maxLines: maxLines,
            style: style,
            decoration: search.loading && decoration.suffixIcon == null
                ? decoration.copyWith(
                    suffixIconConstraints: const BoxConstraints.tightFor(width: 24, height: 24),
                    suffixIcon: const Padding(
                      padding: EdgeInsets.all(4),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: AppShimmer(
                          label: 'Finding places',
                          child: SkeletonBox.circle(size: 16),
                        ),
                      ),
                    ),
                  )
                : decoration,
            );
            return fieldBuilder?.call(field) ?? field;
          },
          optionsViewBuilder: (context, select, options) => Consumer(
            builder: (context, ref, _) {
              final current = ref.watch(placeSearchProvider(identity));
              // Do not allow selection of an older query while its replacement loads.
              if (current.loading || current.query.isEmpty)
                return const SizedBox.shrink();
              final items = options.toList(growable: false);
              final hasGoogle = items.any(
                (o) => o.source == PlaceSource.google,
              );
              final googleEnabled = ref.watch(googlePlacesEnabledProvider) && current.query.runes.length >= 3;
              return Material(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < items.length; i++)
                              _PlaceOptionTile(option: items[i], index: i, select: select),
                            if (googleEnabled) _PlacesFooter(
                              unavailable: current.unavailable,
                              hasGoogle: hasGoogle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              );
            },
          ),
        );
      },
    );
  }
}

/// At most ten rows. Building this small bounded list allows keyboard focus
/// to reveal any highlighted row, including one outside the visible viewport.
class _PlaceOptionTile extends HookWidget {
  final PlaceOption option;
  final int index;
  final ValueChanged<PlaceOption> select;
  const _PlaceOptionTile({required this.option, required this.index, required this.select});
  @override
  Widget build(BuildContext context) {
    final selected = AutocompleteHighlightedOption.of(context) == index;
    useEffect(() {
      if (selected) WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Scrollable.ensureVisible(context, alignment: .5);
      });
      return null;
    }, [selected, option.value]);
    return ListTile(
      key: ValueKey('place-option-$index'),
      selected: selected,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      minVerticalPadding: 10,
      title: Text(option.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (option.source == PlaceSource.google)
            const Text('Google Maps', style: TextStyle(fontSize: 14)),
          Text(option.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
      onTap: () => select(option),
    );
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
        if (unavailable || !hasGoogle) Text(
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
              _PolicyLink(
                'Privacy',
                'https://subair71.github.io/kerala-bus-connect/places-privacy.html',
              ),
              _PolicyLink(
                'Terms',
                'https://subair71.github.io/kerala-bus-connect/places-terms.html',
              ),
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
      minimumSize: Size(
        math.max(48, MediaQuery.textScalerOf(context).scale(32)),
        48,
      ),
    ),
    onPressed: () =>
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    child: Text(label),
  );
}
