import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/datasources/transit_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/transit_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/transit_repository.dart';
import '../../presentation/blocs/auth/auth_bloc.dart';
import '../../presentation/blocs/navigation/navigation_cubit.dart';
import '../../presentation/blocs/owner/owner_bloc.dart';
import '../../presentation/blocs/passenger/search_cubit.dart';

final sl = GetIt.instance;

Future<void> initDI() async {
  // External
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);

  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<TransitRemoteDataSource>(
    () => TransitRemoteDataSourceImpl(sl()),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<TransitRepository>(
    () => TransitRepositoryImpl(sl()),
  );

  // BLoCs & Cubits (Factory registration for clean lifecycle)
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(sl()),
  );
  sl.registerFactory<NavigationCubit>(
    () => NavigationCubit(),
  );
  sl.registerFactory<SearchCubit>(
    () => SearchCubit(),
  );
  sl.registerFactory<OwnerBloc>(
    () => OwnerBloc(sl()),
  );
}
