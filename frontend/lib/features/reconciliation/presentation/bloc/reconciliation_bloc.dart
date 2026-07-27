import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:budget_book/features/reconciliation/domain/entities/reconciliation.dart';
import 'package:budget_book/features/reconciliation/domain/repositories/reconciliation_repository.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transfer/domain/repositories/transfer_repository.dart';
import 'reconciliation_event.dart';
import 'reconciliation_state.dart';

/// 정산 스냅샷 BLoC.
///
/// 규칙
/// - 목록과 요약은 **한 핸들러에서 함께** 로드한다 (원자적 로딩 — 두 값이 다른 달을 가리키는
///   중간 상태를 만들지 않는다).
/// - 소계는 BE 값을 그대로 표시한다. FE 에서 항목을 다시 더하지 않는다.
/// - mutation 성공 후에는 목록+요약을 재로드해 미기록 건수까지 함께 갱신한다.
class ReconciliationBloc extends Bloc<ReconciliationEvent, ReconciliationState> {
  final ReconciliationRepository repository;

  /// 미기록 목록을 **서버 필터(`reconciled=false`)로 직접** 가져오기 위한 의존성.
  /// 화면에 이미 로드된 페이지를 클라이언트에서 걸러 쓰면, 200건 넘는 달에서 미로드
  /// 페이지의 미기록 항목이 목록에 안 나타난다(건수만 맞고 행은 빠짐).
  final TransactionRepository transactionRepository;
  final TransferRepository transferRepository;

  ReconciliationBloc({
    required this.repository,
    required this.transactionRepository,
    required this.transferRepository,
  }) : super(const ReconciliationInitial()) {
    on<LoadReconciliations>(_onLoad);
    on<CreateReconciliation>(_onCreate);
    on<RenameReconciliation>(_onRename);
    on<RemoveReconciliationItems>(_onRemoveItems);
    on<DeleteReconciliation>(_onDelete);
    on<LoadReconciliationDetail>(_onLoadDetail);
  }

  /// 미기록 목록 페이지 크기. 거래 목록(`TransactionBloc._pageSize`)·BE 상한과 동일.
  static const int _unrecordedPageSize = 200;

  int _currentYear = DateTime.now().year;
  int _currentMonth = DateTime.now().month;

  int get currentYear => _currentYear;
  int get currentMonth => _currentMonth;

  Future<void> _onLoad(
    LoadReconciliations event,
    Emitter<ReconciliationState> emit,
  ) async {
    _currentYear = event.year;
    _currentMonth = event.month;

    if (state is! ReconciliationLoaded) {
      emit(const ReconciliationLoading());
    }

    // 스냅샷 + 요약 + 미기록(거래/이체) 을 한 번에 요청한다.
    // 별도 이벤트로 쪼개면 "요약은 8월, 목록은 7월" 같은 중간 상태가 생긴다.
    final results = await Future.wait([
      repository.getReconciliations(year: event.year, month: event.month),
      repository.getSummary(year: event.year, month: event.month),
      transactionRepository.getTransactions(
        year: event.year,
        month: event.month,
        // 서버가 미기록만 골라준다 (클라 게이팅 금지).
        filter: const TransactionFilter(reconciled: false),
        size: _unrecordedPageSize,
      ),
      transferRepository.getTransfers(
        year: event.year,
        month: event.month,
        reconciled: false,
      ),
    ]);

    String? error;
    List<Reconciliation>? snapshots;
    ReconciliationSummary? summary;
    List<Transaction>? unrecordedTransactions;
    List<Transfer>? unrecordedTransfers;
    var hasMoreUnrecorded = false;

    results[0].fold(
      (f) => error = (f as dynamic).message as String,
      (data) => snapshots = (data as List).cast<Reconciliation>(),
    );
    results[1].fold(
      (f) => error ??= (f as dynamic).message as String,
      (data) => summary = data as ReconciliationSummary,
    );
    results[2].fold(
      (f) => error ??= (f as dynamic).message as String,
      (page) {
        unrecordedTransactions =
            ((page as dynamic).content as List).cast<Transaction>();
        hasMoreUnrecorded = !((page as dynamic).last as bool);
      },
    );
    results[3].fold(
      (f) => error ??= (f as dynamic).message as String,
      (data) => unrecordedTransfers = (data as List).cast<Transfer>(),
    );

    if (snapshots == null ||
        summary == null ||
        unrecordedTransactions == null ||
        unrecordedTransfers == null) {
      emit(ReconciliationError(error ?? '정산 정보를 불러오지 못했습니다'));
      return;
    }

    emit(ReconciliationLoaded(
      year: event.year,
      month: event.month,
      snapshots: snapshots!,
      summary: summary!,
      unrecordedTransactions: unrecordedTransactions!,
      unrecordedTransfers: unrecordedTransfers!,
      hasMoreUnrecorded: hasMoreUnrecorded,
      // 달이 바뀌면 항목 캐시는 버린다 (다른 달의 항목이 남아 보이는 drift 방지).
      itemsBySnapshot: const {},
    ));
  }

