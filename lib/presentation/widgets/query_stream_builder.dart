import 'package:flutter/widgets.dart';

/// Creates a stream only when its repository/query identity changes.
class QueryStreamBuilder<T> extends StatefulWidget {
  final Object identity;
  final Stream<T> Function() createStream;
  final AsyncWidgetBuilder<T> builder;

  const QueryStreamBuilder({
    super.key,
    required this.identity,
    required this.createStream,
    required this.builder,
  });

  @override
  State<QueryStreamBuilder<T>> createState() => _QueryStreamBuilderState<T>();
}

class _QueryStreamBuilderState<T> extends State<QueryStreamBuilder<T>> {
  late Stream<T> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.createStream();
  }

  @override
  void didUpdateWidget(covariant QueryStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.identity != oldWidget.identity) {
      _stream = widget.createStream();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
        // Clear the previous owner's/business's data when the query changes.
        key: ValueKey(widget.identity),
        stream: _stream,
        builder: widget.builder,
      );
}
