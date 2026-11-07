import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/data_set.dart';

AsyncValue<DataSet<T>> sampleFallback<T>(
  AsyncValue<List<T>> live,
  List<T> samples, {
  bool previewWhileLoading = false,
}) => live.when(
  // A refresh of the same source keeps its last records visible.
  skipLoadingOnRefresh: true,
  loading: () => previewWhileLoading
      ? AsyncData(DataSet(samples, isDemo: true, unavailable: live.hasError))
      : const AsyncLoading(),
  error: (_, _) => AsyncData(DataSet(samples, isDemo: true, unavailable: true)),
  data: (rows) =>
      AsyncData(rows.isEmpty ? DataSet(samples, isDemo: true) : DataSet(rows)),
);
