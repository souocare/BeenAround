import 'package:beenaround/app/theme/app_action_icons.dart';
import 'package:beenaround/core/models/partial_visit_date.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/core/widgets/adaptive_record_actions_menu.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/residences/application/residences_cubit.dart';
import 'package:beenaround/features/residences/presentation/widgets/show_residences.dart';
import 'package:beenaround/features/wishlist/application/wishlist_cubit.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry.dart';
import 'package:beenaround/features/wishlist/presentation/widgets/show_remove_wishlist_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/explore_cubit.dart';
import '../../application/explore_state.dart';
import '../../domain/country.dart';
import '../../domain/country_visit.dart';

import 'package:beenaround/app/widgets/country_flag.dart';
import '../widgets/show_add_destination.dart';
import '../widgets/show_delete_country_visit.dart';
import '../widgets/show_edit_country_visit.dart';
import '../../../map/presentation/widgets/country_map.dart';
import '../../../wishlist/presentation/widgets/wishlist_entry_controls.dart';
import '../../../wishlist/presentation/widgets/show_edit_wishlist_note.dart';
import '../../application/visited_cities_cubit.dart';
import '../../application/visited_cities_state.dart';
import '../../../geography/domain/city_visits_repository.dart';
import '../../../residences/domain/residence_repository.dart';
import '../../../wishlist/domain/wishlist_repository.dart';
import '../../application/country_trips_cubit.dart';
import '../../application/country_trips_state.dart';

import '../../../trips/domain/trip.dart';
import '../../../trips/domain/trip_repository.dart';
import '../../../trips/domain/trip_association_repository.dart';
import '../../../trips/presentation/pages/trip_details_page.dart';

import 'city_details_page.dart';

import '../../domain/visited_city.dart';
import '../widgets/destination_details_tabs.dart';
import '../../../trips/presentation/navigation/open_trip_details.dart';

enum _CountryTab { overview, visits, cities, trips }

class CountryDetailsPage extends StatefulWidget {
  const CountryDetailsPage({required this.country, super.key});

  final Country country;

  @override
  State<CountryDetailsPage> createState() => _CountryDetailsPageState();
}

class _CountryDetailsPageState extends State<CountryDetailsPage> {
  _CountryTab _selectedTab = _CountryTab.overview;

  Future<void> _addVisit() async {
    final created = await showAddDestination(
      context,
      initialCountry: widget.country,
    );

    if (!mounted || !created) return;

    await _refreshDetails();
  }

  Future<void> _editWishlistNote(WishlistEntry entry) async {
    final wishlistCubit = context.read<WishlistCubit>();

    final updated = await showEditWishlistNote(context: context, entry: entry);

    if (!updated || !mounted || wishlistCubit.isClosed) return;

    await wishlistCubit.refresh();
  }

  Future<void> _editVisit(CountryVisit visit) async {
    final exploreCubit = context.read<ExploreCubit>();

    final updated = await showEditCountryVisit(
      context,
      country: widget.country,
      visit: visit,
    );

    if (updated && !exploreCubit.isClosed) {
      await exploreCubit.refresh();
    }
  }

  Future<void> _deleteVisit(CountryVisit visit) async {
    final exploreCubit = context.read<ExploreCubit>();

    final deleted = await showDeleteCountryVisit(
      context,
      country: widget.country,
      visit: visit,
    );

    if (deleted && !exploreCubit.isClosed) {
      await exploreCubit.refresh();
    }
  }

  Future<void> _removeFromWishlist(WishlistEntry entry) async {
    final wishlistCubit = context.read<WishlistCubit>();

    final removed = await showRemoveWishlistEntry(
      context: context,
      entry: entry,
      destinationName: widget.country.name,
    );

    if (!removed || !mounted || wishlistCubit.isClosed) return;

    await wishlistCubit.refresh();
  }

  Future<void> _showResidences() async {
    await showResidences(
      context: context,
      destinationName: widget.country.name,
      countryCode: widget.country.code,
    );
  }

  Future<void> _refreshDetails() async {
    final exploreCubit = context.read<ExploreCubit>();
    final visitedCitiesCubit = context.read<VisitedCitiesCubit>();
    final residencesCubit = context.read<ResidencesCubit>();
    final wishlistCubit = context.read<WishlistCubit>();
    final countryTripsCubit = context.read<CountryTripsCubit>();

    await Future.wait([
      if (!exploreCubit.isClosed) exploreCubit.refresh(),
      if (!visitedCitiesCubit.isClosed) visitedCitiesCubit.load(),
      if (!residencesCubit.isClosed) residencesCubit.refresh(),
      if (!wishlistCubit.isClosed) wishlistCubit.refresh(),
      if (!countryTripsCubit.isClosed) countryTripsCubit.refresh(),
    ]);
  }

