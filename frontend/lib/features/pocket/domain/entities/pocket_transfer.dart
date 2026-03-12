import 'package:equatable/equatable.dart';

class PocketTransfer extends Equatable {
  final String id;
  final PocketRef fromPocket;
  final PocketRef toPocket;
  final int amount;
  final String? description;
  final String transferDate;
  final String authorId;

  const PocketTransfer({
    required this.id,
    required this.fromPocket,
    required this.toPocket,
    required this.amount,
    this.description,
    required this.transferDate,
    required this.authorId,
  });

  @override
  List<Object?> get props => [
        id,
        fromPocket,
        toPocket,
        amount,
        description,
        transferDate,
        authorId,
      ];
}

class PocketRef extends Equatable {
  final String id;
  final String name;

  const PocketRef({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}
