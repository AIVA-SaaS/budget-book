import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

/// A unified display item that wraps either a [Transaction] or a [Transfer]
/// for the combined transaction list view.
class LedgerItem {
  final Transaction? transaction;
  final Transfer? transfer;

  LedgerItem.fromTransaction(Transaction t)
      : transaction = t,
        transfer = null;

  LedgerItem.fromTransfer(Transfer t)
      : transaction = null,
        transfer = t;

  String get date =>
      transaction?.transactionDate ?? transfer!.transferDate;

  bool get isTransfer => transfer != null;
  bool get isTransaction => transaction != null;
}
