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
import 'package:budget_book/features/weekly_budget/data/datasources/weekly_settlement_remote_datasource.dart';
import 'package:budget_book/features/weekly_budget/data/repositories/weekly_settlement_repository_impl.dart';
import 'package:budget_book/features/weekly_budget/domain/repositories/weekly_settlement_repository.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_settlement_bloc.dart';
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
import 'package:budget_book/features/transfer/data/datasources/transfer_remote_datasource.dart';
import 'package:budget_book/features/transfer/data/repositories/transfer_repository_impl.dart';
import 'package:budget_book/features/transfer/domain/repositories/transfer_repository.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/core/websocket/websocket_service.dart';
import 'package:budget_book/core/websocket/sync_event_handler.dart';
import 'package:budget_book/core/websocket/websocket_bloc.dart';
import 'package:budget_book/features/insurance/data/datasources/insurance_remote_datasource.dart';
import 'package:budget_book/features/insurance/data/repositories/insurance_repository_impl.dart';
import 'package:budget_book/features/insurance/domain/repositories/insurance_repository.dart';
import 'package:budget_book/features/insurance/presentation/bloc/insurance_bloc.dart';
import 'package:budget_book/features/spending_plan/data/datasources/spending_plan_remote_datasource.dart';
import 'package:budget_book/features/spending_plan/data/repositories/spending_plan_repository_impl.dart';
import 'package:budget_book/features/spending_plan/domain/repositories/spending_plan_repository.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_bloc.dart';
import 'package:budget_book/features/preference/data/datasources/preference_remote_datasource.dart';
import 'package:budget_book/features/preference/data/repositories/preference_repository_impl.dart';
import 'package:budget_book/features/preference/domain/repositories/preference_repository.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_bloc.dart';
import 'package:budget_book/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:budget_book/features/settings/presentation/cubit/locale_cubit.dart';
import 'package:budget_book/core/services/connectivity_service.dart';
import 'package:budget_book/core/services/cache_service.dart';
import 'package:budget_book/features/feedback/data/datasources/feedback_remote_datasource.dart';
import 'package:budget_book/features/feedback/data/repositories/feedback_repository_impl.dart';
import 'package:budget_book/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:budget_book/features/feedback/presentation/bloc/release_note_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/period_summary_bloc.dart';

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
  getIt.registerLazySingleton<CoupleBloc>(
    () => CoupleBloc(coupleRepository: getIt<CoupleRepository>()),
    dispose: (bloc) => bloc.close(),
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
        transactionRepository: getIt<TransactionRepository>(),
        statisticsRepository: getIt<StatisticsRepository>()),
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
  getIt.registerLazySingleton<StatisticsBloc>(
    () => StatisticsBloc(
        statisticsRepository: getIt<StatisticsRepository>()),
    dispose: (bloc) => bloc.close(),
  );
  getIt.registerLazySingleton<PeriodSummaryBloc>(
    () => PeriodSummaryBloc(
        statisticsRepository: getIt<StatisticsRepository>()),
    dispose: (bloc) => bloc.close(),
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
  getIt.registerLazySingleton<WeeklyBudgetBloc>(
    () => WeeklyBudgetBloc(
        weeklyBudgetRepository: getIt<WeeklyBudgetRepository>()),
    dispose: (bloc) => bloc.close(),
  );

  // Weekly Settlement feature
  getIt.registerLazySingleton<WeeklySettlementRemoteDataSource>(
    () => WeeklySettlementRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<WeeklySettlementRepository>(
    () => WeeklySettlementRepositoryImpl(
        remoteDataSource: getIt<WeeklySettlementRemoteDataSource>()),
  );
  getIt.registerLazySingleton<WeeklySettlementBloc>(
    () => WeeklySettlementBloc(
        settlementRepository: getIt<WeeklySettlementRepository>()),
    dispose: (bloc) => bloc.close(),
  );

  // Report feature
  getIt.registerLazySingleton<ReportRemoteDataSource>(
    () => ReportRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<ReportRepository>(
    () => ReportRepositoryImpl(
        remoteDataSource: getIt<ReportRemoteDataSource>()),
  );
  getIt.registerLazySingleton<ReportBloc>(
    () => ReportBloc(reportRepository: getIt<ReportRepository>()),
    dispose: (bloc) => bloc.close(),
  );

  // Recurring Transaction feature
  getIt.registerLazySingleton<RecurringRemoteDataSource>(
    () => RecurringRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<RecurringRepository>(
    () => RecurringRepositoryImpl(
        remoteDataSource: getIt<RecurringRemoteDataSource>()),
  );
  getIt.registerLazySingleton<RecurringBloc>(
    () => RecurringBloc(recurringRepository: getIt<RecurringRepository>()),
    dispose: (bloc) => bloc.close(),
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

  // Transfer feature
  getIt.registerLazySingleton<TransferRemoteDataSource>(
    () => TransferRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<TransferRepository>(
    () => TransferRepositoryImpl(
        remoteDataSource: getIt<TransferRemoteDataSource>()),
  );
  getIt.registerLazySingleton<TransferBloc>(
    () => TransferBloc(
        transferRepository: getIt<TransferRepository>()),
    dispose: (bloc) => bloc.close(),
  );

  // Insurance feature
  getIt.registerLazySingleton<InsuranceRemoteDataSource>(
    () => InsuranceRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<InsuranceRepository>(
    () => InsuranceRepositoryImpl(
        remoteDataSource: getIt<InsuranceRemoteDataSource>()),
  );
  getIt.registerLazySingleton<InsuranceBloc>(
    () => InsuranceBloc(
        insuranceRepository: getIt<InsuranceRepository>()),
    dispose: (bloc) => bloc.close(),
  );

  // Spending Plan feature
  getIt.registerLazySingleton<SpendingPlanRemoteDataSource>(
    () => SpendingPlanRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<SpendingPlanRepository>(
    () => SpendingPlanRepositoryImpl(
        remoteDataSource: getIt<SpendingPlanRemoteDataSource>()),
  );
  getIt.registerLazySingleton<SpendingPlanBloc>(
    () => SpendingPlanBloc(
        spendingPlanRepository: getIt<SpendingPlanRepository>()),
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

  // Preference (Favorites) feature
  getIt.registerLazySingleton<PreferenceRemoteDataSource>(
    () => PreferenceRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<PreferenceRepository>(
    () => PreferenceRepositoryImpl(
        remoteDataSource: getIt<PreferenceRemoteDataSource>()),
  );
  getIt.registerLazySingleton<FavoritesBloc>(
    () => FavoritesBloc(
        preferenceRepository: getIt<PreferenceRepository>()),
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

  // Feedback feature
  getIt.registerLazySingleton<FeedbackRemoteDataSource>(
    () => FeedbackRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<FeedbackRepository>(
    () => FeedbackRepositoryImpl(
        remoteDataSource: getIt<FeedbackRemoteDataSource>()),
  );
  getIt.registerLazySingleton<FeedbackBloc>(
    () => FeedbackBloc(
        feedbackRepository: getIt<FeedbackRepository>()),
    dispose: (bloc) => bloc.close(),
  );
  getIt.registerLazySingleton<ReleaseNoteBloc>(
    () => ReleaseNoteBloc(
        feedbackRepository: getIt<FeedbackRepository>()),
    dispose: (bloc) => bloc.close(),
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
