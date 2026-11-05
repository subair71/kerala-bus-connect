import 'package:flutter/material.dart';
import '../../../../core/widgets/editor_sheet.dart';
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
        EditorHeading(
          title: business == null ? 'Create business' : 'Rename business',
          icon: Icons.business_outlined,
        ),
        TextField(
          key: const ValueKey('business-name'),
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Business name',
            prefixIcon: Icon(Icons.business_outlined),
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
