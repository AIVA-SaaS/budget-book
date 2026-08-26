import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/ledger_date_header.dart';
import 'package:budget_book/core/widgets/reconciled_badge.dart';
import 'package:budget_book/features/reconciliation/domain/entities/reconciliation.dart';
import 'package:budget_book/features/reconciliation/presentation/bloc/reconciliation_bloc.dart';
import 'package:budget_book/features/reconciliation/presentation/bloc/reconciliation_event.dart';
import 'package:budget_book/features/reconciliation/presentation/bloc/reconciliation_state.dart';
import 'package:budget_book/features/transaction/domain/entities/ledger_item.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transaction_list_tile.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transfer_list_tile.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_bloc.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_event.dart';
import '../../../../core/theme/bb_scale.dart';

/// 정산 뷰 — 상단 "미기록", 하단 "스냅샷별 기록".
///
/// 거래 목록의 3번째 뷰 모드로 쓰인다. 기존 리스트/달력 모드는 손대지 않는다
/// (리스트 모드에는 날짜 역순 누적에 의존하는 러닝 밸런스가 있어, 섹션을 재정렬하면
/// 잔액 숫자가 틀어진다 — 기획서 §2.5).
///
/// 표시 원칙
/// - 미기록 목록은 **서버 필터(`reconciled=false`)** 결과를 쓴다. 화면에 로드된 페이지를
///   클라이언트에서 걸러 쓰면 200건 넘는 달에서 미로드 페이지 항목이 목록에서 빠진다
///   (요약 건수는 맞는데 행이 없는 상태).
/// - 소계는 BE 가 게이팅 후 계산한 값을 그대로 표시한다 (FE 재합산 금지).
class ReconciliationView extends StatefulWidget {
  final int year;
  final int month;

  const ReconciliationView({
    super.key,
    required this.year,
    required this.month,
  });

  @override
  State<ReconciliationView> createState() => _ReconciliationViewState();
}

class _ReconciliationViewState extends State<ReconciliationView> {
  /// 선택된 미기록 항목. 거래/이체를 분리해 담는다 (BE 요청 필드가 분리돼 있다).
  final Set<String> _selectedTransactionIds = {};
  final Set<String> _selectedTransferIds = {};

  @override
  void initState() {
    super.initState();
    context
        .read<ReconciliationBloc>()
        .add(LoadReconciliations(year: widget.year, month: widget.month));
  }

  @override
  void didUpdateWidget(covariant ReconciliationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 월 이동 시 재로드 + 선택 초기화 (다른 달 항목이 선택에 남는 drift 방지).
    if (oldWidget.year != widget.year || oldWidget.month != widget.month) {
      _clearSelection();
      context
          .read<ReconciliationBloc>()
          .add(LoadReconciliations(year: widget.year, month: widget.month));
    }
  }

  void _clearSelection() {
    _selectedTransactionIds.clear();
    _selectedTransferIds.clear();
  }

