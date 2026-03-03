import 'package:equatable/equatable.dart';
import 'package:budget_book/features/couple/domain/entities/couple.dart';
import 'package:budget_book/features/couple/domain/entities/invitation.dart';

sealed class CoupleState extends Equatable {
  const CoupleState();

  @override
  List<Object?> get props => [];
}

class CoupleInitial extends CoupleState {
  const CoupleInitial();
}

class CoupleLoading extends CoupleState {
  const CoupleLoading();
}

class CoupleNotLinked extends CoupleState {
  const CoupleNotLinked();
}

class CoupleInvitationPending extends CoupleState {
  final Invitation invitation;

  const CoupleInvitationPending(this.invitation);

  @override
  List<Object?> get props => [invitation];
}

class CoupleLinked extends CoupleState {
  final Couple couple;

  const CoupleLinked(this.couple);

  @override
  List<Object?> get props => [couple];
}

class CoupleError extends CoupleState {
  final String message;

  const CoupleError(this.message);

  @override
  List<Object?> get props => [message];
}
