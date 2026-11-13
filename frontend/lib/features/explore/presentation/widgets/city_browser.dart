import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../geography/domain/city.dart';
import '../../../geography/domain/city_repository.dart';
import '../../../geography/domain/city_sort.dart';
import '../../../geography/domain/country_city_count.dart';
import 'package:beenaround/app/widgets/country_flag.dart';

class CityBrowser extends StatefulWidget {
  const CityBrowser({
    required this.onBack,
    required this.onCitySelected,
    super.key,
  });

  final VoidCallback onBack;
  final ValueChanged<City> onCitySelected;

  @override
  State<CityBrowser> createState() => _CityBrowserState();
}

class _CityBrowserState extends State<CityBrowser> {
  static const int _pageSize = 30;

  String _globalQuery = '';
  List<City> _globalCities = const [];
  List<CountryCityCount> _countries = const [];

  bool _globalSearchLoading = false;
  String? _globalSearchError;

  CountryCityCount? _selectedCountry;

  bool _isLoading = true;
  String? _errorMessage;

  List<City> _cities = const [];
  CitySort _citySort = CitySort.population;
  String _cityQuery = '';

  bool _citiesLoading = false;
  String? _citiesError;

  Timer? _searchDebounce;
  int _cityRequestGeneration = 0;

  int _globalTotal = 0;
  int _countryTotal = 0;

  bool _globalLoadingMore = false;
  bool _countryLoadingMore = false;

  String? _globalLoadMoreError;
  String? _countryLoadMoreError;

  bool _globalPaginationExhausted = false;
  bool _countryPaginationExhausted = false;
  final TextEditingController _globalSearchController = TextEditingController();

