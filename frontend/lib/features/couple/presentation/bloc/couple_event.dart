import 'package:equatable/equatable.dart';

sealed class CoupleEvent extends Equatable {
  const CoupleEvent();

  @override
  List<Object?> get props => [];
}

class LoadCouple extends CoupleEvent {
  const LoadCouple();
}

class GenerateInvitation extends CoupleEvent {
  const GenerateInvitation();
}

class AcceptInvitation extends CoupleEvent {
  final String code;

  const AcceptInvitation(this.code);

  @override
  List<Object?> get props => [code];
}

class CheckInvitationStatus extends CoupleEvent {
  const CheckInvitationStatus();
}

class DissolveCouple extends CoupleEvent {
  const DissolveCouple();
}
