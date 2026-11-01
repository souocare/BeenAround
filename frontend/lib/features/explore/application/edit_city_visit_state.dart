import '../../geography/domain/country_visit_date_expansion.dart';
import 'pending_city_visit_update.dart';

enum EditCityVisitPhase {
  idle,
  submitting,
  expansionRequired,
  success,
  failure,
}

class EditCityVisitState {
  const EditCityVisitState({
    this.phase = EditCityVisitPhase.idle,
    this.errorMessage,
    this.pendingUpdate,
  });

  final EditCityVisitPhase phase;
  final String? errorMessage;

  /// Original PATCH request awaiting explicit expansion confirmation.
  final PendingCityVisitUpdate? pendingUpdate;

  CountryVisitDateExpansion? get pendingExpansion => pendingUpdate?.expansion;

  bool get isSubmitting => phase == EditCityVisitPhase.submitting;
}
