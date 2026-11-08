import 'dart:async';
import 'dart:convert';
import '../models/service_model.dart';

abstract class ScheduleCacheStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> remove();
}

class CachedSchedule {
  final List<ServiceModel> records;
  final DateTime confirmedAt;
  const CachedSchedule(this.records, this.confirmedAt);
}

/// One bounded, complete public snapshot; never owner/financial/location data.
/// Writes coalesce and serialize so an old save cannot overwrite a newer one.
class ScheduleCache {
  final ScheduleCacheStore store;
  final DateTime Function() now;
  final Duration maxAge;
  final int maxBytes;
  Future<void> Function()? _pending;
  Future<void>? _writing;
  int _generation = 0;

  ScheduleCache(
    this.store, {
    DateTime Function()? now,
    this.maxAge = const Duration(days: 7),
    this.maxBytes = 2 * 1024 * 1024,
  }) : now = now ?? DateTime.now;

  bool usable(DateTime date) {
    final age = now().toUtc().difference(date);
    return !age.isNegative && age <= maxAge;
  }

  Future<CachedSchedule?> read() async {
    try {
      await flush();
      final generation = _generation;
      final value = await store.read();
      if (generation != _generation) return null;
      if (value == null || utf8.encode(value).length > maxBytes) return null;
      final data = jsonDecode(value) as Map<String, dynamic>;
      if (data['version'] != 1 || data['complete'] != true) return null;
      final date = DateTime.parse(data['confirmedAt'] as String).toUtc();
      if (!usable(date)) return null;
      final rows = data['records'] as List;
      final records = <ServiceModel>[];
      final ids = <String>{};
      for (final row in rows) {
        final item = Map<String, dynamic>.from(row as Map);
        final id = item.remove('id') as String;
        if (id.isEmpty || !ids.add(id) || item['published'] != true)
          return null;
        records.add(ServiceModel.fromMap(id, item, cachedAt: date));
      }
      return CachedSchedule(List.unmodifiable(records), date);
    } catch (_) {
      // Unavailable storage, old schema and corrupt JSON are all cache misses.
      return null;
    }
  }

  void save(List<ServiceModel> records) {
    try {
      final value = jsonEncode({
        'version': 1,
        'complete': true,
        'confirmedAt': now().toUtc().toIso8601String(),
        'records': [
          for (final record in records)
            {
              'id': record.id,
              ...record.toJson(),
              // Preserve legacy unknown operating days across serialization.
              'offDays': record.operatingDaysKnown ? record.offDays : null,
            },
        ],
      });
      if (utf8.encode(value).length > maxBytes) {
        invalidate();
      } else {
        _enqueue(() => store.write(value));
      }
    } catch (_) {
      invalidate();
    }
  }

  void invalidate() {
    _generation++;
    _enqueue(store.remove);
  }

  void _enqueue(Future<void> Function() operation) {
    _pending = operation;
    _writing ??= _drain();
  }

  Future<void> _drain() async {
    while (_pending != null) {
      final operation = _pending!;
      _pending = null;
      try {
        await operation();
      } catch (_) {
        // Storage failure must not break a working server timetable.
      }
    }
    _writing = null;
  }

  Future<void> flush() async {
    while (_writing != null) {
      await _writing;
    }
  }

  /// Subscribe once, show disk data while revalidating, and prefer server data.
  /// The input must contain only complete, server-confirmed snapshots.
  Stream<List<ServiceModel>> watch(
    Stream<List<ServiceModel>> server, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    late StreamController<List<ServiceModel>> output;
    StreamSubscription<List<ServiceModel>>? subscription;
    Timer? timer;
    var cancelled = false;
    var confirmed = false;
    var diskLoaded = false;
    var serverDone = false;
    CachedSchedule? cached;
    var cachedGeneration = _generation;
    Object? pendingError;
    StackTrace? pendingStack;

    void fallback(Object error, StackTrace stack) {
      if (cancelled) return;
      pendingError = error;
      pendingStack = stack;
      final saved = cached;
      if (saved != null &&
          cachedGeneration == _generation &&
          usable(saved.confirmedAt)) {
        output.add(saved.records);
      } else if (diskLoaded) {
        output.addError(error, stack);
      }
    }

    output = StreamController<List<ServiceModel>>(
      onListen: () {
        subscription = server.listen(
          (records) {
            if (cancelled) return;
            confirmed = true;
            pendingError = null;
            timer?.cancel();
            final date = now().toUtc();
            cachedGeneration = _generation;
            cached = CachedSchedule(
              List.unmodifiable([
                for (final record in records)
                  ServiceModel.fromMap(record.id, {
                    ...record.toJson(),
                    'offDays': record.operatingDaysKnown
                        ? record.offDays
                        : null,
                  }, cachedAt: date),
              ]),
              date,
            );
            save(records);
            output.add(records);
          },
          onError: (Object error, StackTrace stack) => fallback(error, stack),
          onDone: () {
            serverDone = true;
            timer?.cancel();
            if (diskLoaded || confirmed) output.close();
          },
        );
        timer = Timer(timeout, () {
          fallback(
            TimeoutException('Timetable refresh timed out.'),
            StackTrace.current,
          );
        });
        read().then((saved) {
          if (cancelled || output.isClosed) return;
          diskLoaded = true;
          if (!confirmed) {
            cached = saved;
            if (saved != null) {
              output.add(saved.records);
            } else if (pendingError != null) {
              output.addError(pendingError!, pendingStack);
            }
          }
          if (serverDone) output.close();
        });
      },
      onCancel: () async {
        cancelled = true;
        timer?.cancel();
        await subscription?.cancel();
      },
    );
    return output.stream;
  }
}
