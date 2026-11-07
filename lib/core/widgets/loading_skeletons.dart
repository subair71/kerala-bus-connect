import 'package:flutter/material.dart';
import 'shimmer_loading.dart';

enum SkeletonLayout { departures, routes, crew, businesses, buses, trips, timeline }

/// Sliver rows remain lazy and can also be appended after existing page items.
class LoadingSliver extends StatelessWidget {
  final SkeletonLayout layout;
  final int count;
  final String label;
  const LoadingSliver({
    super.key,
    required this.layout,
    this.count = 3,
    this.label = 'Loading content',
  });
  @override
  Widget build(BuildContext context) => SliverList.builder(
    itemCount: count,
    itemBuilder: (context, index) => AppShimmer(
      label: index == 0 ? label : null,
      child: SkeletonCard(layout: layout),
    ),
  );
}

class SkeletonCard extends StatelessWidget {
  final SkeletonLayout layout;
  const SkeletonCard({super.key, required this.layout});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(layout == SkeletonLayout.departures ? 16 : 20),
      child: switch (layout) {
        SkeletonLayout.departures => const _DepartureShape(),
        SkeletonLayout.routes => const _RouteShape(),
        SkeletonLayout.crew => const _CrewShape(),
        SkeletonLayout.businesses => const _BusinessShape(),
        SkeletonLayout.buses => const _BusShape(),
        SkeletonLayout.trips => const _TripShape(),
        SkeletonLayout.timeline => const _TimelineShape(),
      },
    ),
  );
}

class _DepartureShape extends StatelessWidget {
  const _DepartureShape();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Row(children: [
        Expanded(child: SkeletonText(fraction: .6, height: 24)),
        SizedBox(width: 24),
        Expanded(child: SkeletonText(fraction: .6, height: 28)),
      ]),
      const SizedBox(height: 16),
      const SkeletonText(fraction: .55, height: 20),
      const SizedBox(height: 6),
      const SkeletonText(fraction: .8, height: 12),
      const SizedBox(height: 18),
      const Row(children: [
        Expanded(child: _TimeShape()),
        Padding(padding: EdgeInsets.all(12), child: SkeletonBox(width: 24, height: 2)),
        Expanded(child: _TimeShape()),
      ]),
      const SizedBox(height: 16),
      const Row(children: [
        Expanded(child: SkeletonText(fraction: .65, height: 12)),
        SizedBox(width: 16),
        SkeletonBox(width: 92, height: 36, radius: 18),
      ]),
    ],
  );
}

class _TimeShape extends StatelessWidget {
  const _TimeShape();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SkeletonText(fraction: .65, height: 24),
      SizedBox(height: 8),
      SkeletonText(fraction: .85, height: 12),
    ],
  );
}

class _RouteShape extends StatelessWidget {
  const _RouteShape();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(children: [
        SkeletonBox(width: 44, height: 44, radius: 12),
        SizedBox(width: 12),
        Expanded(child: Column(children: [
          SkeletonText(fraction: .65, height: 20),
          SizedBox(height: 8),
          SkeletonText(fraction: .9, height: 13),
        ])),
      ]),
      SizedBox(height: 20),
      Row(children: [
        Expanded(child: _TimeShape()),
        SizedBox(width: 24),
        Expanded(child: _TimeShape()),
      ]),
      SizedBox(height: 20),
      SkeletonText(fraction: .75),
      SizedBox(height: 14),
      SkeletonBox(height: 44, radius: 14),
    ],
  );
}

class _CrewShape extends StatelessWidget {
  const _CrewShape();
  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SkeletonBox(width: 44, height: 44, radius: 12),
      SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonText(fraction: .6, height: 18),
          SizedBox(height: 8),
          SkeletonText(fraction: .85),
          SizedBox(height: 12),
          SkeletonText(fraction: .45, height: 28),
        ],
      )),
    ],
  );
}

class _BusinessShape extends StatelessWidget {
  const _BusinessShape();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SkeletonText(fraction: .2, height: 12),
      SizedBox(height: 8),
      SkeletonBox(height: 56, radius: 14),
      SizedBox(height: 12),
      SkeletonText(fraction: .35, height: 20),
    ],
  );
}

class _BusShape extends StatelessWidget {
  const _BusShape();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SkeletonBox(height: 56, radius: 14),
      SizedBox(height: 12),
      Row(children: [
        Expanded(child: SkeletonText(fraction: .7, height: 32)),
        SizedBox(width: 16),
        Expanded(child: SkeletonText(fraction: .7, height: 32)),
      ]),
      SizedBox(height: 12),
      SkeletonBox(height: 48, radius: 14),
    ],
  );
}

