import '../constants/transit_constants.dart';

String todayName() {
  final now = DateTime.now();
  return weekDays[now.weekday - 1];
}

String timeLabel(int minutes) {
  final h = (minutes ~/ 60) % 24, m = minutes % 60;
  final displayH = h % 12 == 0 ? 12 : h % 12;
  final period = h < 12 ? 'AM' : 'PM';
  return '$displayH:${m.toString().padLeft(2, '0')} $period';
}

int minutesNow() {
  final now = DateTime.now();
  return now.hour * 60 + now.minute;
}
