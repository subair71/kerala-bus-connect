import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerala_bus_connect/features/timetables/data/datasources/schedule_cache.dart';
import 'package:kerala_bus_connect/features/timetables/data/models/service_model.dart';

class MemoryScheduleStore implements ScheduleCacheStore {
  String? value;
  bool fail = false;
  Completer<String?>? blockedRead;
  Completer<void>? blockedWrite;
  int writes = 0;

  @override
  Future<String?> read() async {
    if (fail) throw StateError('storage unavailable');
    return blockedRead == null ? value : blockedRead!.future;
  }

  @override
  Future<void> write(String next) async {
    if (fail) throw StateError('storage unavailable');
    writes++;
    await blockedWrite?.future;
    value = next;
  }

  @override
  Future<void> remove() async {
    value = null;
  }
}

ServiceModel timetable(String id, {int time = 480, bool knownDays = true}) =>
    ServiceModel.fromMap(id, {
      'published': true,
      'busName': 'Test',
      'stops': ['Origin', 'Destination'],
      'departureMinutes': time,
      'stopTimings': {'Origin': time, 'Destination': time + 30},
      'offDays': knownDays ? <String>[] : null,
    });

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'persists complete schedules and preserves unknown operating days',
    () async {
      final store = MemoryScheduleStore();
      final cache = ScheduleCache(store);
      cache.save([timetable('one', knownDays: false)]);
      await cache.flush();
      final reopened = await ScheduleCache(store).read();
      expect(reopened!.records.single.id, 'one');
      expect(reopened.records.single.operatingDaysKnown, isFalse);
      expect(reopened.records.single.cachedAt, isNotNull);
      expect(reopened.records.single.expectedStopTimings, isEmpty);
    },
  );

  test(
    'expired, future dated, corrupt and incomplete snapshots are misses',
    () async {
      final store = MemoryScheduleStore();
      var now = DateTime.utc(2026, 11, 8);
      final cache = ScheduleCache(store, now: () => now);
      cache.save([timetable('one')]);
      await cache.flush();
      final saved = store.value;
      now = now.add(const Duration(days: 8));
      expect(await cache.read(), isNull);
      now = DateTime.utc(2026, 11, 7);
      expect(await cache.read(), isNull);
      now = DateTime.utc(2026, 11, 8);
      store.value = '{broken';
      expect(await cache.read(), isNull);
      final data = jsonDecode(saved!) as Map<String, dynamic>;
      data['complete'] = false;
      store.value = jsonEncode(data);
      expect(await cache.read(), isNull);
      data['complete'] = true;
      data['version'] = 999;
      store.value = jsonEncode(data);
      expect(await cache.read(), isNull);
    },
  );

  test('oversized replacement evicts the older snapshot', () async {
    final store = MemoryScheduleStore();
    final cache = ScheduleCache(store);
    cache.save([timetable('old')]);
    await cache.flush();
    final bounded = ScheduleCache(store, maxBytes: 1);
    bounded.save([timetable('new')]);
    await bounded.flush();
    expect(store.value, isNull);
  });

  test('new snapshots replace deletions and confirmed empty results', () async {
    final store = MemoryScheduleStore();
    final cache = ScheduleCache(store);
    cache.save([timetable('one'), timetable('two')]);
    await cache.flush();
    cache.save([timetable('two')]);
    await cache.flush();
    expect((await cache.read())!.records.map((row) => row.id), ['two']);
    cache.save([]);
    await cache.flush();
    expect((await cache.read())!.records, isEmpty);
  });

  test(
    'coalesces writes and invalidation cannot be overwritten by old saves',
    () async {
      final store = MemoryScheduleStore()..blockedWrite = Completer<void>();
      final cache = ScheduleCache(store);
      cache.save([timetable('old')]);
      cache.save([timetable('middle')]);
      cache.save([timetable('latest')]);
      store.blockedWrite!.complete();
      await cache.flush();
      expect(store.writes, 2);
      expect((await cache.read())!.records.single.id, 'latest');
      cache.invalidate();
      await cache.flush();
      expect(await cache.read(), isNull);
    },
  );

  test(
    'cached data appears before refresh and server edits replace it',
    () async {
      final store = MemoryScheduleStore();
      final cache = ScheduleCache(store);
      cache.save([timetable('one')]);
      await cache.flush();
      final server = StreamController<List<ServiceModel>>();
      final events = <List<ServiceModel>>[];
      final sub = cache.watch(server.stream).listen(events.add);
      await tick();
      expect(events.single.single.cachedAt, isNotNull);
      server.add([timetable('one', time: 510)]);
      await tick();
      expect(events.last.single.departureMinutes, 510);
      expect(events.last.single.cachedAt, isNull);
      server.addError(StateError('offline'));
      await tick();
      expect(events.last.single.departureMinutes, 510);
      expect(events.last.single.cachedAt, isNotNull);
      await sub.cancel();
      await server.close();
      await cache.flush();
    },
  );

  test('a delayed disk read never replaces newer server records', () async {
    final store = MemoryScheduleStore();
    final cache = ScheduleCache(store);
    cache.save([timetable('old')]);
    await cache.flush();
    final oldValue = store.value;
    store.blockedRead = Completer<String?>();
    final server = StreamController<List<ServiceModel>>();
    final events = <List<ServiceModel>>[];
    final sub = cache.watch(server.stream).listen(events.add);
    await tick();
    server.add([timetable('new')]);
    await tick();
    store.blockedRead!.complete(oldValue);
    await tick();
    expect(events, hasLength(1));
    expect(events.single.single.id, 'new');
    await sub.cancel();
    await server.close();
    await cache.flush();
  });

  test(
    'invalidation during a disk read discards the obsolete snapshot',
    () async {
      final store = MemoryScheduleStore();
      final cache = ScheduleCache(store);
      cache.save([timetable('old')]);
      await cache.flush();
      final oldValue = store.value;
      store.blockedRead = Completer<String?>();
      final pending = cache.read();
      await tick();
      cache.invalidate();
      store.blockedRead!.complete(oldValue);
      expect(await pending, isNull);
      await cache.flush();
    },
  );

  test(
    'storage failure does not interrupt live records or cancellation',
    () async {
      final store = MemoryScheduleStore()..fail = true;
      final cache = ScheduleCache(store);
      var cancelled = false;
      final server = StreamController<List<ServiceModel>>(
        onCancel: () => cancelled = true,
      );
      final events = <List<ServiceModel>>[];
      final sub = cache.watch(server.stream).listen(events.add);
      server.add([timetable('live')]);
      await tick();
      expect(events.single.single.id, 'live');
      await sub.cancel();
      expect(cancelled, isTrue);
      await server.close();
      await cache.flush();
    },
  );

  test('offline failure without a saved snapshot remains an error', () async {
    final cache = ScheduleCache(MemoryScheduleStore());
    final server = StreamController<List<ServiceModel>>();
    final errors = <Object>[];
    final sub = cache.watch(server.stream).listen((_) {}, onError: errors.add);
    server.addError(StateError('offline'));
    await tick();
    expect(errors, hasLength(1));
    await sub.cancel();
    await server.close();
  });

  test(
    'an early server error followed by close still restores saved data',
    () async {
      final store = MemoryScheduleStore();
      final cache = ScheduleCache(store);
      cache.save([timetable('saved')]);
      await cache.flush();
      final rows = await cache
          .watch(Stream<List<ServiceModel>>.error(StateError('offline')))
          .toList();
      expect(rows.last.single.id, 'saved');
      expect(rows.last.single.cachedAt, isNotNull);
    },
  );
}
