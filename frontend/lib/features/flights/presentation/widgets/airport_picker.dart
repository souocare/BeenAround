import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/widgets/country_flag.dart';

import '../../../explore/data/countries_repository.dart';
import '../../../explore/domain/country.dart';

import '../../domain/airport.dart';
import '../../domain/airport_repository.dart';

import 'flight_picker_header.dart';

/// Opens the airport picker.
///
/// Browsing starts with countries. Search always covers
/// the global airport catalog.
///
/// Returns null when dismissed without a selection.
Future<Airport?> showAirportPicker(
  BuildContext context, {
  String title = 'Select Airport',
}) {
  final airportRepository = context.read<AirportRepository>();
  final countriesRepository = context.read<CountriesRepository>();

  return showModalBottomSheet<Airport>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: _AirportPickerContent(
          airportRepository: airportRepository,
          countriesRepository: countriesRepository,
          title: title,
        ),
      );
    },
  );
}

class _AirportPickerContent extends StatefulWidget {
  const _AirportPickerContent({
    required this.airportRepository,
    required this.countriesRepository,
    required this.title,
  });

  final AirportRepository airportRepository;
  final CountriesRepository countriesRepository;
  final String title;

  @override
  State<_AirportPickerContent> createState() => _AirportPickerContentState();
}

class _AirportPickerContentState extends State<_AirportPickerContent> {
  static const int _pageSize = 30;

  final _searchController = TextEditingController();

  Timer? _debounce;

  List<Country> _countries = const [];
  Country? _selectedCountry;

  bool _isLoadingCountries = true;
  String? _countriesError;

  List<Airport> _results = const [];

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;

  String? _errorMessage;
  String? _loadMoreError;

  String _query = '';

  int _requestGeneration = 0;

  bool get _isSearching => _query.isNotEmpty;

  bool get _isBrowsingCountry => _selectedCountry != null;

  @override
  void initState() {
    super.initState();

    // Country browsing is the initial screen.
    _loadCountries();
  }

  @override
  void dispose() {
    _requestGeneration++;

    _debounce?.cancel();
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadCountries() async {
    setState(() {
      _isLoadingCountries = true;
      _countriesError = null;
    });

    try {
      final countries = await widget.countriesRepository.getCountries();

      if (!mounted) return;

      final sorted = List<Country>.of(countries)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      setState(() {
        _countries = List.unmodifiable(sorted);
        _isLoadingCountries = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingCountries = false;
        _countriesError = 'Unable to load countries.';
      });
    }
  }

  void _selectCountry(Country country) {
    _debounce?.cancel();

    // Invalidate outstanding global searches.
    _requestGeneration++;

    setState(() {
      _selectedCountry = country;

      _query = '';
      _searchController.clear();

      _results = const [];
      _hasMore = false;

      _errorMessage = null;
      _loadMoreError = null;

      _isLoading = false;
      _isLoadingMore = false;
    });

    _loadAirports();
  }

  void _goBack() {
    if (_selectedCountry == null) {
      Navigator.of(context).pop();
      return;
    }

    _debounce?.cancel();
    _requestGeneration++;

    setState(() {
      _selectedCountry = null;
      _query = '';
      _searchController.clear();

      _results = const [];
      _hasMore = false;

      _isLoading = false;
      _isLoadingMore = false;

      _errorMessage = null;
      _loadMoreError = null;
    });

    FocusScope.of(context).unfocus();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    final query = value.trim();

    // Invalidate all previously started airport requests.
    _requestGeneration++;

    setState(() {
      _query = query;

      _results = const [];
      _hasMore = false;

      _errorMessage = null;
      _loadMoreError = null;

      _isLoading = false;
      _isLoadingMore = false;
    });

    if (query.isEmpty) {
      // Restore the current browsing level.
      //
      // At root, countries are already loaded.
      // Inside a country, reload that country's airports.
      if (_selectedCountry != null) {
        _loadAirports();
      }

      return;
    }

    if (query.length < 2) {
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), _loadAirports);
  }

  Future<void> _loadAirports({bool append = false}) async {
    if (append) {
      if (_isLoading || _isLoadingMore || !_hasMore) {
        return;
      }
    }

    final query = _query;

    // Search always takes precedence over country browsing.
    final countryCode = query.isEmpty ? _selectedCountry?.code : null;

    // Never make an unfiltered airport catalog request.
    if (query.isEmpty && countryCode == null) {
      return;
    }

    if (query.isNotEmpty && query.length < 2) {
      return;
    }

    final generation = ++_requestGeneration;

    final offset = append ? _results.length : 0;

    setState(() {
      if (append) {
        _isLoadingMore = true;
        _loadMoreError = null;
      } else {
        _isLoading = true;
        _errorMessage = null;
        _loadMoreError = null;
      }
    });

    try {
      final page = await widget.airportRepository.search(
        query: query.isEmpty ? null : query,
        countryCode: countryCode,
        limit: _pageSize,
        offset: offset,
      );

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _results = append ? [..._results, ...page.items] : page.items;

        _hasMore = page.hasMore;

        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isLoadingMore = false;

        if (append) {
          _loadMoreError = 'Unable to load more airports.';
        } else {
          _results = const [];
          _hasMore = false;

          _errorMessage = 'Unable to search airports. Please try again.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = _isSearching
        ? widget.title
        : _selectedCountry?.name ?? widget.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FlightPickerHeader(title: title, onBack: _goBack),

              const SizedBox(height: 16),

              TextField(
                key: const Key('airportSearchField'),
                controller: _searchController,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Airport code, name or city',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isSearching && _query.length < 2) {
      return const Center(
        child: Text('Enter at least two characters to search.'),
      );
    }

    // A global search takes precedence over country browsing.
    if (_isSearching || _isBrowsingCountry) {
      return _buildAirportResults(context);
    }

    return _buildCountryList(context);
  }

  Widget _buildCountryList(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_isLoadingCountries) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_countriesError != null) {
      return _buildError(_countriesError!, _loadCountries);
    }

    if (_countries.isEmpty) {
      return const Center(child: Text('No countries available.'));
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: _countries.length,
      itemBuilder: (context, index) {
        final country = _countries[index];

        return ListTile(
          key: ValueKey('airport-country-${country.code}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          leading: CountryFlag(countryCode: country.code, size: 44),
          title: Text(
            country.name,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: colors.onSurfaceVariant,
          ),
          onTap: () => _selectCountry(country),
        );
      },
    );
  }

  Widget _buildAirportResults(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildError(_errorMessage!, _loadAirports);
    }

    if (_results.isEmpty) {
      return const Center(child: Text('No airports found.'));
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: _results.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _results.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                if (_loadMoreError != null) ...[
                  Text(_loadMoreError!, style: TextStyle(color: colors.error)),
                  const SizedBox(height: 8),
                ],
                OutlinedButton(
                  key: const Key('loadMoreAirports'),
                  onPressed: _isLoadingMore
                      ? null
                      : () => _loadAirports(append: true),
                  child: _isLoadingMore
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load More'),
                ),
              ],
            ),
          );
        }

        final airport = _results[index];

        final city = airport.municipality?.trim();

        final location = city != null && city.isNotEmpty
            ? city
            : airport.displayLocation;

        return ListTile(
          key: ValueKey('airport-${airport.id}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          leading: CountryFlag(
            countryCode: airport.countryCode ?? '',
            size: 44,
          ),
          title: Row(
            children: [
              Text(
                airport.displayCode,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  airport.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            Navigator.of(context).pop(airport);
          },
        );
      },
    );
  }

  Widget _buildError(String message, VoidCallback onRetry) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.error),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
