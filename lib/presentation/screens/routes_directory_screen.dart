import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/colors.dart';
import '../../domain/entities/service_entity.dart';
import '../blocs/passenger/published_services_cubit.dart';
import '../widgets/debounced_builder.dart';
import '../widgets/train_route_view.dart';

class RoutesDirectoryScreen extends StatefulWidget {
  const RoutesDirectoryScreen({super.key});

  @override
  State<RoutesDirectoryScreen> createState() => _RoutesDirectoryScreenState();
}

class _RoutesDirectoryScreenState extends State<RoutesDirectoryScreen> {
  final searchController = TextEditingController();
  final queryNotifier = ValueNotifier<String>('');

  @override
  void dispose() {
    searchController.dispose();
    queryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 852),
        child: CustomScrollView(
          key: const PageStorageKey('routes-directory'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TRANSIT NETWORK',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: AppColors.secondary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Routes Directory',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'All active lines, stop sequences, and connecting junction paths.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Search Filter Field
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: searchController,
                        onChanged: (val) =>
                            queryNotifier.value = val.trim().toLowerCase(),
                        decoration: InputDecoration(
                          icon: const Icon(Icons.search,
                              color: AppColors.outline),
                          hintText:
                              'Search by route name or stop (e.g. Aluva, Fort Kochi)',
                          hintStyle: const TextStyle(
                              fontSize: 13, color: AppColors.outlineVariant),
                          border: InputBorder.none,
                          suffixIcon: ValueListenableBuilder<String>(
                            valueListenable: queryNotifier,
                            builder: (context, query, _) {
                              if (query.isEmpty) return const SizedBox.shrink();
                              return IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  searchController.clear();
                                  queryNotifier.value = '';
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver:
                  BlocBuilder<PublishedServicesCubit, PublishedServicesState>(
                builder: (context, catalog) {
                  if (catalog.hasError) {
                    return SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const Text('Unable to load routes. Please retry.'),
                          TextButton(
                            onPressed: () =>
                                context.read<PublishedServicesCubit>().reload(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (catalog.index == null) {
                    return const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    );
                  }
                  return ValueListenableBuilder<String>(
                    valueListenable: queryNotifier,
                    builder: (context, query, _) => DebouncedBuilder<String>(
                      value: query,
                      builder: (context, term) {
                        final filtered = catalog.index!.directory(term);
                        if (filtered.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child:
                                    Text('No matching routes found in network'),
                              ),
                            ),
                          );
                        }
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => KeyedSubtree(
                              key: ValueKey(filtered[index].id),
                              child: _buildRouteCard(context, filtered[index]),
                            ),
                            childCount: filtered.length,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, ServiceEntity svc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  svc.routeName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${svc.stops.length} stops',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${svc.stops.first} ➔ ${svc.stops.last}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final st in svc.stops.take(4))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    st,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              if (svc.stops.length > 4)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+${svc.stops.length - 4} more',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bus: ${svc.busName}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.alt_route, size: 16),
                label: const Text(
                  'Train Route Ladder',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (sheetContext) => FractionallySizedBox(
                      heightFactor: 0.85,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: TrainRouteView(
                            service: svc,
                            queryFrom: svc.stops.first,
                            queryTo: svc.stops.last,
                            effectiveDay: "All Days"),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
