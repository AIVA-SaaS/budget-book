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
  static const String coupleInvite = '/api/v1/couples/invite';
  static const String coupleJoin = '/api/v1/couples/join';

  // Transaction
  static const String transactions = '/api/v1/transactions';

  // Category
  static const String categories = '/api/v1/categories';

  // Budget
  static const String budgets = '/api/v1/budgets';

  // Statistics
  static const String statisticsMonthly = '/api/v1/statistics/monthly';
  static const String statisticsYearly = '/api/v1/statistics/yearly';
  static const String statisticsCategory = '/api/v1/statistics/category';

  // Export
  static const String exportCsv = '/api/v1/export/csv';
}
