import '../../../core/models/visit_date_precision.dart';

/// A destination and historical period represented in an overlap snapshot.
///
/// Dates are retained as canonical API strings so that an explicit
/// confirmation reproduces the exact state returned by the backend.
class ResidenceOverlapLocation {
  const ResidenceOverlapLocation({
    required this.countryCode,
    required this.cityId,
    required this.startedOn,
    required this.startedOnPrecision,
    required this.endedOn,
    required this.endedOnPrecision,
  });

  final String countryCode;
  final int? cityId;

  final String startedOn;
  final VisitDatePrecision startedOnPrecision;

  final String endedOn;
  final VisitDatePrecision endedOnPrecision;

  factory ResidenceOverlapLocation.fromJson(Map<String, dynamic> json) {
    final startedOn = json['started_on'] as String;
    final endedOn = json['ended_on'] as String;

    // Reject malformed date values before they reach the confirmation UI.
    DateTime.parse(startedOn);
    DateTime.parse(endedOn);

    return ResidenceOverlapLocation(
      countryCode: json['country_code'] as String,
      cityId: json['city_id'] as int?,
      startedOn: startedOn,
      startedOnPrecision: VisitDatePrecision.fromJson(
        json['started_on_precision'] as String,
      ),
      endedOn: endedOn,
      endedOnPrecision: VisitDatePrecision.fromJson(
        json['ended_on_precision'] as String,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'country_code': countryCode,
    'city_id': cityId,
    'started_on': startedOn,
    'started_on_precision': startedOnPrecision.toJson(),
    'ended_on': endedOn,
    'ended_on_precision': endedOnPrecision.toJson(),
  };
}

/// A residence that overlaps with the requested period.
class ResidenceOverlapEntry {
  const ResidenceOverlapEntry({
    required this.residenceId,
    required this.kind,
    required this.location,
  });

  final String residenceId;

  /// Backend classification, for example "certain" or "possible".
  ///
  /// Kept as a string until the UI needs a dedicated presentation enum.
  final String kind;

  final ResidenceOverlapLocation location;

  factory ResidenceOverlapEntry.fromJson(Map<String, dynamic> json) {
    final residenceId = json['residence_id'] as String;
    final kind = json['kind'] as String;

    if (residenceId.isEmpty || kind.isEmpty) {
      throw const FormatException('Invalid residence overlap entry.');
    }

    return ResidenceOverlapEntry(
      residenceId: residenceId,
      kind: kind,
      location: ResidenceOverlapLocation.fromJson(json),
    );
  }

  Map<String, dynamic> toJson() => {
    ...location.toJson(),
    'residence_id': residenceId,
    'kind': kind,
  };
}

/// Original state of the residence being edited.
///
/// Null for creation requests.
class ResidenceOverlapTarget {
  const ResidenceOverlapTarget({
    required this.residenceId,
    required this.location,
  });

  final String residenceId;
  final ResidenceOverlapLocation location;

  factory ResidenceOverlapTarget.fromJson(Map<String, dynamic> json) {
    final residenceId = json['residence_id'] as String;

    if (residenceId.isEmpty) {
      throw const FormatException('Invalid residence overlap target.');
    }

    return ResidenceOverlapTarget(
      residenceId: residenceId,
      location: ResidenceOverlapLocation.fromJson(json),
    );
  }

  Map<String, dynamic> toJson() => {
    ...location.toJson(),
    'residence_id': residenceId,
  };
}

/// Exact overlap proposal received from the backend.
///
/// The user must explicitly approve this proposal before it can be
/// included in a subsequent POST or PATCH request.
class ResidenceOverlapProposal {
  ResidenceOverlapProposal({
    required this.message,
    required this.requested,
    required List<ResidenceOverlapEntry> overlaps,
    required this.expectedTarget,
  }) : overlaps = List.unmodifiable(overlaps);

  final String message;

  final ResidenceOverlapLocation requested;
  final List<ResidenceOverlapEntry> overlaps;
  final ResidenceOverlapTarget? expectedTarget;

  bool get isCreate => expectedTarget == null;
  bool get isUpdate => expectedTarget != null;

  factory ResidenceOverlapProposal.fromJson(Map<String, dynamic> detail) {
    if (detail['code'] != 'RESIDENCE_PERIOD_OVERLAP') {
      throw const FormatException('Invalid residence overlap error code.');
    }

    final requested = detail['requested'];
    final rawOverlaps = detail['overlaps'];
    final rawTarget = detail['expected_target'];

    if (requested is! Map || rawOverlaps is! List) {
      throw const FormatException('Invalid residence overlap response.');
    }

    if (!detail.containsKey('expected_target')) {
      throw const FormatException('Missing residence overlap target.');
    }

    if (rawOverlaps.isEmpty) {
      throw const FormatException(
        'Residence overlap response contains no overlaps.',
      );
    }

    if (rawTarget != null && rawTarget is! Map) {
      throw const FormatException('Invalid residence overlap target.');
    }

    return ResidenceOverlapProposal(
      message: detail['message'] as String,
      requested: ResidenceOverlapLocation.fromJson(
        Map<String, dynamic>.from(requested),
      ),
      overlaps: rawOverlaps
          .map((item) {
            if (item is! Map) {
              throw const FormatException('Invalid residence overlap entry.');
            }

            return ResidenceOverlapEntry.fromJson(
              Map<String, dynamic>.from(item),
            );
          })
          .toList(growable: false),
      expectedTarget: rawTarget == null
          ? null
          : ResidenceOverlapTarget.fromJson(
              Map<String, dynamic>.from(rawTarget),
            ),
    );
  }

  /// Serialize only the snapshot explicitly approved by the user.
  ///
  /// This matches ResidenceOverlapConfirmation on the FastAPI backend.
  Map<String, dynamic> toConfirmationJson() => {
    'requested': requested.toJson(),
    'overlaps': [for (final overlap in overlaps) overlap.toJson()],
    'expected_target': expectedTarget?.toJson(),
  };
}

/// Raised when the backend requires explicit approval of an overlap.
class ResidenceOverlapRequired implements Exception {
  const ResidenceOverlapRequired(this.proposal);

  final ResidenceOverlapProposal proposal;

  @override
  String toString() => 'ResidenceOverlapRequired: ${proposal.message}';
}

/// Raised when a previously approved overlap snapshot is no longer valid.
///
/// The UI should discard the old confirmation and request a fresh proposal.
class ResidenceOverlapStale implements Exception {
  const ResidenceOverlapStale(this.message);

  final String message;

  @override
  String toString() => 'ResidenceOverlapStale: $message';
}
