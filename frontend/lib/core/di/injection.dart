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
import 'package:budget_book/features/category_group/data/datasources/category_group_remote_datasource.dart';
import 'package:budget_book/features/category_group/data/repositories/category_group_repository_impl.dart';
import 'package:budget_book/features/category_group/domain/repositories/category_group_repository.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/payment_method/data/datasources/payment_method_remote_datasource.dart';
import 'package:budget_book/features/payment_method/data/repositories/payment_method_repository_impl.dart';
import 'package:budget_book/features/payment_method/domain/repositories/payment_method_repository.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/weekly_budget/data/datasources/weekly_budget_remote_datasource.dart';
import 'package:budget_book/features/weekly_budget/data/repositories/weekly_budget_repository_impl.dart';
import 'package:budget_book/features/weekly_budget/domain/repositories/weekly_budget_repository.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_bloc.dart';
import 'package:budget_book/features/report/data/datasources/report_remote_datasource.dart';
import 'package:budget_book/features/report/data/repositories/report_repository_impl.dart';
import 'package:budget_book/features/report/domain/repositories/report_repository.dart';
import 'package:budget_book/features/report/presentation/bloc/report_bloc.dart';
import 'package:budget_book/features/recurring/data/datasources/recurring_remote_datasource.dart';
import 'package:budget_book/features/recurring/data/repositories/recurring_repository_impl.dart';
import 'package:budget_book/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:budget_book/features/recurring/presentation/bloc/recurring_bloc.dart';
import 'package:budget_book/features/pocket/data/datasources/pocket_remote_datasource.dart';
import 'package:budget_book/features/pocket/data/repositories/pocket_repository_impl.dart';
import 'package:budget_book/features/pocket/domain/repositories/pocket_repository.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/data/datasources/pocket_transfer_remote_datasource.dart';
import 'package:budget_book/features/pocket/data/repositories/pocket_transfer_repository_impl.dart';
import 'package:budget_book/features/pocket/domain/repositories/pocket_transfer_repository.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_transfer_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/core/websocket/websocket_service.dart';
import 'package:budget_book/core/websocket/sync_event_handler.dart';
import 'package:budget_book/core/websocket/websocket_bloc.dart';
import 'package:budget_book/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:budget_book/features/settings/presentation/cubit/locale_cubit.dart';
import 'package:budget_book/core/services/connectivity_service.dart';
import 'package:budget_book/core/services/cache_service.dart';

final getIt = GetIt.instance;

/// Disposes all singleton BLoCs and services registered in GetIt.
/// Call this on app shutdown to prevent resource leaks.
Future<void> disposeAllSingletons() async {
  await getIt.reset();
}

