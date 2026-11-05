import 'package:flutter/material.dart';

Future<T?> openEditor<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(context: context, isScrollControlled: true,
      useSafeArea: true, showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * .85),
          child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: child),
        ),
      ));

Future<bool> confirmDelete(BuildContext context, String label) async =>
    await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Confirm deletion'),
      content: Text('Delete $label?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    )) ?? false;
