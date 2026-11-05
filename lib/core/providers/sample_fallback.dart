import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/data_set.dart';

AsyncValue<DataSet<T>> sampleFallback<T>(
  AsyncValue<List<T>> live,
  List<T> samples,
) => live.when(
  skipLoadingOnRefresh: false,
  loading: () => const AsyncLoading(),
  error: (_, _) => AsyncData(DataSet(samples, isDemo: true, unavailable: true)),
  data: (rows) => AsyncData(rows.isEmpty
      ? DataSet(samples, isDemo: true)
      : DataSet(rows)),
);
