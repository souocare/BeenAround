import 'package:beenaround/core/widgets/adaptive_record_actions_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/visited_cities_cubit.dart';
import '../../application/visited_cities_state.dart';
import '../../domain/visited_city.dart';

import '../../../geography/domain/city.dart';
import '../../../geography/domain/city_visit.dart';

import '../../../residences/application/residences_cubit.dart';
import '../../../residences/presentation/widgets/show_residences.dart';

import '../../../wishlist/application/wishlist_cubit.dart';
import '../../../wishlist/domain/wishlist_entry.dart';
import '../../../wishlist/presentation/widgets/show_edit_wishlist_note.dart';
import '../../../wishlist/presentation/widgets/show_remove_wishlist_entry.dart';
import '../../../wishlist/presentation/widgets/wishlist_entry_controls.dart';

import '../widgets/show_delete_city_visit.dart';
import '../widgets/show_edit_city_visit.dart';
import '../../application/city_trips_cubit.dart';
import '../../application/city_trips_state.dart';

import '../../../trips/domain/trip_repository.dart';
import '../../../trips/domain/trip_association_repository.dart';
import '../../../trips/domain/trip.dart';
import '../../../trips/presentation/pages/trip_details_page.dart';
import '../widgets/destination_details_tabs.dart';

enum _CityTab { overview, visits, trips }

class CityDetailsPage extends StatelessWidget {
  const CityDetailsPage({required VisitedCity this.city, super.key})
    : catalogCity = null;

  const CityDetailsPage.fromCatalog({required City city, super.key})
    : catalogCity = city,
      city = null;

  final VisitedCity? city;
  final City? catalogCity;

  int get cityId => catalogCity?.id ?? city!.cityId;

  String get cityName => catalogCity?.name ?? city!.cityName;

  String get countryName => catalogCity?.countryName ?? city!.countryName;
  String get countryCode => catalogCity?.countryCode ?? city!.countryCode;

  VisitedCity? _findVisitedCity(VisitedCitiesState state) {
    for (final visitedCity in state.visitedCities) {
      if (visitedCity.cityId == cityId) {
        return visitedCity;
      }
    }

    return null;
  }

  Future<void> _editWishlistNote(
    BuildContext context,
    WishlistEntry entry,
  ) async {
    final wishlistCubit = context.read<WishlistCubit>();

    final updated = await showEditWishlistNote(context: context, entry: entry);

    if (!updated || !context.mounted || wishlistCubit.isClosed) return;

    await wishlistCubit.refresh();
  }

  Future<void> _refreshDetails(BuildContext context) async {
    final visitedCitiesCubit = context.read<VisitedCitiesCubit>();
    final cityTripsCubit = context.read<CityTripsCubit>();

    await Future.wait([
      if (!visitedCitiesCubit.isClosed) visitedCitiesCubit.load(),
      if (!cityTripsCubit.isClosed) cityTripsCubit.refresh(),
    ]);
  }

