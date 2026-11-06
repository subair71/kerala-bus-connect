import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../domain/entities/sponsored_ad.dart';
import '../providers/sponsor_providers.dart';

class SponsoredCarousel extends ConsumerWidget {
  const SponsoredCarousel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(sponsorLocationProvider);
    return ref
        .watch(sponsorsProvider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (data) => data.records.isEmpty
              ? const SizedBox.shrink()
              : _Slides(
                  key: ValueKey(
                    '$location:${data.isDemo}:${data.records.map((ad) => ad.id).join(',')}',
                  ),
                  location: location,
                  ads: data.records,
                  demo: data.isDemo,
                ),
        );
  }
}

class _Slides extends HookConsumerWidget {
  final String location;
  final List<SponsoredAd> ads;
  final bool demo;
  const _Slides({
    super.key,
    required this.location,
    required this.ads,
    required this.demo,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref
        .watch(sponsorPageProvider(location))
        .clamp(0, ads.length - 1);
    final controller = usePageController(initialPage: page);
    final rotationTimer = useRef<Timer?>(null);
    final hovering = useRef(false);
    final touching = useRef(false);
    final interval = ref.watch(sponsorRotationIntervalProvider);
    final canRotate =
        ads.length > 1 &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context);
    void move(int delta) {
      if (!controller.hasClients || ads.length < 2) return;
      final current = controller.page?.round() ?? page;
      final target = (current + delta) % ads.length;
      controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }

    void stopRotation() {
      rotationTimer.value?.cancel();
      rotationTimer.value = null;
    }

    void startRotation() {
      stopRotation();
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (!canRotate ||
          interval <= Duration.zero ||
          (lifecycle != null && lifecycle != AppLifecycleState.resumed))
        return;
      rotationTimer.value = Timer.periodic(interval, (_) {
        if (!controller.hasClients ||
            controller.position.isScrollingNotifier.value ||
            hovering.value ||
            touching.value)
          return;
        move(1);
      });
    }

    // Cancel immediately on backgrounding, even when Flutter stops drawing frames.
    useOnAppLifecycleStateChange((_, state) {
      if (state == AppLifecycleState.resumed) {
        startRotation();
      } else {
        stopRotation();
      }
    });
    useEffect(() {
      startRotation();
      return null;
    }, [controller, page, ads.length, canRotate, interval]);
    // Keyed hook cleanup runs after replacement effects. Only unmount cleanup
    // should cancel the current timer; an old page must not cancel its successor.
    useEffect(() => stopRotation, const []);

    return MouseRegion(
      onEnter: (_) => hovering.value = true,
      onExit: (_) => hovering.value = false,
      child: Listener(
        onPointerDown: (_) => touching.value = true,
        onPointerUp: (_) => touching.value = false,
        onPointerCancel: (_) => touching.value = false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final stacked = constraints.maxWidth < 340 || scale > 1.3;
                return SizedBox(
                  height: (stacked ? 198 : 148) * scale.clamp(1, 2.5),
                  child: PageView.builder(
                    key: PageStorageKey('sponsor-slides-$location'),
                    controller: controller,
                    itemCount: ads.length,
                    onPageChanged: ref
                        .read(sponsorPageProvider(location).notifier)
                        .select,
                    itemBuilder: (context, i) =>
                        _AdCard(ad: ads[i], demo: demo, stacked: stacked),
                  ),
                );
              },
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Local sponsors near $location',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                if (ads.length > 1) ...[
                  Semantics(
                    label: 'Advertisement ${page + 1} of ${ads.length}',
                    child: Row(
                      children: [
                        for (var i = 0; i < ads.length; i++)
                          Container(
                            width: i == page ? 16 : 5,
                            height: 5,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: i == page
                                  ? AppColors.onSurface
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous sponsor',
                    onPressed: () => move(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Next sponsor',
                    onPressed: () => move(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _AdCard extends ConsumerWidget {
  final SponsoredAd ad;
  final bool demo, stacked;
  const _AdCard({required this.ad, required this.demo, required this.stacked});

  void info(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(ad.advertiser),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ad.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(ad.description),
            const SizedBox(height: 16),
            Text(
              demo
                  ? 'Sample data. This fictional advertisement previews local sponsors near ${ad.location}. No advertiser is contacted.'
                  : 'Sponsored placement by ${ad.advertiser}, selected for your boarding location.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = Center(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Text(
          ad.advertiser.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontSize: 10,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            letterSpacing: -.2,
          ),
        ),
      ),
    );
    final picture = ExcludeSemantics(
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ad.imageUrl == 'asset:hotel'
              ? Image.asset(
                  'assets/images/sponsor-hotel.jpg',
                  fit: BoxFit.cover,
                  cacheWidth: 180,
                )
              : ad.imageUrl?.startsWith('https://') == true
              ? Image.network(
                  ad.imageUrl!,
                  fit: BoxFit.contain,
                  cacheWidth: 180,
                  errorBuilder: (_, _, _) => fallback,
                )
              : fallback,
        ),
      ),
    );
    final action = Tooltip(
      message: demo || ad.website == null
          ? 'About this advertisement'
          : 'Visit website',
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          minimumSize: const Size(68, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        onPressed: demo || ad.website == null
            ? () => info(context)
            : () async {
                var opened = false;
                try {
                  opened = await ref.read(openSponsorProvider)(ad);
                } catch (_) {}
                if (!opened && context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to open the advertiser website.'),
                    ),
                  );
              },
        child: Text(demo || ad.website == null ? 'VIEW' : 'VISIT'),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Row(
                  children: [
                    picture,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ad.advertiser,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.2,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ad.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ad.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!stacked) ...[const SizedBox(width: 12), action],
                  ],
                ),
              ),
              if (stacked) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
