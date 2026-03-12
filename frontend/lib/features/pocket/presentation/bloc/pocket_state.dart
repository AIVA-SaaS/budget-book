import 'package:equatable/equatable.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';

sealed class PocketState extends Equatable {
  const PocketState();

  @override
  List<Object?> get props => [];
}

class PocketInitial extends PocketState {
  const PocketInitial();
}

class PocketLoading extends PocketState {
  const PocketLoading();
}

class PocketLoaded extends PocketState {
  final List<MoneyPocket> pockets;
  final String? operationError;

  const PocketLoaded(this.pockets, {this.operationError});

  List<MoneyPocket> get activePockets =>
      pockets.where((p) => p.isActive).toList();

  int get totalBalance => pockets.fold(0, (sum, p) => sum + p.balance);

  int get totalAllocated =>
      pockets.fold(0, (sum, p) => sum + p.allocatedAmount);

  @override
  List<Object?> get props => [pockets, operationError];
}

class PocketError extends PocketState {
  final String message;

  const PocketError(this.message);

  @override
  List<Object?> get props => [message];
}
