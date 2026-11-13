/// Extracts possible airline designators from flight numbers.
///
/// This parser does not identify an airline by itself.
/// Catalog resolution is required to confirm a match.
class FlightNumber {
  const FlightNumber._();

  static final RegExp _iataPattern = RegExp(
    r'^([A-Z0-9]{2})([0-9]{1,4}[A-Z]?)$',
  );

  static final RegExp _icaoPattern = RegExp(r'^([A-Z]{3})([0-9]{1,4}[A-Z]?)$');

  static String normalize(String value) {
    return value.trim().toUpperCase().replaceAll(' ', '');
  }

  /// Potential airline codes from a flight number.
  ///
  /// ICAO is checked first because it uses three letters,
  /// while IATA uses two alphanumeric characters.
  ///
  /// A candidate must still be validated against the catalog.
  static List<String> airlineCodeCandidates(String value) {
    final normalized = normalize(value);

    final candidates = <String>[];

    final icaoMatch = _icaoPattern.firstMatch(normalized);

    if (icaoMatch != null) {
      candidates.add(icaoMatch.group(1)!);
    }

    final iataMatch = _iataPattern.firstMatch(normalized);

    if (iataMatch != null) {
      final code = iataMatch.group(1)!;

      if (!candidates.contains(code)) {
        candidates.add(code);
      }
    }

    return List.unmodifiable(candidates);
  }
}
