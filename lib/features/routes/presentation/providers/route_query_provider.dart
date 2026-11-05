import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../passenger/presentation/providers/search_providers.dart';
import '../../../timetables/domain/entities/service_entity.dart';

final routeQueryProvider = NotifierProvider<RouteQuery, String>(RouteQuery.new);
class RouteQuery extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value.trim().toLowerCase();
}
final debouncedRouteQueryProvider = NotifierProvider.autoDispose<DebouncedRouteQuery, String>(DebouncedRouteQuery.new);
class DebouncedRouteQuery extends Notifier<String> {
  @override
  String build() {
    Timer? timer;
    ref.listen(routeQueryProvider, (previous, next) {
      timer?.cancel();
      timer = Timer(const Duration(milliseconds: 200), () {
        if (ref.mounted) state = next;
      });
    });
    ref.onDispose(() => timer?.cancel());
    return ref.read(routeQueryProvider);
  }
}
final directoryResultsProvider = Provider.autoDispose<AsyncValue<List<ServiceEntity>>>((ref) {
  final query = ref.watch(debouncedRouteQueryProvider);
  return ref.watch(serviceIndexProvider).whenData((index) => index.directory(query));
});
