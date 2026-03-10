import 'package:get_it/get_it.dart';
import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/storage/secure_storage.dart';
import 'package:budget_book/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:budget_book/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:budget_book/features/auth/domain/repositories/auth_repository.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/couple/data/datasources/couple_remote_datasource.dart';
import 'package:budget_book/features/couple/data/repositories/couple_repository_impl.dart';
import 'package:budget_book/features/couple/domain/repositories/couple_repository.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/category/data/datasources/category_remote_datasource.dart';
import 'package:budget_book/features/category/data/repositories/category_repository_impl.dart';
import 'package:budget_book/features/category/domain/repositories/category_repository.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/transaction/data/datasources/transaction_remote_datasource.dart';
import 'package:budget_book/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/budget/data/datasources/budget_remote_datasource.dart';
import 'package:budget_book/features/budget/data/repositories/budget_repository_impl.dart';
import 'package:budget_book/features/budget/domain/repositories/budget_repository.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/statistics/data/datasources/statistics_remote_datasource.dart';
import 'package:budget_book/features/statistics/data/repositories/statistics_repository_impl.dart';
import 'package:budget_book/features/statistics/domain/repositories/statistics_repository.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_bloc.dart';

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

  // Couple feature
  getIt.registerLazySingleton<CoupleRemoteDataSource>(
    () => CoupleRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<CoupleRepository>(
    () => CoupleRepositoryImpl(
        remoteDataSource: getIt<CoupleRemoteDataSource>()),
  );
  getIt.registerFactory<CoupleBloc>(
    () => CoupleBloc(coupleRepository: getIt<CoupleRepository>()),
  );

  // Category feature
  getIt.registerLazySingleton<CategoryRemoteDataSource>(
    () => CategoryRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(
        remoteDataSource: getIt<CategoryRemoteDataSource>()),
  );
  getIt.registerFactory<CategoryBloc>(
    () => CategoryBloc(categoryRepository: getIt<CategoryRepository>()),
  );

  // Transaction feature
  getIt.registerLazySingleton<TransactionRemoteDataSource>(
    () => TransactionRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(
        remoteDataSource: getIt<TransactionRemoteDataSource>()),
  );
  getIt.registerFactory<TransactionBloc>(
    () => TransactionBloc(
        transactionRepository: getIt<TransactionRepository>()),
  );

  // Budget feature
  getIt.registerLazySingleton<BudgetRemoteDataSource>(
    () => BudgetRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<BudgetRepository>(
    () => BudgetRepositoryImpl(
        remoteDataSource: getIt<BudgetRemoteDataSource>()),
  );
  getIt.registerFactory<BudgetBloc>(
    () => BudgetBloc(budgetRepository: getIt<BudgetRepository>()),
  );

  // Statistics feature
  getIt.registerLazySingleton<StatisticsRemoteDataSource>(
    () => StatisticsRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<StatisticsRepository>(
    () => StatisticsRepositoryImpl(
        remoteDataSource: getIt<StatisticsRemoteDataSource>()),
  );
  getIt.registerFactory<StatisticsBloc>(
    () => StatisticsBloc(
        statisticsRepository: getIt<StatisticsRepository>()),
  );
}
