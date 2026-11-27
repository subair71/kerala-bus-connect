import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;

class DepartureReminder {
  static Future<String> schedule({
    required String serviceId,
    required String bus,
    required String stop,
    required DateTime boarding,
    required int lead,
    Rect? origin,
  }) async {
    final alarm = boarding.subtract(Duration(minutes: lead));
    if (!alarm.isAfter(DateTime.now().toUtc()))
      throw StateError('Choose a future departure or a shorter reminder.');
    final identity =
        '$serviceId|$stop|${boarding.toIso8601String().substring(0, 10)}';
    var id = 17;
    for (final c in identity.codeUnits) {
      id = (id * 31 + c) & 0x7fffffff;
    }
    if (kIsWeb ||
        ![
          TargetPlatform.iOS,
          TargetPlatform.android,
        ].contains(defaultTargetPlatform)) {
      String stamp(DateTime d) =>
          d
              .toUtc()
              .toIso8601String()
              .split('.')
              .first
              .replaceAll(RegExp('[-:]'), '') +
          'Z';
      String clean(String s) => s
          .replaceAll('\\', r'\\')
          .replaceAll(RegExp(r'[\r\n]+'), ' ')
          .replaceAll(',', r'\,')
          .replaceAll(';', r'\;');
      final ics = [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//FindMyBus//Journey//EN',
        'BEGIN:VEVENT',
        'UID:$id@findmybus',
        'DTSTAMP:${stamp(DateTime.now())}',
        'DTSTART:${stamp(boarding)}',
        'DTEND:${stamp(boarding.add(const Duration(minutes: 1)))}',
        'SUMMARY:${clean(bus)} from ${clean(stop)}',
        'BEGIN:VALARM',
        'TRIGGER:-PT${lead}M',
        'ACTION:DISPLAY',
        'DESCRIPTION:Bus departure',
        'END:VALARM',
        'END:VEVENT',
        'END:VCALENDAR',
        '',
      ].join('\r\n');
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(ics)),
              mimeType: 'text/calendar',
            ),
          ],
          fileNameOverrides: ['FindMyBus-reminder.ics'],
          sharePositionOrigin: origin,
        ),
      );
      return result.status == ShareResultStatus.dismissed
          ? 'Calendar export dismissed.'
          : 'Open the calendar file and save the event to activate its reminder.';
    }
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    final granted = defaultTargetPlatform == TargetPlatform.iOS
        ? await plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true)
        : await plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission();
    if (granted != true)
      throw StateError(
        'Enable notifications in device settings to set a reminder.',
      );
    await plugin.zonedSchedule(
      id: id,
      title: '$bus leaves soon',
      body: 'Board at $stop in $lead minutes.',
      scheduledDate: tz.TZDateTime.from(alarm, tz.UTC),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'departures',
          'Departure reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return 'Departure reminder scheduled on this device.';
  }
}
