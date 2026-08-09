import 'dart:async';

import 'package:flutter/material.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/utils/category_display_helper.dart';
import 'package:budget_book/core/utils/dialog_helpers.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:budget_book/core/services/couple_prefs.dart';
import 'package:flutter/services.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/calculator_amount_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/widgets/item_selector_sheet.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';
import 'package:budget_book/core/widgets/category_group_selector_sheet.dart';
import 'package:budget_book/features/transaction/domain/adjustment_submission.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/core/utils/payment_method_helpers.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/widgets/payment_method_form_sheet.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_event.dart';
import 'package:budget_book/features/pocket/presentation/widgets/pocket_form_sheet.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart'
    as tx_entity;
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_state.dart';
import 'package:budget_book/features/ai/data/datasources/ai_remote_datasource.dart';
import 'package:budget_book/features/ai/domain/entities/ai_classify_result.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_bloc.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_event.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_state.dart';

class TransactionFormPage extends StatefulWidget {
  /// If editing, pass the transaction ID (from URL path parameter).
  /// The page will load the transaction data from the BLoC/repository.
  final String? transactionId;

  /// Optional initial transaction type ('EXPENSE' or 'INCOME').
  /// Used when navigating from dashboard quick actions.
  final String? initialType;

  /// Pre-fill fields from an existing transaction (for copy).
  /// Date defaults to today; all other fields are copied.
  /// 배치 4 D-4 (2026-04-26): state.extra 사용은 deprecated — 웹 새로고침 시 유실.
  /// 신규 진입은 copyFromId (query param) 권장. 본 필드는 기존 호환을 위해 유지.
  final tx_entity.Transaction? copyFrom;

  /// 배치 4 D-4: copy-from transaction 의 id (query param 으로 전달).
  /// 새로고침 시에도 URL 에서 보존되어 prefill 가능.
  final String? copyFromId;

  /// 이체 → 거래 역변환 대상 이체의 id (2026-08-09, query param).
  ///
  /// 지정되면 이 폼은 "새 거래 등록" 이 아니라 **원본 이체를 거래로 옮기는** 모드가 된다:
  /// 저장 시 변환 API(이체 삭제 + 거래 생성)를 타고, 이체 탭은 숨긴다.
  /// 변환을 이체 폼이 아니라 이 폼에서 하는 이유는 카테고리·포켓 피커가 여기에만 있어
  /// 복제를 피하기 위함이다 (거래 → 이체 변환도 이 폼에서 일어난다).
  final String? convertFromTransferId;

  /// Optional initial date for the transaction.
  /// Used when navigating from a date header in the transaction list.
  final DateTime? initialDate;

  /// Optional initial payment method ID.
  /// Used when adding a transaction from a filtered payment method view.
  final String? initialPaymentMethodId;

  /// Optional initial tab: 'expense' (0), 'income' (1), 'transfer' (2).
  /// Determines which tab is shown on page load.
  final String? initialTab;

  const TransactionFormPage({
    super.key,
    this.transactionId,
    this.initialType,
    this.copyFrom,
    this.copyFromId,
    this.convertFromTransferId,
    this.initialDate,
    this.initialPaymentMethodId,
    this.initialTab,
  });

  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage>
    with SingleTickerProviderStateMixin {
  final _expenseFormKey = GlobalKey<FormState>();
  final _incomeFormKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  String _amountHint = '';
  late final TextEditingController _descriptionController;
  late final TextEditingController _memoController;
  late String _selectedType;
  String? _selectedCategoryId;
  String? _selectedCategoryDisplayName;

  /// 회차 4 — 잔액 조정 모드 방향 (true=증가/+, false=감소/-).
  /// _isAdjustmentSelected 일 때만 의미 있음.
  bool _adjustmentIsIncrease = true;

  bool get _isAdjustmentSelected =>
      _selectedType == 'ADJUSTMENT' ||
      _selectedCategoryId == kAdjustmentSentinel;
  String? _selectedPaymentMethodId;
  String? _selectedPocketId;
  late DateTime _selectedDate;
  bool _isLoadingTransaction = false;
  bool _isSubmitting = false;
  bool _continueMode = false;
  bool _keepSameItems = false;
  /// 이 폼 세션에서 마지막으로 저장 성공한 거래의 달.
  /// continue 모드로 등록 후 뒤로가기로 폼을 나갈 때, stale URL 로 복귀해
  /// 목록이 이전 달로 돌아가는 drift 를 막기 위해 등록한 달로 이동한다.
  int? _savedYear;
  int? _savedMonth;
  /// V61 (2026-05-06) — 사용자가 "확인/입력 필요" 로 마킹한 거래 여부.
  bool _needsReview = false;
  String? _categoryError;
  String? _paymentMethodError;

  // Suggestion state
  List<SuggestionGroup> _suggestions = [];
  SuggestionGroup? _expandedSuggestion;
  bool _suppressSuggestions = false;
  Timer? _debounceTimer;

  // AI classification state
  AiClassifyResult? _aiResult;
  bool _aiLoading = false;
  Timer? _aiDebounceTimer;

  /// 회차 5 — _onSubmit 후 spinner 무한 회귀 방지용 timeout 가드.
  Timer? _submitTimeoutTimer;

  // FocusNodes for keyboard navigation on selector fields.
  // 지출/수입 탭이 TabBarView 에서 동시에 렌더링될 때 동일 FocusNode 를
  // 두 Focus 위젯이 공유하면 소유권 충돌 → 지출 탭 검은 화면 회귀.
  // 탭별 독립 인스턴스 사용.
  final FocusNode _categoryFocusNode = FocusNode();
  final FocusNode _paymentMethodFocusNode = FocusNode();
  final FocusNode _pocketFocusNode = FocusNode();
  final FocusNode _incomeCategoryFocusNode = FocusNode();
  final FocusNode _incomePmFocusNode = FocusNode();
  final FocusNode _incomePocketFocusNode = FocusNode();

  // Tab controller for expense/income/transfer tabs
  late final TabController _tabController;

  // Transfer form fields (used when tab index == 2)
  // 회차 12 P5 (2026-05-03) — 공통 controllers (_amountController/_descriptionController/_memoController)
  // 사용으로 통일. _transfer*Controller 별도 controllers 제거.
  // 사용자 요구: 수입/지출/예산/이체 탭 전환 시 공통 항목 (금액/설명/메모) 유지.
  final _transferFormKey = GlobalKey<FormState>();
  String? _transferSourcePaymentMethodId;
  String? _transferDestinationPaymentMethodId;
  late DateTime _transferDate;
  bool _isTransferSubmitting = false;
  int _swapCounter = 0;

  /// 수정 모드에서 고른 유형: `EXPENSE` / `INCOME` / `TRANSFER` (2026-07-27).
  ///
  /// 이전에는 "(유형 수정 불가)" 라벨만 있었다. 수입↔지출은 그 자리에서 저장되고,
  /// `TRANSFER` 를 고르면 이체 폼으로 바뀌며 저장 시 **변환 API**(거래 삭제 + 이체 생성)를 쓴다
  /// — 거래와 이체는 테이블이 달라 update 로는 바꿀 수 없다.
  String _editTargetType = 'EXPENSE';

  /// 수정 진입 시점의 원래 유형. 저장할 때 **바뀐 경우에만** `type` 을 보낸다 —
  /// 거래 로드가 실패한 상태에서 저장하면 초기값(EXPENSE)이 그대로 나가 수입 거래가
  /// 지출로 뒤집힐 수 있다.
  String? _originalType;

  bool get isEditing => widget.transactionId != null;

  /// 수정 모드에서 이체로 바꾸는 중인가 (본문/저장 경로가 갈린다).
  bool get _isConvertingToTransfer => isEditing && _editTargetType == 'TRANSFER';

  /// 이체 → 거래 역변환 모드인가 (저장 경로가 갈린다. 정방향의 거울상).
  bool get _isConvertingFromTransfer => widget.convertFromTransferId != null;

  /// 이체 탭을 숨겨야 하는가 — 수정 모드, 그리고 역변환 모드(목적지가 거래로 고정).
  bool get _hidesTransferTab => isEditing || _isConvertingFromTransfer;

  int _resolveInitialTabIndex() {
    // When editing, determine tab from transaction type (no transfer tab for edit)
    if (isEditing) {
      if (widget.initialType == 'INCOME') return 1;
      return 0;
    }
    // From initialTab query parameter
    switch (widget.initialTab) {
      case 'income':
        return 1;
      case 'transfer':
        return 2;
      case 'expense':
      default:
        // Also check initialType for backward compatibility
        if (widget.initialType == 'INCOME') return 1;
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize tab controller (hide transfer tab when editing)
    final initialIndex = _resolveInitialTabIndex();
    _tabController = TabController(
      length: _hidesTransferTab ? 2 : 3,
      vsync: this,
      initialIndex:
          _hidesTransferTab ? initialIndex.clamp(0, 1) : initialIndex,
    );
    _tabController.addListener(_onTabChanged);

    _amountController = TextEditingController();
    _amountController.addListener(_updateAmountHint);
    _descriptionController = TextEditingController();
    _descriptionController.addListener(_onDescriptionChanged);
    _memoController = TextEditingController();
    _selectedType = (initialIndex == 1 || widget.initialType == 'INCOME')
        ? 'INCOME'
        : 'EXPENSE';
    _selectedDate = widget.initialDate ?? DateTime.now();

    // 회차 12 P5 — transfer 별도 controllers 제거. 공통 controller 사용.
    _transferDate = widget.initialDate ?? DateTime.now();

    if (isEditing) {
      _isLoadingTransaction = true;
      _loadTransaction();
    } else if (_isConvertingFromTransfer) {
      // copyFromId 와 같은 방식 — query param 의 id 로 fetch 후 prefill 하므로
      // 새로고침해도 변환 대상이 살아남는다.
      _isLoadingTransaction = true;
      _loadConvertFromTransfer(widget.convertFromTransferId!);
    } else if (widget.copyFrom != null) {
      _prefillFromTransaction(widget.copyFrom!);
    } else if (widget.copyFromId != null) {
      // 배치 4 D-4: query param 으로 전달된 copy-from id → API 로 fetch 후 prefill.
      // 새로고침 시에도 URL 에서 보존되어 정상 동작.
      _isLoadingTransaction = true;
      _loadCopyFromTransaction(widget.copyFromId!);
    } else {
      _loadDefaultPaymentMethod();
    }
  }

  void _prefillFromTransaction(tx_entity.Transaction src) {
    _descriptionController.text = src.description;
    _memoController.text = src.memo ?? '';
    _selectedType = src.type;
    _editTargetType = src.type;
    _originalType = src.type;
    _selectedCategoryId = src.category?.id;
    _selectedCategoryDisplayName = src.category?.displayName;
    _selectedPaymentMethodId = src.paymentMethodId;
    _selectedPocketId = src.pocketId;
    _needsReview = src.needsReview;
    // 회차 4 — ADJUSTMENT 거래 prefill: sentinel 카테고리 + 부호로 방향 추정.
    if (src.type == 'ADJUSTMENT') {
      _selectedCategoryId = kAdjustmentSentinel;
      _selectedCategoryDisplayName = '잔액 조정';
      _adjustmentIsIncrease = src.amount >= 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // ADJUSTMENT 는 form 에 절대값 표시 (방향은 radio 로). 그 외는 그대로.
        final displayAmount =
            src.type == 'ADJUSTMENT' ? src.amount.abs() : src.amount;
        _amountController.text = CurrencyFormatter.format(displayAmount);
      }
    });
  }

