import 'package:equatable/equatable.dart';
import 'money_pocket.dart';

class PocketSummary extends Equatable {
  final MoneyPocket pocket;
  final int totalIncome;
  final int totalExpense;
  final int totalTransferIn;
  final int totalTransferOut;
  final int balance;

  const PocketSummary({
    required this.pocket,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalTransferIn,
    required this.totalTransferOut,
    required this.balance,
  });

  @override
  List<Object?> get props => [
        pocket,
        totalIncome,
        totalExpense,
        totalTransferIn,
        totalTransferOut,
        balance,
      ];
}
