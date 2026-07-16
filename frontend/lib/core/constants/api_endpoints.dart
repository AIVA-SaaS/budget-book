class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8090',
  );

  // Auth
  static const String authGoogle = '/oauth2/authorization/google';
  static const String authKakao = '/oauth2/authorization/kakao';
  static const String authRefresh = '/api/v1/auth/refresh';
  static const String authMe = '/api/v1/auth/me';
  static const String authLogout = '/api/v1/auth/logout';
  static const String authProfileImage = '/api/v1/auth/me/profile-image';

  // Couple
  static const String coupleMe = '/api/v1/couples/me';
  static const String coupleInvitations = '/api/v1/couples/invitations';
  static const String coupleMyInvitation = '/api/v1/couples/invitations/me';

  // Transaction
  static const String transactions = '/api/v1/transactions';
  static const String transactionSuggestions =
      '/api/v1/transactions/suggestions';

  // Category
  static const String categories = '/api/v1/categories';
  static const String categoriesReorder = '/api/v1/categories/reorder';

  // Category Group
  static const String categoryGroups = '/api/v1/category-groups';
  static const String categoryGroupReorder = '/api/v1/category-groups/reorder';

  // Budget
  static const String budgets = '/api/v1/budgets';

  // Statistics
  static const String statisticsSummary = '/api/v1/statistics/summary';
  static const String statisticsByCategory = '/api/v1/statistics/by-category';
  static const String statisticsMonthlyTrend = '/api/v1/statistics/monthly-trend';

  // Payment Methods
  static const String paymentMethods = '/api/v1/payment-methods';
  static const String paymentMethodsReorder = '/api/v1/payment-methods/reorder';
  static const String paymentMethodsCardPending =
      '/api/v1/payment-methods/card-pending';
  static const String paymentMethodsCardSettlementSummary =
      '/api/v1/payment-methods/card-settlement-summary';
  /// Balance-as-of-date for a single payment method (asOf = exclusive upper
  /// bound, YYYY-MM-DD). See api-spec §7 "Balance As Of Date".
  static String paymentMethodBalance(String id) =>
      '/api/v1/payment-methods/$id/balance';

  // Weekly Budget
  static const String weeklyBudgets = '/api/v1/budgets/weekly';
  static const String weeklyBudgetCurrent = '/api/v1/budgets/weekly/current';

  // Weekly Settlements
  static const String weeklySettlements =
      '/api/v1/budgets/weekly/settlements';
  static const String weeklySettlementsSettle =
      '/api/v1/budgets/weekly/settlements/settle';
  static const String weeklySettlementsUnsettle =
      '/api/v1/budgets/weekly/settlements/unsettle';

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

  // Export / Import
  static const String transactionsExportCsv =
      '/api/v1/transactions/export/csv';
  static const String transactionsImportCsv =
      '/api/v1/transactions/import/csv';

  // Budget Alerts
  static const String budgetAlerts = '/api/v1/budgets/alerts';

  // Statistics - Payment Methods
  static const String statisticsPaymentMethods =
      '/api/v1/statistics/payment-methods';

  // Statistics - Period Summary
  static const String statisticsPeriodSummary =
      '/api/v1/statistics/period-summary';

  // Transfers (payment method to payment method)
  static const String transfers = '/api/v1/transfers';

  // Preferences (Favorites)
  static const String preferencesFavorites = '/api/v1/preferences/favorites';
  static const String preferencesFavoritesToggle =
      '/api/v1/preferences/favorites/toggle';

  // Spending Plans
  static const String spendingPlans = '/api/v1/spending-plans';

  // Insurances
  static const String insurances = '/api/v1/insurances';

  // Admin
  static const String adminStats = '/api/v1/admin/stats';
  static const String adminUsers = '/api/v1/admin/users';
  static const String adminAnnouncements = '/api/v1/admin/announcements';

  // Announcements (public)
  static const String announcementsActive = '/api/v1/announcements/active';

  // Feedback
  static const String feedback = '/api/v1/feedback';
  static const String feedbackPublic = '/api/v1/feedback/public';
  static const String feedbackPublicTop = '/api/v1/feedback/public/top';

  // Release Notes (public)
  static const String releases = '/api/v1/releases';

  // Admin Feedback
  static const String adminFeedback = '/api/v1/admin/feedback';

  // Admin Release Notes
  static const String adminReleases = '/api/v1/admin/releases';

  // Smart Analysis (replaces old /api/v1/ai/* endpoints)
  static const String smartClassify = '/api/v1/smart/classify';
  static const String smartInsights = '/api/v1/smart/insights';
  static const String smartBudgetSuggestions = '/api/v1/smart/budget-suggestions';

  // Legacy AI endpoints (kept for reference)
  static const String aiClassify = '/api/v1/ai/classify';
  static const String aiInsights = '/api/v1/ai/insights';
}
