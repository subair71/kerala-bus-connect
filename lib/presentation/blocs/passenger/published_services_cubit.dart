import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/service_entity.dart';
import '../../../domain/repositories/transit_repository.dart';
import '../../../domain/services/service_search_index.dart';

class PublishedServicesState {
  final ServiceSearchIndex? index;
  final bool loading;
  final bool hasError;

  const PublishedServicesState({
    this.index,
    this.loading = true,
    this.hasError = false,
  });
}

/// One subscription shared by passenger search and the route directory.
/// Created lazily and closed by the application BlocProvider.
class PublishedServicesCubit extends Cubit<PublishedServicesState> {
  final TransitRepository _repository;
  StreamSubscription<List<ServiceEntity>>? _subscription;
  int _generation = 0;

  PublishedServicesCubit(this._repository)
      : super(const PublishedServicesState()) {
    reload();
  }

  Future<void> reload() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    if (isClosed || generation != _generation) return;
    emit(PublishedServicesState(index: state.index));
    try {
      _subscription = _repository.getPublishedServices().listen(
        (services) {
          if (!isClosed && generation == _generation) {
            emit(PublishedServicesState(
              index: ServiceSearchIndex(services),
              loading: false,
            ));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!isClosed && generation == _generation) {
            emit(PublishedServicesState(
              index: state.index,
              loading: false,
              hasError: true,
            ));
          }
        },
      );
    } catch (_) {
      if (!isClosed && generation == _generation) {
        emit(PublishedServicesState(
          index: state.index,
          loading: false,
          hasError: true,
        ));
      }
    }
  }

  @override
  Future<void> close() async {
    ++_generation;
    await _subscription?.cancel();
    return super.close();
  }
}
