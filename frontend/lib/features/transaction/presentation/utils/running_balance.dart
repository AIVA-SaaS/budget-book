// Running-balance / running-total computation for the transaction list.
//
// Two display modes (see transaction_list_page CHANGE 3):
//
// - MODE A (computeExpenseCumulative) — no single-asset filter (default).
//   Running value = cumulative EXPENSE only (negative). Anchored on the
//   month's total expense so it is pagination-safe: the newest expense row
//   shows -totalExpense, older rows show less accumulated expense. Income /
//   adjustment rows carry the current cumulative but do NOT change it;
//   transfers get no value at all.
//
// - MODE B (computeAssetBalance) — single non-credit asset filter.
//   Running value = that asset's balance right after each row. Anchored on the
//   asset's end-of-month balance (asOf = first day of next month) and
//   accumulated NEWEST-FIRST by subtracting each row's net effect. Shown on
//   both transaction and transfer rows.
//
// All inputs are expected in display order (newest-first) — the exact order
// the grouped list renders (sortedDates descending, transactions then
// transfers within a day).
import 'package:budget_book/features/transaction/domain/entities/ledger_item.dart';

/// Stable per-row key that never collides between a transaction and a transfer
/// even if they happen to share an id.
String ledgerRowKey(LedgerItem item) =>
    item.isTransfer ? 'tf:${item.transfer!.id}' : 'tx:${item.transaction!.id}';

/// MODE A — cumulative expense (negative). [anchorExpense] is the month's total
/// expense (server total preferred; caller may pass a local fallback sum).
/// Only transaction rows receive a value; transfers are skipped.
Map<String, int> computeExpenseCumulative(
  List<LedgerItem> orderedNewestFirst,
  int anchorExpense,
) {
  final map = <String, int>{};
  int running = anchorExpense;
  for (final item in orderedNewestFirst) {
    if (!item.isTransaction) continue; // transfers: no running total in MODE A
    final t = item.transaction!;
    map[ledgerRowKey(item)] = -running;
    if (t.isExpense) running -= t.amount;
  }
  return map;
}

/// Signed effect of a row on [pmId]'s balance.
/// - transaction: income +amount, expense -amount, adjustment +amount (signed),
///   else 0.
/// - transfer: destination is [pmId] → +amount, source is [pmId] → -amount,
///   else 0.
int netEffectOnAsset(LedgerItem item, String pmId) {
  if (item.isTransaction) {
    final t = item.transaction!;
    if (t.isIncome) return t.amount;
    if (t.isExpense) return -t.amount;
    if (t.isAdjustment) return t.amount; // ADJUSTMENT amount is a signed delta
    return 0;
  }
  final tr = item.transfer!;
  if (tr.destinationPaymentMethod.id == pmId) return tr.amount;
  if (tr.sourcePaymentMethod.id == pmId) return -tr.amount;
  return 0;
}

/// MODE B — asset balance backward-accumulation. [anchorBalance] is the asset's
/// balance at end of the viewed month (balance considering everything with
/// date < firstDayOfNextMonth). Every row (transaction AND transfer) receives
/// the balance right after it.
Map<String, int> computeAssetBalance(
  List<LedgerItem> orderedNewestFirst,
  int anchorBalance,
  String pmId,
) {
  final map = <String, int>{};
  int running = anchorBalance;
  for (final item in orderedNewestFirst) {
    map[ledgerRowKey(item)] = running;
    running -= netEffectOnAsset(item, pmId);
  }
  return map;
}
