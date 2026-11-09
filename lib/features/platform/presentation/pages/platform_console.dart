import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/theme/home_theme.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../core/widgets/page_heading.dart';
import '../../domain/platform_forms.dart';
import '../providers/platform_providers.dart';

Future<void> openPlatformConsole(BuildContext context, {bool admin = false}) =>
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: HomeTheme.from(Theme.of(context)),
          child: PlatformConsole(admin: admin),
        ),
      ),
    );

const _ownerSections = {
  'advertisers': 'Advertisers',
  'sponsored_ads': 'Advertisements',
  'advertising_orders': 'Orders & renewals',
  'commissions': 'Commissions',
  'payouts': 'Payouts',
  'financial_stats': 'Monthly earnings',
  'platform_notifications': 'Renewal notices',
  'advertising_packages': 'Packages',
};
const _adminSections = {
  ..._ownerSections,
  'businesses': 'Bus owners',
  'services': 'Timetables',
  'routes': 'Routes',
  'stops': 'Verified stops',
  'schedule_reports': 'Timing reports',
  'owner_access': 'Account access',
  'analytics': 'Usage analytics',
};
typedef ConsoleKey = ({bool admin, String collection, String? cursor});
final consoleSelectionProvider = NotifierProvider.autoDispose
    .family<ConsoleSelection, ConsoleKey, bool>(ConsoleSelection.new);

class ConsoleSelection extends Notifier<ConsoleKey> {
  ConsoleSelection(this.admin);
  final bool admin;
  @override
  ConsoleKey build() => (admin: admin, collection: 'advertisers', cursor: null);
  void select(String collection) =>
      state = (admin: admin, collection: collection, cursor: null);
  void next(String cursor) =>
      state = (admin: admin, collection: state.collection, cursor: cursor);
}

class PlatformConsole extends ConsumerWidget {
  final bool admin;
  const PlatformConsole({super.key, this.admin = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(consoleSelectionProvider(admin));
    final key = (collection: selection.collection, cursor: selection.cursor);
    final records = ref.watch(platformRecordsProvider(key));
    final sections = admin ? _adminSections : _ownerSections;
    final actions = admin
        ? [
            'savePackage',
            'configureCommission',
            'reviewAd',
            'verifyPayment',
            'recordPayout',
            'refundOrder',
            'cancelAd',
            'saveStop',
            'ownerAccess',
            'changeAttribution',
            'reviewSchedule',
            'reviewReport',
          ]
        : [
            'registerAdvertiser',
            'submitAd',
            'createOrder',
            'submitReceipt',
            'cancelOrder',
          ];
    return Scaffold(
      appBar: AppBar(
        title: Text(admin ? 'Administration' : 'Advertising & earnings'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PageHeading(
                        title: admin
                            ? 'Platform administration'
                            : 'Your advertising partnerships',
                        subtitle: admin
                            ? 'Review operations, verify payments and manage packages.'
                            : 'Bus management stays free. Commissions apply to verified advertising payments.',
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final action in actions)
                            OutlinedButton(
                              onPressed: () => showPlatformForm(
                                context,
                                platformForms[action]!,
                              ),
                              child: Text(platformForms[action]!.title),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selection.collection,
                        decoration: const InputDecoration(labelText: 'View'),
                        items: [
                          for (final entry in sections.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null)
                            ref
                                .read(consoleSelectionProvider(admin).notifier)
                                .select(value);
                        },
                      ),
                      if (selection.cursor != null)
                        TextButton(
                          onPressed: () => ref
                              .read(consoleSelectionProvider(admin).notifier)
                              .select(selection.collection),
                          child: const Text('Back to first page'),
                        ),
                    ],
                  ),
                ),
              ),
              records.when(
                loading: () => const LoadingSliver(
                  layout: SkeletonLayout.businesses,
                  count: 3,
                  label: 'Loading dashboard',
                ),
                error: (_, _) => SliverToBoxAdapter(
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(platformRecordsProvider(key)),
                    child: const Text(
                      'Unable to load this view. Check your access or retry.',
                    ),
                  ),
                ),
                data: (data) {
                  final rows = List<Map<String, dynamic>>.from(
                    (data['records'] as List).map(
                      (r) => Map<String, dynamic>.from(r as Map),
                    ),
                  );
                  return SliverMainAxisGroup(
                    slivers: [
                      if (rows.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No records yet.'),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, i) =>
                              _RecordCard(record: rows[i]),
                        ),
                      ),
                      if (data['cursor'] != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: OutlinedButton(
                              onPressed: () => ref
                                  .read(
                                    consoleSelectionProvider(admin).notifier,
                                  )
                                  .next(data['cursor'] as String),
                              child: const Text('Next page'),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String displayPlatformValue(String key, dynamic value) {
  if (key.endsWith('Paise') && value is num)
    return '₹${(value / 100).toStringAsFixed(2)}';
  if (key.endsWith('BasisPoints') && value is num) return '${value / 100}%';
  if ((key.endsWith('At') ||
          key == 'paidUntil' ||
          key == 'periodStart' ||
          key == 'periodEnd' ||
          key == 'expiresAt') &&
      value is num &&
      value > 1000000000000) {
    return DateTime.fromMillisecondsSinceEpoch(
      value.toInt(),
    ).toLocal().toString().split('.').first;
  }
  if (value is List) return value.where((v) => v is! Map).join(', ');
  return value?.toString() ?? '—';
}

class _RecordCard extends StatelessWidget {
  final Map<String, dynamic> record;
  const _RecordCard({required this.record});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            (record['name'] ??
                    record['title'] ??
                    record['routeName'] ??
                    record['month'] ??
                    record['id'])
                .toString(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (record['imageUrl'] is String)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Image.network(
                record['imageUrl'],
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text('Image unavailable'),
              ),
            ),
          for (final entry in record.entries)
            if (entry.value is! Map &&
                entry.key != 'imageUrl' &&
                entry.key != 'paidPeriods' &&
                entry.key != 'stopTimings')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: SelectableText(
                  '${entry.key.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]}')}: ${displayPlatformValue(entry.key, entry.value)}',
                ),
              ),
        ],
      ),
    ),
  );
}

