import 'package:flutter/material.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/models/unified_filter_state.dart';
import 'package:budget_book/core/widgets/filters/date_range_filter.dart';
import 'package:budget_book/core/widgets/filters/category_filter.dart';
import 'package:budget_book/core/widgets/filters/payment_method_filter.dart';
import 'package:budget_book/core/widgets/filters/amount_range_filter.dart';
import 'package:budget_book/core/widgets/filters/selectable_chip_group.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_state.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';

/// A unified filter bar that shows active filter chips and provides
/// filter controls based on the enabled filter types for each page.
///
/// PR-C3: 카테고리/결제수단/포켓을 **복수 선택** + 카테고리 그룹 선택 지원.
/// displayLabel 규칙: 0개 = "전체", 1개 = 이름, 2개 이상 = "{이름} 외 N개".
class UnifiedFilterBar extends StatelessWidget {
  final Set<FilterType> enabledFilters;
  final UnifiedFilterState state;
  final ValueChanged<UnifiedFilterState> onFilterChanged;

  /// Optional: category type for category filter ('EXPENSE', 'INCOME')
  final String categoryType;

  /// 필터 행 우측에 추가로 노출할 위젯 (옵션). Phase 25 Step 7 — 거래 탭에서
  /// 리스트/달력 toggle 을 같은 행에 배치하기 위해 도입. 다른 페이지에서는
  /// 미전달 시 영향 없음.
  final Widget? trailing;

  const UnifiedFilterBar({
    super.key,
    required this.enabledFilters,
    required this.state,
    required this.onFilterChanged,
    this.categoryType = 'EXPENSE',
    this.trailing,
  });

  int get _activeFilterCount {
    int count = 0;
    if (enabledFilters.contains(FilterType.transactionType) &&
        state.transactionTypes.isNotEmpty) count++;
    if (enabledFilters.contains(FilterType.visibility) &&
        state.visibility != null &&
        state.visibility != 'ALL') count++;
    if (enabledFilters.contains(FilterType.category) &&
        (state.categoryIds.isNotEmpty || state.categoryGroupIds.isNotEmpty)) {
      count++;
    }
    if (enabledFilters.contains(FilterType.paymentMethod) &&
        state.paymentMethodIds.isNotEmpty) count++;
    if (enabledFilters.contains(FilterType.pocket) &&
        state.pocketIds.isNotEmpty) count++;
    if (enabledFilters.contains(FilterType.amountRange) &&
        (state.amountMin != null || state.amountMax != null)) count++;
    if (enabledFilters.contains(FilterType.dateRange) && state.hasDateRange)
      count++;
    if (enabledFilters.contains(FilterType.needsReview) &&
        state.needsReviewOnly) count++;
    return count;
  }

