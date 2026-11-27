part of 'passenger_app.dart';

const _ink = Color(0xff172f3f),
    _muted = Color(0xff576a70),
    _orange = Color(0xffb84800),
    _line = Color(0xffdce3de),
    _wash = Color(0xfff3f5f3),
    _teal = Color(0xff265e58),
    _mint = Color(0xffecf4ef);
TextStyle _style(
  double size, {
  Color color = _ink,
  FontWeight weight = FontWeight.w500,
  double spacing = 0,
}) => TextStyle(
  fontFamily: 'Plus Jakarta Sans',
  fontSize: size,
  height: 1.34,
  color: color,
  fontWeight: weight,
  letterSpacing: spacing,
);
Widget _text(
  String s, {
  double size = 14,
  Color color = _ink,
  FontWeight weight = FontWeight.w600,
}) => Text(
  s,
  style: _style(size, color: color, weight: weight),
);
Widget _title(String s) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(s, style: _style(27, weight: FontWeight.w800, spacing: -1)),
);
Widget _ey(String s) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    s.toUpperCase(),
    style: _style(
      10,
      color: const Color(0xff86623e),
      weight: FontWeight.w800,
      spacing: 1.3,
    ),
  ),
);
Widget _section(String s) => Padding(
  padding: const EdgeInsets.fromLTRB(0, 12, 0, 7),
  child: _text(s, size: 18, weight: FontWeight.w800),
);
Widget _sub(String s) =>
    _text(s, size: 13, color: _muted, weight: FontWeight.w500);
Widget _gap([double h = 8]) => SizedBox(height: h);
BoxDecoration _box([Color color = Colors.white, double radius = 14]) =>
    BoxDecoration(
      color: color,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(radius),
    );
