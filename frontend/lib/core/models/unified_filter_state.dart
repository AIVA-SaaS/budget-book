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
}

class UnifiedFilterState extends Equatable {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? dateRangeLabel;
  final Set<String> categoryIds;
  final String? categoryName;
  final Set<String> paymentMethodIds;
  final String? paymentMethodName;
  final Set<String> pocketIds;
  final int? amountMin;
  final int? amountMax;
  final String? keyword;
  final String? transactionType;
  final String? visibility;
  final String? status;

  const UnifiedFilterState({
    this.dateFrom,
    this.dateTo,
    this.dateRangeLabel,
    this.categoryIds = const {},
    this.categoryName,
    this.paymentMethodIds = const {},
    this.paymentMethodName,
    this.pocketIds = const {},
    this.amountMin,
    this.amountMax,
    this.keyword,
    this.transactionType,
    this.visibility,
    this.status,
  });

  bool get hasActiveFilters =>
      dateFrom != null ||
      dateTo != null ||
      categoryIds.isNotEmpty ||
      paymentMethodIds.isNotEmpty ||
      pocketIds.isNotEmpty ||
      amountMin != null ||
      amountMax != null ||
      (keyword != null && keyword!.isNotEmpty) ||
      transactionType != null ||
      (visibility != null && visibility != 'ALL') ||
      status != null;

  bool get hasDateRange => dateFrom != null && dateTo != null;

  UnifiedFilterState copyWith({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? dateRangeLabel,
    Set<String>? categoryIds,
    String? categoryName,
    Set<String>? paymentMethodIds,
    String? paymentMethodName,
    Set<String>? pocketIds,
    int? amountMin,
    int? amountMax,
    String? keyword,
    String? transactionType,
    String? visibility,
    String? status,
    bool clearDateRange = false,
    bool clearCategory = false,
    bool clearPaymentMethod = false,
    bool clearPocket = false,
    bool clearAmount = false,
    bool clearKeyword = false,
    bool clearTransactionType = false,
    bool clearVisibility = false,
    bool clearStatus = false,
  }) {
    return UnifiedFilterState(
      dateFrom: clearDateRange ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateRange ? null : (dateTo ?? this.dateTo),
      dateRangeLabel:
          clearDateRange ? null : (dateRangeLabel ?? this.dateRangeLabel),
      categoryIds:
          clearCategory ? const {} : (categoryIds ?? this.categoryIds),
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
      transactionType: clearTransactionType
          ? null
          : (transactionType ?? this.transactionType),
      visibility:
          clearVisibility ? null : (visibility ?? this.visibility),
      status: clearStatus ? null : (status ?? this.status),
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
        categoryName,
        paymentMethodIds,
        paymentMethodName,
        pocketIds,
        amountMin,
        amountMax,
        keyword,
        transactionType,
        visibility,
        status,
      ];
}
