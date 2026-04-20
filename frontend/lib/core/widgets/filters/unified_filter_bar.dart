import 'package:flutter/material.dart';
import 'package:budget_book/core/models/unified_filter_state.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/filters/date_range_filter.dart';
import 'package:budget_book/core/widgets/filters/category_filter.dart';
import 'package:budget_book/core/widgets/filters/payment_method_filter.dart';
import 'package:budget_book/core/widgets/filters/amount_range_filter.dart';

/// A unified filter bar that shows active filter chips and provides
/// filter controls based on the enabled filter types for each page.
class UnifiedFilterBar extends StatelessWidget {
  final Set<FilterType> enabledFilters;
  final UnifiedFilterState state;
  final ValueChanged<UnifiedFilterState> onFilterChanged;
  /// Optional: category type for category filter ('EXPENSE', 'INCOME')
  final String categoryType;

  const UnifiedFilterBar({
    super.key,
    required this.enabledFilters,
    required this.state,
    required this.onFilterChanged,
    this.categoryType = 'EXPENSE',
  });

  int get _activeFilterCount {
    int count = 0;
    if (enabledFilters.contains(FilterType.transactionType) && state.transactionType != null) count++;
    if (enabledFilters.contains(FilterType.visibility) && state.visibility != null && state.visibility != 'ALL') count++;
    if (enabledFilters.contains(FilterType.category) && state.categoryIds.isNotEmpty) count++;
    if (enabledFilters.contains(FilterType.paymentMethod) && state.paymentMethodIds.isNotEmpty) count++;
    if (enabledFilters.contains(FilterType.pocket) && state.pocketIds.isNotEmpty) count++;
    if (enabledFilters.contains(FilterType.amountRange) && (state.amountMin != null || state.amountMax != null)) count++;
    if (enabledFilters.contains(FilterType.dateRange) && state.hasDateRange) count++;
    return count;
  }

