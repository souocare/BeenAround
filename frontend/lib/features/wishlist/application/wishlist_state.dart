import '../domain/wishlist_entry.dart';

enum WishlistPhase { initial, loading, ready, failure }

class WishlistState {
  const WishlistState({
    this.phase = WishlistPhase.initial,
    this.entries = const [],
    this.errorMessage,
  });

  final WishlistPhase phase;
  final List<WishlistEntry> entries;
  final String? errorMessage;

  bool get hasData => phase == WishlistPhase.ready;

  int get totalEntries => entries.length;

  Set<String> get countryCodes => Set.unmodifiable(
    entries
        .where((entry) => entry.countryCode != null)
        .map((entry) => entry.countryCode!),
  );

  Set<int> get cityIds => Set.unmodifiable(
    entries
        .where((entry) => entry.cityId != null)
        .map((entry) => entry.cityId!),
  );

  int get countryCount => countryCodes.length;

  int get cityCount => cityIds.length;

  bool containsCountry(String countryCode) {
    return countryCodes.contains(countryCode);
  }

  bool containsCity(int cityId) {
    return cityIds.contains(cityId);
  }

  WishlistEntry? entryForCountry(String countryCode) {
    for (final entry in entries) {
      if (entry.countryCode == countryCode) {
        return entry;
      }
    }

    return null;
  }

  WishlistEntry? entryForCity(int cityId) {
    for (final entry in entries) {
      if (entry.cityId == cityId) {
        return entry;
      }
    }

    return null;
  }
}
