import 'package:flutter/material.dart';
import 'package:budget_book/core/models/unified_filter_state.dart';
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFilterButtons(context),
        if (_hasActiveChips) _buildActiveChips(context),
      ],
    );
  }

  bool get _hasActiveChips {
    if (enabledFilters.contains(FilterType.dateRange) &&
        state.hasDateRange) {
      return true;
    }
    if (enabledFilters.contains(FilterType.category) &&
        state.categoryIds.isNotEmpty) {
      return true;
    }
    if (enabledFilters.contains(FilterType.paymentMethod) &&
        state.paymentMethodIds.isNotEmpty) {
      return true;
    }
    if (enabledFilters.contains(FilterType.pocket) &&
        state.pocketIds.isNotEmpty) {
      return true;
    }
    if (enabledFilters.contains(FilterType.amountRange) &&
        (state.amountMin != null || state.amountMax != null)) {
      return true;
    }
    return false;
  }

  Widget _buildFilterButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Main filter button (opens bottom sheet with category, payment, pocket, amount)
          if (_hasAdvancedFilters)
            Badge(
              isLabelVisible: _hasAdvancedActiveFilters,
              child: IconButton(
                icon: const Icon(Icons.tune),
                onPressed: () => _showAdvancedFilterSheet(context),
                tooltip: '필터',
              ),
            ),
          // Date range button
          if (enabledFilters.contains(FilterType.dateRange))
            IconButton(
              icon: Icon(
                Icons.date_range,
                color: state.hasDateRange
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              onPressed: () => showDateRangeFilterSheet(
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
              ),
              tooltip: '기간 필터',
            ),
        ],
      ),
    );
  }

  bool get _hasAdvancedFilters =>
      enabledFilters.contains(FilterType.category) ||
      enabledFilters.contains(FilterType.paymentMethod) ||
      enabledFilters.contains(FilterType.pocket) ||
      enabledFilters.contains(FilterType.amountRange);

  bool get _hasAdvancedActiveFilters =>
      state.categoryIds.isNotEmpty ||
      state.paymentMethodIds.isNotEmpty ||
      state.pocketIds.isNotEmpty ||
      state.amountMin != null ||
      state.amountMax != null;

  Widget _buildActiveChips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          if (state.categoryIds.isNotEmpty)
            _ActiveFilterChip(
              label: '카테고리: ${state.categoryName ?? "선택됨"}',
              onRemove: () =>
                  onFilterChanged(state.copyWith(clearCategory: true)),
            ),
          if (state.paymentMethodIds.isNotEmpty)
            _ActiveFilterChip(
              label: '결제수단: ${state.paymentMethodName ?? "선택됨"}',
              onRemove: () =>
                  onFilterChanged(state.copyWith(clearPaymentMethod: true)),
            ),
          if (state.pocketIds.isNotEmpty)
            _ActiveFilterChip(
              label: '포켓',
              onRemove: () =>
                  onFilterChanged(state.copyWith(clearPocket: true)),
            ),
          if (state.amountMin != null || state.amountMax != null)
            _ActiveFilterChip(
              label:
                  '금액: ${state.amountMin ?? 0}~${state.amountMax ?? "\u221E"}원',
              onRemove: () =>
                  onFilterChanged(state.copyWith(clearAmount: true)),
            ),
          if (state.hasDateRange)
            _ActiveFilterChip(
              label: state.dateRangeLabel ?? '기간 설정됨',
              onRemove: () =>
                  onFilterChanged(state.copyWith(clearDateRange: true)),
            ),
        ],
      ),
    );
  }

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
                              visibility: state.visibility,
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

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 14),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