  List<_ChipData> get _allChips {
    final chips = <_ChipData>[];
    if (enabledFilters.contains(FilterType.transactionType) && state.transactionType != null) {
      chips.add(_ChipData(
        label: state.transactionType == 'EXPENSE' ? '지출' : '수입',
        onRemove: () => onFilterChanged(state.copyWith(clearTransactionType: true)),
      ));
    }
    if (enabledFilters.contains(FilterType.visibility) && state.visibility != null && state.visibility != 'ALL') {
      chips.add(_ChipData(
        label: state.visibility == 'SHARED' ? '공유' : '개인',
        onRemove: () => onFilterChanged(state.copyWith(clearVisibility: true)),
      ));
    }
    if (enabledFilters.contains(FilterType.category) && state.categoryIds.isNotEmpty) {
      chips.add(_ChipData(
        label: '카테고리: ${state.categoryName ?? "선택됨"}',
        onRemove: () => onFilterChanged(state.copyWith(clearCategory: true)),
      ));
    }
    if (enabledFilters.contains(FilterType.paymentMethod) && state.paymentMethodIds.isNotEmpty) {
      chips.add(_ChipData(
        label: '결제수단: ${state.paymentMethodName ?? "선택됨"}',
        onRemove: () => onFilterChanged(state.copyWith(clearPaymentMethod: true)),
      ));
    }
    if (enabledFilters.contains(FilterType.pocket) && state.pocketIds.isNotEmpty) {
      chips.add(_ChipData(
        label: '포켓',
        onRemove: () => onFilterChanged(state.copyWith(clearPocket: true)),
      ));
    }
    if (enabledFilters.contains(FilterType.amountRange) && (state.amountMin != null || state.amountMax != null)) {
      final minStr = state.amountMin != null
          ? CurrencyFormatter.format(state.amountMin!)
          : '0';
      final maxStr = state.amountMax != null
          ? CurrencyFormatter.format(state.amountMax!)
          : '\u221E';
      chips.add(_ChipData(
        label: '금액: $minStr~$maxStr원',
        onRemove: () => onFilterChanged(state.copyWith(clearAmount: true)),
      ));
    }
    if (enabledFilters.contains(FilterType.dateRange) && state.hasDateRange) {
      chips.add(_ChipData(
        label: state.dateRangeLabel ?? '기간 설정됨',
        onRemove: () => onFilterChanged(state.copyWith(clearDateRange: true)),
      ));
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAdvancedFilters) return const SizedBox.shrink();

    final chips = _allChips;
    const maxVisible = 3;
    final visibleChips = chips.take(maxVisible).toList();
    final overflowCount = chips.length > maxVisible ? chips.length - maxVisible : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Badge(
            isLabelVisible: _activeFilterCount > 0,
            label: Text('$_activeFilterCount'),
            child: IconButton(
              icon: const Icon(Icons.tune),
              onPressed: () => _showAdvancedFilterSheet(context),
              tooltip: '필터',
            ),
          ),
          ...visibleChips.map((chip) => Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _ActiveFilterChip(
                label: chip.label,
                onRemove: chip.onRemove,
              ),
            ),
          )),
          if (overflowCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Chip(
                label: Text('+$overflowCount', style: const TextStyle(fontSize: 12)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }

  bool get _hasAdvancedFilters =>
      enabledFilters.contains(FilterType.dateRange) ||
      enabledFilters.contains(FilterType.category) ||
      enabledFilters.contains(FilterType.paymentMethod) ||
      enabledFilters.contains(FilterType.pocket) ||
      enabledFilters.contains(FilterType.amountRange) ||
      enabledFilters.contains(FilterType.transactionType) ||
      enabledFilters.contains(FilterType.visibility);

  void _showAdvancedFilterSheet(BuildContext context) {
    final amountMinController = TextEditingController(
      text: state.amountMin?.toString() ?? '',
    );
    final amountMaxController = TextEditingController(
      text: state.amountMax?.toString() ?? '',
    );
    String? tempCategoryId =
        state.categoryIds.isNotEmpty ? state.categoryIds.first : null;
    String? tempCategoryName = state.categoryName;
    String? tempPaymentMethodId =
        state.paymentMethodIds.isNotEmpty
            ? state.paymentMethodIds.first
            : null;
    String? tempPocketId =
        state.pocketIds.isNotEmpty ? state.pocketIds.first : null;
    String? tempTransactionType = state.transactionType;
    String? tempVisibility = state.visibility;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '필터',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  // Transaction type selector
                  if (enabledFilters.contains(FilterType.transactionType)) ...[
                    Text('거래 유형', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<String?>(
                      segments: const [
                        ButtonSegment(value: null, label: Text('전체')),
                        ButtonSegment(value: 'EXPENSE', label: Text('지출')),
                        ButtonSegment(value: 'INCOME', label: Text('수입')),
                      ],
                      selected: {tempTransactionType},
                      onSelectionChanged: (values) {
                        setSheetState(() => tempTransactionType = values.first);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Visibility selector
                  if (enabledFilters.contains(FilterType.visibility)) ...[
                    Text('공개 범위', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<String?>(
                      segments: const [
                        ButtonSegment(value: null, label: Text('전체')),
                        ButtonSegment(value: 'SHARED', label: Text('공유')),
                        ButtonSegment(value: 'PRIVATE', label: Text('개인')),
                      ],
                      selected: {tempVisibility},
                      onSelectionChanged: (values) {
                        setSheetState(() => tempVisibility = values.first);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Date range
                  if (enabledFilters.contains(FilterType.dateRange)) ...[
                    Text('기간', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.hasDateRange
                                ? (state.dateRangeLabel ?? '기간 설정됨')
                                : '전체 기간',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.date_range, size: 18),
                          label: const Text('기간 변경'),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            showDateRangeFilterSheet(
                              context: context,
                              currentFrom: state.dateFrom,
                              currentTo: state.dateTo,
                              onApply: (label, from, to) {
                                onFilterChanged(state.copyWith(
                                  dateFrom: from,
                                  dateTo: to,
                                  dateRangeLabel: label,
                                ));
                              },
                              onClear: () {
                                onFilterChanged(state.copyWith(clearDateRange: true));
                              },
                            );
                          },
                        ),
                        if (state.hasDateRange)
                          IconButton(
                            icon: Icon(Icons.clear, size: 18,
                              color: Theme.of(context).colorScheme.error),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              onFilterChanged(state.copyWith(clearDateRange: true));
                            },
                            tooltip: '기간 초기화',
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Amount range
                  if (enabledFilters.contains(FilterType.amountRange)) ...[
                    AmountRangeFilter(
                      minController: amountMinController,
                      maxController: amountMaxController,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Category selector
                  if (enabledFilters.contains(FilterType.category)) ...[
                    CategoryFilter(
                      selectedCategoryId: tempCategoryId,
                      selectedCategoryName: tempCategoryName,
                      categoryType: categoryType,
                      onChanged: (id, name) {
                        setSheetState(() {
                          tempCategoryId = id;
                          tempCategoryName = name;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Payment method dropdown
                  if (enabledFilters.contains(FilterType.paymentMethod)) ...[
                    PaymentMethodFilter(
                      selectedId: tempPaymentMethodId,
                      onChanged: (value) =>
                          setSheetState(() => tempPaymentMethodId = value),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Pocket dropdown
                  if (enabledFilters.contains(FilterType.pocket)) ...[
                    PocketFilter(
                      selectedId: tempPocketId,
                      onChanged: (value) =>
                          setSheetState(() => tempPocketId = value),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            onFilterChanged(state.copyWith(
                              clearCategory: true,
                              clearPaymentMethod: true,
                              clearPocket: true,
                              clearAmount: true,
                              clearDateRange: true,
                              clearTransactionType: true,
                              clearVisibility: true,
                            ));
                          },
                          child: const Text('초기화'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final minText = amountMinController.text.trim();
                            final maxText = amountMaxController.text.trim();
                            Navigator.of(ctx).pop();
                            onFilterChanged(UnifiedFilterState(
                              dateFrom: state.dateFrom,
                              dateTo: state.dateTo,
                              dateRangeLabel: state.dateRangeLabel,
                              categoryIds: tempCategoryId != null
                                  ? {tempCategoryId!}
                                  : const {},
                              categoryName: tempCategoryName,
                              paymentMethodIds: tempPaymentMethodId != null
                                  ? {tempPaymentMethodId!}
                                  : const {},
                              paymentMethodName:
                                  tempPaymentMethodId != null
                                      ? _resolvePaymentMethodName(
                                          tempPaymentMethodId!)
                                      : null,
                              pocketIds: tempPocketId != null
                                  ? {tempPocketId!}
                                  : const {},
                              amountMin: minText.isEmpty
                                  ? null
                                  : int.tryParse(minText),
                              amountMax: maxText.isEmpty
                                  ? null
                                  : int.tryParse(maxText),
                              keyword: state.keyword,
                              transactionType: tempTransactionType,
                              visibility: tempVisibility,
                              status: state.status,
                            ));
                          },
                          child: const Text('적용'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String? _resolvePaymentMethodName(String pmId) {
    // The payment method name will be resolved by the PaymentMethodFilter
    // For now, we keep the existing name if the ID hasn't changed
    if (state.paymentMethodIds.contains(pmId)) {
      return state.paymentMethodName;
    }
    return null;
  }
}

class _ChipData {
  final String label;
  final VoidCallback onRemove;
  const _ChipData({required this.label, required this.onRemove});
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 14),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
