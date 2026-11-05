import 'dart:async';
import 'package:flutter/widgets.dart';

/// Keeps input responsive while delaying expensive derived result updates.
class DebouncedBuilder<T> extends StatefulWidget {
  final T value;
  final Widget Function(BuildContext context, T value) builder;
  final Duration delay;

  const DebouncedBuilder({
    super.key,
    required this.value,
    required this.builder,
    this.delay = const Duration(milliseconds: 200),
  });

  @override
  State<DebouncedBuilder<T>> createState() => _DebouncedBuilderState<T>();
}

class _DebouncedBuilderState<T> extends State<DebouncedBuilder<T>> {
  late T _value;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant DebouncedBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _timer?.cancel();
      _timer = Timer(widget.delay, () {
        if (mounted) setState(() => _value = widget.value);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
