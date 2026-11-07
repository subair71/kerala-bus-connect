import '../../../../core/widgets/data_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/widgets/async_status.dart';
import '../../../../core/widgets/page_heading.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../../timetables/presentation/widgets/service_card.dart';
import '../providers/route_query_provider.dart';

class RoutesPage extends HookConsumerWidget {
  const RoutesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController(
      text: ref.read(routeQueryProvider),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: CustomScrollView(
          key: const PageStorageKey('routes'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PageHeading(
                      title: 'Routes directory',
                      subtitle:
                          'Browse published services by route name or stop.',
                    ),
                    DataNotice(
                      demo:
                          ref
                              .watch(serviceCatalogProvider.select((data) => data.asData?.value.isDemo ?? false)),
                      unavailable:
                          ref
                              .watch(serviceCatalogProvider.select((data) => data.asData?.value.unavailable ?? false)),
                      retry: () => ref.invalidate(publishedServicesProvider),
                    ),
                    TextField(
                      controller: controller,
                      onChanged: ref.read(routeQueryProvider.notifier).update,
                      decoration: InputDecoration(
                        labelText: 'Search routes or stops',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            controller.clear();
                            ref.read(routeQueryProvider.notifier).update('');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: _RoutesList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutesList extends ConsumerWidget {
  const _RoutesList();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(directoryResultsProvider)
      .when(
        loading: () =>
            const SliverToBoxAdapter(child: AsyncStatus(loading: true)),
        error: (_, stack) => SliverToBoxAdapter(
          child: AsyncStatus(
            message: 'Unable to load routes.',
            retry: () => ref.invalidate(publishedServicesProvider),
          ),
        ),
        data: (services) => services.isEmpty
            ? const SliverToBoxAdapter(
                child: AsyncStatus(message: 'No matching published routes.'),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => ServiceCard(
                    key: ValueKey(services[i].id),
                    service: services[i],
                  ),
                  childCount: services.length,
                ),
              ),
      );
}
