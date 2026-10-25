import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../geography/domain/city.dart';
import '../../../geography/domain/city_repository.dart';
import '../../../geography/domain/city_sort.dart';
import '../../../geography/domain/country_city_count.dart';
import 'country_flag.dart';

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
  String _globalQuery = '';
  List<City> _globalCities = const [];

  bool _globalSearchLoading = false;
  String? _globalSearchError;
  List<CountryCityCount> _countries = const [];

  CountryCityCount? _selectedCountry;

  bool _isLoading = true;
  String? _errorMessage;
  static const int _pageSize = 30;

  List<City> _cities = const [];

  CitySort _citySort = CitySort.population;

  String _cityQuery = '';

  bool _citiesLoading = false;

  String? _citiesError;

  Timer? _searchDebounce;

  int _cityRequestGeneration = 0;

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
      _globalSearchError = null;
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
        _globalSearchLoading = false;
        _globalSearchError = null;
      });
    } catch (_) {
      if (!mounted || generation != _cityRequestGeneration) return;

      setState(() {
        _globalSearchLoading = false;
        _globalSearchError = 'Unable to search cities. Please try again.';
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

    setState(() {
      _selectedCountry = country;

      _globalQuery = '';
      _globalCities = const [];
      _globalSearchLoading = false;
      _globalSearchError = null;

      _cityQuery = '';
      _cities = const [];
      _citiesError = null;
      _citiesLoading = true;
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
        _citiesLoading = false;
        _citiesError = null;
      });
    } catch (_) {
      if (!mounted || generation != _cityRequestGeneration) return;

      setState(() {
        _citiesLoading = false;
        _citiesError = 'Unable to load cities. Please try again.';
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
    });

    _loadCities(generation);
  }

  void _goBack() {
    if (_selectedCountry != null) {
      _searchDebounce?.cancel();
      ++_cityRequestGeneration;

      setState(() {
        _selectedCountry = null;

        _globalQuery = '';
        _globalCities = const [];
        _globalSearchLoading = false;
        _globalSearchError = null;

        _cityQuery = '';
        _cities = const [];
        _citiesError = null;
        _citiesLoading = false;
      });

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
          child: TextField(
            key: const Key('destinationCitySearch'),
            decoration: const InputDecoration(
              hintText: 'Search countries or cities...',
              prefixIcon: Icon(Icons.search),
            ),
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
                      else
                        for (final city in _globalCities) ...[
                          _buildGlobalCityTile(city),
                          const SizedBox(height: 6),
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

  Widget _buildCountryCitiesView() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TextField(
            key: const Key('cityBrowserCountrySearch'),
            decoration: const InputDecoration(
              hintText: 'Search cities in this country...',
              prefixIcon: Icon(Icons.search),
            ),
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
              DropdownButton<CitySort>(
                key: const Key('cityBrowserSort'),
                value: _citySort,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: CitySort.population,
                    child: Text('Population'),
                  ),
                  DropdownMenuItem(
                    value: CitySort.name,
                    child: Text('Name A–Z'),
                  ),
                ],
                onChanged: (sort) {
                  if (sort != null) _changeSort(sort);
                },
              ),
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
      itemCount: _cities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    ++_cityRequestGeneration;
    super.dispose();
  }
}