Future<void> showPlatformForm(
  BuildContext context,
  PlatformForm form, {
  Map<String, Object?> initial = const {},
}) => showDialog<void>(
  context: context,
  builder: (_) => _PlatformFormDialog(form: form, initial: initial),
);

class _PlatformFormDialog extends HookConsumerWidget {
  final PlatformForm form;
  final Map<String, Object?> initial;
  const _PlatformFormDialog({required this.form, required this.initial});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllers = useMemoized(
      () => {
        for (final field in form.fields)
          field.name: TextEditingController(
            text:
                initial[field.name]?.toString() ??
                (field.type == 'boolean'
                    ? 'true'
                    : field.type == 'workflow'
                    ? 'ownerCollected'
                    : field.type == 'approval'
                    ? 'approved'
                    : ''),
          ),
      },
    );
    useEffect(
      () => () {
        for (final c in controllers.values) {
          c.dispose();
        }
      },
      [controllers],
    );
    final requestId = useMemoized(operationId);
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final action = ref.watch(platformActionProvider);
    return AlertDialog(
      title: Text(form.title),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (form.action == 'createOrder')
                  const Text(
                    'Owner collected: remit the platform share and retain your commission. Direct payment: the advertiser pays FindMyBus, then commission becomes payable. No automatic charges.',
                  ),
                if (form.action == 'refundOrder')
                  const Text(
                    'Use only after the full refund has been completed outside the app. Paid or retained commissions become recoverable.',
                  ),
                for (final field in form.fields)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child:
                        ['boolean', 'workflow', 'approval'].contains(field.type)
                        ? DropdownButtonFormField<String>(
                            initialValue: controllers[field.name]!.text,
                            decoration: InputDecoration(labelText: field.label),
                            isExpanded: true,
                            items: [
                              for (final value
                                  in field.type == 'boolean'
                                      ? ['true', 'false']
                                      : field.type == 'workflow'
                                      ? ['ownerCollected', 'direct']
                                      : ['approved', 'rejected'])
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    value == 'ownerCollected'
                                        ? 'Owner collects payment'
                                        : value == 'direct'
                                        ? 'Advertiser pays FindMyBus'
                                        : value,
                                  ),
                                ),
                            ],
                            onChanged: action.isLoading
                                ? null
                                : (value) =>
                                      controllers[field.name]!.text = value!,
                          )
                        : TextFormField(
                            controller: controllers[field.name],
                            enabled: !action.isLoading,
                            decoration: InputDecoration(
                              labelText: field.label,
                              suffixIcon: field.collection == null
                                  ? null
                                  : IconButton(
                                      tooltip: 'Choose ${field.label}',
                                      onPressed: () async {
                                        final selected =
                                            await showDialog<String>(
                                              context: context,
                                              builder: (_) => _ReferencePicker(
                                                collection: field.collection!,
                                              ),
                                            );
                                        if (selected != null) {
                                          final controller =
                                              controllers[field.name]!;
                                          controller.text =
                                              field.type == 'list' &&
                                                  controller.text.isNotEmpty
                                              ? '${controller.text},$selected'
                                              : selected;
                                        }
                                      },
                                      icon: const Icon(Icons.list),
                                    ),
                            ),
                            validator: (value) {
                              if (field.type == 'money' &&
                                  !RegExp(
                                    r'^\d+(\.\d{1,2})?$',
                                  ).hasMatch(value ?? ''))
                                return 'Enter a positive amount with up to two decimals.';
                              if (field.type == 'integer' &&
                                  int.tryParse(value ?? '') == null)
                                return 'Enter a whole number.';
                              if (field.type == 'decimal' &&
                                  double.tryParse(value ?? '') == null)
                                return 'Enter a number.';
                              return null;
                            },
                          ),
                  ),
                if (action.hasError)
                  Text(
                    action.error.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: action.isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: action.isLoading
              ? null
              : () async {
                  if (!formKey.currentState!.validate()) return;
                  final data = <String, Object?>{...initial};
                  for (final field in form.fields) {
                    final value = controllers[field.name]!.text.trim();
                    data[field.name] = switch (field.type) {
                      'integer' => int.parse(value),
                      'decimal' => double.parse(value),
                      'money' => (double.parse(value) * 100).round(),
                      'boolean' => value == 'true',
                      'list' =>
                        value
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList(),
                      _ => value,
                    };
                  }
                  final saved = await ref
                      .read(platformActionProvider.notifier)
                      .run(form.action, data, requestId);
                  if (saved && context.mounted) Navigator.pop(context);
                },
          child: ActionShimmer(
            loading: action.isLoading,
            label: 'Confirm',
            child: const Text('Confirm'),
          ),
        ),
      ],
    );
  }
}

