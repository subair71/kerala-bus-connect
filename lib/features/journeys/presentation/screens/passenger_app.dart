import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/transit_constants.dart';
import '../../../../core/utils/sample_ids.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../crew/presentation/providers/crew_providers.dart';
import '../../../owner/presentation/providers/owner_providers.dart';
import '../../../passenger/presentation/providers/paged_search_provider.dart';
import '../../../passenger/presentation/providers/search_providers.dart';
import '../../../places/presentation/providers/nearby_providers.dart';
import '../../../places/presentation/providers/places_providers.dart';
import '../../../places/presentation/widgets/place_text_field.dart';
import '../../../platform/presentation/providers/platform_providers.dart';
import '../../../sponsors/presentation/providers/sponsor_providers.dart';
import '../../../timetables/domain/entities/service_entity.dart';
import '../../../timetables/domain/entities/business_entity.dart';
import '../../../timetables/presentation/providers/timetable_providers.dart';
import '../../../tracking/presentation/providers/tracking_providers.dart';
import '../../../trips/domain/entities/trip_plan.dart';
import '../../../trips/presentation/providers/trip_providers.dart';
import '../../domain/journey_filters.dart';
import '../providers/journey_providers.dart';
part 'components.dart';
part 'planning.dart';
part 'timetables.dart';
part 'operator.dart';

class PassengerApp extends StatelessWidget {
  const PassengerApp({super.key});
  @override
  Widget build(BuildContext context) => const _Home();
}

final _selection = NotifierProvider.autoDispose.family<_Choice, int, Object>(
  _Choice.new,
);

class _Choice extends Notifier<int> {
  _Choice(Object key);
  @override
  int build() => 0;
  void select(int value) => state = value;
}

typedef _Picker = ({int index, ValueChanged<int> select});
_Picker _choice(WidgetRef ref) {
  final key = useMemoized(Object.new);
  return (
    index: ref.watch(_selection(key)),
    select: ref.read(_selection(key).notifier).select,
  );
}

Future<T?> _open<T>(BuildContext c, Widget page) =>
    Navigator.of(c).push<T>(MaterialPageRoute(builder: (_) => page));
const _tabTitles = ['Find bus', 'Departures', 'Routes', 'Saved', 'More'];
const _tabIcons = [
  Icons.map_outlined,
  Icons.departure_board_outlined,
  Icons.route_outlined,
  Icons.bookmark_border,
  Icons.more_horiz,
];
void _tab(BuildContext c, int i) {
  final page = <Widget>[
    const _Home(),
    const _Board(),
    const _Routes(),
    const _Saved(),
    const _More(),
  ][i];
  Navigator.of(
    c,
  ).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => page), (_) => false);
}

DateTime _date(WidgetRef ref) =>
    ref.watch(searchQueryProvider).serviceDate ??
    ref.watch(journeyTodayProvider);
String _day(DateTime d, {bool long = false}) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return long
      ? '${weekDays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}'
      : '${weekDays[d.weekday - 1].substring(0, 3)}, ${d.day} ${months[d.month - 1].substring(0, 3)}';
}

DepartureQuery _query(
  String from,
  String to,
  DateTime date, {
  bool directory = false,
}) => (from: from, to: to, date: serviceDateKey(date), directory: directory);
void _retry(WidgetRef ref, DepartureQuery q) {
  ref.invalidate(journeyUpdatesProvider);
  if (ref.read(passengerPagingEnabledProvider)) {
    ref.invalidate(pagedDeparturesProvider(q));
  } else {
    ref.invalidate(publishedServicesProvider);
  }
  ref.invalidate(journeyFeedProvider(q));
}

void _message(BuildContext c, String text) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(text)));
Future<int?> _pickTime(BuildContext c, int minutes) async {
  final t = await showTimePicker(
    context: c,
    initialTime: TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60),
    builder: (c, w) => MediaQuery(
      data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
      child: w!,
    ),
  );
  return t == null ? null : t.hour * 60 + t.minute;
}
