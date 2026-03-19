import 'package:equatable/equatable.dart';

class Category extends Equatable {
  final String id;
  final String name;
  final String type;
  final String? icon;
  final String? color;
  final bool isDefault;
  final int displayOrder;
  final String? groupId;
  final String visibility;
  final String? ownerId;
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    required this.isDefault,
    required this.displayOrder,
    this.groupId,
    this.visibility = 'SHARED',
    this.ownerId,
    required this.createdAt,
  });

  bool get isIncome => type == 'INCOME';
  bool get isExpense => type == 'EXPENSE';
  bool get isPrivate => visibility == 'PRIVATE';
  bool get isShared => visibility == 'SHARED';

  @override
  List<Object?> get props =>
      [id, name, type, icon, color, isDefault, displayOrder, groupId, visibility, ownerId, createdAt];
}
