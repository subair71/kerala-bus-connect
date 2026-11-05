import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../timetables/domain/entities/business_entity.dart';
import '../../../timetables/domain/entities/route_entity.dart';
import '../providers/owner_providers.dart';

class RouteEditor extends HookConsumerWidget {
  final BusinessEntity business;
  final RouteEntity? route;
  const RouteEditor({super.key, required this.business, this.route});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = useTextEditingController(text: route?.name ?? '');
    final from = useTextEditingController(text: route?.startStop ?? '');
    final to = useTextEditingController(text: route?.endStop ?? '');
    final stops = useTextEditingController(
      text: route == null || route!.stops.length < 3
          ? ''
          : route!.stops.sublist(1, route!.stops.length - 1).join(', '),
    );
    final returnKey = '${business.id}/${route?.id ?? 'new'}';
    final generateReturn = ref.watch(returnRouteProvider(returnKey));
    final action = ref.watch(ownerActionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          route == null ? 'Create route' : 'Edit route',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Route name (optional)'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('route-from'),
          controller: from,
          decoration: const InputDecoration(labelText: 'Starting stop'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('route-to'),
          controller: to,
          decoration: const InputDecoration(labelText: 'Ending stop'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: stops,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Intermediate stops, separated by commas',
          ),
        ),
        if (route == null)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Also create the return route'),
            value: generateReturn,
            onChanged: (value) => ref
                .read(returnRouteProvider(returnKey).notifier)
                .update(value ?? false),
          ),
        if (action.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              action.error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: action.isLoading
              ? null
              : () async {
                  final saved = await ref
                      .read(ownerActionsProvider.notifier)
                      .saveRoute(
                        business: business,
                        name: name.text,
                        from: from.text,
                        to: to.text,
                        stops: stops.text,
                        returnRoute: route == null && generateReturn,
                        id: route?.id,
                      );
                  if (saved && context.mounted) Navigator.pop(context);
                },
          child: Text(action.isLoading ? 'Saving…' : 'Save route'),
        ),
      ],
    );
  }
}
