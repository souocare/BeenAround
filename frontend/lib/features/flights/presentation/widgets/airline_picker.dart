import 'dart:async';

import 'package:beenaround/features/flights/presentation/widgets/flight_picker_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/airline.dart';
import '../../domain/airline_repository.dart';
import '../../domain/airline_selection.dart';
import 'airline_avatar.dart';

/// Opens the airline picker.
///
/// Returns null when dismissed without making a selection.
Future<AirlineSelection?> showAirlinePicker(
  BuildContext context, {
  String title = 'Select Airline',
}) {
  final repository = context.read<AirlineRepository>();

  return showModalBottomSheet<AirlineSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height * 0.85;

      return SizedBox(
        height: height,
        child: _AirlinePickerContent(repository: repository, title: title),
      );
    },
  );
}

class _AirlinePickerContent extends StatefulWidget {
  const _AirlinePickerContent({required this.repository, required this.title});

  final AirlineRepository repository;
  final String title;

  @override
  State<_AirlinePickerContent> createState() => _AirlinePickerContentState();
}

class _AirlinePickerContentState extends State<_AirlinePickerContent> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;

  List<Airline> _results = const [];

  bool _isLoading = false;
  String? _errorMessage;
  String _query = '';

  int _requestGeneration = 0;

  static const int _pageSize = 30;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  String? _loadMoreError;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _search('');
    });
  }

  @override
  void dispose() {
    _requestGeneration++;
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    final query = value.trim();

    // Invalidate any pending catalog or pagination response.
    _requestGeneration++;

    setState(() {
      _query = query;

      _results = const [];
      _hasMore = false;

      _isLoading = false;
      _isLoadingMore = false;

      _errorMessage = null;
      _loadMoreError = null;
    });

    if (query.isEmpty) {
      // Return to the initial alphabetical catalog.
      _search('');
      return;
    }

    if (query.length < 2) {
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query, {bool append = false}) async {
    if (append) {
      if (_isLoading || _isLoadingMore || !_hasMore) {
        return;
      }
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
      final page = await widget.repository.search(
        query: query.isEmpty ? null : query,
        limit: _pageSize,
        offset: offset,
      );

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _results = append
            ? List.unmodifiable([..._results, ...page.items])
            : page.items;

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
          // Preserve previously loaded catalog entries.
          _loadMoreError = 'Unable to load more airlines.';
        } else {
          _results = const [];
          _hasMore = false;

          _errorMessage = 'Unable to search airlines. Please try again.';
        }
      });
    }
  }

  void _retry() {
    if (!_isLoading) {
      _search(_query);
    }
  }

  void _loadMore() {
    if (_isLoading || _isLoadingMore || !_hasMore) {
      return;
    }

    _search(_query, append: true);
  }

  Future<void> _enterManualAirline() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _ManualAirlineDialog(initialName: _query),
    );

    if (!mounted || name == null) {
      return;
    }

    Navigator.of(context).pop(AirlineSelection.manual(name));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FlightPickerHeader(title: widget.title),
              const SizedBox(height: 16),
              TextField(
                key: const Key('airlineSearchField'),
                controller: _searchController,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Airline name, IATA or ICAO code',
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

        Expanded(child: _buildResults(context)),

        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: OutlinedButton.icon(
              key: const Key('enterManualAirline'),
              onPressed: _enterManualAirline,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Enter airline manually'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_query.isNotEmpty && _query.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Enter at least two characters to search.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: _retry, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No airlines found. You can enter one manually.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: _results.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // -------------------------------------------------------
        // Pagination
        // -------------------------------------------------------
        if (index == _results.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                if (_loadMoreError != null) ...[
                  Text(
                    _loadMoreError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.error),
                  ),

                  const SizedBox(height: 8),
                ],

                OutlinedButton(
                  key: const Key('loadMoreAirlines'),
                  onPressed: _isLoadingMore ? null : _loadMore,
                  child: _isLoadingMore
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load More Airlines'),
                ),
              ],
            ),
          );
        }

        // -------------------------------------------------------
        // Airline
        // -------------------------------------------------------
        final airline = _results[index];

        final codes = [
          if (airline.iataCode?.isNotEmpty == true) airline.iataCode!,
          if (airline.icaoCode?.isNotEmpty == true) airline.icaoCode!,
        ];

        final subtitle = codes.isNotEmpty
            ? codes.join(' · ')
            : airline.countryName ?? 'Airline';

        return Column(
          children: [
            ListTile(
              key: ValueKey('airline-${airline.id}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              leading: AirlineAvatar(airline: airline, size: 48),
              title: Text(
                airline.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).pop(AirlineSelection.catalog(airline));
              },
            ),

            if (index < _results.length - 1)
              Divider(
                height: 1,
                indent: 76,
                color: colors.outlineVariant.withValues(alpha: 0.4),
              ),
          ],
        );
      },
    );
  }
}

/// Explicit manual-airline entry.
///
/// The result is returned to the picker; no catalog entry is created.
class _ManualAirlineDialog extends StatefulWidget {
  const _ManualAirlineDialog({required this.initialName});

  final String initialName;

  @override
  State<_ManualAirlineDialog> createState() => _ManualAirlineDialogState();
}

class _ManualAirlineDialogState extends State<_ManualAirlineDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manual Airline'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('manualAirlineNameField'),
          controller: _controller,
          autofocus: true,
          maxLength: 200,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: 'Airline name',
            hintText: 'e.g. Air Berlin',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Enter an airline name.';
            }

            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirmManualAirline'),
          onPressed: _submit,
          child: const Text('Use Airline'),
        ),
      ],
    );
  }
}
