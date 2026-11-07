import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/shimmer_delay_provider.dart';

/// One paint-only animation per loading region. Data loading stays in Riverpod.
class AppShimmer extends HookConsumerWidget {
  final Widget child;
  final String? label;
  const AppShimmer({
    super.key,
    required this.child,
    this.label = 'Loading content',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = useMemoized(Object.new);
    final ready = ref.watch(shimmerDelayProvider(identity));
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1400),
    );
    final regionKey = useMemoized(() => GlobalKey());
    final lifecycle = useAppLifecycleState();
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final enabled =
        ready &&
        !reduced &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    // Include every enclosing viewport, including a sponsor PageView inside
    // the home scroller. Cached, off-screen children must not keep ticking.
    final scrollables = <ScrollableState>[];
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        scrollables.add(element.state as ScrollableState);
      }
      return true;
    });
    final positions = scrollables.map((s) => s.position).toList();
    useEffect(() {
      var disposed = false;
      var scheduled = false;
      void updateVisibility() {
        scheduled = false;
        if (disposed) return;
        final box = regionKey.currentContext?.findRenderObject();
        var visible =
            enabled && box is RenderBox && box.attached && box.hasSize;
        if (enabled && box is RenderBox && box.attached && box.hasSize) {
          final bounds = MatrixUtils.transformRect(
            box.getTransformTo(null),
            Offset.zero & box.size,
          );
          var viewport = Offset.zero & MediaQuery.sizeOf(context);
          for (final scrollable in scrollables) {
            final render = scrollable.context.findRenderObject();
            if (render is RenderBox && render.attached && render.hasSize) {
              viewport = viewport.intersect(
                MatrixUtils.transformRect(
                  render.getTransformTo(null),
                  Offset.zero & render.size,
                ),
              );
            }
          }
          visible = !viewport.isEmpty && bounds.overlaps(viewport);
        }
        if (visible && !controller.isAnimating) controller.repeat();
        if (!visible && controller.isAnimating) controller.stop();
      }

      void scheduleVisibility() {
        if (scheduled || disposed) return;
        scheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => updateVisibility());
      }

      if (!enabled) controller.stop();
      for (final position in positions) {
        position.addListener(scheduleVisibility);
      }
      scheduleVisibility();
      return () {
        disposed = true;
        for (final position in positions) {
          position.removeListener(scheduleVisibility);
        }
        controller.stop();
      };
    }, [enabled, ...positions, MediaQuery.sizeOf(context)]);

    final content = IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: ready ? 1 : 0,
          child: RepaintBoundary(
            key: regionKey,
            child: _ShimmerMotion(animation: controller, child: child),
          ),
        ),
      ),
    );
    return label == null
        ? content
        : Semantics(
            container: true,
            liveRegion: true,
            label: label,
            child: content,
          );
  }
}

class _ShimmerMotion extends InheritedWidget {
  final AnimationController animation;
  const _ShimmerMotion({required this.animation, required super.child});
  @override
  bool updateShouldNotify(_ShimmerMotion oldWidget) =>
      animation != oldWidget.animation;
}

/// Use within AppShimmer to share its controller; outside it this is static.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height, radius;
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = 6});
  const SkeletonBox.circle({super.key, double size = 44})
    : width = size,
      height = size,
      radius = size / 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final animation = context
        .dependOnInheritedWidgetOfExactType<_ShimmerMotion>()
        ?.animation;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SkeletonPainter(
          animation: animation,
          base: scheme.surfaceContainerHighest,
          highlight: Color.alphaBlend(
            scheme.onSurface.withValues(alpha: .08),
            scheme.surfaceContainerHighest,
          ),
          radius: radius,
        ),
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  final AnimationController? animation;
  final Color base, highlight;
  final double radius;
  _SkeletonPainter({
    required this.animation,
    required this.base,
    required this.highlight,
    required this.radius,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(bounds, Radius.circular(radius));
    canvas.drawRRect(shape, Paint()..color = base);
    if (animation == null || !animation!.isAnimating) return;
    final x = (animation!.value * 3 - 1) * size.width;
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(colors: [base, highlight, base]).createShader(
          Rect.fromLTWH(x - size.width, 0, size.width, size.height),
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkeletonPainter oldDelegate) =>
      animation != oldDelegate.animation ||
      base != oldDelegate.base ||
      highlight != oldDelegate.highlight ||
      radius != oldDelegate.radius;
}

class SkeletonText extends StatelessWidget {
  final double fraction, height;
  const SkeletonText({super.key, this.fraction = 1, this.height = 14});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: fraction,
      child: SkeletonBox(
        height: MediaQuery.textScalerOf(context).scale(height),
      ),
    ),
  );
}

/// Keeps the label and button size stable; the parent retains its disabled state.
class ActionShimmer extends StatelessWidget {
  final bool loading;
  final String label;
  final Widget child;
  const ActionShimmer({
    super.key,
    required this.loading,
    required this.label,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: loading,
    label: loading ? '$label. In progress' : null,
    excludeSemantics: loading,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (loading)
          const Positioned(
            left: 0,
            right: 0,
            bottom: -5,
            child: AppShimmer(
              label: null,
              child: SkeletonBox(height: 3, radius: 2),
            ),
          ),
      ],
    ),
  );
}
