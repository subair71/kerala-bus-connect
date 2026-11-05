import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../utils/time_utils.dart';
import '../constants/transit_constants.dart';

final clockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield keralaNow();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => keralaNow());
});
final todayProvider = Provider.autoDispose<String>((ref) {
  final date = ref.watch(clockProvider).asData?.value ?? keralaNow();
  return weekDays[date.weekday - 1];
});
