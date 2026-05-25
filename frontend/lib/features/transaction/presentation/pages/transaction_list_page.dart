import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/utils/web_download_stub.dart'
    if (dart.library.html) 'package:budget_book/core/utils/web_download_web.dart'
    as web_download;
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/ledger_item.dart';
import 'package:budget_book/features/statistics/domain/entities/ledger_summary.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/transaction/presentation/widgets/month_summary_bar.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transaction_list_tile.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transfer_list_tile.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_bloc.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_event.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_state.dart';
import 'package:budget_book/core/widgets/balance_adjustment_sheet.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';
import 'package:budget_book/core/widgets/skeleton_loader.dart';
import 'package:budget_book/core/models/unified_filter_state.dart';
import 'package:budget_book/core/widgets/filters/unified_filter_bar.dart';
import 'package:budget_book/core/widgets/filters/payment_method_filter.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transaction_calendar_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';

class TransactionListPage extends StatefulWidget {
  final String? initialPaymentMethodId;
  final String? initialPaymentMethodName;
  final String? initialCategoryId;
  final String? initialCategoryName;
  /// Phase 25 후속 — 예산/분석에서 그룹 단위로 거래 필터.
  final String? initialCategoryGroupId;

  const TransactionListPage({
    super.key,
    this.initialPaymentMethodId,
    this.initialPaymentMethodName,
    this.initialCategoryId,
    this.initialCategoryName,
    this.initialCategoryGroupId,
  });

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

/// Phase 25 Step 7 — 거래 탭 view mode (리스트 / 달력).
enum _TxViewMode { list, calendar }

const String _kTxViewModePrefKey = 'tx_view_mode';

class _TransactionListPageState extends State<TransactionListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _dateKeys = {};
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isSearching = false;
  String? _pendingScrollToDate;
  _TxViewMode _viewMode = _TxViewMode.list;

  // Unified filter state
  late UnifiedFilterState _filterState = UnifiedFilterState(
    categoryIds: widget.initialCategoryId != null ? {widget.initialCategoryId!} : const {},
    categoryGroupIds: widget.initialCategoryGroupId != null
        ? {widget.initialCategoryGroupId!}
        : const {},
    categoryName: widget.initialCategoryName,
    paymentMethodIds: widget.initialPaymentMethodId != null ? {widget.initialPaymentMethodId!} : const {},
    paymentMethodName: widget.initialPaymentMethodName,
  );