Widget _card(List<Widget> children, {Color color = Colors.white}) => Container(
  margin: const EdgeInsets.symmetric(vertical: 4),
  padding: const EdgeInsets.all(13),
  decoration: _box(color),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  ),
);
Widget _notice(String s) => Container(
  margin: const EdgeInsets.symmetric(vertical: 7),
  padding: const EdgeInsets.all(11),
  decoration: const BoxDecoration(
    color: Color(0xfffff4e8),
    border: Border(left: BorderSide(color: Color(0xffd87628), width: 3)),
  ),
  child: _text(s, size: 12, color: Color(0xff75441b)),
);
Widget _pill(String label, {bool accent = false}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: accent ? const Color(0xffffe9d6) : _wash,
    borderRadius: BorderRadius.circular(20),
  ),
  child: _text(label, size: 10, color: accent ? _orange : _muted),
);
Widget _pair(Widget a, Widget b) => Row(
  children: [
    Expanded(child: a),
    const SizedBox(width: 7),
    Flexible(
      child: Align(alignment: Alignment.centerRight, child: b),
    ),
  ],
);
Widget _button(String label, VoidCallback? tap, {bool secondary = false}) {
  final style = TextButton.styleFrom(
    foregroundColor: secondary ? _orange : Colors.white,
    backgroundColor: secondary ? Colors.white : _orange,
    disabledBackgroundColor: _wash,
    disabledForegroundColor: _muted,
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    textStyle: _style(14, weight: FontWeight.w800),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: secondary
          ? const BorderSide(color: Color(0xffdbb69c))
          : BorderSide.none,
    ),
  );
  return Padding(
    padding: const EdgeInsets.only(top: 7),
    child: TextButton(
      onPressed: tap,
      style: style,
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

Widget _tile(
  IconData icon,
  String label,
  String detail,
  VoidCallback? tap, {
  Widget? trailing,
}) => InkWell(
  onTap: tap,
  borderRadius: BorderRadius.circular(8),
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xffe5e8e5))),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xffedf2f0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _teal, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _text(label, weight: FontWeight.w700),
              if (detail.isNotEmpty) _sub(detail),
            ],
          ),
        ),
        if (trailing != null)
          trailing
        else if (tap != null)
          const Icon(Icons.chevron_right, size: 17, color: _muted),
      ],
    ),
  ),
);
Widget _segments(List<String> labels, int selected, ValueChanged<int> change) =>
    Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _wash,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                child: InkWell(
                  onTap: () => change(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 2,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected ? Colors.white : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: _style(
                        12,
                        color: i == selected ? _orange : _muted,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
InputDecoration _input(String label, {IconData? icon}) => InputDecoration(
  isDense: true,
  labelText: label,
  prefixIcon: icon == null ? null : Icon(icon, size: 20, color: _muted),
  filled: true,
  fillColor: _wash,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _line),
  ),
);

class _Frame extends StatelessWidget {
  final String heading;
  final int tab;
  final bool root, staff;
  final Widget? map, action;
  final List<Widget> children;
  const _Frame(
    this.heading,
    this.children, {
    this.tab = 0,
    this.root = false,
    this.staff = false,
    this.map,
    this.action,
  });
  @override
  Widget build(BuildContext c) {
    final brand = root && tab == 0 && !staff;
    return Scaffold(
      backgroundColor: _wash,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Material(
              color: Colors.white,
              child: Column(
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 4,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: _line)),
                    ),
                    child: Row(
                      children: [
                        if (brand) ...[
                          Image.asset(
                            'assets/images/findmybus-logo.jpg',
                            width: 43,
                            height: 34,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _text(
                                  'FindMyBus',
                                  size: 17,
                                  weight: FontWeight.w800,
                                ),
                                _sub('Kerala Transit'),
                              ],
                            ),
                          ),
                        ] else ...[
                          if (!root)
                            _round(
                              'Back',
                              Icons.chevron_left,
                              () => Navigator.maybePop(c),
                            ),
                          if (!root) const SizedBox(width: 9),
                          Expanded(
                            child: _text(
                              heading,
                              size: 18,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ],
                        ?action,
                      ],
                    ),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      key: PageStorageKey(heading),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        if (map != null)
                          SliverToBoxAdapter(
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                map!,
                                Container(
                                  height: 14,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(21),
                                    ),
                                  ),
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: 41,
                                    height: 4,
                                    decoration: _box(_line, 4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            17,
                            map == null ? 16 : 8,
                            17,
                            16,
                          ),
                          sliver: SliverList.list(children: children),
                        ),
                      ],
                    ),
                  ),
                  if (staff)
                    Container(
                      height: 40,
                      color: const Color(0xfff7f5fa),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 16,
                            color: Color(0xff6b597f),
                          ),
                          const SizedBox(width: 7),
                          _text(
                            'Operator workspace',
                            size: 11,
                            color: const Color(0xff6b597f),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: _line)),
                      ),
                      child: Row(
                        children: [
                          for (var i = 0; i < 5; i++)
                            Expanded(
                              child: Semantics(
                                identifier:
                                    'nav-${['passenger', 'departures', 'routes', 'saved', 'more'][i]}',
                                button: true,
                                selected: i == tab,
                                child: InkWell(
                                  onTap: () => _tab(c, i),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 9,
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 44,
                                          decoration: BoxDecoration(
                                            color: i == tab
                                                ? const Color(0xffffead9)
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                          ),
                                          child: Icon(
                                            _tabIcons[i],
                                            size: 21,
                                            color: i == tab ? _orange : _muted,
                                          ),
                                        ),
                                        _text(
                                          _tabTitles[i],
                                          size: 10,
                                          color: i == tab ? _orange : _muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _round(String tip, IconData icon, VoidCallback tap) => IconButton(
  tooltip: tip,
  onPressed: tap,
  style: IconButton.styleFrom(
    backgroundColor: _wash,
    minimumSize: const Size(36, 36),
    tapTargetSize: MaterialTapTargetSize.padded,
    padding: const EdgeInsets.all(7),
  ),
  icon: Icon(icon, size: 20, color: _ink),
);

List<String> _areaPins(String boarding) => [
  if (boarding.isNotEmpty) boarding,
  if (boarding.toLowerCase() == 'aluva') ...['Market Road', 'Railway Station'],
];

class _MapPanel extends StatelessWidget {
  final List<String> labels;
  final ValueChanged<String>? select;
  final VoidCallback? locate;
  final bool route;
  final int? reported;
  final double ratio;
  const _MapPanel(
    this.labels, {
    this.select,
    this.locate,
    this.route = false,
    this.reported,
    this.ratio = 2.0,
  });
  @override
  Widget build(BuildContext c) {
    final pins = labels.length <= 3
        ? labels
        : [labels.first, labels[labels.length ~/ 2], labels.last];
    return AspectRatio(
      aspectRatio: ratio,
      child: LayoutBuilder(
        builder: (c, b) {
          final w = b.maxWidth, h = b.maxHeight;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/guide-map.png',
                  fit: BoxFit.fill,
                ),
              ),
              if (route)
                Positioned.fill(child: CustomPaint(painter: _RouteLine())),
              for (var i = 0; i < pins.length; i++)
                Positioned(
                  left: ((route ? [.16, .5, .81] : [.5, .23, .77])[i] * w - 52)
                      .clamp(0, w - 104),
                  top: (route ? [.67, .45, .22] : [.26, .57, .53])[i] * h,
                  child: Semantics(
                    button: select != null,
                    child: InkWell(
                      onTap: select == null ? null : () => select!(pins[i]),
                      child: SizedBox(
                        width: 104,
                        child: Column(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: route ? _teal : _orange,
                                ),
                              ),
                              child: Icon(
                                Icons.directions_bus_outlined,
                                size: 14,
                                color: route ? _teal : _orange,
                              ),
                            ),
                            Text(
                              pins[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _style(10, weight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (reported != null && labels.isNotEmpty)
                Align(
                  alignment: Alignment(
                    -.68 +
                        1.36 *
                            (reported! /
                                (labels.length > 1 ? labels.length - 1 : 1)),
                    .29 -
                        .9 *
                            (reported! /
                                (labels.length > 1 ? labels.length - 1 : 1)),
                  ),
                  child: _pill('BUS', accent: true),
                ),
              Positioned(
                left: 8,
                bottom: 18,
                child: Material(
                  color: Colors.white,
                  child: _text('Illustrative map', size: 9, color: _muted),
                ),
              ),
              if (locate != null)
                Positioned(
                  right: 7,
                  bottom: 16,
                  child: _round(
                    'Choose a mapped stop',
                    Icons.my_location,
                    locate!,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RouteLine extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(s.width * .16, s.height * .67 + 10)
      ..lineTo(s.width * .34, s.height * .59)
      ..lineTo(s.width * .5, s.height * .45 + 10)
      ..lineTo(s.width * .66, s.height * .4)
      ..lineTo(s.width * .81, s.height * .22 + 10);
    canvas.drawPath(
      p,
      Paint()
        ..color = _teal
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_RouteLine old) => false;
}

Widget _loading() => const Center(
  child: Padding(
    padding: EdgeInsets.all(22),
    child: CircularProgressIndicator(strokeWidth: 2),
  ),
);
