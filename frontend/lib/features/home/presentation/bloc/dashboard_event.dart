import 'package:equatable/equatable.dart';

sealed class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboard extends DashboardEvent {
  final int year;
  final int month;

  const LoadDashboard({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}
