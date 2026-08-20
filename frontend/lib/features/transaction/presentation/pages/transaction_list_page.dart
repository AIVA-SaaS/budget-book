import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
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
import 'package:budget_book/features/card_settlement/presentation/card_settlement_route.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transaction/presentation/bloc/ledger_transfers_cubit.dart';
import 'package:budget_book/core/widgets/balance_adjustment_sheet.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/ledger_date_header.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';
import 'package:budget_book/core/widgets/skeleton_loader.dart';
import 'package:budget_book/core/models/unified_filter_state.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';
import 'package:budget_book/core/widgets/filters/unified_filter_bar.dart';
import 'package:budget_book/core/widgets/filters/payment_method_filter.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transaction_calendar_view.dart';
import 'package:budget_book/features/reconciliation/presentation/bloc/reconciliation_bloc.dart';
import 'package:budget_book/features/reconciliation/presentation/widgets/reconciliation_view.dart';
import 'package:budget_book/features/transaction/presentation/utils/running_balance.dart';
import 'package:budget_book/core/utils/ledger_route.dart';
import 'package:budget_book/features/transaction/presentation/utils/ledger_gating.dart';
import 'package:budget_book/features/transaction/presentation/utils/ledger_empty_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/payment_method/domain/repositories/payment_method_repository.dart';

class TransactionListPage extends StatefulWidget {
  final String? initialPaymentMethodId;
  final String? initialPaymentMethodName;
  final String? initialCategoryId;
  final String? initialCategoryName;

  /// Phase 25 후속 — 예산/분석에서 그룹 단위로 거래 필터.
  final String? initialCategoryGroupId;

  /// URL `?view=` 로 지정된 뷰 모드(`list`/`calendar`/`reconciliation`).
  ///
  /// 2026-08-10 신설 — 홈 "월말 점검" 위젯이 정산 뷰로 직접 진입하기 위해 필요하다.
  /// 지정되면 저장된 뷰(SharedPreferences)보다 **우선**하지만, 저장값을 덮어쓰지는
  /// 않는다 (1회성 이동 의도이지 기본 뷰 변경이 아니다).
  final String? initialView;

  const TransactionListPage({
    super.key,
    this.initialPaymentMethodId,
    this.initialPaymentMethodName,
    this.initialCategoryId,
    this.initialCategoryName,
    this.initialCategoryGroupId,
    this.initialView,
  });

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

/// Phase 25 Step 7 — 거래 탭 view mode (리스트 / 달력 / 정산).
///
/// V65 (2026-07-27) `reconciliation` 추가. 정산은 별도 모드로 두었다 — 리스트 모드의
/// 러닝 밸런스는 날짜 역순 누적에 의존하므로, 미기록/기록 섹션으로 재정렬하면 잔액 숫자가
/// 틀어진다 (기획서 §2.5).
enum _TxViewMode { list, calendar, reconciliation }

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

  // MODE B (single non-credit asset filter) — memoized end-of-month balance.
  // Keyed by "$pmId|$year|$month" so it is fetched once per rebuild cycle and
  // not re-requested on every build.
  Future<int?>? _monthEndBalanceFuture;
  String? _monthEndBalanceKey;

  // Unified filter state
  late UnifiedFilterState _filterState = UnifiedFilterState(
    categoryIds: widget.initialCategoryId != null
        ? {widget.initialCategoryId!}
        : const {},
    categoryGroupIds: widget.initialCategoryGroupId != null
        ? {widget.initialCategoryGroupId!}
        : const {},
    categoryName: widget.initialCategoryName,
    paymentMethodIds: widget.initialPaymentMethodId != null
        ? {widget.initialPaymentMethodId!}
        : const {},
    paymentMethodName: widget.initialPaymentMethodName,
  );