  bool _globalSearchNeedsReload = false;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  void _onGlobalQueryChanged(String value) {
    _searchDebounce?.cancel();

    final generation = ++_cityRequestGeneration;
    final query = value.trim();

    setState(() {
      _globalQuery = value;
      _globalCities = const [];
      _globalTotal = 0;

      _globalSearchError = null;
      _globalLoadMoreError = null;

      _globalLoadingMore = false;
      _globalPaginationExhausted = false;

      _globalSearchLoading = query.isNotEmpty;
    });

    if (query.isEmpty) return;

    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _searchGlobalCities(query, generation),
    );
  }

  Future<void> _searchGlobalCities(String query, int generation) async {
    try {
      final result = await context.read<CityRepository>().search(
        query: query,
        sort: CitySort.population,
        limit: _pageSize,
        offset: 0,
      );

      if (!mounted || generation != _cityRequestGeneration) return;

      setState(() {
        _globalCities = result.items;
        _globalTotal = result.total;

        _globalSearchLoading = false;
        _globalSearchError = null;

        _globalPaginationExhausted = false;
      });
    } catch (_) {
      if (!mounted || generation != _cityRequestGeneration) return;

      setState(() {
        _globalSearchLoading = false;
        _globalSearchError = 'Unable to search cities. Please try again.';
      });
    }
  }

  Future<void> _loadMoreGlobalCities() async {
    if (_globalSearchLoading ||
        _globalLoadingMore ||
        _globalPaginationExhausted ||
        _globalCities.length >= _globalTotal ||
        _globalQuery.trim().isEmpty) {
      return;
    }

    final generation = _cityRequestGeneration;
    final query = _globalQuery.trim();
    final offset = _globalCities.length;

    setState(() {
      _globalLoadingMore = true;
      _globalLoadMoreError = null;
    });

    try {
      final result = await context.read<CityRepository>().search(
        query: query,
        sort: CitySort.population,
        limit: _pageSize,
        offset: offset,
      );

      if (!mounted || generation != _cityRequestGeneration) return;

      setState(() {
        _globalCities = [..._globalCities, ...result.items];
        _globalTotal = result.total;

        _globalLoadingMore = false;
        _globalPaginationExhausted = result.items.isEmpty;
      });
    } catch (_) {
      if (!mounted || generation != _cityRequestGeneration) return;

      setState(() {
        _globalLoadingMore = false;
        _globalLoadMoreError = 'Unable to load more cities.';
      });
    }
  }

  Future<void> _loadCountries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final countries = await context
          .read<CityRepository>()
          .listCountryCityCounts();

      if (!mounted) return;

      final sortedCountries = List<CountryCityCount>.of(countries)
        ..sort((a, b) {
          final nameComparison = a.countryName.toLowerCase().compareTo(
            b.countryName.toLowerCase(),
          );

          if (nameComparison != 0) return nameComparison;

          return a.countryCode.compareTo(b.countryCode);
        });

      setState(() {
        _countries = sortedCountries;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load countries. Please try again.';
      });
    }
  }

  void _openCountry(CountryCityCount country) {
    _searchDebounce?.cancel();

    final generation = ++_cityRequestGeneration;

    // Preserve the global query and its loaded results.
    // If a search was interrupted, reload it when returning.
    _globalSearchNeedsReload =
        _globalQuery.trim().isNotEmpty &&
        (_globalSearchLoading || _globalCities.isEmpty);

    setState(() {
      _selectedCountry = country;

      _globalSearchLoading = false;

      // Country-specific navigation starts with a fresh search.
      _cityQuery = '';
      _cities = const [];
      _citiesError = null;
      _citiesLoading = true;

      _countryTotal = 0;
      _countryLoadingMore = false;
      _countryLoadMoreError = null;
      _countryPaginationExhausted = false;
    });

    _loadCities(generation);
  }

  Future<void> _loadCities(int generation) async {
    final country = _selectedCountry;

    if (country == null) return;

    try {
      final result = await context.read<CityRepository>().search(
        query: _cityQuery.trim().isEmpty ? null : _cityQuery.trim(),
        countryCode: country.countryCode,
        sort: _citySort,
        limit: _pageSize,
        offset: 0,
      );

      if (!mounted || generation != _cityRequestGeneration) return;

      setState(() {
        _cities = result.items;
        _countryTotal = result.total;

        _citiesLoading = false;
        _citiesError = null;

        _countryPaginationExhausted = false;
      });
    } catch (_) {
      if (!mounted || generation != _cityRequestGeneration) return;

      setState(() {
        _citiesLoading = false;
        _citiesError = 'Unable to load cities. Please try again.';
      });
    }
  }

  Future<void> _loadMoreCountryCities() async {
    final country = _selectedCountry;

    if (country == null ||
        _citiesLoading ||
        _countryLoadingMore ||
        _countryPaginationExhausted ||
        _cities.length >= _countryTotal) {
      return;
    }

    final generation = _cityRequestGeneration;
    final query = _cityQuery.trim();
    final sort = _citySort;
    final offset = _cities.length;

    setState(() {
      _countryLoadingMore = true;
      _countryLoadMoreError = null;
    });

    try {
      final result = await context.read<CityRepository>().search(
        query: query.isEmpty ? null : query,
        countryCode: country.countryCode,
        sort: sort,
        limit: _pageSize,
        offset: offset,
      );

      if (!mounted || generation != _cityRequestGeneration) return;

      setState(() {
        _cities = [..._cities, ...result.items];
        _countryTotal = result.total;

        _countryLoadingMore = false;
        _countryPaginationExhausted = result.items.isEmpty;
      });
    } catch (_) {
      if (!mounted || generation != _cityRequestGeneration) return;

      setState(() {
        _countryLoadingMore = false;
        _countryLoadMoreError = 'Unable to load more cities.';
      });
    }
  }

  void _onCityQueryChanged(String value) {
    _searchDebounce?.cancel();

    final generation = ++_cityRequestGeneration;

    setState(() {
      _cityQuery = value;
      _cities = const [];

      _citiesError = null;
      _citiesLoading = true;

      _countryTotal = 0;
      _countryLoadingMore = false;
      _countryLoadMoreError = null;
      _countryPaginationExhausted = false;
    });

    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadCities(generation),
    );
  }

  void _changeSort(CitySort sort) {
    if (_citySort == sort) return;

    _searchDebounce?.cancel();

    final generation = ++_cityRequestGeneration;

    setState(() {
      _citySort = sort;
      _cities = const [];

      _citiesError = null;
      _citiesLoading = true;

      _countryTotal = 0;
      _countryLoadingMore = false;
      _countryLoadMoreError = null;
      _countryPaginationExhausted = false;
    });

    _loadCities(generation);
  }

  void _goBack() {
    if (_selectedCountry != null) {
      _searchDebounce?.cancel();
      ++_cityRequestGeneration;

      final shouldReloadGlobalSearch = _globalSearchNeedsReload;
      _globalSearchNeedsReload = false;

      setState(() {
        _selectedCountry = null;

        // Clear only the country-specific state.
        _cityQuery = '';
        _cities = const [];
        _citiesError = null;
        _citiesLoading = false;

        _countryTotal = 0;
        _countryLoadingMore = false;
        _countryLoadMoreError = null;
        _countryPaginationExhausted = false;
      });

      // A previous global search might have been interrupted.
      // Restart it only when necessary.
      if (shouldReloadGlobalSearch && _globalQuery.trim().isNotEmpty) {
        _onGlobalQueryChanged(_globalQuery);
      }

      return;
    }

    widget.onBack();
  }

  Widget _buildCountryTile(CountryCityCount country) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('cityBrowserCountry_${country.countryCode}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openCountry(country),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CountryFlag(countryCode: country.countryCode, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      country.countryName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${country.cityCount} cities',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalCityTile(City city) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('cityBrowserGlobalCity_${city.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => widget.onCitySelected(city),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.location_city_outlined, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      city.countryName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 20, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedCountry?.countryName ?? 'Select City',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _selectedCountry == null
              ? _buildCountriesView()
              : _buildCountryCitiesView(),
        ),
      ],
    );
  }

  Widget _buildCountriesView() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final query = _globalQuery.trim().toLowerCase();

    final filteredCountries = _countries
        .where((country) {
          return query.isEmpty ||
              country.countryName.toLowerCase().contains(query) ||
              country.countryCode.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: _AdaptiveCitySearchField(
            fieldKey: const Key('destinationCitySearch'),
            controller: _globalSearchController,
            placeholder: 'Search countries or cities...',
            onChanged: _onGlobalQueryChanged,
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.error),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _loadCountries,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  key: const Key('cityBrowserCountries'),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    if (filteredCountries.isNotEmpty) ...[
                      Text(
                        'COUNTRIES',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final country in filteredCountries) ...[
                        _buildCountryTile(country),
                        const SizedBox(height: 6),
                      ],
                    ],
                    if (query.isNotEmpty) ...[
                      if (filteredCountries.isNotEmpty)
                        const SizedBox(height: 16),
                      Text(
                        'CITIES',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_globalSearchLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_globalSearchError != null) ...[
                        Text(
                          _globalSearchError!,
                          style: TextStyle(color: colors.error),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            final generation = ++_cityRequestGeneration;

                            setState(() {
                              _globalSearchLoading = true;
                              _globalSearchError = null;
                              _globalPaginationExhausted = false;
                            });

                            _searchGlobalCities(
                              _globalQuery.trim(),
                              generation,
                            );
                          },
                          child: const Text('Try again'),
                        ),
                      ] else if (_globalCities.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No cities found.'),
                        )
                      else ...[
                        for (final city in _globalCities) ...[
                          _buildGlobalCityTile(city),
                          const SizedBox(height: 6),
                        ],
                        _buildLoadMoreFooter(
                          loaded: _globalCities.length,
                          total: _globalTotal,
                          isLoading: _globalLoadingMore,
                          error: _globalLoadMoreError,
                          exhausted: _globalPaginationExhausted,
                          onLoadMore: _loadMoreGlobalCities,
                          buttonKey: 'cityBrowserGlobalLoadMore',
                        ),
                      ],
                    ],
                    if (query.isEmpty && _countries.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No countries available.'),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _showCupertinoSortSheet() async {
    final selected = await showCupertinoModalPopup<CitySort>(
      context: context,
      builder: (popupContext) {
        final colors = Theme.of(context).colorScheme;

        Widget sortAction(CitySort sort, String label) {
          return CupertinoActionSheetAction(
            key: Key('cityBrowserSortOption_${sort.name}'),
            onPressed: () => Navigator.of(popupContext).pop(sort),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label),
                if (_citySort == sort) ...[
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.check_mark,
                    size: 17,
                    color: colors.primary,
                  ),
                ],
              ],
            ),
          );
        }

        return CupertinoActionSheet(
          title: const Text('Sort cities by'),
          actions: [
            sortAction(CitySort.population, 'Population'),
            sortAction(CitySort.name, 'Name A–Z'),
          ],
          cancelButton: CupertinoActionSheetAction(
            key: const Key('cityBrowserSortCancel'),
            onPressed: () => Navigator.of(popupContext).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;

    _changeSort(selected);
  }

  Widget _buildCitySortSelector() {
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    if (isIOS) {
      return CupertinoButton(
        key: const Key('cityBrowserSort'),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
        onPressed: _showCupertinoSortSheet,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_citySort == CitySort.population ? 'Population' : 'Name A–Z'),
            const SizedBox(width: 5),
            const Icon(CupertinoIcons.chevron_down, size: 13),
          ],
        ),
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return PopupMenuButton<CitySort>(
        key: const Key('cityBrowserSort'),
        initialValue: _citySort,
        tooltip: 'Sort cities',
        onSelected: _changeSort,
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
            value: CitySort.population,
            checked: _citySort == CitySort.population,
            child: const Text('Population'),
          ),
          CheckedPopupMenuItem(
            value: CitySort.name,
            checked: _citySort == CitySort.name,
            child: const Text('Name A–Z'),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _citySort == CitySort.population ? 'Population' : 'Name A–Z',
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      );
    }

    return DropdownButton<CitySort>(
      key: const Key('cityBrowserSort'),
      value: _citySort,
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(value: CitySort.population, child: Text('Population')),
        DropdownMenuItem(value: CitySort.name, child: Text('Name A–Z')),
      ],
      onChanged: (sort) {
        if (sort != null) _changeSort(sort);
      },
    );
  }

  Widget _buildCountryCitiesView() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: _AdaptiveCitySearchField(
            fieldKey: const Key('cityBrowserCountrySearch'),
            placeholder: 'Search cities in this country...',
            onChanged: _onCityQueryChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Text(
                'CITIES',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              _buildCitySortSelector(),
            ],
          ),
        ),
        Expanded(child: _buildCitiesContent()),
      ],
    );
  }

  Widget _buildCitiesContent() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_citiesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_citiesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 36, color: colors.error),
              const SizedBox(height: 12),
              Text(_citiesError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  final generation = ++_cityRequestGeneration;

                  setState(() {
                    _citiesLoading = true;
                    _citiesError = null;
                    _countryPaginationExhausted = false;
                  });

                  _loadCities(generation);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_cities.isEmpty) {
      return Center(
        child: Text(
          'No cities found.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      key: const Key('cityBrowserCities'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _cities.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        if (index == _cities.length) {
          return _buildLoadMoreFooter(
            loaded: _cities.length,
            total: _countryTotal,
            isLoading: _countryLoadingMore,
            error: _countryLoadMoreError,
            exhausted: _countryPaginationExhausted,
            onLoadMore: _loadMoreCountryCities,
            buttonKey: 'cityBrowserCountryLoadMore',
          );
        }

        final city = _cities[index];

        return Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: Key('cityBrowserCity_${city.id}'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => widget.onCitySelected(city),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.location_city_outlined, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          city.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          city.population == null
                              ? city.countryName
                              : 'Population: ${city.population}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadMoreFooter({
    required int loaded,
    required int total,
    required bool isLoading,
    required String? error,
    required bool exhausted,
    required VoidCallback onLoadMore,
    required String buttonKey,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (loaded == 0) return const SizedBox.shrink();

    final canLoadMore = loaded < total && !exhausted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          if (canLoadMore) ...[
            if (error != null) ...[
              Text(error, style: TextStyle(color: colors.error)),
              const SizedBox(height: 8),
            ],
            if (isLoading)
              const CircularProgressIndicator()
            else
              OutlinedButton(
                key: Key(buttonKey),
                onPressed: onLoadMore,
                child: Text(error == null ? 'Load more' : 'Try again'),
              ),
            const SizedBox(height: 12),
          ],
          Text(
            'Showing $loaded of $total',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    ++_cityRequestGeneration;
    super.dispose();
  }
}

class _AdaptiveCitySearchField extends StatelessWidget {
  const _AdaptiveCitySearchField({
    required this.fieldKey,
    required this.placeholder,
    required this.onChanged,
    this.controller,
  });

  final Key fieldKey;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final useCupertino = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    if (useCupertino) {
      return CupertinoSearchTextField(
        key: fieldKey,
        controller: controller,
        placeholder: placeholder,
        onChanged: onChanged,
      );
    }

    return TextField(
      key: fieldKey,
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: placeholder,
        prefixIcon: const Icon(Icons.search),
      ),
      onChanged: onChanged,
    );
  }
}