  int get _selectedCount =>
      _selectedTransactionIds.length + _selectedTransferIds.length;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReconciliationBloc, ReconciliationState>(
      listener: (context, state) {
        if (state is ReconciliationLoaded) {
          if (state.operationError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state.operationSuccess != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.operationSuccess!)));
            setState(_clearSelection);
            // **본인이 만든 변경은 WebSocket 이벤트가 self-authored 로 skip 된다** →
            // 거래/이체 목록의 정산 배지가 갱신되지 않는다. 로컬에서 직접 재조회한다.
            _refreshLedgerAfterMutation(context);
          }
        }
      },
      builder: (context, state) {
        if (state is ReconciliationLoading || state is ReconciliationInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ReconciliationError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message, textAlign: TextAlign.center),
                  context.bbSpace.gapV(BbSpaceToken.xl),
                  TextButton(
                    onPressed: () => context.read<ReconciliationBloc>().add(
                        LoadReconciliations(
                            year: widget.year, month: widget.month)),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          );
        }

        final loaded = state as ReconciliationLoaded;
        return Column(
          children: [
            Expanded(child: _buildBody(context, loaded)),
            _buildActionBar(context, loaded),
          ],
        );
      },
    );
  }

  /// 정산 변경 후 거래/이체 목록을 재조회한다.
  ///
  /// SyncEventHandler 는 authorId == 본인 이벤트를 skip 하므로(중복 갱신 방지),
  /// 본인 변경은 이렇게 로컬에서 cross-bloc 갱신을 해줘야 배지/미기록 분리가 즉시 반영된다.
  /// 필터는 `fromFilter` 로 통째로 전달해 드롭을 원천 차단한다.
  void _refreshLedgerAfterMutation(BuildContext context) {
    final txnBloc = context.read<TransactionBloc>();
    txnBloc.add(LoadTransactions.fromFilter(
      widget.year,
      widget.month,
      txnBloc.currentFilter,
    ));
    context
        .read<TransferBloc>()
        .add(LoadTransfers(year: widget.year, month: widget.month));
  }

  Widget _buildBody(BuildContext context, ReconciliationLoaded state) {
    final unrecordedTx = state.unrecordedTransactions;
    final unrecordedTf = state.unrecordedTransfers;
    final items = <LedgerItem>[
      ...unrecordedTx.map(LedgerItem.fromTransaction),
      ...unrecordedTf.map(LedgerItem.fromTransfer),
    ]..sort((a, b) => b.date.compareTo(a.date));

    // 날짜별 그룹 — 타일 자체에는 날짜가 없다(리스트 모드도 헤더로 보여준다).
    // 평면 리스트로 두면 "언제 거래인지 모르겠다" 가 된다.
    final groups = <String, List<LedgerItem>>{};
    for (final item in items) {
      groups.putIfAbsent(item.date, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        _UnrecordedHeader(summary: state.summary),
        if (state.summary.isFullyReconciled)
          const _FullyReconciledBanner()
        else if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('표시할 미기록 항목이 없습니다')),
          )
        else ...[
          _buildSelectAllRow(context, items),
          for (final entry in groups.entries) ...[
            _buildDateGroupHeader(context, entry.key, entry.value),
            ...entry.value.map((item) => _buildSelectableRow(context, item)),
          ],
        ],
        if (state.hasMoreUnrecorded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              // 200건을 넘는 달: 첫 페이지만 보여주고 있음을 숨기지 않는다.
              '미기록 ${state.summary.unrecordedCount}건 중 ${items.length}건 표시 — '
              '정산을 진행하면 나머지가 이어서 표시됩니다',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ),
        const Divider(height: 24, thickness: 1),
        _SnapshotSectionHeader(count: state.snapshots.length),
        if (state.snapshots.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('이 달에는 아직 정산 기록이 없습니다')),
          )
        else
          ...state.snapshots.map((s) => _SnapshotTile(
                snapshot: s,
                items: state.itemsBySnapshot[s.id],
                onExpand: () => context
                    .read<ReconciliationBloc>()
                    .add(LoadReconciliationDetail(s.id)),
                onRename: () => _promptRename(context, s),
                onDelete: () => _confirmDelete(context, s),
                onRemoveItems: (itemIds) =>
                    _confirmRemoveItems(context, s, itemIds),
              )),
        const SizedBox(height: 88),  // ui-fixed: FAB(56) 회피 — 스크롤 꼬리 여백
      ],
    );
  }

  bool _isSelected(LedgerItem item) => item.isTransfer
      ? _selectedTransferIds.contains(item.transfer!.id)
      : _selectedTransactionIds.contains(item.transaction!.id);

  /// 목록 항목 여러 건의 선택을 한 번에 켜고 끈다 (전체 선택 / 날짜별 선택 공용).
  void _setSelection(Iterable<LedgerItem> items, bool selected) {
    setState(() {
      for (final item in items) {
        final target =
            item.isTransfer ? _selectedTransferIds : _selectedTransactionIds;
        final id = item.isTransfer ? item.transfer!.id : item.transaction!.id;
        if (selected) {
          target.add(id);
        } else {
          target.remove(id);
        }
      }
    });
  }

  /// 셋 중 하나: 전부 선택(true) / 일부(null, 삼상태) / 없음(false).
  bool? _tristateValue(List<LedgerItem> items) {
    final selected = items.where(_isSelected).length;
    if (selected == 0) return false;
    if (selected == items.length) return true;
    return null;
  }

  /// 목록 맨 위 "전체 선택" 행.
  ///
  /// 하단 액션 바에도 같은 기능이 있지만, 사용자가 바를 발견하지 못했다
  /// (2026-07-27 라이브 검증). 선택 대상 바로 위에 체크박스를 둬서 어포던스를 드러낸다.
  Widget _buildSelectAllRow(BuildContext context, List<LedgerItem> items) {
    final theme = Theme.of(context);
    final value = _tristateValue(items);
    return InkWell(
      onTap: () => _setSelection(items, value != true),
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 16),
        child: Row(
          children: [
            Checkbox(
              tristate: true,
              value: value,
              onChanged: (_) => _setSelection(items, value != true),
            ),
            Text(
              value == true ? '전체 선택 해제' : '전체 선택',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (_selectedCount > 0)
              Text(
                '$_selectedCount건 선택',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 날짜 구분 헤더 + 그 날짜만 토글하는 체크박스. 표기는 리스트 모드와 공용 위젯.
  Widget _buildDateGroupHeader(
      BuildContext context, String dateStr, List<LedgerItem> dayItems) {
    final value = _tristateValue(dayItems);
    return LedgerDateHeader(
      dateStr: dateStr,
      onTap: () => _setSelection(dayItems, value != true),
      leading: SizedBox(
        width: 40,
        child: Checkbox(
          tristate: true,
          value: value,
          onChanged: (_) => _setSelection(dayItems, value != true),
        ),
      ),
      trailing: [
        Text(
          '${dayItems.length}건',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
      ],
    );
  }

  Widget _buildSelectableRow(BuildContext context, LedgerItem item) {
    final isTransfer = item.isTransfer;
    final id = isTransfer ? item.transfer!.id : item.transaction!.id;
    final selected = isTransfer
        ? _selectedTransferIds.contains(id)
        : _selectedTransactionIds.contains(id);

    return Row(
      children: [
        Checkbox(
          value: selected,
          onChanged: (v) => setState(() {
            final target =
                isTransfer ? _selectedTransferIds : _selectedTransactionIds;
            if (v == true) {
              target.add(id);
            } else {
              target.remove(id);
            }
          }),
        ),
        Expanded(
          child: isTransfer
              ? TransferListTile(transfer: item.transfer!)
              : TransactionListTile(transaction: item.transaction!),
        ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context, ReconciliationLoaded state) {
    final unrecordedCount =
        state.unrecordedTransactions.length + state.unrecordedTransfers.length;
    final canSelectAll =
        unrecordedCount > 0 && _selectedCount < unrecordedCount;

    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            TextButton(
              onPressed: unrecordedCount == 0
                  ? null
                  : () => setState(() {
                        if (canSelectAll) {
                          // "전체 선택" 은 **표시된** 미기록 항목 전체 (서버가 준 첫 페이지).
                          _selectedTransactionIds
                            ..clear()
                            ..addAll(
                                state.unrecordedTransactions.map((t) => t.id));
                          _selectedTransferIds
                            ..clear()
                            ..addAll(
                                state.unrecordedTransfers.map((t) => t.id));
                        } else {
                          _clearSelection();
                        }
                      }),
              child: Text(canSelectAll ? '전체 선택' : '선택 해제'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _selectedCount == 0 || state.isMutating
                  ? null
                  : () => _promptCreate(context),
              icon: state.isMutating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle, size: 18),
              label: Text(
                _selectedCount == 0 ? '정산하기' : '선택 $_selectedCount건 정산하기',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptCreate(BuildContext context) async {
    final bloc = context.read<ReconciliationBloc>();
    final state = bloc.state;
    final nextSeq =
        state is ReconciliationLoaded ? state.snapshots.length + 1 : 1;
    final controller = TextEditingController(text: '$nextSeq차');

    // 선택 항목 중 "확인/입력 필요" 건수 — 정산 전에 경고한다.
    final needsReviewCount = (state is ReconciliationLoaded
            ? state.unrecordedTransactions
            : const <Transaction>[])
        .where((t) => _selectedTransactionIds.contains(t.id) && t.needsReview)
        .length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('정산 완료 처리'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('선택한 $_selectedCount건을 정산 스냅샷으로 기록합니다.'),
            if (needsReviewCount > 0) ...[
              context.bbSpace.gapV(BbSpaceToken.lg),
              Row(
                children: [
                  Icon(Icons.warning_amber,
                      size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '"확인/입력 필요" $needsReviewCount건이 포함됩니다',
                      style:
                          TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ],
            context.bbSpace.gapV(BbSpaceToken.xl),
            TextField(
              controller: controller,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: '라벨 (선택)',
                hintText: '예: 1차',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('정산 완료'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final ym = '${widget.year}-${widget.month.toString().padLeft(2, '0')}';
    bloc.add(CreateReconciliation(
      yearMonth: ym,
      label: controller.text.trim().isEmpty ? null : controller.text.trim(),
      transactionIds: _selectedTransactionIds.toList(),
      transferIds: _selectedTransferIds.toList(),
    ));
  }

  Future<void> _promptRename(
      BuildContext context, Reconciliation snapshot) async {
    final bloc = context.read<ReconciliationBloc>();
    final controller = TextEditingController(text: snapshot.label ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('라벨 수정'),
        content: TextField(
          controller: controller,
          maxLength: 100,
          decoration: const InputDecoration(isDense: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    bloc.add(
        RenameReconciliation(id: snapshot.id, label: controller.text.trim()));
  }

  /// 스냅샷 항목 일부만 정산 취소 (다중 선택). 남은 항목이 없으면 BE 가 스냅샷 자체를 지운다.
  Future<void> _confirmRemoveItems(BuildContext context,
      Reconciliation snapshot, List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    final bloc = context.read<ReconciliationBloc>();
    final all = itemIds.length >= snapshot.itemCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('선택 ${itemIds.length}건 정산 취소'),
        content: Text(
          all
              ? '${snapshot.displayName} 의 모든 항목이 빠집니다. 스냅샷도 함께 삭제되고 '
                  '항목들은 미기록으로 되돌아갑니다. 거래 자체는 삭제되지 않습니다.'
              : '선택한 ${itemIds.length}건이 미기록으로 되돌아갑니다. 거래 자체는 삭제되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('정산 취소'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // 다건이어도 **한 번의 요청** — 낱건 반복은 중간 실패 시 절반만 취소된 상태가 남는다.
    bloc.add(RemoveReconciliationItems(id: snapshot.id, itemIds: itemIds));
  }

  Future<void> _confirmDelete(
      BuildContext context, Reconciliation snapshot) async {
    final bloc = context.read<ReconciliationBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${snapshot.displayName} 정산 취소'),
        content: Text(
          '${snapshot.itemCount}건이 미기록으로 되돌아갑니다. 거래 자체는 삭제되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('정산 취소'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    bloc.add(DeleteReconciliation(snapshot.id));
  }
}

class _UnrecordedHeader extends StatelessWidget {
  final ReconciliationSummary summary;

  const _UnrecordedHeader({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        children: [
          Text(
            '미기록 ${summary.unrecordedCount}건',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              // BE 계산 소계를 그대로 표시 (FE 재합산 금지).
              [
                if (summary.unrecordedExpense > 0)
                  '지출 ${CurrencyFormatter.format(summary.unrecordedExpense)}',
                if (summary.unrecordedIncome > 0)
                  '수입 ${CurrencyFormatter.format(summary.unrecordedIncome)}',
                if (summary.unrecordedTransfer > 0)
                  '이체 ${CurrencyFormatter.format(summary.unrecordedTransfer)}',
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (summary.needsReviewCount > 0)
            Tooltip(
              message: '확인/입력 필요 ${summary.needsReviewCount}건',
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      size: 14, color: Colors.amber.shade800),
                  Text(
                    '${summary.needsReviewCount}',
                    style:
                        TextStyle(fontSize: 11, color: Colors.amber.shade900),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FullyReconciledBanner extends StatelessWidget {
  const _FullyReconciledBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Icon(Icons.verified, size: 36, color: Color(0xFF2E7D32)),
          context.bbSpace.gapV(BbSpaceToken.lg),
          Text(
            '이 달 정산 완료',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          context.bbSpace.gapV(BbSpaceToken.xs),
          Text(
            '미기록 항목이 없습니다',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotSectionHeader extends StatelessWidget {
  final int count;

  const _SnapshotSectionHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.history, size: 16),
          const SizedBox(width: 6),
          Text(
            '정산 기록 $count건',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// 스냅샷 1건. 펼치면 항목 목록 + 액션(라벨 수정 / 선택 정산 취소 / 전체 정산 취소).
///
/// 이전에는 `trailing` 을 `PopupMenuButton(⋮)` 으로 덮어써서 **펼침 chevron 이 사라졌다** →
/// 사용자가 스냅샷이 펼쳐진다는 것도, 그 안의 정산 취소도 발견하지 못했다
/// (2026-07-27 라이브 검증). chevron 을 되돌리고 액션은 펼친 본문에 드러낸다.
class _SnapshotTile extends StatefulWidget {
  final Reconciliation snapshot;
  final List<ReconciliationItem>? items;
  final VoidCallback onExpand;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final ValueChanged<List<String>> onRemoveItems;

  const _SnapshotTile({
    required this.snapshot,
    required this.items,
    required this.onExpand,
    required this.onRename,
    required this.onDelete,
    required this.onRemoveItems,
  });

  @override
  State<_SnapshotTile> createState() => _SnapshotTileState();
}

class _SnapshotTileState extends State<_SnapshotTile> {
  final Set<String> _selectedItemIds = {};

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final items = widget.items;
    final theme = Theme.of(context);
    final when =
        DateFormat('M/d HH:mm').format(snapshot.reconciledAt.toLocal());
    final subtitle = [
      when,
      snapshot.reconciledBy.nickname,
      '${snapshot.itemCount}건',
      if (snapshot.totalExpense > 0)
        '지출 ${CurrencyFormatter.format(snapshot.totalExpense)}',
      if (snapshot.totalIncome > 0)
        '수입 ${CurrencyFormatter.format(snapshot.totalIncome)}',
      if (snapshot.totalTransfer > 0)
        '이체 ${CurrencyFormatter.format(snapshot.totalTransfer)}',
    ].join(' · ');

    return ExpansionTile(
      // 접힌 상태에서 헤더만 보이고, 펼칠 때 항목을 지연 로드한다.
      // 접으면 선택도 비운다 (다른 스냅샷과 선택이 섞여 보이지 않게).
      onExpansionChanged: (expanded) {
        if (expanded) {
          widget.onExpand();
        } else if (_selectedItemIds.isNotEmpty) {
          setState(_selectedItemIds.clear);
        }
      },
      title: Row(
        children: [
          ReconciledBadge(
            seq: snapshot.seq,
            changed: snapshot.hasChangedItems,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              snapshot.displayName,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        maxLines: 2,
      ),
      children: [
        if (items == null)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else ...[
          ...items.map((item) => _SnapshotItemRow(
                item: item,
                selected: _selectedItemIds.contains(item.itemId),
                onSelectedChanged: (v) => setState(() {
                  if (v) {
                    _selectedItemIds.add(item.itemId);
                  } else {
                    _selectedItemIds.remove(item.itemId);
                  }
                }),
              )),
          _buildActions(context, items),
        ],
      ],
    );
  }

  Widget _buildActions(BuildContext context, List<ReconciliationItem> items) {
    final allSelected =
        items.isNotEmpty && _selectedItemIds.length == items.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => setState(() {
              if (allSelected) {
                _selectedItemIds.clear();
              } else {
                _selectedItemIds
                  ..clear()
                  ..addAll(items.map((i) => i.itemId));
              }
            }),
            icon: Icon(
              allSelected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 16,
            ),
            label: Text(allSelected ? '선택 해제' : '항목 전체 선택'),
          ),
          TextButton.icon(
            onPressed: widget.onRename,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('라벨 수정'),
          ),
          TextButton.icon(
            onPressed: _selectedItemIds.isEmpty
                ? null
                : () => widget.onRemoveItems(_selectedItemIds.toList()),
            icon: const Icon(Icons.remove_circle_outline, size: 16),
            label: Text('선택 ${_selectedItemIds.length}건 정산 취소'),
          ),
          TextButton.icon(
            onPressed: widget.onDelete,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            icon: const Icon(Icons.undo, size: 16),
            label: const Text('전체 정산 취소'),
          ),
        ],
      ),
    );
  }
}

class _SnapshotItemRow extends StatelessWidget {
  final ReconciliationItem item;
  final bool selected;
  final ValueChanged<bool> onSelectedChanged;

  const _SnapshotItemRow({
    required this.item,
    required this.selected,
    required this.onSelectedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deleted = item.originDeleted;
    final color = deleted
        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
        : theme.colorScheme.onSurface;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 8, right: 8),
      onTap: () => onSelectedChanged(!selected),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: selected,
            onChanged: (v) => onSelectedChanged(v == true),
          ),
          Icon(
            item.isTransfer ? Icons.swap_horiz : Icons.receipt_long,
            size: 16,
            color: color,
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.snapshotDescription ?? (item.isTransfer ? '이체' : '거래'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                decoration: deleted ? TextDecoration.lineThrough : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (deleted)
            Text(
              '삭제된 항목',
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            )
          else if (item.changedAfterReconcile)
            Tooltip(
              message:
                  '정산 당시 ${CurrencyFormatter.format(item.snapshotAmount)}원 → '
                  '현재 ${CurrencyFormatter.format(item.currentAmount ?? 0)}원',
              child: Icon(Icons.error_outline,
                  size: 14, color: Colors.orange.shade900),
            ),
        ],
      ),
      subtitle: Text(
        item.snapshotDate,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      trailing: Text(
        '${CurrencyFormatter.format(item.snapshotAmount)}원',
        style: theme.textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}
