import 'package:get_it/get_it.dart';
import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/storage/secure_storage.dart';
import 'package:budget_book/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:budget_book/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:budget_book/features/auth/domain/repositories/auth_repository.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Core
  getIt.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(),
  );
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(),
  );

  // Auth feature
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: getIt<AuthRemoteDataSource>()),
  );
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(
      authRepository: getIt<AuthRepository>(),
      storageService: getIt<SecureStorageService>(),
    ),
  );
}