  String get _appBarTitle {
    if (!_filterState.hasActiveFilters) return '거래 (전체)';
    if (_filterState.categoryName != null) return '거래 (${_filterState.categoryName})';
    if (_filterState.paymentMethodName != null) return '거래 (${_filterState.paymentMethodName})';
    return '거래 (필터)';
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialPaymentMethodId != null && _filterState.paymentMethodName == null) {
      final name = PaymentMethodFilter.resolveName(widget.initialPaymentMethodId!);
      if (name != null) {
        setState(() {
          _filterState = _filterState.copyWith(paymentMethodName: name);
        });
      }
    }
    _loadViewMode();
  }

  @override
  void didUpdateWidget(covariant TransactionListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 회차 12 follow-up A (2026-05-04) — _filterState desync 회귀 fix.
    // GoRouter 가 같은 path 재진입 시 State 재사용 → `late _filterState` initializer
    // 가 한 번만 fire → widget.initialPaymentMethodId 새 값이라도 _filterState 는
    // 빈 값 그대로 → UI "전체" 표시 / 필터 chip 제거 안 됨 / list 는 BE 필터 적용
    // (sync 깨짐).
    //
    // 자산 → 결제수단 클릭 (`/transactions?paymentMethodId=X`) 시 widget 새 prop
    // 으로 _filterState 동기화. payment_method/category/categoryGroup 모두 처리.
    final pmChanged = widget.initialPaymentMethodId != oldWidget.initialPaymentMethodId;
    final catChanged = widget.initialCategoryId != oldWidget.initialCategoryId;
    final groupChanged = widget.initialCategoryGroupId != oldWidget.initialCategoryGroupId;
    if (pmChanged || catChanged || groupChanged) {
      setState(() {
        _filterState = _filterState.copyWith(
          paymentMethodIds: widget.initialPaymentMethodId != null
              ? {widget.initialPaymentMethodId!}
              : const {},
          paymentMethodName: widget.initialPaymentMethodName,
          categoryIds: widget.initialCategoryId != null
              ? {widget.initialCategoryId!}
              : const {},
          categoryName: widget.initialCategoryName,
          categoryGroupIds: widget.initialCategoryGroupId != null
              ? {widget.initialCategoryGroupId!}
              : const {},
          // copyWith 의 clearCategory/clearPaymentMethod 는 nullable name 까지
          // 클리어. 위 explicit 값 set 으로 동일 효과 (initialXxxId == null 시 빈 set).
        );
      });
      // 회차 1 (2026-05-07) — _filterState 갱신과 동시에 BLoC reload 동기화.
      // 회차 12 follow-up A 는 _filterState 만 reset 하고 BLoC.currentFilter 는
      // 이전 값 유지 → 사용자 시나리오: 자산→카카오페이 클릭 후 거래탭 클릭 시
      // /transactions (paymentMethodId 없는 path) 진입 → didUpdateWidget 가
      // _filterState 빈 set 으로 reset (UI 는 "전체") 하지만 BLoC._currentPaymentMethodIds
      // 는 카카오페이 그대로 → BE 호출 시 카카오페이로 필터 → 5건만 노출 (desync).
      // _reloadWithFilters() 가 _filterState 의 새 값으로 LoadTransactions 발행 →
      // BLoC._currentXxx 도 동시 갱신 → UI/결과 정합.
      _reloadWithFilters();
    }
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kTxViewModePrefKey);
    if (!mounted) return;
    if (saved == 'calendar') {
      setState(() => _viewMode = _TxViewMode.calendar);
    }
  }

  Future<void> _saveViewMode(_TxViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTxViewModePrefKey,
        mode == _TxViewMode.calendar ? 'calendar' : 'list');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _isSearching = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _reloadWithFilters();
      // Restore focus after reload completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isSearching && mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    });
  }

  void _reloadWithFilters() {
    final state = context.read<TransactionBloc>().state;
    final year = state is TransactionLoaded ? state.year : DateTime.now().year;
    final month =
        state is TransactionLoaded ? state.month : DateTime.now().month;

    final keyword =
        _searchController.text.trim().isEmpty ? null : _searchController.text.trim();

    final fmt = DateFormat('yyyy-MM-dd');
    context.read<TransactionBloc>().add(LoadTransactions(
          year: year,
          month: month,
          keyword: keyword,
          categoryIds: _filterState.categoryIds,
          categoryGroupIds: _filterState.categoryGroupIds,
          paymentMethodIds: _filterState.paymentMethodIds,
          pocketIds: _filterState.pocketIds,
          amountMin: _filterState.amountMin,
          amountMax: _filterState.amountMax,
          dateFrom: _filterState.dateFrom != null ? fmt.format(_filterState.dateFrom!) : null,
          dateTo: _filterState.dateTo != null ? fmt.format(_filterState.dateTo!) : null,
          transactionTypes: _filterState.transactionTypes,
          visibility: _filterState.visibility,
          needsReviewOnly:
              _filterState.needsReviewOnly ? true : null,
        ));
    context.read<TransferBloc>().add(LoadTransfers(year: year, month: month));
  }

  /// 회차 1 (2026-05-26) — 거래 추가 진입 URL 단일 조립.
  ///
  /// 모든 "거래 추가" 진입 경로 (FAB, _DateHeader, empty state, etc.) 는 이
  /// 헬퍼를 통해서만 URL 을 만든다. 필터된 결제수단(`paymentMethodIds` 단일)
  /// 이 자동 전파되도록 강제. 새 진입 경로 추가 시 헬퍼 미경유 → 코드 리뷰
  /// 차단.
  String _buildCreateTransactionUrl({String? date, String? tab}) {
    final pmId = _filterState.paymentMethodIds.length == 1
        ? _filterState.paymentMethodIds.first
        : null;
    final params = <String>[
      if (tab != null) 'tab=$tab',
      if (date != null) 'date=$date',
      if (pmId != null) 'paymentMethodId=$pmId',
    ];
    return params.isEmpty
        ? '/transactions/create'
        : '/transactions/create?${params.join('&')}';
  }

  Future<void> _exportCsv(BuildContext context) async {
    final state = context.read<TransactionBloc>().state;
    final year = state is TransactionLoaded ? state.year : DateTime.now().year;
    final month =
        state is TransactionLoaded ? state.month : DateTime.now().month;

    try {
      final response = await getIt<ApiClient>().dio.get(
        ApiEndpoints.transactionsExportCsv,
        queryParameters: {'year': year, 'month': month},
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data as List<int>;
      final filename = 'transactions_${year}_$month.csv';

      if (kIsWeb) {
        web_download.triggerBrowserDownload(bytes, filename, 'text/csv');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV 내보내기 완료')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내보내기 실패: $e')),
        );
      }
    }
  }

  void _onFilterChanged(UnifiedFilterState newState) {
    // Resolve payment method name if ID changed
    if (newState.paymentMethodIds.isNotEmpty &&
        newState.paymentMethodName == null) {
      final name = PaymentMethodFilter.resolveName(
          newState.paymentMethodIds.first);
      if (name != null) {
        newState = newState.copyWith(paymentMethodName: name);
      }
    }

    // 회차 1 (2026-05-18) — URL ↔ state desync 회귀 fix.
    // 사용자 시나리오: 자산 → 국민 선택 → /transactions?paymentMethodId=X 진입
    // → 거래탭 필터 chip 으로 X 제거 → 자산 재선택(같은 자산) → 필터 미적용 회귀.
    //
    // 근본 원인: GoRouter StatefulShellRoute branch 는 **동일 URL 재진입 시
    // builder 를 재실행하지 않음**. X chip 제거 시점에 _filterState/BLoC 는
    // 클리어되지만 URL 은 그대로 → 자산 재선택 시 context.go(같은 URL) → no-op →
    // BLoC reload 미발생.
    //
    // 해결: nav 필터(paymentMethodId/categoryId/categoryGroupId) 의 단일↔단일,
    // 단일→empty, empty→단일 transition 시 URL 도 함께 정리. 다음 navigation
    // 이 새 URL 로 인식되어 router builder 가 정상 실행. multi-select 케이스는
    // URL 에 표현 불가 → 변경 안 함 (in-memory BLoC/UI 동기화 유지).
    final oldPm = _filterState.paymentMethodIds.length == 1
        ? _filterState.paymentMethodIds.first
        : null;
    final newPm = newState.paymentMethodIds.length == 1
        ? newState.paymentMethodIds.first
        : null;
    final oldCat = _filterState.categoryIds.length == 1
        ? _filterState.categoryIds.first
        : null;
    final newCat = newState.categoryIds.length == 1
        ? newState.categoryIds.first
        : null;
    final oldGroup = _filterState.categoryGroupIds.length == 1
        ? _filterState.categoryGroupIds.first
        : null;
    final newGroup = newState.categoryGroupIds.length == 1
        ? newState.categoryGroupIds.first
        : null;
    final oldWasSingleOrNone = _filterState.paymentMethodIds.length <= 1 &&
        _filterState.categoryIds.length <= 1 &&
        _filterState.categoryGroupIds.length <= 1;
    final newIsSingleOrNone = newState.paymentMethodIds.length <= 1 &&
        newState.categoryIds.length <= 1 &&
        newState.categoryGroupIds.length <= 1;
    final navTransition = oldPm != newPm || oldCat != newCat || oldGroup != newGroup;
    final shouldSyncUrl =
        navTransition && oldWasSingleOrNone && newIsSingleOrNone;

    setState(() => _filterState = newState);
    _reloadWithFilters();

    if (shouldSyncUrl) {
      _syncUrlForNavigationFilter(newState);
    }
  }

  /// nav 필터를 URL 에 반영 (회차 1 — 2026-05-18).
  /// 단일 nav 필터 (paymentMethodId / categoryId / categoryGroupId) 가 있으면 URL
  /// 에 포함, 없으면 strip. year/month 는 URL 에서 제외 (BLoC/MonthCubit 가 보존).
  void _syncUrlForNavigationFilter(UnifiedFilterState s) {
    final params = <String>[];
    if (s.paymentMethodIds.length == 1) {
      params.add('paymentMethodId=${s.paymentMethodIds.first}');
      if (s.paymentMethodName != null) {
        params.add(
            'paymentMethodName=${Uri.encodeComponent(s.paymentMethodName!)}');
      }
    }
    if (s.categoryIds.length == 1) {
      params.add('categoryId=${s.categoryIds.first}');
      if (s.categoryName != null) {
        params.add('categoryName=${Uri.encodeComponent(s.categoryName!)}');
      }
    }
    if (s.categoryGroupIds.length == 1) {
      params.add('categoryGroupId=${s.categoryGroupIds.first}');
    }
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    context.go('/transactions$query');
  }

  /// 회차 1 (2026-05-10) — HARD GUARANTEE: 필터 UI ↔ BE 동기화.
  ///
  /// 사용자 명령: "필터 미적용되어있는데 거래 항목이 일부 보이는 문제는 절대
  /// 있어선 안된다." → BlocListener 가 매 TransactionLoaded emit 시 _filterState
  /// 를 BLoC.currentFilter (실제 BE 에 보낸 필터) 와 강제 동기화. 어떤 dispatch
  /// 경로 (router builder, MainShell case 0, didUpdateWidget, form save reload)
  /// 로 BLoC 가 reload 되어도, **emit 후에는 항상** UI 와 BE 가 동치.
  ///
  /// 이전 구조 (회차 12 follow-up A + PR #230): _filterState 와 BLoC._currentXxx
  /// 가 **양분된 store** → 양쪽이 어긋날 가능성 잔존 → 3회 회귀. 본 sync 는
  /// emit 시점 invariant 로 drift 자체를 self-heal.
  void _syncFilterStateFromBloc() {
    final bloc = context.read<TransactionBloc>();
    // BLoC 의 singular + Set 두 필드를 합쳐서 UI Set 으로 정규화.
    final pmIds = <String>{
      if (bloc.currentPaymentMethodId != null) bloc.currentPaymentMethodId!,
      ...bloc.currentPaymentMethodIds,
    };
    final catIds = <String>{
      if (bloc.currentCategoryId != null) bloc.currentCategoryId!,
      ...bloc.currentCategoryIds,
    };

    // 이름 보존 — BLoC 에는 ID 만 있고 사용자에게 보이는 이름은 UI 가 보유.
    // Set 의 단일 원소가 바뀌면 이름 재해결, 그 외에는 이전 이름 유지.
    String? pmName = _filterState.paymentMethodName;
    if (pmIds.length == 1) {
      final id = pmIds.first;
      if (_filterState.paymentMethodIds.length != 1 ||
          _filterState.paymentMethodIds.first != id) {
        pmName = PaymentMethodFilter.resolveName(id);
      }
    } else {
      pmName = null;
    }
    String? catName = _filterState.categoryName;
    if (catIds.isEmpty) catName = null;

    final synced = UnifiedFilterState(
      dateFrom: _filterState.dateFrom,
      dateTo: _filterState.dateTo,
      dateRangeLabel: _filterState.dateRangeLabel,
      categoryIds: catIds,
      categoryGroupIds: bloc.currentCategoryGroupIds,
      categoryName: catName,
      paymentMethodIds: pmIds,
      paymentMethodName: pmName,
      pocketIds: bloc.currentPocketIds,
      amountMin: _filterState.amountMin,
      amountMax: _filterState.amountMax,
      keyword: _filterState.keyword,
      transactionTypes: _filterState.transactionTypes,
      visibility: _filterState.visibility,
      status: _filterState.status,
      needsReviewOnly: _filterState.needsReviewOnly,
    );

    if (synced != _filterState) {
      setState(() => _filterState = synced);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TransactionBloc, TransactionState>(
      // 매 Loaded emit 시 _filterState 를 BLoC 의 실제 적용 필터와 동기화.
      // listenWhen 으로 Loaded 전후 비교 — Loading/Initial 시점에는 미실행.
      listenWhen: (previous, current) => current is TransactionLoaded,
      listener: (context, state) => _syncFilterStateFromBloc(),
      child: Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final bloc = context.watch<TransactionBloc>();
            final state = bloc.state;
            final count = state is TransactionLoaded ? state.totalElements : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_appBarTitle, style: const TextStyle(fontSize: 18)),
                if (count != null)
                  Text(
                    '$count건',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          _buildBalanceAdjustAction(context),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: '가져오기',
            onPressed: () => context.push('/transactions/import'),
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: '내보내기',
            onPressed: () => _exportCsv(context),
          ),
        ],
      ),
      body: BlocConsumer<TransactionBloc, TransactionState>(
        listener: (context, state) {
          if (state is TransactionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state is TransactionLoaded &&
              state.operationError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state is TransactionLoaded &&
              state.operationSuccess != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationSuccess!),
              ),
            );
          }
        },
        builder: (context, state) {
          return switch (state) {
            TransactionInitial() || TransactionLoading() =>
              const SkeletonLoader(itemCount: 5),
            TransactionLoaded() => _buildLoaded(context, state),
            TransactionError() => _buildError(context),
          };
        },
      ),
      floatingActionButton: _buildFab(context),
    ),
    );
  }

  bool get _isFilteredByCreditCard {
    if (_filterState.paymentMethodIds.isEmpty) return false;
    final pmId = _filterState.paymentMethodIds.first;
    final pmState = getIt<PaymentMethodBloc>().state;
    if (pmState is PaymentMethodLoaded) {
      return pmState.paymentMethods.any((pm) => pm.id == pmId && pm.isCredit);
    }
    return false;
  }

  /// 회차 1 (2026-05-10) — 이슈 Z1: 거래 탭에서 잔액 수정 진입점 추가.
  /// 단일 BANK 결제수단 필터 활성 시에만 노출.
  Widget _buildBalanceAdjustAction(BuildContext context) {
    if (_filterState.paymentMethodIds.length != 1) {
      return const SizedBox.shrink();
    }
    final pmId = _filterState.paymentMethodIds.first;
    final pmState = getIt<PaymentMethodBloc>().state;
    if (pmState is! PaymentMethodLoaded) return const SizedBox.shrink();
    final pm = pmState.paymentMethods
        .where((p) => p.id == pmId)
        .cast<dynamic>()
        .firstOrNull;
    if (pm == null) return const SizedBox.shrink();
    final type = pm.type as String?;
    if (type != 'BANK' && type != 'CASH' && type != 'DEBIT') {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: const Icon(Icons.tune),
      tooltip: '잔액 수정',
      onPressed: () => BalanceAdjustmentSheet.show(
        context,
        paymentMethodId: pm.id as String,
        paymentMethodName: pm.name as String,
        currentBalance: (pm.balance as int?) ?? 0,
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    // 회차 1 (2026-05-26) — `_buildCreateTransactionUrl` 헬퍼 단일화.
    // 헬퍼가 _filterState.paymentMethodIds 를 직접 참조 → pmParam 수동 조립 제거.
    if (_isFilteredByCreditCard) {
      final pmId = _filterState.paymentMethodIds.isNotEmpty
          ? _filterState.paymentMethodIds.first
          : null;
      final state = context.read<TransactionBloc>().state;
      final year = state is TransactionLoaded ? state.year : DateTime.now().year;
      final month = state is TransactionLoaded ? state.month : DateTime.now().month;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'settle',
            onPressed: () => context.push('/card-settlement?cardId=$pmId&year=$year&month=$month'),
            icon: const Icon(Icons.credit_score),
            label: const Text('결제'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: () =>
                context.push(_buildCreateTransactionUrl(tab: 'expense')),
            tooltip: '거래 추가',
            child: const Icon(Icons.add),
          ),
        ],
      );
    }

    return FloatingActionButton(
      onPressed: () =>
          context.push(_buildCreateTransactionUrl(tab: 'expense')),
      tooltip: '거래 추가',
      child: const Icon(Icons.add),
    );
  }

  Widget _buildLoaded(BuildContext context, TransactionLoaded state) {
    return Column(
      children: [
        // Month navigator — MonthCubit.state를 자동 watch (year/month 파라미터 생략)
        MonthNavigator(
          onDatePicked: (picked) {
            // Store the target date for scroll-after-load
            final day = picked.day;
            if (day > 1) {
              final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              setState(() => _pendingScrollToDate = dateStr);
            }
          },
          onMonthChanged: (m) {
            // Clear period filter when navigating months
            setState(() {
              _filterState = _filterState.copyWith(clearDateRange: true);
            });
            // MonthCubit 동기화 (다른 페이지와 양방향 sync)
            context.read<MonthCubit>().changeMonth(m.year, m.month);
            // 필터가 복잡하므로 페이지 자체에서도 dispatch (MonthSyncHandler가
            // 먼저 기본 필터로 reload하지만, 페이지 고유 필터 적용 필요)
            final kw = _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim();
            final fmt = DateFormat('yyyy-MM-dd');
            context.read<TransactionBloc>().add(
                  LoadTransactions(
                    year: m.year,
                    month: m.month,
                    keyword: kw,
                    categoryIds: _filterState.categoryIds,
                    categoryGroupIds: _filterState.categoryGroupIds,
                    paymentMethodIds: _filterState.paymentMethodIds,
                    pocketIds: _filterState.pocketIds,
                    amountMin: _filterState.amountMin,
                    amountMax: _filterState.amountMax,
                    dateFrom: _filterState.dateFrom != null ? fmt.format(_filterState.dateFrom!) : null,
                    dateTo: _filterState.dateTo != null ? fmt.format(_filterState.dateTo!) : null,
                    scrollToDate: _pendingScrollToDate,
                    transactionTypes: _filterState.transactionTypes,
                    visibility: _filterState.visibility,
                  ),
                );
          },
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: '거래 검색...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _isSearching = false;
                        _reloadWithFilters();
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        // Unified filter bar (category, payment, pocket, amount, date range)
        // Phase 25 Step 7 — 우측 trailing 에 [리스트][달력] toggle.
        UnifiedFilterBar(
          enabledFilters: const {
            FilterType.dateRange,
            FilterType.transactionType,
            FilterType.visibility,
            FilterType.category,
            FilterType.paymentMethod,
            FilterType.pocket,
            FilterType.amountRange,
            FilterType.needsReview,
          },
          state: _filterState,
          onFilterChanged: _onFilterChanged,
          trailing: _ViewModeToggle(
            mode: _viewMode,
            onChanged: (m) {
              setState(() => _viewMode = m);
              _saveViewMode(m);
            },
          ),
        ),
        // Summary bar + Transaction list (both need transfers)
        Expanded(
          child: BlocBuilder<TransferBloc, TransferState>(
            builder: (context, transferState) {
              final transfers = transferState is TransferLoaded
                  ? transferState.transfers
                  : <Transfer>[];

              // Filter transfers by payment method if filter is active
              final filterPmId = _filterState.paymentMethodIds.isNotEmpty
                  ? _filterState.paymentMethodIds.first
                  : null;
              final filteredTransfers = filterPmId != null
                  ? transfers.where((t) =>
                      t.sourcePaymentMethod.id == filterPmId ||
                      t.destinationPaymentMethod.id == filterPmId).toList()
                  : transfers;

              // Filter transfers by date if date filter is active
              final fmt = DateFormat('yyyy-MM-dd');
              final filterDateFrom = _filterState.dateFrom != null ? fmt.format(_filterState.dateFrom!) : null;
              final filterDateTo = _filterState.dateTo != null ? fmt.format(_filterState.dateTo!) : null;
              final dateFilteredTransfers = filterDateFrom != null || filterDateTo != null
                  ? filteredTransfers.where((t) {
                      if (filterDateFrom != null && t.transferDate.compareTo(filterDateFrom) < 0) return false;
                      if (filterDateTo != null && t.transferDate.compareTo(filterDateTo) > 0) return false;
                      return true;
                    }).toList()
                  : filteredTransfers;

              // Filter transfers by keyword if search is active
              final keyword = _searchController.text.trim().toLowerCase();
              final searchedTransfers = keyword.isEmpty
                  ? dateFilteredTransfers
                  : dateFilteredTransfers.where((t) {
                      final desc = t.description?.toLowerCase() ?? '';
                      final src = t.sourcePaymentMethod.name.toLowerCase();
                      final dst = t.destinationPaymentMethod.name.toLowerCase();
                      return desc.contains(keyword) ||
                          src.contains(keyword) ||
                          dst.contains(keyword);
                    }).toList();

              // S2: single aggregation entry point via LedgerSummary.from
              // kind/type branching lives inside the factory, including
              // CARD_SETTLEMENT exclusion (supersedes PR-A heuristic).
              final summary = LedgerSummary.from(
                txs: state.filteredTransactions,
                tfs: searchedTransfers,
                pmFilter: filterPmId,
              );

              // 회차 8 — BE getSummary 가 모든 필터 지원하도록 확장됨.
              // FE client-side fold (page 단위 부정확) 제거.
              // 모든 케이스에서 BE 가 계산한 정확한 합계(state.totalIncome/Expense) 사용.
              // server total 미수신 시 (statisticsRepository 미주입) 만 client summary fallback.
              final hasServerTotals = state.serverTotalIncome != null;
              final displayIncome = hasServerTotals
                  ? state.totalIncome
                  : summary.totalIncome;
              final displayExpense = hasServerTotals
                  ? state.totalExpense
                  : summary.totalExpense;
              final displayTransfer = summary.totalTransfer;

              // Gate transfer display by filter: if user picked EXPENSE/INCOME
              // without TRANSFER, hide transfers from the merged list.
              final types = _filterState.transactionTypes;
              final showTransfers =
                  types.isEmpty || types.contains('TRANSFER');
              final listTransfers = showTransfers ? searchedTransfers : const <Transfer>[];

              return Column(
                children: [
                  MonthSummaryBar(
                    totalIncome: displayIncome,
                    totalExpense: displayExpense,
                    balance: displayIncome - displayExpense,
                    totalTransfer: displayTransfer > 0 ? displayTransfer : null,
                  ),
                  if (_viewMode == _TxViewMode.calendar)
                    Expanded(
                      child: TransactionCalendarView(
                        year: state.year,
                        month: state.month,
                        transactions: state.filteredTransactions,
                        transfers: searchedTransfers,
                        onTransactionTap: (tx) =>
                            context.push('/transactions/${tx.id}'),
                        onTransferTap: (tr) =>
                            context.push('/transfers/${tr.id}'),
                      ),
                    )
                  else if (state.filteredTransactions.isEmpty && listTransfers.isEmpty)
                    Expanded(child: _buildEmpty(context))
                  else
                    Expanded(child: _buildGroupedList(context, state, listTransfers)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedList(BuildContext context, TransactionLoaded state, List<Transfer> transfers) {
    // Merge transactions and transfers into LedgerItems, grouped by date
    // Use filteredGroupedByDate when date filter is active
    final groupedItems = <String, List<LedgerItem>>{};

    // Add transactions (filtered by date if applicable)
    final txnGrouped = state.filteredGroupedByDate;
    for (final entry in txnGrouped.entries) {
      groupedItems.putIfAbsent(entry.key, () => []);
      for (final t in entry.value) {
        groupedItems[entry.key]!.add(LedgerItem.fromTransaction(t));
      }
    }

    // Add transfers
    for (final transfer in transfers) {
      groupedItems.putIfAbsent(transfer.transferDate, () => []);
      groupedItems[transfer.transferDate]!.add(LedgerItem.fromTransfer(transfer));
    }

    final sortedDates = groupedItems.keys.toList()..sort((a, b) => b.compareTo(a));

    // Handle scroll-to-date (one-shot: consume and clear immediately)
    final targetDate = _pendingScrollToDate;
    if (targetDate != null) {
      _pendingScrollToDate = null; // always consume to prevent infinite loops
      if (sortedDates.contains(targetDate)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToDate(targetDate, sortedDates);
        });
      }
      // If target date not loaded, user can scroll manually — no auto-load
    } else if (state.scrollToDate != null && sortedDates.contains(state.scrollToDate!)) {
      // One-shot scroll from BLoC (e.g., after create/update)
      final scrollDate = state.scrollToDate!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToDate(scrollDate, sortedDates);
      });
    }

    // Calculate running totals for transactions only (transfers are not income/expense)
    final flatTransactions = <Transaction>[];
    for (final date in sortedDates) {
      for (final item in groupedItems[date]!) {
        if (item.isTransaction) {
          flatTransactions.add(item.transaction!);
        }
      }
    }
    final runningTotals = <String, int>{};
    int cumulative = 0;
    for (int i = flatTransactions.length - 1; i >= 0; i--) {
      final t = flatTransactions[i];
      cumulative += t.isExpense ? -t.amount : t.amount;
      runningTotals[t.id] = cumulative;
    }
    // Offset running totals to account for unloaded older transactions
    if (state.serverTotalIncome != null && state.serverTotalExpense != null) {
      final serverBalance = state.serverTotalIncome! - state.serverTotalExpense!;
      final offset = serverBalance - cumulative;
      if (offset != 0) {
        for (final key in runningTotals.keys.toList()) {
          runningTotals[key] = runningTotals[key]! + offset;
        }
      }
    }

    // Add 1 extra item for the loading indicator when loading more
    final itemCount =
        sortedDates.length + (state.isLoadingMore || state.hasMore ? 1 : 0);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final maxScroll = notification.metrics.maxScrollExtent;
          final currentScroll = notification.metrics.pixels;
          // Trigger load more at 70% scroll for smoother infinite scrolling
          if (currentScroll >= maxScroll * 0.7) {
            final bloc = context.read<TransactionBloc>();
            final currentState = bloc.state;
            if (currentState is TransactionLoaded &&
                currentState.hasMore &&
                !currentState.isLoadingMore) {
              bloc.add(const LoadMoreTransactions());
            }
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        key: const PageStorageKey('transaction_list'),
        itemCount: itemCount + 1, // +1 for FAB padding
        itemBuilder: (context, index) {
          // Last item is FAB bottom padding
          if (index == itemCount) return const SizedBox(height: 88);
          // Loading indicator
          if (index >= sortedDates.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final date = sortedDates[index];
          final items = groupedItems[date]!;
          final dateKey = _dateKeys.putIfAbsent(date, () => GlobalKey());

          // Calculate day income/expense from transactions only
          final dayTransactions = items.where((i) => i.isTransaction).map((i) => i.transaction!);
          final dayTransferCount = items.where((i) => i.isTransfer).length;

          return Column(
            key: dateKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateHeader(
                dateStr: date,
                dayIncome: dayTransactions.where((t) => t.isIncome).fold(0, (s, t) => s + t.amount),
                dayExpense: dayTransactions.where((t) => t.isExpense).fold(0, (s, t) => s + t.amount),
                dayTransferCount: dayTransferCount,
                // 회차 1 (2026-05-26) — 필터된 결제수단 자동 prefill 을 위해
                // URL 조립을 상위에서 위임. 헬퍼 미경유 진입 경로 차단.
                onAddTap: () => context.push(
                    _buildCreateTransactionUrl(date: date)),
              ),
              ...items.map((item) {
                if (item.isTransfer) {
                  return TransferListTile(
                    transfer: item.transfer!,
                    onTap: () => context.push('/transfers/edit/${item.transfer!.id}'),
                  );
                }
                final t = item.transaction!;
                return TransactionListTile(
                  transaction: t,
                  runningTotal: runningTotals[t.id],
                  onTap: () => context.push('/transactions/detail/${t.id}'),
                  onLongPress: () => _showTransactionActions(context, t),
                  onDelete: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('거래 삭제'),
                        content: const Text('정말 삭제하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('취소'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              context
                                  .read<TransactionBloc>()
                                  .add(DeleteTransaction(t.id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('거래가 삭제되었습니다'),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.error,
                            ),
                            child: const Text('삭제'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _showTransactionActions(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                transaction.description,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('수정'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/transactions/edit/${transaction.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('날짜 이동'),
              onTap: () {
                Navigator.pop(ctx);
                _showDateMoveDialog(context, transaction);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('복사'),
              onTap: () {
                Navigator.pop(ctx);
                // 배치 4 D-4 (2026-04-26): copyFromId query param — 새로고침 유실 fix
                context.push('/transactions/create?copyFromId=${transaction.id}');
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text('삭제', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteTransaction(context, transaction);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDateMoveDialog(BuildContext context, Transaction transaction) async {
    final bloc = context.read<TransactionBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final initialDate = DateTime.tryParse(transaction.transactionDate) ?? DateTime.now();
    final pickedDate = await showCalendarPickerDialog(
      context: context,
      initialDate: initialDate,
    );
    if (pickedDate != null && mounted) {
      final newDateStr = DateFormat('yyyy-MM-dd').format(pickedDate);
      if (newDateStr != transaction.transactionDate) {
        bloc.add(
          UpdateTransaction(
            id: transaction.id,
            transactionDate: newDateStr,
          ),
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text('거래가 ${DateFormat('M월 d일').format(pickedDate)}로 이동되었습니다'),
          ),
        );
      }
    }
  }

  void _confirmDeleteTransaction(BuildContext context, Transaction transaction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('거래 삭제'),
        content: const Text('정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<TransactionBloc>().add(DeleteTransaction(transaction.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('거래가 삭제되었습니다')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _scrollToDate(String targetDate, List<String> sortedDates) {
    final key = _dateKeys[targetDate];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildEmpty(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.receipt_long,
      title: '거래 내역이 없습니다',
      subtitle: '이 달에 기록된 거래가 없습니다',
      actionLabel: '거래 추가',
      // 회차 1 (2026-05-26) — 필터된 결제수단 자동 전파를 위해 헬퍼 사용.
      onAction: () => context.push(_buildCreateTransactionUrl()),
    );
  }

  Widget _buildError(BuildContext context) {
    final now = DateTime.now();
    return AppErrorWidget(
      message: '거래를 불러오지 못했습니다',
      onRetry: () {
        context.read<TransactionBloc>().add(
              LoadTransactions(year: now.year, month: now.month),
            );
      },
      showHomeButton: true,
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String dateStr;
  final int dayIncome;
  final int dayExpense;
  final int dayTransferCount;
  /// 회차 1 (2026-05-26) — 거래 추가 진입 콜백.
  /// 상위 페이지가 `_buildCreateTransactionUrl(date: ...)` 로 URL 을 조립해 inject.
  /// _DateHeader 가 _filterState 에 접근하지 않게 하여 필터 propagation 강제.
  final VoidCallback? onAddTap;

  const _DateHeader({
    required this.dateStr,
    this.dayIncome = 0,
    this.dayExpense = 0,
    this.dayTransferCount = 0,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    String formatted;
    try {
      final date = DateTime.parse(dateStr);
      formatted = DateFormat('M월 d일 (E)', 'ko').format(date);
    } catch (_) {
      formatted = dateStr;
    }

    return InkWell(
      onTap: onAddTap ??
          () => context.push('/transactions/create?date=$dateStr'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        child: Row(
          children: [
            Text(
              formatted,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            const Spacer(),
            if (dayIncome > 0)
              Text(
                '+${CurrencyFormatter.format(dayIncome)}',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade600, fontWeight: FontWeight.w500),
              ),
            if (dayIncome > 0 && dayExpense > 0)
              const SizedBox(width: 6),
            if (dayExpense > 0)
              Text(
                '-${CurrencyFormatter.format(dayExpense)}',
                style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.w500),
              ),
            if (dayTransferCount > 0) ...[
              if (dayIncome > 0 || dayExpense > 0)
                const SizedBox(width: 6),
              Icon(Icons.swap_horiz, size: 12, color: Colors.teal.shade600),
              const SizedBox(width: 1),
              Text(
                '$dayTransferCount',
                style: TextStyle(fontSize: 11, color: Colors.teal.shade600, fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(width: 8),
            Icon(
              Icons.add_circle_outline,
              size: 16,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}


/// Phase 25 Step 7 — 리스트/달력 toggle.
class _ViewModeToggle extends StatelessWidget {
  final _TxViewMode mode;
  final ValueChanged<_TxViewMode> onChanged;

  const _ViewModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_TxViewMode>(
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        ),
      ),
      segments: const [
        ButtonSegment(
          value: _TxViewMode.list,
          icon: Icon(Icons.list, size: 16),
          tooltip: '리스트',
        ),
        ButtonSegment(
          value: _TxViewMode.calendar,
          icon: Icon(Icons.calendar_month, size: 16),
          tooltip: '달력',
        ),
      ],
      selected: {mode},
      onSelectionChanged: (s) {
        if (s.isNotEmpty) onChanged(s.first);
      },
      showSelectedIcon: false,
    );
  }
}

