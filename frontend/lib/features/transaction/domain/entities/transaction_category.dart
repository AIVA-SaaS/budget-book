import 'package:equatable/equatable.dart';

class TransactionCategory extends Equatable {
  final String id;
  final String name;
  final String type;
  final String? icon;
  final String? color;

  const TransactionCategory({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
  });

  @override
  List<Object?> get props => [id, name, type, icon, color];
}
