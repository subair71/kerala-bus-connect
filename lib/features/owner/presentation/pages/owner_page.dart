import '../../../platform/presentation/pages/platform_console.dart';
import '../../../platform/presentation/providers/platform_providers.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/widgets/async_status.dart';
import '../../../../core/widgets/editor_sheet.dart';
import '../../../../core/widgets/page_heading.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/auth_panel.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../../trips/presentation/widgets/bus_trip_dashboard.dart';
import '../providers/owner_providers.dart';
import '../widgets/business_editor.dart';
import '../widgets/sample_owner_preview.dart';

class OwnerPage extends ConsumerWidget {
  const OwnerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(authUserProvider)
      .when(
        loading: () => const AccountSkeleton(),
        error: (_, _) => AsyncStatus(
          message: 'Unable to check your account.',
          retry: () => ref.invalidate(authUserProvider),
        ),
        data: (user) => user == null
            ? const SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 720,
                    child: Column(
                      children: [AuthPanel(), SampleOwnerPreview()],
                    ),
                  ),
                ),
              )
            : _OwnerWorkspace(key: ValueKey(user.id)),
      );
}

class _OwnerWorkspace extends ConsumerWidget {
  const _OwnerWorkspace({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(ownerBusinessesProvider);
    final selected = ref.watch(selectedBusinessProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: CustomScrollView(
          key: const PageStorageKey('owner'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _OwnerHeader()),
            ),
            businesses.when(
              loading: () => const SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: LoadingSliver(
                  layout: SkeletonLayout.businesses,
                  count: 1,
                  label: 'Loading businesses',
                ),
              ),
              error: (_, _) => SliverToBoxAdapter(
                child: AsyncStatus(
                  message: 'Unable to load your businesses.',
                  retry: () => ref.invalidate(ownerBusinessesProvider),
                ),
              ),
              data: (list) => list.isEmpty
                  ? const SliverToBoxAdapter(
                      child: AsyncStatus(
                        message: 'Create your first business to add buses.',
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String>(
                                  key: ValueKey('business-${selected?.id}'),
                                  initialValue: selected?.id,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Business',
                                  ),
                                  items: [
                                    for (final business in list)
                                      DropdownMenuItem(
                                        value: business.id,
                                        child: Text(
                                          business.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (id) {
                                    if (id != null)
                                      ref
                                          .read(
                                            selectedBusinessIdProvider.notifier,
                                          )
                                          .select(id);
                                  },
                                ),
                                if (selected != null)
                                  Consumer(
                                    builder: (context, ref, _) => Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton(
                                        onPressed:
                                            ref.watch(
                                              ownerActionsProvider.select(
                                                (value) => value.isLoading,
                                              ),
                                            )
                                            ? null
                                            : () => openEditor(
                                                context,
                                                BusinessEditor(
                                                  business: selected,
                                                ),
                                              ),
                                        child: const Text('Rename business'),
                                      ),
                                    ),
                                  ),
                                const Divider(height: 32),
                              ],
                            ),
                          ),
                          if (selected != null)
                            BusTripDashboard(
                              key: ValueKey(selected.id),
                              business: selected,
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerHeader extends ConsumerWidget {
  const _OwnerHeader();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(ownerActionsProvider);
    final authAction = ref.watch(authActionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeading(
          title: 'Owner portal',
          subtitle: 'Manage your buses, trips and daily timings.',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (ref.watch(platformEnabledProvider)) OutlinedButton(
              onPressed: () => openPlatformConsole(context), child: const Text('Advertising & earnings')),
            if (ref.watch(administratorProvider).asData?.value == true) OutlinedButton(
              onPressed: () => openPlatformConsole(context, admin: true), child: const Text('Administration')),
            FilledButton.icon(
              onPressed: action.isLoading
                  ? null
                  : () => openEditor(context, const BusinessEditor()),
              icon: const Icon(Icons.add_business),
              label: const Text('Add business'),
            ),
            OutlinedButton(
              onPressed: authAction.isLoading
                  ? null
                  : () => ref.read(authActionProvider.notifier).signOut(),
              child: ActionShimmer(
                loading: authAction.isLoading,
                label: 'Sign out',
                child: const Text('Sign out'),
              ),
            ),
          ],
        ),
        if (action.hasError || authAction.hasError)
          Text(
            (action.error ?? authAction.error).toString(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