  Future<void> _openTripDetails(BuildContext context, Trip trip) async {
    final cityTripsCubit = context.read<CityTripsCubit>();

    final tripRepository = context.read<TripRepository>();

    final tripAssociationRepository = context.read<TripAssociationRepository>();

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<TripRepository>.value(value: tripRepository),
            RepositoryProvider<TripAssociationRepository>.value(
              value: tripAssociationRepository,
            ),
          ],
          child: TripDetailsPage(tripId: trip.id),
        ),
      ),
    );

    if (!context.mounted || cityTripsCubit.isClosed) return;

    await cityTripsCubit.refresh();
  }

  Future<void> _removeFromWishlist(
    BuildContext context,
    WishlistEntry entry,
  ) async {
    final wishlistCubit = context.read<WishlistCubit>();

    final removed = await showRemoveWishlistEntry(
      context: context,
      entry: entry,
      destinationName: cityName,
    );

    if (!removed || !context.mounted || wishlistCubit.isClosed) return;

    await wishlistCubit.refresh();
  }

  Future<void> _editVisit(
    BuildContext context,
    VisitedCity visitedCity,
    CityVisit visit,
  ) async {
    final updated = await showEditCityVisit(
      context,
      city: visitedCity,
      visit: visit,
    );

    if (!updated || !context.mounted) return;

    await context.read<VisitedCitiesCubit>().load();
  }

  Future<void> _deleteVisit(
    BuildContext context,
    VisitedCity visitedCity,
    CityVisit visit,
  ) async {
    final deleted = await showDeleteCityVisit(
      context,
      city: visitedCity,
      visit: visit,
    );

    if (!deleted || !context.mounted) return;

    final cubit = context.read<VisitedCitiesCubit>();

    await cubit.load();

    if (!context.mounted) return;

    // Preserve existing navigation behavior for legacy visit-only details.
    //
    // Catalog-based details remain accessible when the last visit is
    // deleted, because the destination may still be Lived or Wish.
    if (catalogCity == null &&
        cubit.state.hasData &&
        cubit.state.visitsForCity(cityId).isEmpty) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showResidences(BuildContext context) async {
    await showResidences(
      context: context,
      destinationName: cityName,
      countryCode: countryCode,
      cityId: cityId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return BlocProvider<CityTripsCubit>(
      create: (context) => CityTripsCubit(
        repository: context.read<TripRepository>(),

        cityId: cityId,
      )..load(),

      child: Scaffold(
        appBar: AppBar(
          title: Text(cityName, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: BlocBuilder<VisitedCitiesCubit, VisitedCitiesState>(
          builder: (context, state) {
            final residencesState = catalogCity != null
                ? context.watch<ResidencesCubit>().state
                : null;

            final wishlistState = catalogCity != null
                ? context.watch<WishlistCubit>().state
                : null;

            final visits = state.visitsForCity(cityId).toList()
              ..sort(_compareVisits);

            final visitedCity = _findVisitedCity(state);

            final lastVisited = _lastVisitedDate(visits);

            final hasLived =
                residencesState?.residencesForCity(cityId).isNotEmpty ?? false;

            final wishlistEntry = wishlistState?.entryForCity(cityId);

            final cityTripsState = context.watch<CityTripsCubit>().state;

            return RefreshIndicator(
              onRefresh: () => _refreshDetails(context),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ---------------------------------------------------
                          // City identity
                          // ---------------------------------------------------
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  Icons.location_city_rounded,
                                  color: colors.primary,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cityName,
                                      key: const Key('cityDetailsName'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      countryName,
                                      key: const Key('cityDetailsCountry'),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ---------------------------------------------------
                          // Travel statuses
                          // ---------------------------------------------------
                          Wrap(
                            key: const Key('cityTravelStatuses'),
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (visits.isNotEmpty)
                                Chip(
                                  key: const Key('cityStatus-been'),
                                  avatar: Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 18,
                                    color: colors.primary,
                                  ),
                                  label: Text(
                                    '${visits.length} '
                                    '${visits.length == 1 ? 'visit' : 'visits'}',
                                  ),
                                )
                              else
                                Chip(
                                  key: const Key('cityStatus-notVisited'),
                                  avatar: Icon(
                                    Icons.radio_button_unchecked_rounded,
                                    size: 18,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  label: const Text('Not visited'),
                                ),

                              if (hasLived)
                                ActionChip(
                                  key: const Key('cityStatus-lived'),
                                  tooltip: 'Manage residences',
                                  avatar: Icon(
                                    Icons.home_rounded,
                                    color: colors.primary,
                                    size: 18,
                                  ),
                                  label: const Text('Lived'),
                                  backgroundColor: colors.primaryContainer,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  onPressed: () => _showResidences(context),
                                ),

                              if (wishlistEntry != null)
                                WishlistEntryControls(
                                  onRemove: () => _removeFromWishlist(
                                    context,
                                    wishlistEntry,
                                  ),
                                  onEditNote: () =>
                                      _editWishlistNote(context, wishlistEntry),
                                ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ---------------------------------------------------
                          // Statistics
                          // ---------------------------------------------------
                          _CityStatistics(
                            visitCount: visits.length,
                            tripCount: cityTripsState.isReady
                                ? '${cityTripsState.tripCount}'
                                : '—',
                            lastVisited: lastVisited,
                          ),

                          const SizedBox(height: 28),

                          // ---------------------------------------------------
                          // Visit history
                          // ---------------------------------------------------
                          _CityTabsAndHistory(
                            visits: visits,
                            visitedCity: visitedCity,
                            tripsState: cityTripsState,
                            onRetryTrips: () {
                              context.read<CityTripsCubit>().refresh();
                            },
                            onTripSelected: (trip) {
                              _openTripDetails(context, trip);
                            },
                            onEdit: (city, visit) =>
                                _editVisit(context, city, visit),
                            onDelete: (city, visit) =>
                                _deleteVisit(context, city, visit),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static int _compareVisits(CityVisit a, CityVisit b) {
    final aDate = a.startedOn ?? a.endedOn;
    final bDate = b.startedOn ?? b.endedOn;

    if (aDate == null && bDate == null) {
      return b.createdAt.compareTo(a.createdAt);
    }

    if (aDate == null) return 1;
    if (bDate == null) return -1;

    final comparison = bDate.compareTo(aDate);

    if (comparison != 0) return comparison;

    return b.createdAt.compareTo(a.createdAt);
  }

  static DateTime? _lastVisitedDate(List<CityVisit> visits) {
    DateTime? latest;

    for (final visit in visits) {
      final date = visit.endedOn ?? visit.startedOn;

      if (date == null) continue;

      if (latest == null || date.isAfter(latest)) {
        latest = date;
      }
    }

    return latest;
  }
}

class _CityTabsAndHistory extends StatefulWidget {
  const _CityTabsAndHistory({
    required this.visits,
    required this.visitedCity,
    required this.onEdit,
    required this.onDelete,
    required this.tripsState,
    required this.onRetryTrips,
    required this.onTripSelected,
  });

  final List<CityVisit> visits;
  final VisitedCity? visitedCity;
  final CityTripsState tripsState;
  final VoidCallback onRetryTrips;
  final ValueChanged<Trip> onTripSelected;

  final void Function(VisitedCity city, CityVisit visit) onEdit;
  final void Function(VisitedCity city, CityVisit visit) onDelete;

  @override
  State<_CityTabsAndHistory> createState() => _CityTabsAndHistoryState();
}

class _CityTabsAndHistoryState extends State<_CityTabsAndHistory> {
  _CityTab _selectedTab = _CityTab.overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTabs(context),

        const SizedBox(height: 24),

        switch (_selectedTab) {
          _CityTab.overview => _CityVisitHistory(
            visits: widget.visits.take(3).toList(),
            visitedCity: widget.visitedCity,
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
            showViewAll: widget.visits.length > 3,
            onViewAll: () {
              setState(() {
                _selectedTab = _CityTab.visits;
              });
            },
          ),

          _CityTab.visits => _CityVisitHistory(
            visits: widget.visits,
            visitedCity: widget.visitedCity,
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
          ),

          _CityTab.trips => _CityAssociatedTrips(
            state: widget.tripsState,
            onRetry: widget.onRetryTrips,
            onTripSelected: widget.onTripSelected,
          ),
        },
      ],
    );
  }

  Widget _buildTabs(BuildContext context) {
    return DestinationDetailsTabs(
      key: const Key('cityDetailsTabs'),
      labels: const ['Overview', 'Visits', 'Trips'],
      selectedIndex: _selectedTab.index,
      tabKeyPrefix: 'cityTab',
      onSelected: (index) {
        setState(() {
          _selectedTab = _CityTab.values[index];
        });
      },
    );
  }
}

class _CityVisitHistory extends StatelessWidget {
  const _CityVisitHistory({
    required this.visits,
    required this.visitedCity,
    required this.onEdit,
    required this.onDelete,
    this.showViewAll = false,
    this.onViewAll,
  });

  final List<CityVisit> visits;
  final VisitedCity? visitedCity;

  final void Function(VisitedCity city, CityVisit visit) onEdit;
  final void Function(VisitedCity city, CityVisit visit) onDelete;

  final bool showViewAll;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      key: const Key('cityVisitHistory'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Visit History',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            if (showViewAll)
              TextButton(
                key: const Key('cityVisitsViewAll'),
                onPressed: onViewAll,
                child: const Text('View all'),
              ),
          ],
        ),

        const SizedBox(height: 16),

        if (visits.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No visits recorded for this city.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < visits.length; index++) ...[
                  ListTile(
                    key: Key('cityVisit-${visits[index].id}'),
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text('Visit ${index + 1}'),
                    subtitle: Text(_formatVisitDates(visits[index])),
                    trailing: AdaptiveRecordActionsMenu(
                      key: Key('cityVisitMenu-${visits[index].id}'),
                      tooltip: 'Visit actions',
                      editLabel: 'Edit visit',
                      deleteLabel: 'Delete visit',
                      onEdit: () {
                        final city = visitedCity;
                        if (city == null) return;

                        onEdit(city, visits[index]);
                      },
                      onDelete: () {
                        final city = visitedCity;
                        if (city == null) return;

                        onDelete(city, visits[index]);
                      },
                    ),
                  ),

                  if (index < visits.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CityStatistics extends StatelessWidget {
  const _CityStatistics({
    required this.visitCount,
    required this.tripCount,
    required this.lastVisited,
  });

  final int visitCount;
  final String tripCount;
  final DateTime? lastVisited;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      key: const Key('cityStatistics'),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: _CityStatItem(
                    value: '$visitCount',
                    label: 'VISITS',
                    key: const Key('cityVisitsStatistic'),
                  ),
                ),

                Container(width: 1, height: 40, color: colors.outlineVariant),

                Expanded(
                  child: _CityStatItem(
                    value: tripCount,
                    label: 'TRIPS',
                    key: const Key('cityTripsStatistic'),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            thickness: 1,
            color: colors.outline.withValues(alpha: 0.18),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'LAST VISITED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    lastVisited == null ? '—' : _formatDate(lastVisited!),
                    key: const Key('cityLastVisited'),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CityStatItem extends StatelessWidget {
  const _CityStatItem({required this.value, required this.label, super.key});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _CityAssociatedTrips extends StatelessWidget {
  const _CityAssociatedTrips({
    required this.state,
    required this.onRetry,
    required this.onTripSelected,
  });

  final CityTripsState state;
  final VoidCallback onRetry;
  final ValueChanged<Trip> onTripSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (state.isInitial || state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(key: Key('cityTripsLoading')),
        ),
      );
    }

    if (state.isFailure) {
      return Card(
        key: const Key('cityTripsError'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded, color: colors.error, size: 32),
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? 'Unable to load associated trips.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('cityTripsRetry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.trips.isEmpty) {
      return Card(
        key: const Key('cityTripsEmpty'),
        margin: EdgeInsets.zero,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text('No associated trips yet', textAlign: TextAlign.center),
        ),
      );
    }

    return Column(
      key: const Key('cityAssociatedTrips'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ASSOCIATED TRIPS',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        for (final trip in state.trips)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              key: Key('cityTrip-${trip.id}'),
              leading: Icon(Icons.luggage_rounded, color: colors.primary),
              title: Text(
                trip.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                trip.description?.trim().isNotEmpty == true
                    ? trip.description!
                    : 'Trip details',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onTripSelected(trip),
            ),
          ),
      ],
    );
  }
}

String _formatVisitDates(CityVisit visit) {
  final start = visit.startedOn;
  final end = visit.endedOn;

  if (start == null && end == null) {
    return 'Dates not specified';
  }

  if (start != null && end == null) {
    return 'From ${_formatDate(start)}';
  }

  if (start == null && end != null) {
    return 'Until ${_formatDate(end)}';
  }

  return '${_formatDate(start!)} – ${_formatDate(end!)}';
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
