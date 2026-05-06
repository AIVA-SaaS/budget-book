import 'package:equatable/equatable.dart';

enum FilterType {
  dateRange,
  category,
  paymentMethod,
  pocket,
  amountRange,
  keyword,
  transactionType,
  visibility,
  status,
  needsReview,
}

class UnifiedFilterState extends Equatable {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? dateRangeLabel;
  final Set<String> categoryIds;
  final Set<String> categoryGroupIds;
  final String? categoryName;
  final Set<String> paymentMethodIds;
  final String? paymentMethodName;
  final Set<String> pocketIds;
  final int? amountMin;
  final int? amountMax;
  final String? keyword;

  /// Multi-select transaction types. Values: 'EXPENSE', 'INCOME', 'TRANSFER'.
  /// Empty set means "all types" (no filter). Phase 22 §3.
  final Set<String> transactionTypes;
  final String? visibility;
  final String? status;

  /// V61 (2026-05-06) — true 면 needs_review=true 거래만 (확인/입력 필요만 보기).
  final bool needsReviewOnly;

  const UnifiedFilterState({
    this.dateFrom,
    this.dateTo,
    this.dateRangeLabel,
    this.categoryIds = const {},
    this.categoryGroupIds = const {},
    this.categoryName,
    this.paymentMethodIds = const {},
    this.paymentMethodName,
    this.pocketIds = const {},
    this.amountMin,
    this.amountMax,
    this.keyword,
    this.transactionTypes = const {},
    this.visibility,
    this.status,
    this.needsReviewOnly = false,
  });

  /// Legacy single-value accessor. Returns the first selected type, or null.
  /// Kept for transitional callers; new code should read [transactionTypes].
  String? get transactionType =>
      transactionTypes.isEmpty ? null : transactionTypes.first;

  bool get hasActiveFilters =>
      dateFrom != null ||
      dateTo != null ||
      categoryIds.isNotEmpty ||
      categoryGroupIds.isNotEmpty ||
      paymentMethodIds.isNotEmpty ||
      pocketIds.isNotEmpty ||
      amountMin != null ||
      amountMax != null ||
      (keyword != null && keyword!.isNotEmpty) ||
      transactionTypes.isNotEmpty ||
      (visibility != null && visibility != 'ALL') ||
      status != null ||
      needsReviewOnly;

  bool get hasDateRange => dateFrom != null && dateTo != null;

  UnifiedFilterState copyWith({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? dateRangeLabel,
    Set<String>? categoryIds,
    Set<String>? categoryGroupIds,
    String? categoryName,
    Set<String>? paymentMethodIds,
    String? paymentMethodName,
    Set<String>? pocketIds,
    int? amountMin,
    int? amountMax,
    String? keyword,
    Set<String>? transactionTypes,
    String? visibility,
    String? status,
    bool? needsReviewOnly,
    bool clearDateRange = false,
    bool clearCategory = false,
    bool clearPaymentMethod = false,
    bool clearPocket = false,
    bool clearAmount = false,
    bool clearKeyword = false,
    bool clearTransactionType = false,
    bool clearVisibility = false,
    bool clearStatus = false,
    bool clearNeedsReview = false,
  }) {
    return UnifiedFilterState(
      dateFrom: clearDateRange ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateRange ? null : (dateTo ?? this.dateTo),
      dateRangeLabel:
          clearDateRange ? null : (dateRangeLabel ?? this.dateRangeLabel),
      categoryIds:
          clearCategory ? const {} : (categoryIds ?? this.categoryIds),
      categoryGroupIds: clearCategory
          ? const {}
          : (categoryGroupIds ?? this.categoryGroupIds),
      categoryName:
          clearCategory ? null : (categoryName ?? this.categoryName),
      paymentMethodIds: clearPaymentMethod
          ? const {}
          : (paymentMethodIds ?? this.paymentMethodIds),
      paymentMethodName: clearPaymentMethod
          ? null
          : (paymentMethodName ?? this.paymentMethodName),
      pocketIds: clearPocket ? const {} : (pocketIds ?? this.pocketIds),
      amountMin: clearAmount ? null : (amountMin ?? this.amountMin),
      amountMax: clearAmount ? null : (amountMax ?? this.amountMax),
      keyword: clearKeyword ? null : (keyword ?? this.keyword),
      transactionTypes: clearTransactionType
          ? const {}
          : (transactionTypes ?? this.transactionTypes),
      visibility:
          clearVisibility ? null : (visibility ?? this.visibility),
      status: clearStatus ? null : (status ?? this.status),
      needsReviewOnly: clearNeedsReview
          ? false
          : (needsReviewOnly ?? this.needsReviewOnly),
    );
  }

  UnifiedFilterState clearAll() {
    return const UnifiedFilterState();
  }

  @override
  List<Object?> get props => [
        dateFrom,
        dateTo,
        dateRangeLabel,
        categoryIds,
        categoryGroupIds,
        categoryName,
        paymentMethodIds,
        paymentMethodName,
        pocketIds,
        amountMin,
        amountMax,
        keyword,
        transactionTypes,
        visibility,
        status,
        needsReviewOnly,
      ];
}