  /// 역변환 원본 이체. 결제수단 승계(지출=출금 / 수입=입금)에 계속 필요해서 들고 있는다.
  Transfer? _sourceTransfer;

  Future<void> _loadConvertFromTransfer(String id) async {
    try {
      final repo = context.read<TransferBloc>().transferRepository;
      final result = await repo.getTransfer(id);
      if (!mounted) return;
      result.fold(
        (failure) {
          setState(() => _isLoadingTransaction = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('변환할 이체를 불러올 수 없습니다: ${failure.message}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        },
        (transfer) {
          setState(() {
            _isLoadingTransaction = false;
            _prefillFromTransfer(transfer);
          });
        },
      );
    } catch (_) {
      if (mounted) setState(() => _isLoadingTransaction = false);
    }
  }

  /// 이체 값을 거래 폼에 승계한다. 서버 승계 규칙(§4)과 **같은 규칙**이어야 한다 —
  /// 화면에 보이는 값과 저장되는 값이 갈라지면 사용자가 틀린 걸 확인하고 저장하게 된다.
  void _prefillFromTransfer(Transfer transfer) {
    _sourceTransfer = transfer;
    _descriptionController.text = transfer.description ?? '';
    _memoController.text = transfer.memo ?? '';
    _selectedPaymentMethodId = _inheritedPaymentMethodId(transfer);
    final parsed = DateTime.tryParse(transfer.transferDate);
    if (parsed != null) _selectedDate = parsed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _amountController.text = CurrencyFormatter.format(transfer.amount);
      }
    });
  }

  /// 지출은 돈이 나간 쪽(출금), 수입은 들어온 쪽(입금)이 그 거래의 결제수단이다.
  String _inheritedPaymentMethodId(Transfer transfer) =>
      _selectedType == 'INCOME'
          ? transfer.destinationPaymentMethod.id
          : transfer.sourcePaymentMethod.id;

