import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_state.dart';

/// Returns true when the current user has a real partner (not a self-couple).
/// Reads from the singleton CoupleBloc state — requires the couple to have
/// been loaded (via main shell preload).
bool isCoupleMode() {
  final state = getIt<CoupleBloc>().state;
  if (state is CoupleLinked) {
    return state.couple.isCouple;
  }
  return false;
}
