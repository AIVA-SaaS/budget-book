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
  static const String couples = '/api/v1/couples';
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

  // Export
  static const String exportCsv = '/api/v1/export/csv';
}
