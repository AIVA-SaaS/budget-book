import 'package:equatable/equatable.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';

sealed class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

/// 거래 목록 로드 이벤트.
///
/// **필터는 개별 필드가 아니라 [TransactionFilter] VO 하나로만 전달된다.**
///
/// 2026-04-15 "월 이동 후 필터 drop" 인시던트는 소비자들이 필터 필드를 손으로
/// 나열하다 한 개(`transactionTypes` → 이후 `needsReviewOnly`)를 빠뜨려 3회 재발했다.
/// `fromFilter` 팩토리만 추가했던 1차 대응은 **기본 생성자가 살아 있어서** 실효가 없었고
/// (2026-07-27 감사에서 sync_event_handler / main_shell_page / app_router 3곳이
/// `needsReviewOnly` 를 여전히 누락), 그래서 이번에는 생성자 자체를 봉인한다.
///
/// 공개 진입점은 2개뿐이다.
/// - [LoadTransactions.fromFilter] — 필터가 있는 모든 경로 (기본)
/// - [LoadTransactions.monthOnly] — 필터 없는 초기/리셋 로드임을 명시할 때만
///
/// 새 필터 추가 시 [TransactionFilter] 한 곳만 고치면 모든 경로가 자동 전파된다.
/// 개별 필드 getter 는 하위 호환용 위임이며, 새 코드는 `event.filter` 를 직접 쓴다.
class LoadTransactions extends TransactionEvent {
  final int year;
  final int month;

  /// 필터 전체 스냅샷. 절대 필드 단위로 분해해 재조립하지 않는다.
  final TransactionFilter filter;

  final String? scrollToDate;

  const LoadTransactions._({
    required this.year,
    required this.month,
    required this.filter,
    this.scrollToDate,
  });

  /// 필터 VO 전체를 드롭 없이 전파하는 단일 진입점.
  ///
  /// [clearDateRange] 는 월 이동 시 특정 월에 종속된 명시적 기간 필터를 해제한다
  /// (페이지 내비게이터와 동일 규칙).
  factory LoadTransactions.fromFilter(
    int year,
    int month,
    TransactionFilter f, {
    String? scrollToDate,
    bool clearDateRange = false,
  }) {
    return LoadTransactions._(
      year: year,
      month: month,
      filter: clearDateRange ? f.copyWith(clearDateRange: true) : f,
      scrollToDate: scrollToDate,
    );
  }

  /// 필터 없이 해당 월만 로드. "필터를 잃어버린 것"과 "의도적으로 필터가 없는 것"을
  /// 호출부에서 구분해 읽을 수 있도록 별도 팩토리로 둔다.
  factory LoadTransactions.monthOnly(
    int year,
    int month, {
    String? scrollToDate,
  }) {
    return LoadTransactions._(
      year: year,
      month: month,
      filter: TransactionFilter.empty,
      scrollToDate: scrollToDate,
    );
  }

  // ── 하위 호환 위임 getter (신규 코드는 `filter` 사용) ──
  String? get keyword => filter.keyword;
  String? get categoryId => filter.categoryId;
  Set<String> get categoryIds => filter.categoryIds;
  Set<String> get categoryGroupIds => filter.categoryGroupIds;
  String? get paymentMethodId => filter.paymentMethodId;
  Set<String> get paymentMethodIds => filter.paymentMethodIds;
  String? get pocketId => filter.pocketId;
  Set<String> get pocketIds => filter.pocketIds;
  int? get amountMin => filter.amountMin;
  int? get amountMax => filter.amountMax;
  String? get dateFrom => filter.dateFrom;
  String? get dateTo => filter.dateTo;
  String? get type => filter.type;
  Set<String> get transactionTypes => filter.transactionTypes;
  String? get visibility => filter.visibility;

  /// V61 (2026-05-06) — true 면 needs_review=true 거래만 (확인/입력 필요만 보기).
  bool? get needsReviewOnly => filter.needsReviewOnly;

  @override
  List<Object?> get props => [year, month, filter, scrollToDate];
}

class CreateTransaction extends TransactionEvent {
  final String type;
  final int amount;
  final String description;
  final String? categoryId;
  final String transactionDate;
  final String? memo;
  final String? paymentMethodId;
  final String? pocketId;
  /// V61 (2026-05-06) — 확인/입력 필요 플래그.
  final bool needsReview;

  const CreateTransaction({
    required this.type,
    required this.amount,
    required this.description,
    this.categoryId,
    required this.transactionDate,
    this.memo,
    this.paymentMethodId,
    this.pocketId,
    this.needsReview = false,
  });

  @override
  List<Object?> get props =>
      [type, amount, description, categoryId, transactionDate, memo, paymentMethodId, pocketId, needsReview];
}

class UpdateTransaction extends TransactionEvent {
  final String id;
  /// 수입↔지출 유형 변경 (2026-07-27). null = 미변경.
  /// 이체로 바꾸는 건 테이블이 달라 [ConvertTransactionToTransfer] 를 쓴다.
  final String? type;
  final int? amount;
  final String? description;
  final String? categoryId;
  final String? transactionDate;
  final String? memo;
  final bool clearMemo;
  final String? paymentMethodId;
  final String? pocketId;
  /// V61 (2026-05-06) — null 이면 미변경, true/false 면 토글.
  final bool? needsReview;

  const UpdateTransaction({
    required this.id,
    this.type,
    this.amount,
    this.description,
    this.categoryId,
    this.transactionDate,
    this.memo,
    this.clearMemo = false,
    this.paymentMethodId,
    this.pocketId,
    this.needsReview,
  });

  @override
  List<Object?> get props =>
      [id, type, amount, description, categoryId, transactionDate, memo, clearMemo, paymentMethodId, pocketId, needsReview];
}

class LoadMoreTransactions extends TransactionEvent {
  const LoadMoreTransactions();
}

class DeleteTransaction extends TransactionEvent {
  final String id;

  const DeleteTransaction(this.id);

  @override
  List<Object?> get props => [id];
}