  Future<void> _loadCopyFromTransaction(String id) async {
    try {
      final repo = context.read<TransactionBloc>().transactionRepository;
      final result = await repo.getTransaction(id);
      result.fold(
        (failure) {
          if (mounted) {
            setState(() => _isLoadingTransaction = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('복사할 거래를 불러올 수 없습니다: ${failure.message}'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        (transaction) {
          if (mounted) {
            setState(() => _isLoadingTransaction = false);
            _prefillFromTransaction(transaction);
          }
        },
      );
    } catch (_) {
      if (mounted) setState(() => _isLoadingTransaction = false);
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        if (_tabController.index == 0) {
          _selectedType = 'EXPENSE';
          _selectedCategoryId = null;
          _selectedCategoryDisplayName = null;
        } else if (_tabController.index == 1) {
          _selectedType = 'INCOME';
          _selectedCategoryId = null;
          _selectedCategoryDisplayName = null;
        }
        // 역변환 모드에서 지출↔수입을 바꾸면 승계할 결제수단도 반대쪽이 된다
        // (지출=출금 / 수입=입금). 안 바꾸면 화면 값과 서버 승계 규칙이 갈라진다.
        final source = _sourceTransfer;
        if (source != null && _tabController.index < 2) {
          _selectedPaymentMethodId = _inheritedPaymentMethodId(source);
        }
        // Tab 2 (transfer) doesn't change _selectedType
      });
    }
  }

  String? _coupleId;

  Future<void> _loadDefaultPaymentMethod() async {
    // If initial payment method is specified (e.g., from filtered view), use it
    if (widget.initialPaymentMethodId != null && _selectedPaymentMethodId == null) {
      setState(() => _selectedPaymentMethodId = widget.initialPaymentMethodId);
      return;
    }

    _coupleId ??= _resolveCoupleId();
    if (_coupleId == null) return;

    final defaultId = await CouplePrefs.getString(_coupleId!, 'default_payment_method_id');
    if (defaultId == null || !mounted) return;

    // Validate against current payment methods from server
    final pmBloc = getIt<PaymentMethodBloc>();
    final pmState = pmBloc.state;
    if (pmState is PaymentMethodLoaded) {
      final exists = pmState.paymentMethods.any((pm) => pm.id == defaultId);
      if (exists) {
        setState(() => _selectedPaymentMethodId = defaultId);
      } else {
        // Stale reference — clear it
        await CouplePrefs.remove(_coupleId!, 'default_payment_method_id');
      }
    } else {
      // PM list not loaded yet — set tentatively, will be validated on submit
      setState(() => _selectedPaymentMethodId = defaultId);
    }
  }

  String? _resolveCoupleId() {
    final authState = getIt<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.coupleId;
    }
    return null;
  }

  Future<void> _loadTransaction() async {
    try {
      final bloc = context.read<TransactionBloc>();
      final repo = bloc.transactionRepository;
      final result = await repo.getTransaction(widget.transactionId!);
      result.fold(
        (failure) {
          if (mounted) {
            setState(() {
              _isLoadingTransaction = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('거래를 불러올 수 없습니다: ${failure.message}'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        (transaction) {
          if (mounted) {
            // 회차 5 회귀 fix — _prefillFromTransaction 단일 진입점 사용.
            // 이전: raw amount 직접 set + ADJUSTMENT 분기 누락 → 감소(-1) 거래
            // 수정 시 controller 에 "-1" 표시 + 라디오 부호 충돌로 수정 불가.
            setState(() {
              _isLoadingTransaction = false;
              _selectedDate = DateTime.parse(transaction.transactionDate);
              _prefillFromTransaction(transaction);
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTransaction = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('거래 로드 실패: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _onDescriptionChanged() {
    // Skip if programmatically set (e.g., from suggestion apply)
    if (_suppressSuggestions) return;

    final text = _descriptionController.text.trim();
    _debounceTimer?.cancel();
    _aiDebounceTimer?.cancel();
    if (text.length < 2) {
      if (_suggestions.isNotEmpty || _expandedSuggestion != null) {
        setState(() {
          _suggestions = [];
          _expandedSuggestion = null;
        });
      }
      if (_aiResult != null || _aiLoading) {
        setState(() {
          _aiResult = null;
          _aiLoading = false;
        });
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(text);
    });
    _aiDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchAiClassification(text);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    final repo = context.read<TransactionBloc>().transactionRepository;
    // 수입/지출 타입별 제안 분리 — ADJUSTMENT 는 EXPENSE 로 취급(카테고리 필터와 동일 규칙).
    final suggestionType = _selectedType == 'INCOME' ? 'INCOME' : 'EXPENSE';
    final result = await repo.getSuggestions(query, type: suggestionType);
    if (!mounted) return;
    result.fold(
      (_) => setState(() {
        _suggestions = [];
        _expandedSuggestion = null;
      }),
      (data) => setState(() {
        _suggestions = data;
        // expand 보존 — 사용자가 chip expand 한 뒤 fetch 재발화 시
        // 같은 description 가 응답에 있으면 expand 유지, 없으면 null.
        // (SuggestionGroup 는 description 기준 Equatable)
        if (_expandedSuggestion != null &&
            !data.contains(_expandedSuggestion)) {
          _expandedSuggestion = null;
        }
      }),
    );
  }

  void _applySuggestionPattern(SuggestionGroup group, SuggestionPattern? pattern) {
    _suppressSuggestions = true;
    _debounceTimer?.cancel();
    setState(() {
      _descriptionController.text = group.description;
      _descriptionController.selection =
          TextSelection.collapsed(offset: group.description.length);
      if (pattern != null) {
        _selectedCategoryId = pattern.categoryId;
        // 회차 12 P3 + follow-up — 자동 선택도 picker 직접 선택과 동일한 "그룹 > 하위" 형식.
        // BE 응답의 categoryGroupName 우선 사용. fallback 으로 helper (group lookup).
        _selectedCategoryDisplayName = pattern.categoryName != null
            ? (pattern.categoryGroupName != null && pattern.categoryGroupName!.isNotEmpty
                ? '${pattern.categoryGroupName} > ${pattern.categoryName}'
                : formatCategoryDisplay(
                    pattern.categoryId,
                    categoryName: pattern.categoryName!,
                  ))
            : null;
        _selectedPaymentMethodId = pattern.paymentMethodId;
      }
      _suggestions = [];
      _expandedSuggestion = null;
    });
    // Re-enable after listener fires
    Future.microtask(() => _suppressSuggestions = false);
  }

  Future<void> _fetchAiClassification(String description) async {
    if (!mounted) return;
    setState(() => _aiLoading = true);
    try {
      final datasource = getIt<AiRemoteDataSource>();
      final results = await datasource.classify(description, _selectedType);
      if (!mounted) return;
      setState(() {
        _aiResult = results.isNotEmpty ? results.first : null;
        _aiLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiResult = null;
        _aiLoading = false;
      });
    }
  }

  void _applyAiCategory(AiClassifyResult result) {
    setState(() {
      _selectedCategoryId = result.categoryId;
      // 회차 12 P3 + follow-up — AI 추천도 "그룹 > 하위" 형식 통일.
      // AiClassifyResult.groupName 직접 사용 (BE 응답).
      _selectedCategoryDisplayName = result.groupName.isNotEmpty
          ? '${result.groupName} > ${result.categoryName}'
          : result.categoryName;
      _aiResult = null;
    });
  }

  void _updateAmountHint() {
    final parsed = CurrencyFormatter.parse(_amountController.text);
    final hint = (parsed != null && parsed >= 10000)
        ? CurrencyFormatter.toKoreanUnit(parsed)
        : '';
    if (hint != _amountHint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _amountHint = hint);
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _aiDebounceTimer?.cancel();
    _submitTimeoutTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _descriptionController.removeListener(_onDescriptionChanged);
    _amountController.removeListener(_updateAmountHint);
    _amountController.dispose();
    _descriptionController.dispose();
    _memoController.dispose();
    _categoryFocusNode.dispose();
    _paymentMethodFocusNode.dispose();
    _pocketFocusNode.dispose();
    _incomeCategoryFocusNode.dispose();
    _incomePmFocusNode.dispose();
    _incomePocketFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTransaction) {
      return Scaffold(
        appBar: AppBar(title: const Text('거래 수정')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // BlocListeners are placed outside the TabBarView/Scaffold body
    // to prevent them from being rebuilt (and missing state changes)
    // when setState is called (e.g., _isTransferSubmitting toggling).
    return MultiBlocListener(
      listeners: [
        BlocListener<TransactionBloc, TransactionState>(
          listener: (context, state) {
            // Only react when user actually submitted the form.
            // Without this guard, any TransactionLoaded change (e.g., LoadMore
            // from the list page behind) would trigger premature navigation.
            if (!_isSubmitting) return;
            // 회차 1 follow-up (2026-05-06) — TransactionLoaded(operationError)
            // 케이스를 success 와 분리. 이전: BE 검증 실패 후 BLoC catch 가
            // operationError 가진 TransactionLoaded 로 emit 했을 때 listener 가
            // 그대로 navigate 했고, 일부 케이스에서는 _isSubmitting 이 풀리지
            // 않아 무한 로딩. 이제 operationError 가 있으면 에러 경로로 처리.
            if (state is TransactionLoaded && state.operationError != null) {
              _submitTimeoutTimer?.cancel();
              setState(() => _isSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.operationError!),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            } else if (state is TransactionLoaded) {
              _submitTimeoutTimer?.cancel();
              _isSubmitting = false;
              // 등록/수정한 거래의 달로 전역 포커스 이동.
              // state.year/month = 방금 등록/수정한 거래의 달 (TransactionBloc 가
              // 거래 날짜 기준으로 재조회). MonthCubit 을 맞춰 네비게이터 + 모든
              // 월 의존 뷰를 동기화 → "다른 달 등록 시 이전 달만 보임"(버그1) 및
              // "달력 6월 / 내역 5월" 불일치(버그2)를 함께 해소.
              // 같은 달이면 changeMonth 는 no-op 이므로 아래 명시 reload 유지.
              getIt<MonthCubit>().changeMonth(state.year, state.month);
              getIt<DashboardBloc>().add(LoadDashboard(year: state.year, month: state.month));
              getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
              // 등록/수정한 거래의 달을 기록 → continue 모드 뒤로가기 시 이 달로 복귀.
              _savedYear = state.year;
              _savedMonth = state.month;
              if (_continueMode) {
                _resetFormForContinue();
              } else if (isEditing) {
                // After editing, go directly to transactions list
                // to avoid stale edit page in browser history
                context.go('/transactions?year=${state.year}&month=${state.month}');
              } else {
                // 등록 월을 URL 에 실어 복귀 → 라우터가 목록/달력을 모두 그 달로
                // 동기화 (pop 으로 stale URL 복귀 시 발생하던 drift 방지).
                context.go('/transactions?year=${state.year}&month=${state.month}');
              }
            } else if (state is TransactionError) {
              _submitTimeoutTimer?.cancel();
              setState(() => _isSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
        ),
        BlocListener<TransferBloc, TransferState>(
          listener: (context, state) {
            debugPrint('[TransferForm] BlocListener state=$state, submitting=$_isTransferSubmitting');
            if (!_isTransferSubmitting) return;
            if (state is TransferLoaded) {
              if (state.operationError != null) {
                setState(() => _isTransferSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.operationError!),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              } else {
                setState(() => _isTransferSubmitting = false);
                final dashState = getIt<DashboardBloc>().state;
                final year = dashState is DashboardLoaded ? dashState.year : DateTime.now().year;
                final month = dashState is DashboardLoaded ? dashState.month : DateTime.now().month;
                getIt<DashboardBloc>().add(LoadDashboard(year: year, month: month));
                getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('이체가 등록되었습니다')),
                );
                context.pop();
              }
            } else if (state is TransferError) {
              setState(() => _isTransferSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
        ),
      ],
      // continue 모드로 거래를 등록한 뒤 뒤로가기로 폼을 나가면, 진입 전의
      // stale URL (이전 달) 로 복귀해 목록이 이전 달로 돌아가는 drift 가 발생.
      // 저장 이력이 있으면 pop 을 가로채 등록한 달의 목록 URL 로 이동한다.
      child: PopScope(
        canPop: _savedYear == null,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || _savedYear == null) return;
          context.go('/transactions?year=$_savedYear&month=$_savedMonth');
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(isEditing
                ? '거래 수정'
                : (_isConvertingFromTransfer ? '거래로 변경' : '거래 추가')),
          actions: [
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _isSubmitting ? null : () => _confirmDelete(context),
              ),
          ],
          bottom: isEditing
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: _buildEditTypeSelector(context),
                )
              : TabBar(
                  controller: _tabController,
                  tabs: [
                    const Tab(icon: Icon(Icons.arrow_downward), text: '지출'),
                    const Tab(icon: Icon(Icons.arrow_upward), text: '수입'),
                    // 역변환 모드에서는 목적지가 거래로 고정이라 이체 탭이 없다
                    // (TabController.length 와 반드시 같은 조건이어야 한다).
                    if (!_hidesTransferTab)
                      const Tab(icon: Icon(Icons.swap_horiz), text: '이체'),
                  ],
                ),
        ),
        body: isEditing
            ? (_isConvertingToTransfer
                ? _buildTransferFormContent(context)
                : _buildTransactionFormBody(context))
            : Column(
                children: [
                  if (_isConvertingFromTransfer) _buildConvertBanner(context),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 0: Expense form
                        _buildTransactionFormBody(context,
                            formKey: _expenseFormKey),
                        // Tab 1: Income form
                        _buildTransactionFormBody(context,
                          formKey: _incomeFormKey,
                          categoryFocusNode: _incomeCategoryFocusNode,
                          pmFocusNode: _incomePmFocusNode,
                          pocketFocusNode: _incomePocketFocusNode,
                        ),
                        // Tab 2: Transfer form (embedded)
                        if (!_hidesTransferTab) _buildTransferFormBody(context),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      ),
    );
  }

  /// 역변환 모드 안내 — 저장이 "추가" 가 아니라 "이동" 임을 미리 알린다.
  Widget _buildConvertBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.swap_horiz, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '이체 → 거래로 변경 — 저장하면 원본 이체가 삭제됩니다',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// 수정 모드 유형 선택 — 지출 / 수입 / 이체.
  ///
  /// 수입↔지출은 카테고리가 유형별로 갈리므로 전환 시 선택을 비운다(서버도 불일치를 400 으로
  /// 막는다). 이체는 폼 자체가 달라 본문이 이체 폼으로 바뀌고, 저장은 변환 API 를 탄다.
  Widget _buildEditTypeSelector(BuildContext context) {
    // 잔액 수정은 잔액 보정 전용(부호 있는 증감값)이라 수입/지출/이체로 바꿀 수 없다
    // (서버도 400 으로 막는다) → 선택지를 주지 않고 상태만 알린다.
    if (_selectedType == 'ADJUSTMENT') {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.tune,
                  size: 16,
                  color: Theme.of(context).colorScheme.tertiary),
              const SizedBox(width: 6),
              Text(
                '잔액 수정 (유형 변경 불가)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Text(
              '유형',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<String>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(
                  value: 'EXPENSE',
                  icon: Icon(Icons.arrow_downward, size: 14),
                  label: Text('지출'),
                ),
                ButtonSegment(
                  value: 'INCOME',
                  icon: Icon(Icons.arrow_upward, size: 14),
                  label: Text('수입'),
                ),
                ButtonSegment(
                  value: 'TRANSFER',
                  icon: Icon(Icons.swap_horiz, size: 14),
                  label: Text('이체'),
                ),
              ],
              selected: {_editTargetType},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                _onEditTypeChanged(selection.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onEditTypeChanged(String next) {
    if (next == _editTargetType) return;
    setState(() {
      _editTargetType = next;
      if (next == 'TRANSFER') {
        // 이체 폼은 금액/설명/메모를 공용 controller 로 쓴다. 날짜만 맞춰 준다.
        _transferDate = _selectedDate;
      } else {
        _selectedType = next;
        // 카테고리는 유형별로 갈린다 — 남겨두면 서버가 400 으로 막는다.
        _selectedCategoryId = null;
        _selectedCategoryDisplayName = null;
      }
    });
    if (next != 'TRANSFER') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${next == 'INCOME' ? '수입' : '지출'}으로 변경 — 카테고리를 다시 선택하세요'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildTransactionFormBody(BuildContext context, {
    GlobalKey<FormState>? formKey,
    FocusNode? categoryFocusNode,
    FocusNode? pmFocusNode,
    FocusNode? pocketFocusNode,
  }) {
    final catFn = categoryFocusNode ?? _categoryFocusNode;
    final pmFn = pmFocusNode ?? _paymentMethodFocusNode;
    final pocketFn = pocketFocusNode ?? _pocketFocusNode;
    // BlocListener is now in the top-level MultiBlocListener in build()
    return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Form(
            key: formKey ?? _expenseFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  // Date picker
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(0),
                    child: _buildDatePicker(context),
                  ),
                  const SizedBox(height: 16),
                  // Amount
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: CalculatorAmountField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: '금액',
                        suffixText: '원',
                        prefixIcon: Icon(Icons.payments),
                      ),
                      helperText: _amountHint.isNotEmpty ? _amountHint : null,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '금액을 입력하세요';
                        }
                        final amount = CurrencyFormatter.parse(value);
                        if (amount == null || amount < 0) {
                          return '금액을 입력하세요';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Description with suggestion chips
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child: TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: '내용',
                        hintText: '예: 점심 식사',
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLength: 255,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '내용을 입력하세요';
                        }
                        return null;
                      },
                    ),
                  ),
                  // Suggestion chips (rich - with category/payment method patterns)
                  if (_suggestions.isNotEmpty)
                    _buildSuggestionArea(context),
                  // AI classification recommendation
                  if (_aiResult != null && _selectedCategoryId != _aiResult!.categoryId)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: ActionChip(
                        avatar: const Icon(Icons.auto_awesome, size: 16),
                        // 회차 12 P3 + follow-up — AI 추천 chip 도 "그룹 > 하위" 형식.
                        // result.groupName 직접 사용.
                        label: Text(_aiResult!.groupName.isNotEmpty
                            ? 'AI 추천: ${_aiResult!.groupName} > ${_aiResult!.categoryName}'
                            : 'AI 추천: ${_aiResult!.categoryName}'),
                        onPressed: () => _applyAiCategory(_aiResult!),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Category picker with keyboard support
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(3),
                    child: _buildKeyboardActivatableField(
                      focusNode: catFn,
                      onActivate: () => _activateCategoryPicker(context),
                      child: _buildCategoryPicker(context),
                    ),
                  ),
                  // 회차 4 — ADJUSTMENT 모드 banner + 증가/감소 radio.
                  if (_isAdjustmentSelected) ...[
                    const SizedBox(height: 12),
                    _buildAdjustmentBanner(context),
                  ],
                  const SizedBox(height: 16),
                  // Payment method picker with keyboard support
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(4),
                    child: _buildKeyboardActivatableField(
                      focusNode: pmFn,
                      onActivate: () => _activatePaymentMethodPicker(context),
                      child: _buildPaymentMethodPicker(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Pocket picker with keyboard support
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(5),
                    child: _buildKeyboardActivatableField(
                      focusNode: pocketFn,
                      onActivate: () => _activatePocketPicker(context),
                      child: _buildPocketPicker(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // V61 (2026-05-06) — 메모 카드 + needs_review 토글.
                  // 이전: prefixIcon 있는 좌측정렬 단행 입력 + maxLines:2.
                  // 변경: 카드 컨테이너 안에 [멀티라인 가운데정렬 메모] + [확인/입력 필요 토글].
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(6),
                    child: _buildMemoCard(context),
                  ),
                  const SizedBox(height: 24),
                  // Continue mode options (new transactions only)
                  if (!isEditing) ...[
                    GestureDetector(
                      onTap: () => setState(() => _keepSameItems = !_keepSameItems),
                      child: Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _keepSameItems,
                              onChanged: (v) => setState(() => _keepSameItems = v ?? false),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '동일 항목 유지 (날짜/카테고리/결제수단)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Submit buttons
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(7),
                    child: isEditing
                        ? FilledButton(
                            onPressed: _isSubmitting ? null : _onSubmit,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20, width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('수정'),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSubmitting ? null : () {
                                    _continueMode = true;
                                    _onSubmit();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: _isSubmitting && _continueMode
                                      ? const SizedBox(
                                          height: 20, width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('저장 & 계속'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _isSubmitting ? null : () {
                                    _continueMode = false;
                                    _onSubmit();
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: _isSubmitting && !_continueMode
                                      ? const SizedBox(
                                          height: 20, width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('저장'),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // ----- Embedded Transfer Form (Tab 2) -----

  Future<void> _selectTransferDate() async {
    final picked = await showCalendarPickerDialog(
      context: context,
      initialDate: _transferDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030, 12, 31),
    );
    if (picked != null) {
      setState(() => _transferDate = picked);
    }
  }

  void _submitTransfer() {
    if (!_transferFormKey.currentState!.validate()) return;
    if (_transferSourcePaymentMethodId == null ||
        _transferDestinationPaymentMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출금/입금 결제수단을 모두 선택해주세요')),
      );
      return;
    }
    if (_transferSourcePaymentMethodId == _transferDestinationPaymentMethodId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출금/입금 결제수단이 같을 수 없습니다')),
      );
      return;
    }

    // Block CREDIT to CREDIT transfers
    final pmState = getIt<PaymentMethodBloc>().state;
    if (pmState is PaymentMethodLoaded) {
      final source = pmState.activePaymentMethods
          .where((pm) => pm.id == _transferSourcePaymentMethodId)
          .firstOrNull;
      final dest = pmState.activePaymentMethods
          .where((pm) => pm.id == _transferDestinationPaymentMethodId)
          .firstOrNull;
      if (source != null && dest != null && source.isCredit && dest.isCredit) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카드 간 이체는 지원하지 않습니다')),
        );
        return;
      }
    }

    // 회차 12 P5 — 공통 controller 사용으로 통일.
    final amount = CurrencyFormatter.parse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('금액을 입력해주세요')),
      );
      return;
    }

    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    final memo = _memoController.text.trim().isEmpty
        ? null
        : _memoController.text.trim();
    final dateStr = DateFormat('yyyy-MM-dd').format(_transferDate);

    setState(() => _isTransferSubmitting = true);

    // 수정 모드에서 유형을 이체로 바꾼 경우 — 새 이체를 만드는 게 아니라 **원본 거래를
    // 이체로 옮긴다**(서버가 삭제+생성을 한 트랜잭션으로 처리). 여기서 CreateTransfer 를
    // 쓰면 거래와 이체가 둘 다 남아 금액이 이중 계상된다.
    if (_isConvertingToTransfer) {
      _convertToTransfer(
        amount: amount,
        description: description,
        memo: memo,
        dateStr: dateStr,
      );
      return;
    }

    debugPrint('[TransferForm] _submitTransfer: amount=$amount, source=$_transferSourcePaymentMethodId, dest=$_transferDestinationPaymentMethodId, date=$dateStr');
    final bloc = context.read<TransferBloc>();
    bloc.add(CreateTransfer(
      sourcePaymentMethodId: _transferSourcePaymentMethodId!,
      destinationPaymentMethodId: _transferDestinationPaymentMethodId!,
      amount: amount,
      description: description,
      transferDate: dateStr,
      memo: memo,
    ));
  }

  /// 거래 → 이체 변환 실행. 성공하면 거래/이체 두 목록을 함께 갱신하고 화면을 닫는다.
  ///
  /// BLoC 을 거치지 않고 repository 를 직접 부른다 — 이 작업은 두 스트림(거래 삭제 + 이체
  /// 생성)에 걸쳐 있어 어느 한쪽 BLoC 의 상태 머신에 얹기가 어색하다. 대신 성공 후 두 BLoC
  /// 을 모두 재조회해 목록이 갈라지지 않게 한다.
  Future<void> _convertToTransfer({
    required int amount,
    required String? description,
    required String? memo,
    required String dateStr,
  }) async {
    final txnBloc = context.read<TransactionBloc>();
    final result = await txnBloc.transactionRepository.convertToTransfer(
      id: widget.transactionId!,
      sourcePaymentMethodId: _transferSourcePaymentMethodId!,
      destinationPaymentMethodId: _transferDestinationPaymentMethodId!,
      amount: amount,
      description: description,
      memo: memo,
      transferDate: dateStr,
    );
    if (!mounted) return;
    setState(() => _isTransferSubmitting = false);

    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      ),
      (transfer) {
        final moved = DateTime.parse(transfer.transferDate);
        _reloadAfterConversion(moved.year, moved.month);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이체로 변경되었습니다')),
        );
        Navigator.of(context).pop(true);
      },
    );
  }

  /// 이체 → 거래 역변환 실행. 정방향 [_convertToTransfer] 의 거울상.
  ///
  /// 마찬가지로 BLoC 을 거치지 않고 repository 를 직접 부른다 — 이체 삭제 + 거래 생성이
  /// 두 스트림에 걸쳐 있어 어느 한쪽 BLoC 의 상태 머신에 얹기가 어색하다.
  Future<void> _convertToTransaction({
    required int amount,
    required String description,
    required String? memo,
    required String dateStr,
    required String? categoryId,
  }) async {
    final repo = context.read<TransferBloc>().transferRepository;
    final result = await repo.convertToTransaction(
      id: widget.convertFromTransferId!,
      type: _selectedType,
      categoryId: categoryId,
      paymentMethodId: _selectedPaymentMethodId,
      pocketId: _selectedPocketId,
      amount: amount,
      transactionDate: dateStr,
      description: description,
      memo: memo,
      needsReview: _needsReview,
    );
    if (!mounted) return;
    _submitTimeoutTimer?.cancel();
    setState(() => _isSubmitting = false);

    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      ),
      (transaction) {
        final moved = DateTime.parse(transaction.transactionDate);
        _reloadAfterConversion(moved.year, moved.month);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('거래로 변경되었습니다')),
        );
        // 원본 이체는 이제 없다 — 진입 경로(이체 수정 폼)로 pop 하면 사라진 이체의
        // 폼으로 되돌아간다. 장부 목록으로 보낸다.
        context.go('/transactions?year=${moved.year}&month=${moved.month}');
      },
    );
  }

  /// 변환 성공 후 재조회 — **양방향 공통**.
  ///
  /// 네 BLoC 을 모두 갱신해야 한다: 거래·이체(장부는 두 스트림 병합) + 대시보드(월 합계)
  /// + 결제수단(자산 잔액). 이전에는 정방향이 앞의 둘만 갱신해 변환 직후 월 합계와 자산
  /// 잔액이 그대로였다 — 한쪽만 고치면 또 갈라지므로 두 방향이 이 헬퍼를 함께 쓴다.
  void _reloadAfterConversion(int year, int month) {
    final txnBloc = context.read<TransactionBloc>();
    txnBloc.add(LoadTransactions.fromFilter(
      year,
      month,
      txnBloc.currentFilter,
    ));
    context.read<TransferBloc>().add(LoadTransfers(year: year, month: month));
    getIt<DashboardBloc>().add(LoadDashboard(year: year, month: month));
    getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
  }

  Widget _buildTransferFormBody(BuildContext context) {
    // BlocListener is now in the top-level MultiBlocListener in build()
    return _buildTransferFormContent(context);
  }

  Widget _buildTransferFormContent(BuildContext context) {
    final pmState = getIt<PaymentMethodBloc>().state;
    final methods = pmState is PaymentMethodLoaded
        ? pmState.activePaymentMethods
        : <PaymentMethod>[];

    final selectedDest = methods
        .where((pm) => pm.id == _transferDestinationPaymentMethodId)
        .firstOrNull;
    final selectedSource = methods
        .where((pm) => pm.id == _transferSourcePaymentMethodId)
        .firstOrNull;
    final destIsCredit = selectedDest?.isCredit ?? false;
    final sourceIsCredit = selectedSource?.isCredit ?? false;

    final sourceMethods = destIsCredit
        ? methods.where((pm) => !pm.isCredit).toList()
        : methods;
    final destMethods = methods
        .where((pm) => pm.id != _transferSourcePaymentMethodId)
        .where((pm) => !sourceIsCredit || !pm.isCredit)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _transferFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date (matches expense/income form order)
            InkWell(
              onTap: _selectTransferDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '이체일',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('yyyy년 M월 d일 (E)', 'ko')
                      .format(_transferDate),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Amount — 회차 12 P5/B-fix: 지출/수입 탭과 동일한 CalculatorAmountField
            // 사용. 이전: AmountInputField 였으나 controller 단일화에도 widget 차이로
            // 텍스트 표시 깨짐. 사용자 요구 "공통화" 의도 반영하여 widget 도 통일.
            CalculatorAmountField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '금액',
                suffixText: '원',
                prefixIcon: Icon(Icons.payments),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '금액을 입력하세요';
                final amount = CurrencyFormatter.parse(value);
                if (amount == null || amount <= 0) return '유효한 금액을 입력하세요';
                if (amount > 999999999) {
                  return '최대 999,999,999원까지 입력 가능합니다';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Source payment method
            DropdownButtonFormField<String>(
              key: ValueKey('transfer_source_$_swapCounter'),
              initialValue: _transferSourcePaymentMethodId,
              decoration: const InputDecoration(
                labelText: '출금 결제수단',
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              isExpanded: true,
              items: sourceMethods
                  .map((pm) => DropdownMenuItem(
                        value: pm.id,
                        child: Text(pm.name),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _transferSourcePaymentMethodId = value;
                  final newSource =
                      methods.where((pm) => pm.id == value).firstOrNull;
                  if (newSource?.isCredit == true &&
                      selectedDest?.isCredit == true) {
                    _transferDestinationPaymentMethodId = null;
                  }
                });
              },
              validator: (value) =>
                  value == null ? '출금 결제수단을 선택하세요' : null,
            ),
            const SizedBox(height: 8),
            // Swap button
            Center(
              child: IconButton(
                onPressed: () {
                  final wouldSwapSourceBeCredit =
                      selectedDest?.isCredit ?? false;
                  final wouldSwapDestBeCredit =
                      selectedSource?.isCredit ?? false;
                  if (wouldSwapSourceBeCredit && wouldSwapDestBeCredit) return;
                  setState(() {
                    final temp = _transferSourcePaymentMethodId;
                    _transferSourcePaymentMethodId =
                        _transferDestinationPaymentMethodId;
                    _transferDestinationPaymentMethodId = temp;
                    _swapCounter++;
                  });
                },
                icon: const Icon(Icons.swap_vert),
                tooltip: '출금/입금 교환',
              ),
            ),
            const SizedBox(height: 8),
            // Destination payment method
            DropdownButtonFormField<String>(
              key: ValueKey('transfer_dest_$_swapCounter'),
              initialValue: _transferDestinationPaymentMethodId,
              decoration: const InputDecoration(
                labelText: '입금 결제수단',
                prefixIcon: Icon(Icons.account_balance),
              ),
              isExpanded: true,
              items: destMethods
                  .map((pm) => DropdownMenuItem(
                        value: pm.id,
                        child: Text(pm.name),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _transferDestinationPaymentMethodId = value;
                  final newDest =
                      methods.where((pm) => pm.id == value).firstOrNull;
                  if (newDest?.isCredit == true &&
                      selectedSource?.isCredit == true) {
                    _transferSourcePaymentMethodId = null;
                    _swapCounter++;
                  }
                });
              },
              validator: (value) =>
                  value == null ? '입금 결제수단을 선택하세요' : null,
            ),
            const SizedBox(height: 16),
            // Description — 회차 12 P5: 공통 controller 사용
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '내용 (선택)',
                prefixIcon: Icon(Icons.description),
                hintText: '예: ATM 출금',
              ),
              maxLength: 255,
            ),
            const SizedBox(height: 8),
            // Memo — 회차 12 P5: 공통 controller 사용
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            // Submit button
            FilledButton(
              onPressed: _isTransferSubmitting ? null : _submitTransfer,
              child: _isTransferSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  /// V61 (2026-05-06) — 메모 + needs_review 통합 카드.
  ///
  /// 사용자 요청 (2026-05-06):
  ///   - 메모를 가운데 정렬 + 여러 줄 입력 가능
  ///   - 메모 영역에 "확인/입력 필요" 토글 (느낌표 표시 활성화)
  Widget _buildMemoCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(
                  Icons.note_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '메모',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextFormField(
              controller: _memoController,
              minLines: 3,
              maxLines: 6,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              decoration: const InputDecoration(
                hintText: '추가 메모 (여러 줄 입력 가능)',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          SwitchListTile(
            value: _needsReview,
            onChanged: (v) => setState(() => _needsReview = v),
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            title: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('확인/입력 필요로 표시'),
              ],
            ),
            subtitle: const Text(
              '나중에 확인하거나 정보를 채워넣어야 하는 거래로 마킹합니다.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionArea(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Suggestion chips (description only)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _suggestions.map((sg) {
              final isExpanded = _expandedSuggestion == sg;
              return ActionChip(
                label: Text(sg.description),
                avatar: isExpanded
                    ? const Icon(Icons.expand_less, size: 18)
                    : null,
                onPressed: () {
                  if (isExpanded) {
                    // Collapse: apply description only (empty pattern)
                    _applySuggestionPattern(sg, null);
                  } else {
                    setState(() => _expandedSuggestion = sg);
                  }
                },
              );
            }).toList(),
          ),
          // Expanded patterns for selected suggestion
          if (_expandedSuggestion != null) ...[
            const SizedBox(height: 8),
            // First option: description only, no pre-fill
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _applySuggestionPattern(_expandedSuggestion!, null),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '내용만 입력 (카테고리·결제수단 직접 선택)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Grouped patterns sorted by count
            ..._expandedSuggestion!.patterns.map((p) {
              // 회차 12 P3 + follow-up — suggestion picker label 도 "그룹 > 하위" 형식.
              // BE 응답의 categoryGroupName 우선 사용.
              final categoryLabel = p.categoryName == null
                  ? null
                  : (p.categoryGroupName != null && p.categoryGroupName!.isNotEmpty
                      ? '${p.categoryGroupName} > ${p.categoryName}'
                      : formatCategoryDisplay(p.categoryId, categoryName: p.categoryName!));
              final label = [
                categoryLabel,
                p.paymentMethodName,
              ].where((s) => s != null).join(' · ');
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _applySuggestionPattern(_expandedSuggestion!, p),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label.isEmpty ? '미분류' : label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${p.count}회',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Wraps a selector field with Focus + KeyboardListener so that
  /// Enter/Space activates the bottom sheet selector.
  Widget _buildKeyboardActivatableField({
    required FocusNode focusNode,
    required VoidCallback onActivate,
    required Widget child,
  }) {
    return Focus(
      focusNode: focusNode,
      canRequestFocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          onActivate();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          focusNode.requestFocus();
          onActivate();
        },
        child: AbsorbPointer(
          // AbsorbPointer prevents the inner InkWell from capturing tap;
          // the GestureDetector above handles it, allowing focus to be set.
          child: child,
        ),
      ),
    );
  }

  void _activateCategoryPicker(BuildContext context) {
    final catState = context.read<CategoryBloc>().state;
    final categories = catState is CategoryLoaded
        ? (_selectedType == 'INCOME'
            ? catState.incomeCategories
            : catState.expenseCategories)
        : <Category>[];
    setState(() => _categoryError = null);
    _showCategorySelectorSheet(context, categories);
  }

  void _activatePaymentMethodPicker(BuildContext context) {
    final pmState = context.read<PaymentMethodBloc>().state;
    final methods = pmState is PaymentMethodLoaded
        ? pmState.activePaymentMethods
        : <PaymentMethod>[];
    setState(() => _paymentMethodError = null);
    _showPaymentMethodSelectorSheet(context, methods);
  }

  void _activatePocketPicker(BuildContext context) {
    final pocketState = context.read<PocketBloc>().state;
    final pockets = pocketState is PocketLoaded
        ? pocketState.pockets
        : <MoneyPocket>[];
    _showPocketSelectorSheet(context, pockets);
  }


  /// 회차 4 — ADJUSTMENT 모드 banner + 증가/감소 ChoiceChip.
  /// 잔액 조정 카테고리 선택 시 노출. 부호는 submit 시 helper 가 처리.
  Widget _buildAdjustmentBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('adjustment-banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 18, color: theme.colorScheme.tertiary),
              const SizedBox(width: 6),
              Text(
                '잔액 조정 모드',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '통계 집계 제외 · 잔액 계산 포함',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer
                        .withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  key: const Key('adjustment-direction-increase'),
                  label: const Center(child: Text('증가 (+)')),
                  selected: _adjustmentIsIncrease,
                  onSelected: (_) =>
                      setState(() => _adjustmentIsIncrease = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  key: const Key('adjustment-direction-decrease'),
                  label: const Center(child: Text('감소 (-)')),
                  selected: !_adjustmentIsIncrease,
                  onSelected: (_) =>
                      setState(() => _adjustmentIsIncrease = false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker(BuildContext context) {
    return BlocBuilder<CategoryBloc, CategoryState>(
      builder: (context, catState) {
        final categories = catState is CategoryLoaded
            ? (_selectedType == 'INCOME'
                ? catState.incomeCategories
                : catState.expenseCategories)
            : <Category>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ItemSelectorField(
              label: '카테고리 *',
              selectedLabel: _selectedCategoryDisplayName ?? (_selectedCategoryId != null ? '(삭제됨)' : null),
              prefixIcon: Icons.category,
              placeholder: '카테고리를 선택하세요',
              onTap: () {
                setState(() => _categoryError = null);
                _showCategorySelectorSheet(context, categories);
              },
            ),
            if (_categoryError != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: Text(
                  _categoryError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentMethodPicker(BuildContext context) {
    return BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
      builder: (context, pmState) {
        final methods = pmState is PaymentMethodLoaded
            ? pmState.activePaymentMethods
            : <PaymentMethod>[];

        final selectedName = _selectedPaymentMethodId != null
            ? methods
                .where((pm) => pm.id == _selectedPaymentMethodId)
                .map((pm) => pm.name)
                .firstOrNull
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ItemSelectorField(
              label: '결제수단 *',
              selectedLabel: selectedName,
              prefixIcon: Icons.account_balance_wallet,
              placeholder: '결제수단을 선택하세요',
              onTap: () {
                setState(() => _paymentMethodError = null);
                _showPaymentMethodSelectorSheet(context, methods);
              },
            ),
            if (_paymentMethodError != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: Text(
                  _paymentMethodError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPocketPicker(BuildContext context) {
    return BlocBuilder<PocketBloc, PocketState>(
      builder: (context, pocketState) {
        final pockets = pocketState is PocketLoaded
            ? pocketState.pockets
            : <MoneyPocket>[];

        final selectedName = _selectedPocketId != null
            ? pockets
                .where((p) => p.id == _selectedPocketId)
                .map((p) => p.name)
                .firstOrNull
            : null;

        return ItemSelectorField(
          label: '포켓 (선택)',
          selectedLabel: selectedName,
          prefixIcon: Icons.account_balance_wallet,
          placeholder: '포켓 미지정',
          onTap: () => _showPocketSelectorSheet(context, pockets),
        );
      },
    );
  }

  void _showCategorySelectorSheet(BuildContext context, List<Category> categories) {
    // 회차 4 — sheet 진입 정책:
    // - 거래 등록 (create) + non-ADJUSTMENT: showAdjustmentOption=true (sentinel 핀 카드)
    // - 거래 수정 (edit) 의 ADJUSTMENT: adjustmentOnly=true (잔액 조정 1개만)
    // - 그 외: 기존 동작.
    final isEditingAdjustment = isEditing && _isAdjustmentSelected;
    final canShowAdjustment = !isEditing;
    // ADJUSTMENT 일 때 categoryType 은 시트 내부 그룹 필터에 영향. EXPENSE 로 fallback.
    final effectiveType =
        _selectedType == 'ADJUSTMENT' ? 'EXPENSE' : _selectedType;

    showDialog(
      context: context,
      builder: (_) => CategoryGroupSelectorSheet(
        selectedCategoryId: _selectedCategoryId,
        categoryType: effectiveType,
        showAdjustmentOption: canShowAdjustment,
        adjustmentOnly: isEditingAdjustment,
        onSelected: (category) {
          _applyCategorySelection(category, null);
        },
        onSelectedWithGroupName: (category, groupName) {
          _applyCategorySelection(category, groupName);
        },
        onDelete: (id) {
          if (_selectedCategoryId == id) {
            setState(() => _selectedCategoryId = null);
          }
        },
      ),
    );
  }

  /// 회차 4 — sentinel 카테고리 선택 처리. 일반 카테고리는 기존 동작.
  void _applyCategorySelection(Category? category, String? groupName) {
    setState(() {
      if (category?.id == kAdjustmentSentinel) {
        // sentinel 선택 → ADJUSTMENT 모드 자동 전환.
        _selectedType = 'ADJUSTMENT';
        _selectedCategoryId = kAdjustmentSentinel;
        _selectedCategoryDisplayName = '잔액 조정';
      } else {
        _selectedCategoryId = category?.id;
        if (category != null && groupName != null && groupName.isNotEmpty) {
          _selectedCategoryDisplayName = '$groupName > ${category.name}';
        } else {
          _selectedCategoryDisplayName = category?.name;
        }
        // ADJUSTMENT → 일반 카테고리 변경 시 type 도 EXPENSE 로 복귀
        // (사용자가 잔액 조정을 취소하고 다른 카테고리로 변경하는 경우).
        if (_selectedType == 'ADJUSTMENT' && category != null) {
          _selectedType = 'EXPENSE';
        }
      }
    });
  }

  void _showPaymentMethodSelectorSheet(BuildContext context, List<PaymentMethod> methods) {
    final pmBloc = context.read<PaymentMethodBloc>();
    showDialog(
      context: context,
      builder: (_) => BlocProvider<PaymentMethodBloc>.value(
        value: pmBloc,
        child: BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
          builder: (sheetContext, pmState) {
            final liveMethods = pmState is PaymentMethodLoaded
                ? pmState.activePaymentMethods
                : methods;
            return ItemSelectorSheet(
              title: '결제수단 선택',
              items: liveMethods
                  .indexed
                  .map((e) => SelectorItem(
                        id: e.$2.id,
                        label: e.$2.name,
                        leadingIcon: paymentMethodTypeIcon(e.$2.type),
                        leadingColor: paymentMethodTypeColor(e.$2.type),
                        isDeletable: true,
                        displayOrder: e.$1,
                        group: e.$2.type,
                      ))
                  .toList(),
              selectedId: _selectedPaymentMethodId,
              nullLabel: '선택 안 함',
              favoriteType: 'PAYMENT_METHOD',
              reorderRoute: '/asset-management',
              groupLabels: paymentMethodGroupLabels,
              onSelected: (item) {
                setState(() {
                  _selectedPaymentMethodId = item?.id;
                });
              },
              onEdit: (item) {
                final pm = liveMethods.where((m) => m.id == item.id).firstOrNull;
                if (pm != null) {
                  _showEditPaymentMethodSheet(context, pm);
                }
              },
              onDelete: (id) {
                pmBloc.add(DeletePaymentMethod(id));
                if (_selectedPaymentMethodId == id) {
                  setState(() => _selectedPaymentMethodId = null);
                }
              },
              onCreate: () => _showCreatePaymentMethodSheet(context),
              createLabel: '+ 새 결제수단',
            );
          },
        ),
      ),
    );
  }

  void _showPocketSelectorSheet(BuildContext context, List<MoneyPocket> pockets) {
    final pocketBloc = context.read<PocketBloc>();
    showDialog(
      context: context,
      builder: (_) => BlocProvider<PocketBloc>.value(
        value: pocketBloc,
        child: BlocBuilder<PocketBloc, PocketState>(
          builder: (sheetContext, pocketState) {
            final livePockets = pocketState is PocketLoaded
                ? pocketState.pockets
                : pockets;
            return ItemSelectorSheet(
              title: '포켓 선택',
              items: livePockets
                  .map((p) => SelectorItem(
                        id: p.id,
                        label: p.name,
                        leadingIcon: Icons.account_balance_wallet,
                        leadingColor: UIHelpers.parseColor(p.color),
                      ))
                  .toList(),
              selectedId: _selectedPocketId,
              nullLabel: '포켓 미지정',
              onSelected: (item) {
                setState(() {
                  _selectedPocketId = item?.id;
                });
              },
              onDelete: (id) {
                pocketBloc.add(DeletePocket(id));
                if (_selectedPocketId == id) {
                  setState(() => _selectedPocketId = null);
                }
              },
              onCreate: () => _showCreatePocketSheet(context),
              createLabel: '+ 새 포켓',
            );
          },
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    // 회차 1 (2026-05-10) 회차 2 — 이슈 Y: ±1일 버튼.
    // 1차 구현 (Row[IconButton, Expanded(InkWell), IconButton]) 는 TabBarView
    // swipe 중 지출 탭이 blank 되는 회귀를 유발 — InkWell+InputDecorator 가
    // Expanded 안에서 트랜지션 중 layout 이상 가능성. 본 fix 는 InkWell +
    // InputDecorator 의 원본 구조를 그대로 두고 ±1일 버튼을 **별도 sibling**
    // Row 로 분리하여 결합 제거.
    final firstDate = DateTime(2020);
    final lastDate = DateTime(2030, 12, 31);
    final canDec = _selectedDate.isAfter(firstDate);
    final canInc = _selectedDate.isBefore(lastDate);
    void shiftDays(int days) {
      final next = _selectedDate.add(Duration(days: days));
      if (next.isBefore(firstDate) || next.isAfter(lastDate)) return;
      setState(() => _selectedDate = next);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () async {
            final picked = await showCalendarPickerDialog(
              context: context,
              initialDate: _selectedDate,
              firstDate: firstDate,
              lastDate: lastDate,
            );
            if (picked != null) {
              setState(() => _selectedDate = picked);
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: '날짜',
              suffixIcon: Icon(Icons.calendar_today),
            ),
            child: Text(formattedDate),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canDec ? () => shiftDays(-1) : null,
                icon: const Icon(Icons.remove, size: 16),
                label: const Text('1일 전'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canInc ? () => shiftDays(1) : null,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('1일 후'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showEditPaymentMethodSheet(BuildContext context, PaymentMethod pm) {
    final bloc = context.read<PaymentMethodBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider<PaymentMethodBloc>.value(
        value: bloc,
        child: PaymentMethodFormSheet(
          paymentMethod: pm,
          onSubmit: (name, type, settlementDay, closingDay, linkedBankId) {
            bloc.add(UpdatePaymentMethod(
              id: pm.id,
              name: name,
              settlementDay: settlementDay,
              closingDay: closingDay,
              linkedBankId: linkedBankId,
              clearLinkedBank: linkedBankId == null && pm.linkedBankId != null,
            ));
          },
        ),
      ),
    );
  }

  Future<void> _showCreatePaymentMethodSheet(BuildContext context) async {
    final bloc = context.read<PaymentMethodBloc>();
    final oldIds = (bloc.state is PaymentMethodLoaded)
        ? (bloc.state as PaymentMethodLoaded)
            .paymentMethods
            .map((pm) => pm.id)
            .toSet()
        : <String>{};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider<PaymentMethodBloc>.value(
        value: bloc,
        child: PaymentMethodFormSheet(
          onSubmit: (name, type, settlementDay, closingDay, linkedBankId) {
            bloc.add(CreatePaymentMethod(
              name: name,
              type: type,
              settlementDay: settlementDay,
              closingDay: closingDay,
              linkedBankId: linkedBankId,
            ));
          },
        ),
      ),
    );

    if (!mounted) return;
    await _autoSelectNewItem<PaymentMethodBloc, PaymentMethodState>(
      bloc: bloc,
      getIds: (s) => s is PaymentMethodLoaded
          ? s.paymentMethods.map((pm) => pm.id).toSet()
          : <String>{},
      oldIds: oldIds,
      onSelect: (newId) => setState(() {
        _selectedPaymentMethodId = newId;
      }),
    );
  }

  Future<void> _showCreatePocketSheet(BuildContext context) async {
    final bloc = context.read<PocketBloc>();
    final oldIds = (bloc.state is PocketLoaded)
        ? (bloc.state as PocketLoaded).pockets.map((p) => p.id).toSet()
        : <String>{};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PocketFormSheet(
        onSubmit: (name, type, allocatedAmount, icon, color, goalAmount,
            targetDate) {
          bloc.add(CreatePocket(
            name: name,
            type: type,
            allocatedAmount: allocatedAmount,
            icon: icon,
            color: color,
            goalAmount: goalAmount,
            targetDate: targetDate,
          ));
        },
      ),
    );

    if (!mounted) return;
    await _autoSelectNewItem<PocketBloc, PocketState>(
      bloc: bloc,
      getIds: (s) => s is PocketLoaded
          ? s.pockets.map((p) => p.id).toSet()
          : <String>{},
      oldIds: oldIds,
      onSelect: (newId) => setState(() {
        _selectedPocketId = newId;
      }),
    );
  }

  Future<void> _autoSelectNewItem<B extends BlocBase<S>, S>({
    required B bloc,
    required Set<String> Function(S state) getIds,
    required Set<String> oldIds,
    required void Function(String newId) onSelect,
  }) async {
    // Check if already updated
    final currentIds = getIds(bloc.state);
    final diff = currentIds.difference(oldIds);
    if (diff.isNotEmpty) {
      onSelect(diff.first);
      return;
    }

    // Wait for next state with new item
    try {
      await for (final state in bloc.stream.timeout(const Duration(seconds: 10))) {
        final newIds = getIds(state);
        final newDiff = newIds.difference(oldIds);
        if (newDiff.isNotEmpty) {
          if (mounted) onSelect(newDiff.first);
          return;
        }
      }
    } catch (_) {
      // Timeout -- user can manually select
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      title: '거래 삭제',
    );
    if (confirmed && context.mounted) {
      context.read<TransactionBloc>().add(
            DeleteTransaction(widget.transactionId!),
          );
    }
  }

  void _resetFormForContinue() {
    setState(() {
      _amountController.clear();
      _amountHint = '';
      _descriptionController.clear();
      _memoController.clear();
      _needsReview = false;
      _suggestions = [];
      _aiResult = null;
      _aiLoading = false;
      _isSubmitting = false;
      _continueMode = false;
      _categoryError = null;
      _paymentMethodError = null;

      if (!_keepSameItems) {
        _selectedCategoryId = null;
        _selectedCategoryDisplayName = null;
        _selectedPaymentMethodId = null;
        _selectedPocketId = null;
        _loadDefaultPaymentMethod();
      }
      // _selectedDate and _selectedType are always kept
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('저장 완료! 다음 항목을 입력하세요.'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _onSubmit() {
    // Validate custom pickers (not part of Form)
    // ADJUSTMENT (sentinel 카테고리 포함) 는 카테고리 필수 검증 skip.
    // (회차 3 — special_type_picker_branch 정책 + 회차 4 sentinel 포함)
    bool hasPickerError = false;
    if (!_isAdjustmentSelected && _selectedCategoryId == null) {
      setState(() => _categoryError = '카테고리를 선택하세요');
      hasPickerError = true;
    } else {
      setState(() => _categoryError = null);
    }
    if (_selectedPaymentMethodId == null) {
      setState(() => _paymentMethodError = '결제수단을 선택하세요');
      hasPickerError = true;
    } else {
      setState(() => _paymentMethodError = null);
    }

    final activeFormKey = _tabController.index == 1 ? _incomeFormKey : _expenseFormKey;
    if (hasPickerError || !(activeFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);
    // 회차 5 — 응답 지연 시 spinner 무한 방지. 15초 후 자동 해제 + 안내.
    _submitTimeoutTimer?.cancel();
    _submitTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || !_isSubmitting) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.'),
          duration: Duration(seconds: 3),
        ),
      );
    });
    final rawAmount = CurrencyFormatter.parse(_amountController.text.trim())!;
    final description = _descriptionController.text.trim();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final memo =
        _memoController.text.trim().isEmpty ? null : _memoController.text.trim();
    final bloc = context.read<TransactionBloc>();

    // 회차 4 — sentinel/ADJUSTMENT 처리: type/categoryId/amount 변환.
    final submission = AdjustmentSubmission.resolve(
      selectedType: _selectedType,
      selectedCategoryId: _selectedCategoryId,
      rawAmount: rawAmount,
      isIncrease: _adjustmentIsIncrease,
    );
    final amount = submission.amount;
    final resolvedCategoryId = submission.categoryId;

    // 역변환 모드 — 새 거래를 만드는 게 아니라 **원본 이체를 거래로 옮긴다**(서버가
    // 삭제+생성을 한 트랜잭션으로 처리). 여기서 CreateTransaction 을 쓰면 이체와 거래가
    // 둘 다 남아 금액이 이중 계상된다 (정방향 _submitTransfer 의 거울상 분기).
    if (_isConvertingFromTransfer) {
      _convertToTransaction(
        amount: amount,
        description: description,
        memo: memo,
        dateStr: dateStr,
        categoryId: resolvedCategoryId,
      );
      return;
    }

    if (isEditing) {
      bloc.add(UpdateTransaction(
        id: widget.transactionId!,
        // 유형 변경 (수입↔지출). 바뀐 경우에만 보낸다. 서버가 카테고리 정합성·정산
        // 기록 여부를 검증한다.
        type: _editTargetType != _originalType ? _editTargetType : null,
        amount: amount,
        description: description,
        categoryId: resolvedCategoryId,
        transactionDate: dateStr,
        memo: memo,
        clearMemo: memo == null,
        paymentMethodId: _selectedPaymentMethodId,
        pocketId: _selectedPocketId,
        needsReview: _needsReview,
      ));
    } else {
      bloc.add(CreateTransaction(
        type: submission.type,
        amount: amount,
        description: description,
        categoryId: resolvedCategoryId,
        transactionDate: dateStr,
        memo: memo,
        paymentMethodId: _selectedPaymentMethodId,
        pocketId: _selectedPocketId,
        needsReview: _needsReview,
      ));
    }
  }
}
