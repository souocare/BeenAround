import '../../explore/domain/country_visit.dart';
import '../../geography/domain/city_visit.dart';

/// State of the visit associations belonging to one Trip.
class TripAssociationsState {
  const TripAssociationsState({
    this.countryVisits = const [],
    this.cityVisits = const [],
    this.hasLoaded = false,
    this.isLoading = false,
    this.isMutating = false,
    this.loadError,
    this.mutationError,
  });

  final List<CountryVisit> countryVisits;
  final List<CityVisit> cityVisits;

  /// Whether at least one complete load succeeded.
  final bool hasLoaded;

  /// Initial loading or refreshing.
  final bool isLoading;

  /// A visit association is being added or removed.
  final bool isMutating;

  /// Loading or refreshing failed.
  final String? loadError;

  /// Adding or removing an association failed.
  final String? mutationError;

  bool get hasLoadError => loadError != null;

  bool get hasMutationError => mutationError != null;

  bool get isInitialLoading => isLoading && !hasLoaded;

  bool get isRefreshing => isLoading && hasLoaded;

  bool get isEmpty => countryVisits.isEmpty && cityVisits.isEmpty;

  bool get isReady => hasLoaded && !isLoading;

  static const Object _unchanged = Object();

  TripAssociationsState copyWith({
    List<CountryVisit>? countryVisits,
    List<CityVisit>? cityVisits,
    bool? hasLoaded,
    bool? isLoading,
    bool? isMutating,
    Object? loadError = _unchanged,
    Object? mutationError = _unchanged,
  }) {
    return TripAssociationsState(
      countryVisits: countryVisits ?? this.countryVisits,
      cityVisits: cityVisits ?? this.cityVisits,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      loadError: identical(loadError, _unchanged)
          ? this.loadError
          : loadError as String?,
      mutationError: identical(mutationError, _unchanged)
          ? this.mutationError
          : mutationError as String?,
    );
  }
}