  List<_ChipData> get _allChips {
    final chips = <_ChipData>[];
    if (enabledFilters.contains(FilterType.transactionType) &&
        state.transactionTypes.isNotEmpty) {
      final labels = state.transactionTypes
          .map((t) => kTransactionTypeLabels[t] ?? t)
          .join('/');
      chips.add(_ChipData(
        label: labels,
        onRemove: () =>
            onFilterChanged(state.copyWith(clearTransactionType: true)),
      ));
    }
    if (enabledFilters.contains(FilterType.visibility) &&
        state.visibility != null &&
        state.visibility != 'ALL') {
      chips.add(_ChipData(
        label: state.visibility == 'SHARED' ? '공유' : '개인',
        onRemove: () => onFilterChanged(state.copyWith(clearVisibility: true)),
      ));
    }
    if (enabledFilters.contains(FilterType.category) &&
        (state.categoryIds.isNotEmpty || state.categoryGroupIds.isNotEmpty)) {
      // state.categoryName 이 명시되어 있으면 단수 fallback 으로 사용 (기존 호출처 호환).
      final label = buildCategoryDisplayLabel(
        state.categoryIds,
        state.categoryGroupIds,
        fallbackName: state.categoryName,
      );
      chips.add(_ChipData(
        label: '카테고리: $label',
        onRemove: () => onFilterChanged(state.copyWith(clearCategory: true)),
      ));
    }
    if (enabledFilters.contains(FilterType.paymentMethod) &&
        state.paymentMethodIds.isNotEmpty) {
      final label = buildPaymentMethodDisplayLabel(
        state.paymentMethodIds,
        fallbackName: state.paymentMethodName,
      );
      chips.add(_ChipData(
        label: '결제수단: $label',
        onRemove: () =>
            onFilterChanged(state.copyWith(clearPaymentMethod: true)),
      ));
    }
    if (enabledFilters.contains(FilterType.pocket) &&
        state.pocketIds.isNotEmpty) {
      final label = buildPocketDisplayLabel(state.pocketIds);
      chips.add(_ChipData(
        label: '포켓: $label',
        onRemove: () => onFilterChanged(state.copyWith(clearPocket: true)),
      ));
    }
    if (enabledFilters.contains(FilterType.amountRange) &&
        (state.amountMin != null || state.amountMax != null)) {
      chips.add(_ChipData(
        label: '금액: ${state.amountMin ?? 0}~${state.amountMax ?? "\u221E"}원',
        onRemove: () => onFilterChanged(state.copyWith(clearAmount: true)),
      ));
    }
    if (enabledFilters.contains(FilterType.dateRange) && state.hasDateRange) {
      chips.add(_ChipData(
        label: state.dateRangeLabel ?? '기간 설정됨',
        onRemove: () => onFilterChanged(state.copyWith(clearDateRange: true)),
      ));
    }
    if (enabledFilters.contains(FilterType.needsReview) &&
        state.needsReviewOnly) {
      chips.add(_ChipData(
        label: '확인 필요만',
        onRemove: () => onFilterChanged(state.copyWith(clearNeedsReview: true)),
      ));
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAdvancedFilters) {
      // trailing 만 있는 경우(필터 disabled) 도 trailing 은 노출.
      if (trailing == null) return const SizedBox.shrink();
      return Padding(
        padding:
            context.bbSpace.symmetric(h: BbSpaceToken.lg, v: BbSpaceToken.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [trailing!],
        ),
      );
    }

    final chips = _allChips;
    const maxVisible = 3;
    final visibleChips = chips.take(maxVisible).toList();
    final overflowCount =
        chips.length > maxVisible ? chips.length - maxVisible : 0;

    // chip 영역을 Expanded(SingleChildScrollView) 로 감싸 trailing 위치 고정.
    // (chip 길이에 따라 trailing toggle 이 좌우로 이동하던 버그 fix)
    return Padding(
      padding:
          context.bbSpace.symmetric(h: BbSpaceToken.lg, v: BbSpaceToken.xs),
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
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...visibleChips.map((chip) => Padding(
                        padding: context.bbSpace.only(left: BbSpaceToken.xs),
                        child: _ActiveFilterChip(
                          label: chip.label,
                          onRemove: chip.onRemove,
                        ),
                      )),
                  if (overflowCount > 0)
                    Padding(
                      padding: context.bbSpace.only(left: BbSpaceToken.xs),
                      child: Chip(
                        label: Text('+$overflowCount',
                            style: TextStyle(fontSize: context.bbType.label)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[
            context.bbSpace.gapH(BbSpaceToken.xs),
            trailing!,
          ],
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
      enabledFilters.contains(FilterType.visibility) ||
      enabledFilters.contains(FilterType.needsReview);

  void _showAdvancedFilterSheet(BuildContext context) {
    final amountMinController = TextEditingController(
      text: state.amountMin?.toString() ?? '',
    );
    final amountMaxController = TextEditingController(
      text: state.amountMax?.toString() ?? '',
    );
    // PR-C3: 단수 temp 변수 → Set 기반. CategoryFilter/PaymentMethodFilter/PocketFilter
    // 는 multi 모드 트리거이므로 이 로컬 Set 을 직접 받아 `적용` 버튼에서 일괄 propagate.
    Set<String> tempCategoryIds = {...state.categoryIds};
    Set<String> tempCategoryGroupIds = {...state.categoryGroupIds};
    Set<String> tempPaymentMethodIds = {...state.paymentMethodIds};
    Set<String> tempPocketIds = {...state.pocketIds};
    // PR-C: Multi-select transaction types (EXPENSE/INCOME/TRANSFER).
    final Set<String> tempTransactionTypes = Set.of(state.transactionTypes);
    String? tempVisibility = state.visibility;
    bool tempNeedsReviewOnly = state.needsReviewOnly;
    // 기간도 다른 필터와 동일하게 임시 상태로 보관 → "적용" 버튼 클릭 시 일괄 propagate.
    DateTime? tempDateFrom = state.dateFrom;
    DateTime? tempDateTo = state.dateTo;
    String? tempDateRangeLabel = state.dateRangeLabel;
    bool tempDateCleared = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bool tempHasDateRange =
                !tempDateCleared && tempDateFrom != null && tempDateTo != null;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: context.bbSpace.only(left: BbSpaceToken.xxl, top: BbSpaceToken.xxl, right: BbSpaceToken.xxl, bottom: BbSpaceToken.xxl),
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
                              borderRadius:
                                  context.bbSpace.radius(BbSpaceToken.xs),
                            ),
                          ),
                        ),
                        context.bbSpace.gapV(BbSpaceToken.xl),
                        Text(
                          '필터',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        context.bbSpace.gapV(BbSpaceToken.xxl),
                        // Transaction type selector (multi-select)
                        if (enabledFilters
                            .contains(FilterType.transactionType)) ...[
                          Text('거래 유형 (중복 선택 가능)',
                              style: Theme.of(context).textTheme.titleSmall),
                          context.bbSpace.gapV(BbSpaceToken.md),
                          SelectableChipGroup<String>.multi(
                            items: const [
                              ChipItem(value: 'EXPENSE', label: '지출'),
                              ChipItem(value: 'INCOME', label: '수입'),
                              ChipItem(value: 'TRANSFER', label: '이체'),
                            ],
                            selected: tempTransactionTypes,
                            onChanged: (next) {
                              setSheetState(() {
                                tempTransactionTypes
                                  ..clear()
                                  ..addAll(next);
                              });
                            },
                            direction: ChipGroupDirection.wrap,
                          ),
                          context.bbSpace.gapV(BbSpaceToken.xl),
                        ],
                        // Visibility selector (single-select with "전체" chip)
                        if (enabledFilters.contains(FilterType.visibility)) ...[
                          Text('공개 범위',
                              style: Theme.of(context).textTheme.titleSmall),
                          context.bbSpace.gapV(BbSpaceToken.md),
                          SelectableChipGroup<String>.single(
                            items: const [
                              ChipItem(value: 'SHARED', label: '공유'),
                              ChipItem(value: 'PRIVATE', label: '개인'),
                            ],
                            selected: (tempVisibility == null ||
                                    tempVisibility == 'ALL')
                                ? null
                                : tempVisibility,
                            onChanged: (v) {
                              setSheetState(() => tempVisibility = v);
                            },
                            direction: ChipGroupDirection.wrap,
                          ),
                          context.bbSpace.gapV(BbSpaceToken.xl),
                        ],
                        // Date range
                        if (enabledFilters.contains(FilterType.dateRange)) ...[
                          Text('기간',
                              style: Theme.of(context).textTheme.titleSmall),
                          context.bbSpace.gapV(BbSpaceToken.md),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tempHasDateRange
                                      ? (tempDateRangeLabel ?? '기간 설정됨')
                                      : '전체 기간',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              TextButton.icon(
                                icon: Icon(Icons.date_range,
                                    size: context.bbType.iconSm),
                                label: const Text('기간 변경'),
                                onPressed: () {
                                  // 기간 프리셋 시트를 외부 필터 시트 위에 쌓기만 하고,
                                  // 프리셋 선택 시 tempXxx 로컬 상태만 갱신한다.
                                  // 외부 필터 시트는 pop 하지 않고, onFilterChanged 는
                                  // 하단 "적용" 버튼에서 일괄 호출된다.
                                  showDateRangeFilterSheet(
                                    context: ctx,
                                    currentFrom: tempDateFrom,
                                    currentTo: tempDateTo,
                                    onApply: (label, from, to) {
                                      setSheetState(() {
                                        tempDateFrom = from;
                                        tempDateTo = to;
                                        tempDateRangeLabel = label;
                                        tempDateCleared = false;
                                      });
                                    },
                                    onClear: () {
                                      setSheetState(() {
                                        tempDateCleared = true;
                                      });
                                    },
                                  );
                                },
                              ),
                              if (tempHasDateRange)
                                IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    size: context.bbType.iconSm,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  onPressed: () {
                                    setSheetState(() {
                                      tempDateCleared = true;
                                    });
                                  },
                                  tooltip: '기간 초기화',
                                ),
                            ],
                          ),
                          context.bbSpace.gapV(BbSpaceToken.xl),
                        ],
                        // Amount range
                        if (enabledFilters
                            .contains(FilterType.amountRange)) ...[
                          AmountRangeFilter(
                            minController: amountMinController,
                            maxController: amountMaxController,
                          ),
                          context.bbSpace.gapV(BbSpaceToken.xl),
                        ],
                        // Category selector (multi + group)
                        if (enabledFilters.contains(FilterType.category)) ...[
                          CategoryFilter(
                            selectedCategoryIds: tempCategoryIds,
                            selectedGroupIds: tempCategoryGroupIds,
                            displayLabel: buildCategoryDisplayLabel(
                              tempCategoryIds,
                              tempCategoryGroupIds,
                            ),
                            categoryType: categoryType,
                            onChanged: (cats, groups) {
                              setSheetState(() {
                                tempCategoryIds = cats;
                                tempCategoryGroupIds = groups;
                              });
                            },
                          ),
                          context.bbSpace.gapV(BbSpaceToken.xl),
                        ],
                        // Payment method multi-selector
                        if (enabledFilters
                            .contains(FilterType.paymentMethod)) ...[
                          PaymentMethodFilter(
                            selectedIds: tempPaymentMethodIds,
                            displayLabel: buildPaymentMethodDisplayLabel(
                                tempPaymentMethodIds),
                            onChanged: (ids) =>
                                setSheetState(() => tempPaymentMethodIds = ids),
                          ),
                          context.bbSpace.gapV(BbSpaceToken.xl),
                        ],
                        // Pocket multi-selector
                        if (enabledFilters.contains(FilterType.pocket)) ...[
                          PocketFilter(
                            selectedIds: tempPocketIds,
                            displayLabel:
                                buildPocketDisplayLabel(tempPocketIds),
                            onChanged: (ids) =>
                                setSheetState(() => tempPocketIds = ids),
                          ),
                          context.bbSpace.gapV(BbSpaceToken.xl),
                        ],
                        // V61 (2026-05-06) — 확인/입력 필요만 보기 토글
                        if (enabledFilters
                            .contains(FilterType.needsReview)) ...[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('확인/입력 필요만 보기'),
                            subtitle: Text(
                              '느낌표 표시한 거래만 표시합니다',
                              style: TextStyle(fontSize: context.bbType.label),
                            ),
                            value: tempNeedsReviewOnly,
                            onChanged: (v) =>
                                setSheetState(() => tempNeedsReviewOnly = v),
                          ),
                          context.bbSpace.gapV(BbSpaceToken.md),
                        ],
                        context.bbSpace.gapV(BbSpaceToken.md),
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
                                    clearNeedsReview: true,
                                  ));
                                },
                                child: const Text('초기화'),
                              ),
                            ),
                            context.bbSpace.gapH(BbSpaceToken.lg),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  final minText =
                                      amountMinController.text.trim();
                                  final maxText =
                                      amountMaxController.text.trim();
                                  Navigator.of(ctx).pop();
                                  onFilterChanged(UnifiedFilterState(
                                    dateFrom:
                                        tempDateCleared ? null : tempDateFrom,
                                    dateTo: tempDateCleared ? null : tempDateTo,
                                    dateRangeLabel: tempDateCleared
                                        ? null
                                        : tempDateRangeLabel,
                                    categoryIds: tempCategoryIds,
                                    categoryGroupIds: tempCategoryGroupIds,
                                    // categoryName/paymentMethodName 은 displayLabel 유틸로
                                    // 대체 — 저장값으로 유지할 이유가 없으므로 null.
                                    categoryName: null,
                                    paymentMethodIds: tempPaymentMethodIds,
                                    paymentMethodName: null,
                                    pocketIds: tempPocketIds,
                                    amountMin: minText.isEmpty
                                        ? null
                                        : int.tryParse(minText),
                                    amountMax: maxText.isEmpty
                                        ? null
                                        : int.tryParse(maxText),
                                    keyword: state.keyword,
                                    transactionTypes: tempTransactionTypes,
                                    visibility: tempVisibility,
                                    status: state.status,
                                    needsReviewOnly: tempNeedsReviewOnly,
                                  ));
                                },
                                child: const Text('적용'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 카테고리 필터 display label 생성기.
///
/// 0개 → "전체", 1개 → 이름, 2개 이상 → "{이름} 외 N개".
/// 그룹과 카테고리가 혼재하면 그룹 이름에 " 그룹" 접미사 (예: "식비 그룹 외 2개").
///
/// [fallbackName] — BLoC 상태에서 이름을 찾지 못할 때 사용 (예: state.categoryName).
String buildCategoryDisplayLabel(
  Set<String> categoryIds,
  Set<String> categoryGroupIds, {
  String? fallbackName,
}) {
  // 그룹 선택 시 cascade 로 자식 categoryIds 도 함께 채워지므로, 라벨 계산
  // 시점에는 "그룹에 흡수된" 자식 categoryIds 를 제외하고 visible count 산정.
  // → 그룹 1개(자식 N개 cascade) 선택 시 "X 그룹 전체" 로 표시.
  Set<String> visibleCategoryIds = categoryIds;
  if (categoryGroupIds.isNotEmpty) {
    final gState = _safeBlocState<CategoryGroupBloc>();
    if (gState is CategoryGroupLoaded) {
      final absorbed = <String>{};
      for (final gid in categoryGroupIds) {
        final group = gState.groups.where((g) => g.id == gid).firstOrNull;
        if (group != null) {
          for (final cat in group.categories) {
            if (categoryIds.contains(cat.id)) absorbed.add(cat.id);
          }
        }
      }
      visibleCategoryIds = categoryIds.difference(absorbed);
    }
  }

  final total = visibleCategoryIds.length + categoryGroupIds.length;
  if (total == 0) return '전체';
  String? firstName;
  bool fromGroup = false;
  if (categoryGroupIds.isNotEmpty) {
    final gState = _safeBlocState<CategoryGroupBloc>();
    if (gState is CategoryGroupLoaded) {
      final g = gState.groups
          .where((g) => g.id == categoryGroupIds.first)
          .firstOrNull;
      firstName = g?.name;
      fromGroup = g != null;
    }
  } else {
    final cState = _safeBlocState<CategoryBloc>();
    if (cState is CategoryLoaded) {
      final all = [...cState.expenseCategories, ...cState.incomeCategories];
      final c = all.where((c) => c.id == visibleCategoryIds.first).firstOrNull;
      firstName = c?.name;
    }
  }
  firstName ??= fallbackName;
  if (total == 1) {
    if (firstName == null) return '선택됨';
    return fromGroup ? '$firstName 그룹 전체' : firstName;
  }
  final base =
      firstName != null ? (fromGroup ? '$firstName 그룹' : firstName) : '선택됨';
  return '$base 외 ${total - 1}개';
}

/// 결제수단 필터 display label 생성기.
String buildPaymentMethodDisplayLabel(
  Set<String> ids, {
  String? fallbackName,
}) {
  if (ids.isEmpty) return '전체';
  String? firstName;
  final pmState = _safeBlocState<PaymentMethodBloc>();
  if (pmState is PaymentMethodLoaded) {
    final first = pmState.activePaymentMethods
        .where((pm) => pm.id == ids.first)
        .firstOrNull;
    firstName = first?.name;
  }
  firstName ??= fallbackName;
  if (firstName == null) return ids.length == 1 ? '선택됨' : '${ids.length}개';
  return ids.length == 1 ? firstName : '$firstName 외 ${ids.length - 1}개';
}

/// 포켓 필터 display label 생성기.
String buildPocketDisplayLabel(Set<String> ids) {
  if (ids.isEmpty) return '전체';
  final pState = _safeBlocState<PocketBloc>();
  if (pState is PocketLoaded) {
    final first =
        pState.activePockets.where((p) => p.id == ids.first).firstOrNull;
    if (first != null) {
      return ids.length == 1
          ? first.name
          : '${first.name} 외 ${ids.length - 1}개';
    }
  }
  return ids.length == 1 ? '선택됨' : '${ids.length}개';
}

/// getIt 에서 BLoC 상태를 안전하게 조회 (미등록/에러 시 null).
/// 테스트 환경에서 BLoC 이 등록되지 않은 경우가 있어 try/catch 감싸기.
Object? _safeBlocState<T extends Object>() {
  try {
    final bloc = getIt<T>();
    return (bloc as dynamic).state;
  } catch (_) {
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
      label: Text(label,
          style: TextStyle(fontSize: context.bbType.label),
          overflow: TextOverflow.ellipsis),
      onDeleted: onRemove,
      deleteIcon: Icon(Icons.close, size: context.bbType.iconSm),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: context.bbSpace.symmetric(h: BbSpaceToken.xs),
    );
  }
}
