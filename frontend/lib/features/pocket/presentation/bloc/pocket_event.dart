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

  const CreatePocket({
    required this.name,
    required this.type,
    required this.allocatedAmount,
    this.icon,
    this.color,
  });

  @override
  List<Object?> get props => [name, type, allocatedAmount, icon, color];
}

class UpdatePocket extends PocketEvent {
  final String id;
  final String? name;
  final String? type;
  final int? allocatedAmount;
  final String? icon;
  final String? color;
  final int? displayOrder;

  const UpdatePocket({
    required this.id,
    this.name,
    this.type,
    this.allocatedAmount,
    this.icon,
    this.color,
    this.displayOrder,
  });

  @override
  List<Object?> get props =>
      [id, name, type, allocatedAmount, icon, color, displayOrder];
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
