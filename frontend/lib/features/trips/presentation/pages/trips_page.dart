import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';

import '../../application/trips_cubit.dart';
import '../../application/trips_state.dart';
import '../../domain/trip.dart';
import '../../domain/trip_repository.dart';
import '../../domain/trip_status.dart';

import '../widgets/trip_card.dart';
import '../widgets/trip_form_dialog.dart';

enum _TripsFilter { all, upcoming, ongoing, completed }

class TripsPage extends StatelessWidget {
  const TripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          TripsCubit(repository: context.read<TripRepository>())..load(),
      child: const _TripsView(),
    );
  }
}

class _TripsView extends StatefulWidget {
  const _TripsView();

  @override
  State<_TripsView> createState() => _TripsViewState();
}

class _TripsViewState extends State<_TripsView> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';

  _TripsFilter _selectedFilter = _TripsFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Trip> _filteredTrips(List<Trip> trips) {
    final normalizedQuery = _query.trim().toLowerCase();

    return trips
        .where((trip) {
          final matchesSearch =
              normalizedQuery.isEmpty ||
              trip.name.toLowerCase().contains(normalizedQuery);

          if (!matchesSearch) {
            return false;
          }

          if (_selectedFilter == _TripsFilter.all) {
            return true;
          }

          final status = resolveTripStatus(trip);

          return switch (_selectedFilter) {
            _TripsFilter.all => true,
            _TripsFilter.upcoming => status == TripStatus.upcoming,
            _TripsFilter.ongoing => status == TripStatus.ongoing,
            _TripsFilter.completed => status == TripStatus.completed,
          };
        })
        .toList(growable: false);
  }

  String _filterLabel(_TripsFilter filter) {
    return switch (filter) {
      _TripsFilter.all => 'All',
      _TripsFilter.upcoming => 'Upcoming',
      _TripsFilter.ongoing => 'Ongoing',
      _TripsFilter.completed => 'Completed',
    };
  }

  Future<void> _openTripForm({Trip? trip}) async {
    final saved = await showTripFormDialog(context: context, trip: trip);

    if (!mounted || !saved) {
      return;
    }

    await context.read<TripsCubit>().refresh();
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trips',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: AppSpacing.xs),

              Text(
                'Every journey tells a story.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: AppSpacing.md),

        IconButton.filled(
          key: const Key('createTripButton'),
          onPressed: () => _openTripForm(),
          tooltip: 'Create Trip',
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      key: const Key('tripsSearchField'),
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _query = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search trips...',
        prefixIcon: const Icon(Icons.search),

        suffixIcon: _query.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _query = '';
                  });
                },
                icon: const Icon(Icons.close),
              )
            : null,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _TripsFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                key: Key('tripsFilter-${filter.name}'),
                label: Text(_filterLabel(filter)),
                selected: _selectedFilter == filter,
                onSelected: (_) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isFiltered =
        _query.trim().isNotEmpty || _selectedFilter != _TripsFilter.all;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxxl,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFiltered ? Icons.search_off_outlined : Icons.luggage_outlined,
              size: 58,
              color: colors.onSurfaceVariant,
            ),

            const SizedBox(height: AppSpacing.lg),

            Text(
              isFiltered ? 'No matching trips' : 'Your journeys start here',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              isFiltered
                  ? 'Try another search or change your filters.'
                  : 'Create your first Trip to start organizing your travel history.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),

            if (!isFiltered) ...[
              const SizedBox(height: AppSpacing.xl),

              FilledButton.icon(
                onPressed: () => _openTripForm(),
                icon: const Icon(Icons.add),
                label: const Text('Create Trip'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFailureState(BuildContext context, TripsState state) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 48, color: colors.error),

          const SizedBox(height: AppSpacing.lg),

          Text('Unable to load Trips', style: theme.textTheme.titleLarge),

          const SizedBox(height: AppSpacing.sm),

          Text(
            state.errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          OutlinedButton.icon(
            onPressed: () {
              context.read<TripsCubit>().load();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildTripList(BuildContext context, TripsState state) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final trips = _filteredTrips(state.trips);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${trips.length} ${trips.length == 1 ? 'trip' : 'trips'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        if (trips.isEmpty)
          _buildEmptyState(context)
        else
          for (final trip in trips) ...[
            TripCard(
              trip: trip,
              onEdit: () => _openTripForm(trip: trip),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripsCubit, TripsState>(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () => context.read<TripsCubit>().refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),

                      const SizedBox(height: AppSpacing.xl),

                      _buildSearch(),

                      const SizedBox(height: AppSpacing.lg),

                      _buildFilters(),

                      const SizedBox(height: AppSpacing.xl),

                      if (state.phase == TripsPhase.initial ||
                          (state.phase == TripsPhase.loading &&
                              state.trips.isEmpty))
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.xxxl),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (state.phase == TripsPhase.failure &&
                          state.trips.isEmpty)
                        _buildFailureState(context, state)
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (state.phase == TripsPhase.loading)
                              const LinearProgressIndicator(),

                            if (state.phase == TripsPhase.failure)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.lg,
                                ),
                                child: _buildFailureState(context, state),
                              ),

                            _buildTripList(context, state),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
