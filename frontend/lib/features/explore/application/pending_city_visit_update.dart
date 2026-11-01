import '../../geography/domain/country_visit_date_expansion.dart';

/// Original city visit update that produced an expansion proposal.
///
/// Stores an immutable snapshot of the submitted changes so a proposal
/// cannot be reused with a different request.
class PendingCityVisitUpdate {
  PendingCityVisitUpdate({
    required this.visitId,
    required Map<String, dynamic> changes,
    required this.expansion,
  }) : changes = Map<String, dynamic>.unmodifiable(changes);

  final String visitId;
  final Map<String, dynamic> changes;
  final CountryVisitDateExpansion expansion;

  bool matches({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    if (this.visitId != visitId) {
      return false;
    }

    if (this.changes.length != changes.length) {
      return false;
    }

    for (final entry in this.changes.entries) {
      if (!changes.containsKey(entry.key) ||
          changes[entry.key] != entry.value) {
        return false;
      }
    }

    return true;
  }
}
