import '../domain/residence.dart';

enum ResidencesPhase { initial, loading, ready, failure }

class ResidencesState {
  const ResidencesState({
    this.phase = ResidencesPhase.initial,
    this.residences = const [],
    this.errorMessage,
  });

  final ResidencesPhase phase;
  final List<Residence> residences;
  final String? errorMessage;

  bool get hasData => phase == ResidencesPhase.ready;

  int get totalResidences => residences.length;

  /// Countries where the user has at least one residence.
  ///
  /// City residences contribute to the country-level lived view,
  /// without creating an additional country residence.
  Set<String> get livedCountryCodes =>
      Set.unmodifiable(residences.map((residence) => residence.countryCode));

  int get livedCountryCount => livedCountryCodes.length;

  /// Number of distinct cities with registered residences.
  int get livedCityCount => residences
      .where((residence) => residence.cityId != null)
      .map((residence) => residence.cityId!)
      .toSet()
      .length;

  List<Residence> residencesForCountry(String countryCode) {
    return List.unmodifiable(
      residences.where((residence) => residence.countryCode == countryCode),
    );
  }

  List<Residence> residencesForCity(int cityId) {
    return List.unmodifiable(
      residences.where((residence) => residence.cityId == cityId),
    );
  }

  /// Explicit residences registered directly against a country.
  ///
  /// This does not include city residences.
  List<Residence> directCountryResidences(String countryCode) {
    return List.unmodifiable(
      residences.where(
        (residence) =>
            residence.countryCode == countryCode && residence.cityId == null,
      ),
    );
  }
}