  Future<void> _openTripDetails(Trip trip) async {
    final countryTripsCubit = context.read<CountryTripsCubit>();

    await openTripDetails(context, tripId: trip.id);

    if (!mounted || countryTripsCubit.isClosed) {
      return;
    }

    await countryTripsCubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      // appBar: AppBar(
      //   title: Text(
      //     widget.country.name,
      //     maxLines: 1,
      //     overflow: TextOverflow.ellipsis,
      //   ),
      // ),
      appBar: AppBar(),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add country visit',
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        onPressed: _addVisit,
        child: Icon(AppActionIcons.add(context)),
      ),
      body: BlocBuilder<ExploreCubit, ExploreState>(
        builder: (context, state) {
          final visits = state.visitsForCountry(widget.country.code).toList()
            ..sort(_compareVisits);
          final visitedCitiesState = context.watch<VisitedCitiesCubit>().state;
          final countryTripsState = context.watch<CountryTripsCubit>().state;

          final countryCities = visitedCitiesState.visitedCities
              .where((city) => city.countryCode == widget.country.code)
              .toList();
          final wishlistState = context.watch<WishlistCubit>().state;

          final wishlistEntry = wishlistState.entryForCountry(
            widget.country.code,
          );

          final residencesState = context.watch<ResidencesCubit>().state;

          final countryResidences = residencesState.residencesForCountry(
            widget.country.code,
          );

          final hasLived = countryResidences.isNotEmpty;

          final isVisited = visits.isNotEmpty;
          final lastVisited = _lastVisitedDate(visits);

          return RefreshIndicator(
            onRefresh: _refreshDetails,
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
                        _CountryHeader(
                          country: widget.country,
                          isVisited: isVisited,
                          visitCount: visits.length,
                        ),

                        if (hasLived || wishlistEntry != null) ...[
                          const SizedBox(height: 12),

                          Wrap(
                            key: const Key('countryTravelStatuses'),
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (hasLived)
                                ActionChip(
                                  key: const Key('countryStatus-lived'),
                                  tooltip: 'Manage residences',
                                  avatar: const Icon(
                                    Icons.home_rounded,
                                    size: 20,
                                  ),
                                  label: const Text('Lived'),
                                  onPressed: _showResidences,
                                ),

                              if (wishlistEntry != null)
                                WishlistEntryControls(
                                  onRemove: () =>
                                      _removeFromWishlist(wishlistEntry),
                                  onEditNote: () =>
                                      _editWishlistNote(wishlistEntry),
                                ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Country map will be integrated here.
                        CountryMap(
                          countryCode: widget.country.code,
                          isVisited: isVisited,
                        ),

                        const SizedBox(height: 20),

                        _CountryStatistics(
                          visitCount: visits.length,
                          cityCount: countryCities.length,
                          tripCount: countryTripsState.isReady
                              ? '${countryTripsState.tripCount}'
                              : '—',
                          lastVisited: lastVisited,
                        ),

                        const SizedBox(height: 28),

                        DestinationDetailsTabs(
                          key: const Key('countryDetailsTabs'),
                          labels: const [
                            'Overview',
                            'Visits',
                            'Cities',
                            'Trips',
                          ],
                          selectedIndex: _selectedTab.index,
                          onSelected: (index) {
                            setState(() {
                              _selectedTab = _CountryTab.values[index];
                            });
                          },
                        ),

                        const SizedBox(height: 24),

                        switch (_selectedTab) {
                          _CountryTab.overview => _VisitHistory(
                            visits: visits.take(3).toList(),
                            onEdit: _editVisit,
                            onDelete: _deleteVisit,
                            showViewAll: visits.length > 3,
                            onViewAll: () {
                              setState(() {
                                _selectedTab = _CountryTab.visits;
                              });
                            },
                          ),

                          _CountryTab.visits => _VisitHistory(
                            visits: visits,
                            onEdit: _editVisit,
                            onDelete: _deleteVisit,
                          ),

                          _CountryTab.cities => _CountryVisitedCities(
                            cities: countryCities,
                            onCitySelected: _openCityDetails,
                          ),

                          _CountryTab.trips => _CountryAssociatedTrips(
                            state: countryTripsState,
                            onRetry: () {
                              context.read<CountryTripsCubit>().refresh();
                            },
                            onTripSelected: _openTripDetails,
                          ),
                        },
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static int _compareVisits(CountryVisit a, CountryVisit b) {
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

  static DateTime? _lastVisitedDate(List<CountryVisit> visits) {
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

  void _openCityDetails(VisitedCity city) {
    final visitedCitiesCubit = context.read<VisitedCitiesCubit>();
    final residencesCubit = context.read<ResidencesCubit>();
    final wishlistCubit = context.read<WishlistCubit>();

    final cityVisitsRepository = context.read<CityVisitsRepository>();
    final countriesRepository = context.read<CountriesRepository>();
    final wishlistRepository = context.read<WishlistRepository>();
    final residenceRepository = context.read<ResidenceRepository>();
    final tripRepository = context.read<TripRepository>();

    final tripAssociationRepository = context.read<TripAssociationRepository>();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<CityVisitsRepository>.value(
              value: cityVisitsRepository,
            ),
            RepositoryProvider<CountriesRepository>.value(
              value: countriesRepository,
            ),
            RepositoryProvider<WishlistRepository>.value(
              value: wishlistRepository,
            ),
            RepositoryProvider<ResidenceRepository>.value(
              value: residenceRepository,
            ),
            RepositoryProvider<TripRepository>.value(value: tripRepository),

            RepositoryProvider<TripAssociationRepository>.value(
              value: tripAssociationRepository,
            ),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<VisitedCitiesCubit>.value(value: visitedCitiesCubit),
              BlocProvider<ResidencesCubit>.value(value: residencesCubit),
              BlocProvider<WishlistCubit>.value(value: wishlistCubit),
            ],
            child: CityDetailsPage(city: city),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Country header
// -----------------------------------------------------------------------------

class _CountryHeader extends StatelessWidget {
  const _CountryHeader({
    required this.country,
    required this.isVisited,
    required this.visitCount,
  });

  final Country country;
  final bool isVisited;
  final int visitCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 480;

        final identity = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CountryFlag(countryCode: country.code, size: compact ? 52 : 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    country.name,
                    key: const Key('countryDetailsName'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    country.alpha3Code,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final metadata = Wrap(
          key: const Key('countryDetailsMetadata'),
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              country.continent,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVisited
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: isVisited ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  isVisited ? 'Visited' : 'Not visited',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isVisited ? colors.primary : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              '$visitCount ${visitCount == 1 ? 'visit' : 'visits'}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [identity, const SizedBox(height: 16), metadata],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: identity),
            const SizedBox(width: 24),
            Flexible(
              child: Align(alignment: Alignment.centerRight, child: metadata),
            ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Map placeholder
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Statistics
// -----------------------------------------------------------------------------

class _CountryStatistics extends StatelessWidget {
  const _CountryStatistics({
    required this.visitCount,
    required this.cityCount,
    required this.tripCount,
    required this.lastVisited,
  });

  final int visitCount;
  final int cityCount;
  final String tripCount;
  final DateTime? lastVisited;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _CountryStatItem(
                    value: '$visitCount',
                    label: 'VISITS',
                  ),
                ),

                _StatDivider(color: colors.outlineVariant),

                Expanded(
                  child: _CountryStatItem(value: '$cityCount', label: 'CITIES'),
                ),

                _StatDivider(color: colors.outlineVariant),

                Expanded(
                  child: KeyedSubtree(
                    key: const Key('countryTripsStatistic'),
                    child: _CountryStatItem(value: tripCount, label: 'TRIPS'),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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

                const Spacer(),

                Text(
                  lastVisited == null
                      ? '—'
                      : _formatStatisticsDate(lastVisited!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
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

class _CountryStatItem extends StatelessWidget {
  const _CountryStatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 2),

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

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(height: 32, width: 1, color: color.withValues(alpha: 0.5));
  }
}

// -----------------------------------------------------------------------------
// Visit history
// -----------------------------------------------------------------------------

class _VisitHistory extends StatelessWidget {
  const _VisitHistory({
    required this.visits,
    required this.onEdit,
    required this.onDelete,
    this.showViewAll = false,
    this.onViewAll,
  });

  final List<CountryVisit> visits;
  final ValueChanged<CountryVisit> onEdit;
  final ValueChanged<CountryVisit> onDelete;
  final bool showViewAll;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            const SizedBox(width: 10),

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
                onPressed: onViewAll,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View All Visits'),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        if (visits.isEmpty)
          const _EmptySection(
            icon: Icons.event_busy_outlined,
            title: 'No visits recorded for this country.',
            message: 'Add your first visit to start your travel history.',
          )
        else
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outline.withValues(alpha: 0.18)),
            ),
            child: Column(
              children: [
                for (var index = 0; index < visits.length; index++) ...[
                  _VisitCard(
                    visit: visits[index],
                    number: index + 1,
                    onEdit: () => onEdit(visits[index]),
                    onDelete: () => onDelete(visits[index]),
                  ),

                  if (index < visits.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 16,
                      endIndent: 16,
                      color: colors.outline.withValues(alpha: 0.25),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.visit,
    required this.number,
    required this.onEdit,
    required this.onDelete,
  });

  final CountryVisit visit;
  final int number;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              color: colors.primary,
              size: 21,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visit $number',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _formatVisitDates(visit),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          AdaptiveRecordActionsMenu(
            tooltip: 'Visit actions',
            editLabel: 'Edit visit',
            deleteLabel: 'Delete visit',
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Empty states
// -----------------------------------------------------------------------------

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icon, size: 32, color: colors.onSurfaceVariant),

            const SizedBox(height: 14),

            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryVisitedCities extends StatelessWidget {
  const _CountryVisitedCities({
    required this.cities,
    required this.onCitySelected,
  });

  final List<VisitedCity> cities;
  final ValueChanged<VisitedCity> onCitySelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (cities.isEmpty) {
      return const _EmptySection(
        icon: Icons.location_city_outlined,
        title: 'No visited cities yet',
        message: 'Cities you visit in this country will appear here.',
      );
    }

    return Column(
      key: const Key('countryVisitedCities'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VISITED CITIES',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),

        const SizedBox(height: 12),

        for (final city in cities) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              key: Key('countryVisitedCity-${city.cityId}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Icon(
                Icons.location_city_outlined,
                color: colors.primary,
              ),
              title: Text(
                city.cityName,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${city.visitCount} ${city.visitCount == 1 ? 'visit' : 'visits'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onCitySelected(city),
            ),
          ),
        ],
      ],
    );
  }
}

class _CountryAssociatedTrips extends StatelessWidget {
  const _CountryAssociatedTrips({
    required this.state,
    required this.onRetry,
    required this.onTripSelected,
  });

  final CountryTripsState state;
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
          child: CircularProgressIndicator(key: Key('countryTripsLoading')),
        ),
      );
    }

    if (state.isFailure) {
      return Card(
        key: const Key('countryTripsError'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded, size: 32, color: colors.error),
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? 'Unable to load associated trips.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('countryTripsRetry'),
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
      return const _EmptySection(
        icon: Icons.luggage_outlined,
        title: 'No associated trips yet',
        message: 'Trips containing visits to this country will appear here.',
      );
    }

    return Column(
      key: const Key('countryAssociatedTrips'),
      crossAxisAlignment: CrossAxisAlignment.start,
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
              key: Key('countryTrip-${trip.id}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
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
                _formatCountryTripDates(context, trip),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onTripSelected(trip),
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Date formatting
// -----------------------------------------------------------------------------

String _formatVisitDates(CountryVisit visit) {
  final start = visit.startedOn;
  final end = visit.endedOn;

  if (start == null && end == null) {
    return 'Dates not specified';
  }

  if (start != null && end == null) {
    return 'From ${_formatStatisticsDate(start)}';
  }

  if (start == null && end != null) {
    return 'Until ${_formatStatisticsDate(end)}';
  }

  if (start!.year == end!.year && start.month == end.month) {
    return '${start.day}–${end.day} '
        '${_formatStatisticsDate(end).split(' ').skip(1).join(' ')}';
  }

  return '${_formatStatisticsDate(start)} – '
      '${_formatStatisticsDate(end)}';
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '$day/$month/${date.year}';
}

String _formatStatisticsDate(DateTime date) {
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

String _formatCountryTripDates(BuildContext context, Trip trip) {
  String formatDate(PartialVisitDate value) {
    final localization = MaterialLocalizations.of(context);

    return switch (value.precision) {
      VisitDatePrecision.day => localization.formatMediumDate(value.date),
      VisitDatePrecision.month => localization.formatMonthYear(value.date),
      VisitDatePrecision.year => '${value.date.year}',
    };
  }

  final start = trip.startedOn;
  final end = trip.endedOn;

  if (start == null && end == null) {
    return 'Dates not specified';
  }

  if (start != null && end == null) {
    return 'From ${formatDate(start)}';
  }

  if (start == null && end != null) {
    return 'Until ${formatDate(end)}';
  }

  return '${formatDate(start!)} – ${formatDate(end!)}';
}
