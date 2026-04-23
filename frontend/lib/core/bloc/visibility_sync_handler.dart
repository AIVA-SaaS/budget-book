import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/bloc/visibility_cubit.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';

/// 전역 visibility 변경 중앙 핸들러.
///
/// `VisibilityCubit` 상태 변화에 반응하여 관련 BLoC 에 자동으로 재조회 이벤트를
/// dispatch 한다. 기존 [MonthSyncHandler] 와 동일한 패턴 — 새 visibility 의존
/// BLoC 추가 시 여기에만 등록.
///
/// Phase 23 PR-X8: Transaction / Statistics / Budget 재조회.
/// Budget 은 현재 backend 에서 visibility 쿼리를 받지 않고 응답 item 에 visibility
/// 필드만 붙어 오지만, 월·범위 계열 BLoC 일관성을 위해 같이 reload 해둔다
/// (클라이언트 재렌더 트리거).
class VisibilitySyncHandler extends StatelessWidget {
  final Widget child;

  const VisibilitySyncHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<VisibilityCubit, String?>(
      listenWhen: (prev, curr) => prev != curr,
      listener: (_, visibility) {
        _syncAllVisibilityDependentBlocs(visibility);
      },
      child: child,
    );
  }

  /// Visibility 의존 BLoC 등록부.
  /// 새 visibility 의존 BLoC 추가 시 여기에만 추가하면 모든 페이지에서 자동 동기화.
  void _syncAllVisibilityDependentBlocs(String? visibility) {
    final month = getIt<MonthCubit>().state;
    final year = month.year;
    final m = month.month;

    // Transaction list — currentFilter 스냅샷을 유지하며 visibility 만 교체.
    try {
      final txnBloc = getIt<TransactionBloc>();
      final f = txnBloc.currentFilter;
      txnBloc.add(LoadTransactions(
        year: year,
        month: m,
        keyword: f.keyword,
        categoryId: f.categoryId,
        categoryIds: f.categoryIds,
        categoryGroupIds: f.categoryGroupIds,
        paymentMethodId: f.paymentMethodId,
        paymentMethodIds: f.paymentMethodIds,
        pocketId: f.pocketId,
        pocketIds: f.pocketIds,
        amountMin: f.amountMin,
        amountMax: f.amountMax,
        dateFrom: f.dateFrom,
        dateTo: f.dateTo,
        type: f.type,
        transactionTypes: f.transactionTypes,
        visibility: visibility,
      ));
    } catch (_) {}

    // Statistics — ChangeVisibilityFilter 이벤트가 내부적으로 LoadAllStatistics 호출.
    // null 은 BE 기본 동작(ALL) 과 동일하므로 문자열 'ALL' 로 변환해 BLoC 에 전달.
    try {
      getIt<StatisticsBloc>()
          .add(ChangeVisibilityFilter(visibility ?? 'ALL'));
    } catch (_) {}

    // Budget — 현재 월 재로드(클라이언트측 visibility 재필터 트리거).
    try {
      getIt<BudgetBloc>().add(LoadBudgets(year: year, month: m));
    } catch (_) {}
  }
}
