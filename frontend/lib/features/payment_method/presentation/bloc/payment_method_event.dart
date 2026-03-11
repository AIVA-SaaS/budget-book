import 'package:equatable/equatable.dart';

sealed class PaymentMethodEvent extends Equatable {
  const PaymentMethodEvent();

  @override
  List<Object?> get props => [];
}

class LoadPaymentMethods extends PaymentMethodEvent {
  const LoadPaymentMethods();
}

class CreatePaymentMethod extends PaymentMethodEvent {
  final String name;
  final String type;
  final int? settlementDay;
  final int? closingDay;

  const CreatePaymentMethod({
    required this.name,
    required this.type,
    this.settlementDay,
    this.closingDay,
  });

  @override
  List<Object?> get props => [name, type, settlementDay, closingDay];
}

class UpdatePaymentMethod extends PaymentMethodEvent {
  final String id;
  final String? name;
  final int? settlementDay;
  final int? closingDay;
  final bool? isActive;
  final int? displayOrder;

  const UpdatePaymentMethod({
    required this.id,
    this.name,
    this.settlementDay,
    this.closingDay,
    this.isActive,
    this.displayOrder,
  });

  @override
  List<Object?> get props =>
      [id, name, settlementDay, closingDay, isActive, displayOrder];
}

class DeletePaymentMethod extends PaymentMethodEvent {
  final String id;

  const DeletePaymentMethod(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadCardPending extends PaymentMethodEvent {
  final int year;
  final int month;

  const LoadCardPending({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}