  Future<void> _onCreate(
    CreateReconciliation event,
    Emitter<ReconciliationState> emit,
  ) async {
    final current = state;
    if (current is! ReconciliationLoaded || current.isMutating) return;
    emit(current.copyWith(isMutating: true, clearMessages: true));

    final result = await repository.createReconciliation(
      yearMonth: event.yearMonth,
      label: event.label,
      transactionIds: event.transactionIds,
      transferIds: event.transferIds,
    );

    await result.fold(
      (failure) async {
        emit(current.copyWith(isMutating: false, operationError: failure.message));
      },
      (detail) async {
        emit(current.copyWith(
          isMutating: false,
          operationSuccess: '${detail.header.displayName} 정산이 완료되었습니다',
        ));
        add(LoadReconciliations(year: _currentYear, month: _currentMonth));
      },
    );
  }

  Future<void> _onRename(
    RenameReconciliation event,
    Emitter<ReconciliationState> emit,
  ) async {
    final current = state;
    if (current is! ReconciliationLoaded || current.isMutating) return;
    emit(current.copyWith(isMutating: true, clearMessages: true));

    final result =
        await repository.updateReconciliation(id: event.id, label: event.label);

    await result.fold(
      (failure) async =>
          emit(current.copyWith(isMutating: false, operationError: failure.message)),
      (_) async {
        emit(current.copyWith(isMutating: false, operationSuccess: '라벨이 변경되었습니다'));
        add(LoadReconciliations(year: _currentYear, month: _currentMonth));
      },
    );
  }

  Future<void> _onRemoveItems(
    RemoveReconciliationItems event,
    Emitter<ReconciliationState> emit,
  ) async {
    final current = state;
    if (current is! ReconciliationLoaded || current.isMutating) return;
    emit(current.copyWith(isMutating: true, clearMessages: true));

    final result = await repository.updateReconciliation(
      id: event.id,
      removeItemIds: event.itemIds,
    );

    await result.fold(
      (failure) async =>
          emit(current.copyWith(isMutating: false, operationError: failure.message)),
      (_) async {
        emit(current.copyWith(
          isMutating: false,
          operationSuccess: '${event.itemIds.length}건이 미기록으로 되돌아갔습니다',
        ));
        add(LoadReconciliations(year: _currentYear, month: _currentMonth));
      },
    );
  }

  Future<void> _onDelete(
    DeleteReconciliation event,
    Emitter<ReconciliationState> emit,
  ) async {
    final current = state;
    if (current is! ReconciliationLoaded || current.isMutating) return;
    emit(current.copyWith(isMutating: true, clearMessages: true));

    final result = await repository.deleteReconciliation(event.id);

    await result.fold(
      (failure) async =>
          emit(current.copyWith(isMutating: false, operationError: failure.message)),
      (_) async {
        emit(current.copyWith(
          isMutating: false,
          operationSuccess: '정산이 취소되었습니다 (항목은 미기록으로 복귀)',
        ));
        add(LoadReconciliations(year: _currentYear, month: _currentMonth));
      },
    );
  }

  Future<void> _onLoadDetail(
    LoadReconciliationDetail event,
    Emitter<ReconciliationState> emit,
  ) async {
    final current = state;
    if (current is! ReconciliationLoaded) return;
    // 이미 로드된 스냅샷은 재요청하지 않는다 (펼침/접힘 반복 시 네트워크 낭비 방지).
    if (current.itemsBySnapshot.containsKey(event.id)) return;

    final result = await repository.getReconciliation(event.id);
    result.fold(
      (failure) => emit(current.copyWith(operationError: failure.message)),
      (detail) => emit(current.copyWith(
        itemsBySnapshot: {
          ...current.itemsBySnapshot,
          event.id: detail.items,
        },
      )),
    );
  }
}
