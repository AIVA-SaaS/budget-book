import 'package:equatable/equatable.dart';

class TransactionCategory extends Equatable {
  final String id;
  final String name;
  final String type;
  final String? icon;
  final String? color;
  final String? groupId;
  final String? groupName;

  const TransactionCategory({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.groupId,
    this.groupName,
  });

  /// Returns "groupName > name" if groupName exists, otherwise just name.
  String get displayName {
    if (groupName != null && groupName!.isNotEmpty) {
      return '$groupName > $name';
    }
    return name;
  }

  @override
  List<Object?> get props => [id, name, type, icon, color, groupId, groupName];
}