class _TripShape extends StatelessWidget {
  const _TripShape();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SkeletonText(fraction: .65, height: 20),
      SizedBox(height: 8),
      SkeletonText(fraction: .45),
      SizedBox(height: 8),
      SkeletonText(fraction: .9),
      SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        SkeletonBox(width: 88, height: 40, radius: 20),
        SkeletonBox(width: 132, height: 40, radius: 20),
        SkeletonBox(width: 104, height: 40, radius: 20),
      ]),
    ],
  );
}

class _TimelineShape extends StatelessWidget {
  const _TimelineShape();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < 4; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(children: [
            const SkeletonBox.circle(size: 28),
            const SizedBox(width: 16),
            const Expanded(child: Column(children: [
              SkeletonText(fraction: .7, height: 18),
              SizedBox(height: 8),
              SkeletonText(fraction: .4, height: 12),
            ])),
          ]),
        ),
    ],
  );
}

class AccountSkeleton extends StatelessWidget {
  const AccountSkeleton({super.key});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: const AppShimmer(
          label: 'Loading your account',
          child: Card(child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft,
                  child: SkeletonBox(width: 48, height: 48, radius: 14)),
                SizedBox(height: 20),
                SkeletonText(fraction: .7, height: 26),
                SizedBox(height: 16),
                SkeletonText(height: 14),
                SizedBox(height: 20),
                SkeletonBox(height: 56, radius: 14),
                SizedBox(height: 14),
                SkeletonBox(height: 56, radius: 14),
                SizedBox(height: 20),
                SkeletonBox(height: 48, radius: 24),
              ],
            ),
          )),
        ),
      ),
    ),
  );
}

class TrackingSkeleton extends StatelessWidget {
  const TrackingSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          AppShimmer(
            label: 'Loading tracking details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SkeletonText(fraction: .55, height: 26),
                SizedBox(height: 12),
                SkeletonText(fraction: .8),
                SizedBox(height: 24),
                SkeletonBox(height: 56, radius: 14),
                SizedBox(height: 16),
                SkeletonCard(layout: SkeletonLayout.timeline),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class SponsorSkeleton extends StatelessWidget {
  const SponsorSkeleton({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final stacked = constraints.maxWidth < 340 || scale > 1.3;
      return AppShimmer(
        label: 'Loading local sponsors',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: (stacked ? 198 : 148) * scale.clamp(1, 2.5),
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    const Expanded(child: Row(children: [
                      SkeletonBox(width: 60, height: 60, radius: 14),
                      SizedBox(width: 14),
                      Expanded(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SkeletonText(fraction: .5, height: 11),
                          SizedBox(height: 6),
                          SkeletonText(height: 15),
                          SizedBox(height: 6),
                          SkeletonText(fraction: .8, height: 12),
                        ],
                      )),
                    ])),
                    if (stacked) ...[
                      const SizedBox(height: 8),
                      const Align(alignment: Alignment.centerRight,
                        child: SkeletonBox(width: 88, height: 48, radius: 24)),
                    ],
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 48,
              child: Align(alignment: Alignment.centerLeft,
                child: SkeletonText(fraction: .55, height: 11))),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

class StartupSkeleton extends StatelessWidget {
  const StartupSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const AppShimmer(
        label: 'Starting FindMyBus',
        child: Row(children: [
          SkeletonBox.circle(size: 36),
          SizedBox(width: 12),
          Expanded(child: SkeletonText(fraction: .45, height: 22)),
        ]),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            AppShimmer(
              label: null,
              child: Card(child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(children: [
                  SkeletonBox(height: 72, radius: 12),
                  SizedBox(height: 8),
                  SkeletonBox(height: 72, radius: 12),
                  SizedBox(height: 16),
                  SkeletonBox(height: 48, radius: 14),
                  SizedBox(height: 16),
                  SkeletonBox(height: 56, radius: 14),
                ]),
              )),
            ),
            SizedBox(height: 12),
            SponsorSkeleton(),
          ],
        ),
      ),
    ),
    bottomNavigationBar: const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: AppShimmer(label: null,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              SkeletonBox.circle(size: 28), SkeletonBox.circle(size: 28),
              SkeletonBox.circle(size: 28), SkeletonBox.circle(size: 28),
              SkeletonBox.circle(size: 28),
            ])),
      ),
    ),
  );
}
