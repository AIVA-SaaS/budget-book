import 'package:equatable/equatable.dart';
import 'package:budget_book/features/card_settlement/domain/entities/settlement_transaction.dart';

sealed class CardSettlementState extends Equatable {
  const CardSettlementState();

  @override
  List<Object?> get props => [];
}

class CardSettlementInitial extends CardSettlementState {
  const CardSettlementInitial();
}

class CardSettlementLoading extends CardSettlementState {
  const CardSettlementLoading();
}

class CardSettlementLoaded extends CardSettlementState {
  final List<SettlementTransaction> transactions;
  final Set<String> selectedIds;
  final int totalAmount;
  final int? customAmount;

  const CardSettlementLoaded({
    required this.transactions,
    required this.selectedIds,
    required this.totalAmount,
    this.customAmount,
  });

  int get selectedAmount => transactions
      .where((t) => selectedIds.contains(t.id))
      .fold(0, (sum, t) => sum + t.amount);

  int get effectiveAmount => customAmount ?? selectedAmount;

  bool get allSelected =>
      transactions.isNotEmpty && selectedIds.length == transactions.length;

  @override
  List<Object?> get props => [transactions, selectedIds, totalAmount, customAmount];
}

class CardSettlementSubmitting extends CardSettlementState {
  const CardSettlementSubmitting();
}

class CardSettlementSuccess extends CardSettlementState {
  const CardSettlementSuccess();
}

class CardSettlementError extends CardSettlementState {
  final String message;

  const CardSettlementError(this.message);

  @override
  List<Object?> get props => [message];
}
