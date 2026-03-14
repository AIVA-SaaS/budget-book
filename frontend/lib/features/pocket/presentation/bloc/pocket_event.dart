import 'package:equatable/equatable.dart';

sealed class PocketEvent extends Equatable {
  const PocketEvent();

  @override
  List<Object?> get props => [];
}

class LoadPockets extends PocketEvent {
  const LoadPockets();
}

class CreatePocket extends PocketEvent {
  final String name;
  final String type;
  final int allocatedAmount;
  final String? icon;
  final String? color;
  final int? goalAmount;
  final String? targetDate;

  const CreatePocket({
    required this.name,
    required this.type,
    required this.allocatedAmount,
    this.icon,
    this.color,
    this.goalAmount,
    this.targetDate,
  });

  @override
  List<Object?> get props =>
      [name, type, allocatedAmount, icon, color, goalAmount, targetDate];
}

class UpdatePocket extends PocketEvent {
  final String id;
  final String? name;
  final String? type;
  final int? allocatedAmount;
  final String? icon;
  final String? color;
  final int? displayOrder;
  final int? goalAmount;
  final String? targetDate;

  const UpdatePocket({
    required this.id,
    this.name,
    this.type,
    this.allocatedAmount,
    this.icon,
    this.color,
    this.displayOrder,
    this.goalAmount,
    this.targetDate,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        allocatedAmount,
        icon,
        color,
        displayOrder,
        goalAmount,
        targetDate,
      ];
}

class DeletePocket extends PocketEvent {
  final String id;

  const DeletePocket(this.id);

  @override
  List<Object?> get props => [id];
}

class DistributeIncome extends PocketEvent {
  final int totalAmount;
  final List<Map<String, dynamic>> distributions;

  const DistributeIncome({
    required this.totalAmount,
    required this.distributions,
  });

  @override
  List<Object?> get props => [totalAmount, distributions];
}

class LoadDistributionRatios extends PocketEvent {
  const LoadDistributionRatios();
}

class SaveDistributionRatios extends PocketEvent {
  final List<Map<String, dynamic>> ratios;

  const SaveDistributionRatios({required this.ratios});

  @override
  List<Object?> get props => [ratios];
}
