import 'package:flutter/material.dart';

/// A stop diagram, with buttons linked to timetable identities rather than guessed coordinates.
class StopMap extends StatelessWidget {
  final List<String> stops;
  final ValueChanged<String>? onStop;
  final VoidCallback? onLocate;
  final String? reportedStop;
  final double height;
  const StopMap({
    super.key,
    required this.stops,
    this.onStop,
    this.onLocate,
    this.reportedStop,
    this.height = 174,
  });
  @override
  Widget build(BuildContext context) {
    final distinct = stops.where((s) => s.isNotEmpty).toSet().toList();
    final shown = distinct.length <= 3
        ? distinct
        : [distinct.first, distinct[distinct.length ~/ 2], distinct.last];
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final alignments = shown.length == 1
              ? [const Alignment(0, -.12)]
              : shown.length == 2
              ? [const Alignment(-.65, .32), const Alignment(.64, -.42)]
              : [
                  const Alignment(-.77, .39),
                  const Alignment(-.02, -.39),
                  const Alignment(.76, .08),
                ];
          return Stack(
            fit: StackFit.expand,
            children: [
              const Image(
                image: AssetImage('assets/images/journey-map.png'),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
              for (var i = 0; i < shown.length; i++)
                Align(
                  alignment: alignments[i],
                  child: TextButton(
                    onPressed: onStop == null ? null : () => onStop!(shown[i]),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xff743909),
                      disabledForegroundColor: const Color(0xff394c45),
                      padding: const EdgeInsets.all(4),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: reportedStop == shown[i]
                                ? const Color(0xffffd9b9)
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xffba5719)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              reportedStop == shown[i]
                                  ? Icons.directions_bus_filled
                                  : Icons.directions_bus_outlined,
                              size: 16,
                            ),
                          ),
                        ),
                        Container(
                          color: Colors.white.withValues(alpha: .9),
                          constraints: BoxConstraints(
                            maxWidth: box.maxWidth * .31,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            shown[i],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Positioned(
                bottom: 5,
                left: 8,
                child: ColoredBox(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Schematic stop map',
                      style: TextStyle(fontSize: 9),
                    ),
                  ),
                ),
              ),
              if (onLocate != null)
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: IconButton.filledTonal(
                    tooltip: 'Choose a nearby stop',
                    onPressed: onLocate,
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                    icon: const Icon(Icons.my_location, size: 18),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