class _ReferencePicker extends ConsumerWidget {
  final String collection;
  const _ReferencePicker({required this.collection});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(referenceCursorProvider(collection));
    final key = (collection: collection, cursor: selection);
    return AlertDialog(
      title: const Text('Choose a record'),
      content: SizedBox(
        width: 480,
        height: 400,
        child: ref
            .watch(platformRecordsProvider(key))
            .when(
              loading: () => const AppShimmer(
                child: SkeletonText(height: 16),
                label: 'Loading choices',
              ),
              error: (_, _) => const Text(
                'Choices unavailable. Check access and try again.',
              ),
              data: (data) => ListView(
                children: [
                  for (final item in data['records'] as List)
                    ListTile(
                      title: Text(
                        (item['name'] ??
                                item['title'] ??
                                item['routeName'] ??
                                item['id'])
                            .toString(),
                      ),
                      subtitle: Text(
                        item['status']?.toString() ?? item['id'].toString(),
                      ),
                      onTap: () => Navigator.pop(context, item['id'] as String),
                    ),
                  if (data['cursor'] != null)
                    TextButton(
                      onPressed: () => ref
                          .read(referenceCursorProvider(collection).notifier)
                          .next(data['cursor'] as String),
                      child: const Text('More choices'),
                    ),
                ],
              ),
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

final referenceCursorProvider = NotifierProvider.autoDispose
    .family<ReferenceCursor, String?, String>(ReferenceCursor.new);

class ReferenceCursor extends Notifier<String?> {
  ReferenceCursor(this.collection);
  final String collection;
  @override
  String? build() => null;
  void next(String cursor) => state = cursor;
}