  String get _appBarTitle {
    if (!_filterState.hasActiveFilters) return '거래 (전체)';
    if (_filterState.categoryName != null) {
      return '거래 (${_filterState.categoryName})';
    }
    if (_filterState.paymentMethodName != null) {
      return '거래 (${_filterState.paymentMethodName})';
    }
    return '거래 (필터)';
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialPaymentMethodId != null &&
        _filterState.paymentMethodName == null) {
      final name =
          PaymentMethodFilter.resolveName(widget.initialPaymentMethodId!);
      if (name != null) {
        setState(() {
          _filterState = _filterState.copyWith(paymentMethodName: name);
        });
      }
    }
    // 뷰 모드 우선순위 (2026-08-10):
    //   URL `?view=` 명시 > SharedPreferences 저장값.
    // URL 이 명시됐으면 _loadViewMode() 를 **호출하지 않는다** — 호출하면 비동기 prefs
    // 복원이 나중에 완료되면서 URL 로 지정한 모드를 덮어쓰는 레이스가 생긴다
    // (홈 위젯 → 정산 뷰 진입이 리스트로 튕기는 형태).
    final urlView = parseLedgerView(widget.initialView);
    if (urlView != null) {
      _viewMode = _viewModeFrom(urlView);
    } else {
      _loadViewMode();
    }
  }

  /// [LedgerView](URL 직렬화용) → 이 페이지의 내부 enum. 이름이 1:1 대응한다.
  _TxViewMode _viewModeFrom(LedgerView v) => switch (v) {
        LedgerView.list => _TxViewMode.list,
        LedgerView.calendar => _TxViewMode.calendar,
        LedgerView.reconciliation => _TxViewMode.reconciliation,
      };

  @override
  void didUpdateWidget(covariant TransactionListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 회차 12 follow-up A (2026-05-04) — _filterState desync 회귀 fix.
    // GoRouter 가 같은 path 재진입 시 State 재사용 → `late _filterState` initializer
    // 가 한 번만 fire → widget.initialPaymentMethodId 새 값이라도 _filterState 는
    // 빈 값 그대로. 자산→카카오페이 진입 (initialPaymentMethodId: null→X) 시 sync.
    //
    // 회차 2 (2026-05-26) — Bug 1 follow-up: value→null transition 제외.
    // 이전 로직은 widget.initialPaymentMethodId 가 X→null 로 변할 때도 reset 했음.
    // 그러나 chip 으로 필터 적용 → 수정 저장 → `context.go('/transactions?year=Y&month=M')`
    // 흐름에서, URL 이 `?paymentMethodId=X` 에서 year/month 만 있는 URL 로 바뀌면
    // initialPaymentMethodId 가 X→null 로 바뀐다. 이때 reset 하면 chip 필터가
    // 사라지는 회귀 (사용자 보고 2026-05-26).
    //
    // 새 규칙: null→value, value→다른 value 만 nav 필터 변경 신호. value→null 은
    // 명시적 reset 신호가 아니라 "URL 에 nav key 가 더 이상 없음" 일 뿐.
    // 후자 케이스는 router builder 의 carry 로직 + _syncFilterStateFromBloc 가
    // BLoC.currentFilter 기준으로 _filterState 를 sync → drift 자체를 self-heal.
    final pmChanged =
        widget.initialPaymentMethodId != oldWidget.initialPaymentMethodId &&
            widget.initialPaymentMethodId != null;
    final catChanged =
        widget.initialCategoryId != oldWidget.initialCategoryId &&
            widget.initialCategoryId != null;
    final groupChanged =
        widget.initialCategoryGroupId != oldWidget.initialCategoryGroupId &&
            widget.initialCategoryGroupId != null;
    if (pmChanged || catChanged || groupChanged) {
      setState(() {
        _filterState = _filterState.copyWith(
          paymentMethodIds: widget.initialPaymentMethodId != null
              ? {widget.initialPaymentMethodId!}
              : _filterState.paymentMethodIds,
          paymentMethodName: widget.initialPaymentMethodId != null
              ? widget.initialPaymentMethodName
              : _filterState.paymentMethodName,
          categoryIds: widget.initialCategoryId != null
              ? {widget.initialCategoryId!}
              : _filterState.categoryIds,
          categoryName: widget.initialCategoryId != null
              ? widget.initialCategoryName
              : _filterState.categoryName,
          categoryGroupIds: widget.initialCategoryGroupId != null
              ? {widget.initialCategoryGroupId!}
              : _filterState.categoryGroupIds,
        );
      });
      _reloadWithFilters();
    }

    // 뷰 모드도 nav 필터와 **같은 규칙**을 따른다 (2026-08-10). 판정 자체는
    // nextLedgerViewOnUpdate 가 단독으로 갖는다 — 규칙(특히 value→null 무시)이
    // 페이지 안에 흩어지지 않도록 순수 함수로 빼고 단위 테스트로 고정했다.
    final newView = nextLedgerViewOnUpdate(
      previous: oldWidget.initialView,
      current: widget.initialView,
    );
    if (newView != null) {
      final mode = _viewModeFrom(newView);
      if (mode != _viewMode) {
        setState(() => _viewMode = mode);
      }
    }
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kTxViewModePrefKey);
    if (!mounted) return;
    final restored = switch (saved) {
      'calendar' => _TxViewMode.calendar,
      'reconciliation' => _TxViewMode.reconciliation,
      _ => _TxViewMode.list,
    };
    if (restored != _viewMode) {
      setState(() => _viewMode = restored);
    }
  }

  Future<void> _saveViewMode(_TxViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    // enum name 을 그대로 저장 — 모드 추가 시 매핑을 손볼 필요가 없다.
    await prefs.setString(_kTxViewModePrefKey, mode.name);
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

    final keyword = _searchController.text.trim().isEmpty
        ? null
        : _searchController.text.trim();

    // UI 필터 → 도메인 VO 변환은 toTransactionFilter 단일 경로 (필드 나열 금지).
    final filter = _filterState.toTransactionFilter(keywordOverride: keyword);
    context.read<TransactionBloc>().add(LoadTransactions.fromFilter(
          year,
          month,
          filter,
        ));
    // 2026-08-12 — 이체도 **같은 필터 VO** 로 서버에서 좁힌다.
    // 공유 TransferBloc 이 아니라 장부 전용 Cubit 을 쓴다(다른 화면 오염 방지).
    // 필터에 dateFrom/dateTo 가 있으면 서버가 월 대신 그 범위를 본다 → 기간 필터가
    // 월을 넘어도 이체 행이 누락되지 않는다.
    getIt<LedgerTransfersCubit>().load(
      year: year,
      month: month,
      filter: filter,
    );
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
      final name =
          PaymentMethodFilter.resolveName(newState.paymentMethodIds.first);
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
    final newCat =
        newState.categoryIds.length == 1 ? newState.categoryIds.first : null;
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
    final navTransition =
        oldPm != newPm || oldCat != newCat || oldGroup != newGroup;
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
              final count =
                  state is TransactionLoaded ? state.totalElements : null;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_appBarTitle,
                      style: TextStyle(fontSize: context.bbType.title)),
                  if (count != null)
                    Text(
                      '$count건',
                      style: TextStyle(
                        fontSize: context.bbType.label,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
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
              TransactionInitial() ||
              TransactionLoading() =>
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

  /// CHANGE 3 — the single asset (BANK/CASH/DEBIT) currently filtered, if any.
  /// Returns null when zero/multiple payment methods are selected OR the single
  /// selection is a CREDIT card (credit balance is null → MODE A applies).
  String? get _singleAssetPmId {
    if (_filterState.paymentMethodIds.length != 1) return null;
    if (_isFilteredByCreditCard) return null;
    return _filterState.paymentMethodIds.first;
  }

  /// CHANGE 4 — memoized end-of-month balance for MODE B. `asOf` = first day of
  /// the month AFTER [year]/[month] (exclusive upper bound), so the result is
  /// the asset's balance at the end of the viewed month.
  Future<int?> _monthEndBalanceFor(String pmId, int year, int month) {
    final nextMonthFirst =
        month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final asOf = DateFormat('yyyy-MM-dd').format(nextMonthFirst);
    final key = '$pmId|$year|$month';
    if (_monthEndBalanceKey != key || _monthEndBalanceFuture == null) {
      _monthEndBalanceKey = key;
      _monthEndBalanceFuture = getIt<PaymentMethodRepository>()
          .getBalanceAsOf(pmId, asOf)
          .then((either) => either.fold((_) => null, (b) => b));
    }
    return _monthEndBalanceFuture!;
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
      final year =
          state is TransactionLoaded ? state.year : DateTime.now().year;
      final month =
          state is TransactionLoaded ? state.month : DateTime.now().month;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'settle',
            onPressed: () => context
                .push('/card-settlement?cardId=$pmId&year=$year&month=$month'),
            icon: const Icon(Icons.credit_score),
            label: const Text('결제'),
          ),
          context.bbSpace.gapH(BbSpaceToken.lg),
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
      onPressed: () => context.push(_buildCreateTransactionUrl(tab: 'expense')),
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
              final dateStr =
                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
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
            context.read<TransactionBloc>().add(
                  LoadTransactions.fromFilter(
                    m.year,
                    m.month,
                    _filterState.toTransactionFilter(keywordOverride: kw),
                    scrollToDate: _pendingScrollToDate,
                  ),
                );
          },
        ),
        // Search bar
        Padding(
          padding:
              context.bbSpace.symmetric(h: BbSpaceToken.lg, v: BbSpaceToken.xs),
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
              contentPadding: context.bbSpace
                  .symmetric(h: BbSpaceToken.lg, v: BbSpaceToken.md),
              border: OutlineInputBorder(
                borderRadius: context.bbSpace.radius(BbSpaceToken.lg),
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
          child: BlocBuilder<LedgerTransfersCubit, LedgerTransfersState>(
            builder: (context, transferState) {
              final transfers = transferState.transfers;

              // 2026-08-12 구조적 수정 — 이체 판정은 **서버**가 한다.
              //
              // 이전에는 FE `gateLedger` 가 이체 축을 전수 판정했고, BE 합계는 "필터가
              // 있으면 이체 제외" 라는 **다른 규칙**을 썼다. 판정이 두 곳이면 한쪽만
              // 고쳐지고 다시 어긋난다(4회 재발). 이제 목록 API·합계 API 가 같은
              // `TransferGating` 을 쓰고, FE 는 받은 결과를 그대로 소비한다.
              //
              // 남은 FE 게이팅은 거래 쪽 타입 표시뿐이다(서버가 이미 좁혔지만,
              // 응답 대기 중 옛 목록이 잠깐 보이는 것을 막는다).
              final gated = gateLedger(
                transactions: state.filteredTransactions,
                transfers: transfers,
                filter: _filterState,
                keyword: _searchController.text,
              );
              final visibleTransactions = gated.transactions;
              final visibleTransfers = gated.transfers;

              // 결제수단 1개 필터 시에만 의미가 있는 자산 모드 판정용(MODE B).
              final filterPmId = _filterState.paymentMethodIds.length == 1
                  ? _filterState.paymentMethodIds.first
                  : null;

              // 2026-08-12 — 합계바는 **서버 단일 소스**다.
              //
              // 이전에는 한 줄 안에서 소스를 섞었다: 수입/지출은 서버값, 이체는 클라
              // 계산(`LedgerSummary`), 그리고 이체는 포커스 월에만 갇혀 있었다.
              // 지금은 세 칸 모두 서버가 같은 필터·같은 범위로 계산한 값이고,
              // 목록 API 도 같은 판정을 쓰므로 합계와 행이 같은 집합을 센다.
              //
              // 클라 집계(`LedgerSummary`)는 **러닝밸런스/자산 모드 전용**으로 남는다
              // (행 순서대로 누적하는 계산은 서버가 대신할 수 없다).
              final clientSummary = LedgerSummary.from(
                txs: visibleTransactions,
                tfs: visibleTransfers,
                pmFilter: filterPmId,
              );

              // 서버 총계 미수신(statisticsRepository 미주입 = 테스트 경로) 시에만
              // 클라 집계로 대체한다.
              final hasServerTotals = state.serverTotalIncome != null;
              final displayIncome = hasServerTotals
                  ? state.totalIncome
                  : clientSummary.totalIncome;
              final displayExpense = hasServerTotals
                  ? state.totalExpense
                  : clientSummary.totalExpense;
              final displayTransfer = hasServerTotals
                  ? (state.serverTotalTransfer ?? 0)
                  : clientSummary.totalTransfer;

              // CHANGE 3/4 — MODE B when exactly one non-credit asset is
              // filtered. singleAssetPmId is null otherwise (→ MODE A).
              final singleAssetPmId = _singleAssetPmId;
              final isModeB = singleAssetPmId != null;

              return Column(
                children: [
                  MonthSummaryBar(
                    totalIncome: displayIncome,
                    totalExpense: displayExpense,
                    balance: displayIncome - displayExpense,
                    totalTransfer: displayTransfer > 0 ? displayTransfer : null,
                  ),
                  if (isModeB)
                    _buildMonthEndBalanceHeader(
                        context, singleAssetPmId, state.year, state.month),
                  if (_viewMode == _TxViewMode.reconciliation)
                    // V65 — 정산 뷰. 리스트/달력의 러닝밸런스·집계 로직은 건드리지 않는다.
                    // 미기록 판정은 서버가 채운 reconciliationId 기준 (§2.5).
                    Expanded(
                      child: BlocProvider.value(
                        value: getIt<ReconciliationBloc>(),
                        // 미기록 목록은 정산 뷰가 서버 필터(reconciled=false)로 직접
                        // 로드한다 — 화면에 로드된 페이지를 재사용하면 미로드 페이지의
                        // 미기록 항목이 빠진다.
                        child: ReconciliationView(
                          year: state.year,
                          month: state.month,
                        ),
                      ),
                    )
                  else if (_viewMode == _TxViewMode.calendar)
                    Expanded(
                      child: TransactionCalendarView(
                        year: state.year,
                        month: state.month,
                        transactions: visibleTransactions,
                        transfers: visibleTransfers,
                        onTransactionTap: (tx) =>
                            context.push('/transactions/detail/${tx.id}'),
                        onTransferTap: (tr) =>
                            context.push('/transfers/${tr.id}'),
                        // 달력 일자 시트의 거래 추가. 목록 모드의 _DateHeader 와 동일하게
                        // `_buildCreateTransactionUrl` 만 경유한다(필터 결제수단 전파).
                        onAddTap: (day) => context.push(
                          _buildCreateTransactionUrl(
                            date: DateFormat('yyyy-MM-dd').format(day),
                          ),
                        ),
                      ),
                    )
                  else if (visibleTransactions.isEmpty &&
                      visibleTransfers.isEmpty)
                    Expanded(child: _buildEmpty(context))
                  else if (isModeB)
                    Expanded(
                      child: FutureBuilder<int?>(
                        future: _monthEndBalanceFor(
                            singleAssetPmId, state.year, state.month),
                        builder: (context, snap) => _buildGroupedList(
                          context,
                          state,
                          visibleTransactions,
                          visibleTransfers,
                          assetPmId: singleAssetPmId,
                          assetAnchor: snap.data,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: _buildGroupedList(context, state,
                          visibleTransactions, visibleTransfers),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// CHANGE 4 — "○월 말 잔액" header, MODE B only. Hidden while the balance is
  /// loading or null (e.g. credit — but credit never reaches MODE B).
  Widget _buildMonthEndBalanceHeader(
      BuildContext context, String pmId, int year, int month) {
    return FutureBuilder<int?>(
      future: _monthEndBalanceFor(pmId, year, month),
      builder: (context, snap) {
        final bal = snap.data;
        if (bal == null) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding:
              context.bbSpace.symmetric(h: BbSpaceToken.xl, v: BbSpaceToken.sm),
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.3),
          child: Text(
            '$month월 말 잔액: ${CurrencyFormatter.format(bal)}원',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.75),
                ),
          ),
        );
      },
    );
  }

  /// [transactions] / [transfers] are the already-gated (CHANGE 2) lists.
  /// MODE B (asset running balance) is active when [assetPmId] != null;
  /// [assetAnchor] is the asset's end-of-month balance (null while the async
  /// fetch is in flight → show no running number). MODE A otherwise.
  Widget _buildGroupedList(
    BuildContext context,
    TransactionLoaded state,
    List<Transaction> transactions,
    List<Transfer> transfers, {
    String? assetPmId,
    int? assetAnchor,
  }) {
    // Merge transactions and transfers into LedgerItems, grouped by date.
    // (Server already filters transactions by dateFrom/dateTo.)
    final groupedItems = <String, List<LedgerItem>>{};

    // Add transactions
    for (final t in transactions) {
      groupedItems.putIfAbsent(t.transactionDate, () => []);
      groupedItems[t.transactionDate]!.add(LedgerItem.fromTransaction(t));
    }

    // Add transfers
    for (final transfer in transfers) {
      groupedItems.putIfAbsent(transfer.transferDate, () => []);
      groupedItems[transfer.transferDate]!
          .add(LedgerItem.fromTransfer(transfer));
    }

    // NEWEST-FIRST: dates sorted descending. Within a day, transactions are
    // inserted before transfers (matches iteration order below). The running
    // balance / total is accumulated in this exact newest-first order.
    final sortedDates = groupedItems.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // 회차 (2026-06-23) — 포커싱-구동 점진 로드.
    // 포커싱 대상: MonthNavigator 날짜 선택(_pendingScrollToDate, 명시적)이
    // BLoC scrollToDate(등록/수정 후, 수동적)보다 우선.
    //
    // 대상이 로드된 페이지에 없으면 (예: 500건 중 가장 과거 항목 수정) hasMore 인
    // 동안 다음 페이지를 자동 요청 → 등장할 때 포커싱. 마지막 페이지까지 부재면
    // 대상 거래 자체가 없는 것(날짜 이동 등)으로 보고 조용히 종료(무한루프 방지).
    final targetDate = _pendingScrollToDate ?? state.scrollToDate;
    if (targetDate != null) {
      if (sortedDates.contains(targetDate)) {
        // 대상 로드됨 → 포커싱. 명시적 선택(_pending)은 1회성 소비.
        // (ensureVisible 는 이미 보이는 항목에 대해선 no-op 이라 rebuild 반복 안전.)
        _pendingScrollToDate = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToDate(targetDate, sortedDates);
        });
      } else if (state.hasMore && !state.isLoadingMore) {
        // 대상 미로드 → 등장할 때까지 다음 페이지 자동 요청.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<TransactionBloc>().add(const LoadMoreTransactions());
          }
        });
      } else {
        // 마지막 페이지까지 로드했는데도 부재 → 조용히 종료.
        _pendingScrollToDate = null;
      }
    } else if (state.hasMore && !state.isLoadingMore) {
      // 뷰포트 자동 채움(증상 1): 콘텐츠가 화면을 못 채우면 스크롤이 불가능해
      // 하단 스피너만 떠 멈춘다. 스크롤 여지가 없으면(maxScrollExtent <= 0) 자동으로
      // 다음 페이지를 요청해 화면을 채우고, 채워지면 기존 70% 무한스크롤로 이어진다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        if (_scrollController.position.maxScrollExtent <= 0) {
          context.read<TransactionBloc>().add(const LoadMoreTransactions());
        }
      });
    }

    // CHANGE 3 — running totals. Flatten to display order (newest-first).
    final orderedItems = <LedgerItem>[];
    for (final date in sortedDates) {
      orderedItems.addAll(groupedItems[date]!);
    }

    // runningTotals keyed by ledgerRowKey (tx:<id> / tf:<id>).
    Map<String, int> runningTotals;
    if (assetPmId != null) {
      // MODE B — asset balance backward-accumulated from end-of-month anchor.
      // While the anchor is still loading (null), emit nothing so we never
      // show a wrong number.
      runningTotals = assetAnchor == null
          ? const <String, int>{}
          : computeAssetBalance(orderedItems, assetAnchor, assetPmId);
    } else {
      // MODE A — cumulative EXPENSE only (negative), anchored on the month's
      // total expense (pagination-safe). Local fallback when no server total.
      final localExpense = transactions
          .where((t) => t.isExpense)
          .fold(0, (s, t) => s + t.amount);
      final anchorExpense = state.serverTotalExpense ?? localExpense;
      runningTotals = computeExpenseCumulative(orderedItems, anchorExpense);
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
          // 목록 마지막 스페이서
          if (index == itemCount) {
            return const SizedBox(height: 88); // ui-fixed: FAB 가림 방지
          }
          // Loading indicator
          if (index >= sortedDates.length) {
            return Padding(
              padding: context.bbSpace.symmetric(v: BbSpaceToken.xl),
              child: const Center(child: const CircularProgressIndicator()),
            );
          }
          final date = sortedDates[index];
          final items = groupedItems[date]!;
          final dateKey = _dateKeys.putIfAbsent(date, () => GlobalKey());

          // Calculate day income/expense from transactions only
          final dayTransactions =
              items.where((i) => i.isTransaction).map((i) => i.transaction!);
          final dayTransferCount = items.where((i) => i.isTransfer).length;

          return Column(
            key: dateKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateHeader(
                dateStr: date,
                dayIncome: dayTransactions
                    .where((t) => t.isIncome)
                    .fold(0, (s, t) => s + t.amount),
                dayExpense: dayTransactions
                    .where((t) => t.isExpense)
                    .fold(0, (s, t) => s + t.amount),
                dayTransferCount: dayTransferCount,
                // 회차 1 (2026-05-26) — 필터된 결제수단 자동 prefill 을 위해
                // URL 조립을 상위에서 위임. 헬퍼 미경유 진입 경로 차단.
                onAddTap: () =>
                    context.push(_buildCreateTransactionUrl(date: date)),
              ),
              ...items.map((item) {
                if (item.isTransfer) {
                  return TransferListTile(
                    transfer: item.transfer!,
                    runningTotal: runningTotals[ledgerRowKey(item)],
                    onTap: () =>
                        context.push(transferEditRoute(item.transfer!)),
                  );
                }
                final t = item.transaction!;
                return TransactionListTile(
                  transaction: t,
                  runningTotal: runningTotals[ledgerRowKey(item)],
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
              margin: context.bbSpace.symmetric(v: BbSpaceToken.lg),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.3),
                borderRadius: context.bbSpace.radius(BbSpaceToken.xs),
              ),
            ),
            Padding(
              padding: context.bbSpace
                  .symmetric(h: BbSpaceToken.xl, v: BbSpaceToken.xs),
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
                context
                    .push('/transactions/create?copyFromId=${transaction.id}');
              },
            ),
            ListTile(
              leading: Icon(Icons.delete,
                  color: Theme.of(context).colorScheme.error),
              title: Text('삭제',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteTransaction(context, transaction);
              },
            ),
            context.bbSpace.gapV(BbSpaceToken.md),
          ],
        ),
      ),
    );
  }

  void _showDateMoveDialog(
      BuildContext context, Transaction transaction) async {
    final bloc = context.read<TransactionBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final initialDate =
        DateTime.tryParse(transaction.transactionDate) ?? DateTime.now();
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
            content:
                Text('거래가 ${DateFormat('M월 d일').format(pickedDate)}로 이동되었습니다'),
          ),
        );
      }
    }
  }

  void _confirmDeleteTransaction(
      BuildContext context, Transaction transaction) {
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
                  .add(DeleteTransaction(transaction.id));
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

  /// 빈 상태. 2026-08-10 — 선택한 필터에 맞는 동적 문구.
  ///
  /// 문구 생성은 `ledger_empty_message.dart` 순수 함수 한 곳에서 한다(필터 축이
  /// 늘어날 때 화면마다 문구가 갈라지는 것을 막는다). 필터가 걸려 있으면
  /// "거래 추가" 보다 "필터 초기화" 가 사용자가 원하는 다음 행동이다.
  Widget _buildEmpty(BuildContext context) {
    final msg = buildLedgerEmptyMessage(
      _filterState,
      keyword: _searchController.text,
    );
    return EmptyStateWidget(
      icon: msg.hasFilters ? Icons.filter_alt_off : Icons.receipt_long,
      title: msg.title,
      subtitle: msg.subtitle,
      actionLabel: msg.hasFilters ? '필터 초기화' : '거래 추가',
      // 회차 1 (2026-05-26) — 필터된 결제수단 자동 전파를 위해 헬퍼 사용.
      onAction: msg.hasFilters
          ? _clearAllFilters
          : () => context.push(_buildCreateTransactionUrl()),
    );
  }

  /// 필터 + 검색어를 함께 해제하고 재조회한다.
  /// (검색어는 VO 밖에 있으므로 필터만 비우면 결과가 그대로인 것처럼 보인다)
  void _clearAllFilters() {
    _searchController.clear();
    _onFilterChanged(const UnifiedFilterState());
  }

  Widget _buildError(BuildContext context) {
    final now = DateTime.now();
    return AppErrorWidget(
      message: '거래를 불러오지 못했습니다',
      onRetry: () {
        context.read<TransactionBloc>().add(
              LoadTransactions.monthOnly(now.year, now.month),
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
    // 날짜 표기(포맷·배경·여백)는 LedgerDateHeader 단일 소스. 정산 뷰가 같은 표기를 쓴다.
    return LedgerDateHeader(
      dateStr: dateStr,
      onTap:
          onAddTap ?? () => context.push('/transactions/create?date=$dateStr'),
      trailing: [
        if (dayIncome > 0)
          Text(
            '+${CurrencyFormatter.format(dayIncome)}',
            style: TextStyle(
                fontSize: context.bbType.label,
                color: Colors.blue.shade600,
                fontWeight: FontWeight.w500),
          ),
        if (dayIncome > 0 && dayExpense > 0)
          context.bbSpace.gapH(BbSpaceToken.sm),
        if (dayExpense > 0)
          Text(
            '-${CurrencyFormatter.format(dayExpense)}',
            style: TextStyle(
                fontSize: context.bbType.label,
                color: Colors.red.shade600,
                fontWeight: FontWeight.w500),
          ),
        if (dayTransferCount > 0) ...[
          if (dayIncome > 0 || dayExpense > 0)
            context.bbSpace.gapH(BbSpaceToken.sm),
          Icon(Icons.swap_horiz,
              size: context.bbType.iconSm, color: Colors.teal.shade600),
          context.bbSpace.gapH(BbSpaceToken.xs),
          Text(
            '$dayTransferCount',
            style: TextStyle(
                fontSize: context.bbType.label,
                color: Colors.teal.shade600,
                fontWeight: FontWeight.w500),
          ),
        ],
        context.bbSpace.gapH(BbSpaceToken.md),
        Icon(
          Icons.add_circle_outline,
          size: context.bbType.iconSm,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}

/// Phase 25 Step 7 — 리스트/달력 toggle. V65 에서 정산 세그먼트 추가.
class _ViewModeToggle extends StatelessWidget {
  final _TxViewMode mode;
  final ValueChanged<_TxViewMode> onChanged;

  const _ViewModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // 2026-07-30 — **아이콘 전용** (텍스트 라벨 제거).
    //
    // 라벨은 원래 "글리프가 안 뜨는 기기"용 안전망이었는데(2026-07-28), 그 근본 원인이
    // 이번에 구조적으로 제거됐다. 원인은 서버 폰트가 아니라 **URL 신원 ≠ 내용 신원**이었다:
    // 트리셰이킹 아이콘 폰트는 내용이 빌드마다 바뀌는데 URL 이
    // `assets/fonts/MaterialIcons-Regular.otf` 로 고정이라, nginx 가 그 URL 을 `immutable`
    // 로 내보내던 시절에 캐시한 기기는 구 subset 을 물고 **재검증 요청조차 하지 않았다**.
    // 그래서 정산 도입 이전 subset 에 없는 0xE256(fact_check) 만 빈칸이고 목록·달력은
    // 정상이었다 — 헤더 fix(#277)로는 그 기기에 도달할 수 없었다.
    //
    // 이제 배포 시 `infra/scripts/hash-icon-font.sh` 가 폰트 파일명에 content hash 를 넣고
    // FontManifest 를 재작성하므로 stale 캐시가 새 글리프를 가릴 수 없고,
    // `infra/scripts/verify-cache-headers.sh` 가 배포마다 그 해시를 강제한다.
    //
    // 아이콘 전용이므로 각 세그먼트는 tooltip(= 접근성 라벨)을 반드시 갖는다
    // — `view_mode_toggle_guard_test.dart` 가 고정한다.
    return SegmentedButton<_TxViewMode>(
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStatePropertyAll(
          context.bbSpace.symmetric(h: BbSpaceToken.md),
        ),
      ),
      segments: [
        ButtonSegment(
          value: _TxViewMode.list,
          icon: Icon(Icons.list, size: context.bbType.iconSm),
          tooltip: '목록 보기',
        ),
        ButtonSegment(
          value: _TxViewMode.calendar,
          icon: Icon(Icons.calendar_month, size: context.bbType.iconSm),
          tooltip: '달력 보기',
        ),
        ButtonSegment(
          value: _TxViewMode.reconciliation,
          icon: Icon(Icons.fact_check, size: context.bbType.iconSm),
          tooltip: '정산 보기 — 미기록 항목 확인/기록',
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
