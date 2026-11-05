import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/data_notice.dart';
import '../../../../core/widgets/app_components.dart';
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
                  unavailable: data.unavailable,
                ),
        );
  }
}

class _Slides extends HookConsumerWidget {
  final String location;
  final List<SponsoredAd> ads;
  final bool demo, unavailable;
  const _Slides({
    super.key,
    required this.location,
    required this.ads,
    required this.demo,
    required this.unavailable,
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
            if (unavailable)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'Live sponsors unavailable • Sample advertisements',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Local sponsors near $location',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (ads.length > 1)
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
                                  ? AppColors.primary
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (ads.length > 1)
                  IconButton(
                    tooltip: 'Previous sponsor',
                    onPressed: () => move(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                if (ads.length > 1)
                  IconButton(
                    tooltip: 'Next sponsor',
                    onPressed: () => move(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
              ],
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 700;
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                return SizedBox(
                  height: (wide ? 188 : 228) * scale.clamp(1, 2.5),
                  child: PageView.builder(
                    controller: controller,
                    itemCount: ads.length,
                    onPageChanged: ref
                        .read(sponsorPageProvider(location).notifier)
                        .select,
                    itemBuilder: (context, i) =>
                        _AdCard(ad: ads[i], demo: demo, wide: wide),
                  ),
                );
              },
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
  final bool demo, wide;
  const _AdCard({required this.ad, required this.demo, required this.wide});
  void info(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('About this advertisement'),
      content: Text(
        demo
            ? 'Sample data. This fictional advertisement previews local sponsors near ${ad.location}. No advertiser is contacted.'
            : 'Sponsored placement by ${ad.advertiser}, selected for your boarding location.',
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
    final fallback = ColoredBox(
      color: AppColors.surfaceLow,
      child: Center(
        child: Icon(
          ad.imageUrl == 'asset:hotel'
              ? Icons.hotel_outlined
              : Icons.local_cafe_outlined,
          color: AppColors.primary,
          size: 32,
        ),
      ),
    );
    final picture = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: wide ? 96 : 74,
        height: wide ? 96 : 80,
        child: ad.imageUrl == 'asset:hotel'
            ? Image.asset(
                'assets/images/sponsor-hotel.jpg',
                fit: BoxFit.cover,
                cacheWidth: 240,
              )
            : ad.imageUrl?.startsWith('https://') == true
            ? Image.network(
                ad.imageUrl!,
                fit: BoxFit.cover,
                cacheWidth: 240,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
    final action = FilledButton.tonalIcon(
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
      icon: Icon(demo ? Icons.info_outline : Icons.open_in_new, size: 15),
      label: Text(demo ? 'Sample advertisement' : 'Visit website'),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const AppStatusBadge(
                  label: 'SPONSORED',
                  foreground: AppColors.onSurfaceVariant,
                  background: AppColors.surfaceLow,
                  fontSize: 10,
                ),
                if (demo) const DemoBadge(),
                Text(
                  '${ad.advertiser} · ${ad.location}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  picture,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ad.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ad.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (wide) action,
                ],
              ),
            ),
            if (!wide) Align(alignment: Alignment.centerRight, child: action),
          ],
        ),
      ),
    );
  }
}
