class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  // Auth
  static const String authGoogle = '/oauth2/authorization/google';
  static const String authKakao = '/oauth2/authorization/kakao';
  static const String authRefresh = '/api/v1/auth/refresh';
  static const String authMe = '/api/v1/auth/me';
  static const String authLogout = '/api/v1/auth/logout';

  // Couple
  static const String coupleMe = '/api/v1/couples/me';
  static const String coupleInvitations = '/api/v1/couples/invitations';

  // Transaction
  static const String transactions = '/api/v1/transactions';

  // Category
  static const String categories = '/api/v1/categories';

  // Category Group
  static const String categoryGroups = '/api/v1/category-groups';

  // Budget
  static const String budgets = '/api/v1/budgets';

  // Statistics
  static const String statisticsSummary = '/api/v1/statistics/summary';
  static const String statisticsByCategory = '/api/v1/statistics/by-category';
  static const String statisticsMonthlyTrend = '/api/v1/statistics/monthly-trend';

  // Payment Methods
  static const String paymentMethods = '/api/v1/payment-methods';
  static const String paymentMethodsCardPending =
      '/api/v1/payment-methods/card-pending';

  // Weekly Budget
  static const String weeklyBudgets = '/api/v1/budgets/weekly';
  static const String weeklyBudgetCurrent = '/api/v1/budgets/weekly/current';

  // Reports
  static const String reportsWeekly = '/api/v1/reports/weekly';
  static const String reportsMonthly = '/api/v1/reports/monthly';

  // Recurring Transactions
  static const String recurringTransactions = '/api/v1/recurring-transactions';

  // Money Pockets
  static const String pockets = '/api/v1/pockets';
  static const String pocketsDistribute = '/api/v1/pockets/distribute';
  static const String pocketsDistributionRatios =
      '/api/v1/pockets/distribution-ratios';

  // Pocket Transfers
  static const String pocketTransfers = '/api/v1/pocket-transfers';

  // Export
  static const String transactionsExportCsv =
      '/api/v1/transactions/export/csv';

}
