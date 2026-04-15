import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';

/// 월 변경 중앙 핸들러.
///
/// MonthCubit의 state 변화를 구독하여 월 의존 BLoC들에 자동으로 reload 이벤트를
/// dispatch. 새 월 의존 BLoC 추가 시 여기에만 등록하면 모든 페이지에서 자동 적용.
///
/// 기존 각 페이지에서 수동으로 `LoadCardSettlementSummary` 등을 dispatch하던
/// 패턴을 제거하여 반복 누락을 원천 차단.
///
/// 앱 최상위(MainShell) 바로 안에 배치하여 모든 페이지에 적용.
class MonthSyncHandler extends StatelessWidget {
  final Widget child;

  const MonthSyncHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<MonthCubit, MonthState>(
      listenWhen: (prev, curr) => prev != curr,
      listener: (_, monthState) {
        _syncAllMonthDependentBlocs(monthState.year, monthState.month);
      },
      child: child,
    );
  }

  /// 월 의존 BLoC 등록부.
  /// 새 월 의존 BLoC 추가 시 여기에만 추가하면 전체 페이지에서 자동 동기화.
  void _syncAllMonthDependentBlocs(int year, int month) {
    // Budget
    try {
      getIt<BudgetBloc>().add(LoadBudgets(year: year, month: month));
    } catch (_) {}

    // Dashboard
    try {
      getIt<DashboardBloc>().add(LoadDashboard(year: year, month: month));
    } catch (_) {}

    // Payment method card settlement summary
    try {
      getIt<PaymentMethodBloc>().add(
        LoadCardSettlementSummary(year: year, month: month),
      );
    } catch (_) {}
  }
}
