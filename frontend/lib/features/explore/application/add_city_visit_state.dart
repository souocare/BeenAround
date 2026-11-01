import '../../geography/domain/country_visit_date_expansion.dart';
import 'pending_city_visit_creation.dart';

enum AddCityVisitPhase { idle, submitting, expansionRequired, success, failure }

class AddCityVisitState {
  const AddCityVisitState({
    this.phase = AddCityVisitPhase.idle,
    this.errorMessage,
    this.pendingCreation,
  });

  final AddCityVisitPhase phase;
  final String? errorMessage;

  /// Original request and proposal awaiting explicit confirmation.
  final PendingCityVisitCreation? pendingCreation;

  CountryVisitDateExpansion? get pendingExpansion => pendingCreation?.expansion;

  bool get isSubmitting => phase == AddCityVisitPhase.submitting;
}
