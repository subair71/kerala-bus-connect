import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../timetables/domain/entities/business_entity.dart';
import '../providers/owner_providers.dart';

class BusinessEditor extends HookConsumerWidget {
  final BusinessEntity? business;
  const BusinessEditor({super.key, this.business});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = useTextEditingController(text: business?.name ?? '');
    final action = ref.watch(ownerActionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          business == null ? 'Create business' : 'Rename business',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('business-name'),
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Business name',
            border: OutlineInputBorder(),
          ),
        ),
        if (action.hasError)
          Text(
            action.error.toString(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: action.isLoading
              ? null
              : () async {
                  final saved = await ref
                      .read(ownerActionsProvider.notifier)
                      .saveBusiness(name.text, id: business?.id);
                  if (saved && context.mounted) Navigator.pop(context);
                },
          child: Text(action.isLoading ? 'Saving…' : 'Save business'),
        ),
      ],
    );
  }
}
