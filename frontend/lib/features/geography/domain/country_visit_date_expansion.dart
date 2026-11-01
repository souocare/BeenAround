import '../../../core/models/visit_date_precision.dart';
import '../../../core/models/visit_date_serializer.dart';

/// Exact date state received from the backend.
///
/// Dates retain their declared precision. A month or year must never be
/// presented as though its stored date represented an exact day.
class CountryVisitDateState {
  const CountryVisitDateState({
    required this.startedOn,
    required this.startedOnPrecision,
    required this.endedOn,
    required this.endedOnPrecision,
  });

  final DateTime startedOn;
  final VisitDatePrecision startedOnPrecision;

  final DateTime endedOn;
  final VisitDatePrecision endedOnPrecision;

  factory CountryVisitDateState.fromJson(Map<String, dynamic> json) {
    return CountryVisitDateState(
      startedOn: DateTime.parse(json['started_on'] as String),
      startedOnPrecision: VisitDatePrecision.fromJson(
        json['started_on_precision'] as String,
      ),
      endedOn: DateTime.parse(json['ended_on'] as String),
      endedOnPrecision: VisitDatePrecision.fromJson(
        json['ended_on_precision'] as String,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'started_on': VisitDateSerializer.formatDate(startedOn),
      'started_on_precision': startedOnPrecision.toJson(),
      'ended_on': VisitDateSerializer.formatDate(endedOn),
      'ended_on_precision': endedOnPrecision.toJson(),
    };
  }
}

/// Backend-generated proposal to expand an existing country visit.
///
/// This is descriptive only. Constructing or receiving a proposal never
/// modifies a visit or authorizes persistence.
class CountryVisitDateExpansion {
  const CountryVisitDateExpansion({
    required this.countryVisitId,
    required this.current,
    required this.proposed,
  });

  final String countryVisitId;
  final CountryVisitDateState current;
  final CountryVisitDateState proposed;

  factory CountryVisitDateExpansion.fromJson(Map<String, dynamic> json) {
    return CountryVisitDateExpansion(
      countryVisitId: json['country_visit_id'] as String,
      current: CountryVisitDateState.fromJson(
        Map<String, dynamic>.from(json['current'] as Map),
      ),
      proposed: CountryVisitDateState.fromJson(
        Map<String, dynamic>.from(json['proposed'] as Map),
      ),
    );
  }

  /// Builds the confirmation payload expected by the backend.
  ///
  /// Only call this after the user explicitly approves the proposal.
  Map<String, dynamic> toConfirmationJson() {
    return {'expected': current.toJson(), 'proposed': proposed.toJson()};
  }
}

/// Raised only for a recognized HTTP 409 country visit expansion proposal.
class CountryVisitDateExpansionRequired implements Exception {
  const CountryVisitDateExpansionRequired(this.expansion);

  final CountryVisitDateExpansion expansion;

  @override
  String toString() {
    return 'Country visit date expansion requires confirmation.';
  }
}