Future<void> configureDependencies() async {
  // Core
  getIt.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(),
  );
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(),
  );

  // Connectivity
  getIt.registerLazySingleton<ConnectivityService>(
    () => ConnectivityService(),
    dispose: (service) => service.dispose(),
  );

  // Cache
  getIt.registerLazySingleton<CacheService>(
    () => CacheService(),
  );

  // Auth feature
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: getIt<AuthRemoteDataSource>()),
  );
  getIt.registerLazySingleton<AuthBloc>(
    () => AuthBloc(
      authRepository: getIt<AuthRepository>(),
      storageService: getIt<SecureStorageService>(),
    ),
    dispose: (bloc) => bloc.close(),
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
  getIt.registerLazySingleton<CategoryBloc>(
    () => CategoryBloc(categoryRepository: getIt<CategoryRepository>()),
    dispose: (bloc) => bloc.close(),
  );

  // Transaction feature
  getIt.registerLazySingleton<TransactionRemoteDataSource>(
    () => TransactionRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(
        remoteDataSource: getIt<TransactionRemoteDataSource>()),
  );
  getIt.registerLazySingleton<TransactionBloc>(
    () => TransactionBloc(
        transactionRepository: getIt<TransactionRepository>()),
    dispose: (bloc) => bloc.close(),
  );

  // Budget feature
  getIt.registerLazySingleton<BudgetRemoteDataSource>(
    () => BudgetRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<BudgetRepository>(
    () => BudgetRepositoryImpl(
        remoteDataSource: getIt<BudgetRemoteDataSource>()),
  );
  getIt.registerLazySingleton<BudgetBloc>(
    () => BudgetBloc(budgetRepository: getIt<BudgetRepository>()),
    dispose: (bloc) => bloc.close(),
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

  // Payment Method feature
  getIt.registerLazySingleton<PaymentMethodRemoteDataSource>(
    () => PaymentMethodRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<PaymentMethodRepository>(
    () => PaymentMethodRepositoryImpl(
        remoteDataSource: getIt<PaymentMethodRemoteDataSource>()),
  );
  getIt.registerLazySingleton<PaymentMethodBloc>(
    () => PaymentMethodBloc(
        paymentMethodRepository: getIt<PaymentMethodRepository>()),
    dispose: (bloc) => bloc.close(),
  );

  // Category Group feature
  getIt.registerLazySingleton<CategoryGroupRemoteDataSource>(
    () => CategoryGroupRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<CategoryGroupRepository>(
    () => CategoryGroupRepositoryImpl(
        remoteDataSource: getIt<CategoryGroupRemoteDataSource>()),
  );
  getIt.registerLazySingleton<CategoryGroupBloc>(
    () => CategoryGroupBloc(
        categoryGroupRepository: getIt<CategoryGroupRepository>()),
    dispose: (bloc) => bloc.close(),
  );

  // Weekly Budget feature
  getIt.registerLazySingleton<WeeklyBudgetRemoteDataSource>(
    () => WeeklyBudgetRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<WeeklyBudgetRepository>(
    () => WeeklyBudgetRepositoryImpl(
        remoteDataSource: getIt<WeeklyBudgetRemoteDataSource>()),
  );
  getIt.registerFactory<WeeklyBudgetBloc>(
    () => WeeklyBudgetBloc(
        weeklyBudgetRepository: getIt<WeeklyBudgetRepository>()),
  );

  // Report feature
  getIt.registerLazySingleton<ReportRemoteDataSource>(
    () => ReportRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<ReportRepository>(
    () => ReportRepositoryImpl(
        remoteDataSource: getIt<ReportRemoteDataSource>()),
  );
  getIt.registerFactory<ReportBloc>(
    () => ReportBloc(reportRepository: getIt<ReportRepository>()),
  );

  // Recurring Transaction feature
  getIt.registerLazySingleton<RecurringRemoteDataSource>(
    () => RecurringRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<RecurringRepository>(
    () => RecurringRepositoryImpl(
        remoteDataSource: getIt<RecurringRemoteDataSource>()),
  );
  getIt.registerFactory<RecurringBloc>(
    () => RecurringBloc(recurringRepository: getIt<RecurringRepository>()),
  );

  // Money Pocket feature
  getIt.registerLazySingleton<PocketRemoteDataSource>(
    () => PocketRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<PocketRepository>(
    () => PocketRepositoryImpl(
        remoteDataSource: getIt<PocketRemoteDataSource>()),
  );
  getIt.registerLazySingleton<PocketBloc>(
    () => PocketBloc(pocketRepository: getIt<PocketRepository>()),
    dispose: (bloc) => bloc.close(),
  );

  // Pocket Transfer feature
  getIt.registerLazySingleton<PocketTransferRemoteDataSource>(
    () => PocketTransferRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<PocketTransferRepository>(
    () => PocketTransferRepositoryImpl(
        remoteDataSource: getIt<PocketTransferRemoteDataSource>()),
  );
  getIt.registerLazySingleton<PocketTransferBloc>(
    () => PocketTransferBloc(
        pocketTransferRepository: getIt<PocketTransferRepository>()),
    dispose: (bloc) => bloc.close(),
  );

  // WebSocket / Real-time sync
  getIt.registerLazySingleton<WebSocketService>(
    () => WebSocketService(),
    dispose: (service) => service.dispose(),
  );
  getIt.registerLazySingleton<SyncEventHandler>(
    () => SyncEventHandler(getIt: getIt),
  );
  getIt.registerLazySingleton<WebSocketBloc>(
    () => WebSocketBloc(
      webSocketService: getIt<WebSocketService>(),
      syncEventHandler: getIt<SyncEventHandler>(),
    ),
    dispose: (bloc) => bloc.close(),
  );

  // Settings cubits
  getIt.registerLazySingleton<ThemeCubit>(
    () => ThemeCubit(),
    dispose: (cubit) => cubit.close(),
  );
  getIt.registerLazySingleton<LocaleCubit>(
    () => LocaleCubit(),
    dispose: (cubit) => cubit.close(),
  );

  // Dashboard feature
  getIt.registerLazySingleton<DashboardBloc>(
    () => DashboardBloc(
      statisticsRepository: getIt<StatisticsRepository>(),
      transactionRepository: getIt<TransactionRepository>(),
      budgetRepository: getIt<BudgetRepository>(),
    ),
    dispose: (bloc) => bloc.close(),
  );
}
