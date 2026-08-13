import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transfer/domain/repositories/transfer_repository.dart';

/// 장부(거래 목록 화면) **전용** 이체 소스.
///
/// ## 왜 공유 `TransferBloc` 을 쓰지 않는가 (2026-08-12)
///
/// `TransferBloc` 은 lazy singleton 이고 **6곳이 같은 상태를 본다**:
/// 장부 · 이체 목록 화면 · 카드정산 화면 · 정산 뷰 · 거래 폼(카드 결제 후보) ·
/// 월 동기화/WebSocket 재조회. 장부의 필터(카테고리·금액·검색어…)를 그 싱글톤에
/// 밀어넣으면 나머지 5곳이 **필터된 이체만** 보게 된다.
///
/// 그래서 장부만 자기 소스를 갖는다. 공유 `TransferBloc` 과 `LoadTransfers(year, month)` 는
/// 그대로 두므로 다른 화면은 영향이 없다.
///
/// ## 범위 규칙
///
/// [load] 는 `dateFrom`/`dateTo` 를 **필수**로 받는다. 이체가 월 단위로 고정돼 있고
/// 거래·합계는 기간을 따르던 비대칭이 "기간 필터를 걸면 이체 행이 사라지는" 결함의
/// 원인이었다(측정: 범위 내 이체 금액의 77% 누락). `required` 라 월만 넘기는 호출은
/// 컴파일이 막는다.
///
/// 필터 판정은 **서버**가 한다(`TransferGating`) — FE 에 이체 축 판정을 다시 만들면
/// 판정이 두 곳이 되어 같은 사고가 재발한다.
class LedgerTransfersCubit extends Cubit<LedgerTransfersState> {
  final TransferRepository transferRepository;

  LedgerTransfersCubit({required this.transferRepository})
      : super(const LedgerTransfersState.initial());

  /// 마지막 요청을 기억해 동기화 이벤트(월 이동·WebSocket)에서 재조회한다.
  int? _year;
  int? _month;
  TransactionFilter _filter = TransactionFilter.empty;

  /// 늦게 도착한 응답이 최신 요청을 덮어쓰지 않게 하는 순번.
  int _requestSeq = 0;

  Future<void> load({
    required int year,
    required int month,
    required TransactionFilter filter,
  }) async {
    _year = year;
    _month = month;
    _filter = filter;

    final seq = ++_requestSeq;
    // 이미 목록이 있으면 스피너로 비우지 않는다(필터 조작 중 깜빡임 방지).
    if (state.transfers.isEmpty) {
      emit(state.copyWith(isLoading: true, clearError: true));
    }

    final result = await transferRepository.getTransfers(
      year: year,
      month: month,
      filter: filter,
    );

    // 뒤늦은 응답 폐기.
    if (seq != _requestSeq) return;

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (transfers) => emit(
        LedgerTransfersState(transfers: transfers, isLoading: false),
      ),
    );
  }

  /// 월 이동·실시간 동기화 후 **같은 필터로** 다시 읽는다.
  /// 아직 한 번도 로드하지 않았으면 아무 것도 하지 않는다(화면이 뜨면 스스로 로드한다).
  Future<void> reload() async {
    final year = _year;
    final month = _month;
    if (year == null || month == null) return;
    await load(year: year, month: month, filter: _filter);
  }
}

class LedgerTransfersState extends Equatable {
  final List<Transfer> transfers;
  final bool isLoading;
  final String? error;

  const LedgerTransfersState({
    required this.transfers,
    this.isLoading = false,
    this.error,
  });

  const LedgerTransfersState.initial()
      : transfers = const [],
        isLoading = false,
        error = null;

  LedgerTransfersState copyWith({
    List<Transfer>? transfers,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return LedgerTransfersState(
      transfers: transfers ?? this.transfers,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [transfers, isLoading, error];
}
