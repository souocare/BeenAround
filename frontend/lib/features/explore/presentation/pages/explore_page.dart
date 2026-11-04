import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/widgets/app_empty_state.dart';
import '../../../../app/widgets/app_error_state.dart';
import '../../../../app/widgets/app_loading_state.dart';
import '../../../geography/domain/city_repository.dart';
import '../../../geography/domain/city_visits_repository.dart';
import '../../../map/presentation/widgets/world_overview_map.dart';
import '../../../residences/application/residences_cubit.dart';
import '../../../residences/application/residences_state.dart';
import '../../../residences/domain/residence_repository.dart';
import '../../../wishlist/application/wishlist_cubit.dart';
import '../../../wishlist/application/wishlist_state.dart';
import '../../../wishlist/domain/wishlist_repository.dart';
import '../../application/country_visit_summary.dart';
import '../../application/explore_cities_cubit.dart';
import '../../application/explore_cities_state.dart';
import '../../application/explore_countries_filter.dart';
import '../../application/explore_country_aggregation.dart';
import '../../application/explore_country_summary.dart';
import '../../application/explore_cubit.dart';
import '../../application/explore_destination_filter.dart';
import '../../application/explore_state.dart';
import '../../application/visited_cities_cubit.dart';
import '../../application/visited_cities_state.dart';
import '../../domain/country.dart';
import '../widgets/country_flag.dart';
import '../widgets/show_add_destination.dart';
import '../widgets/visited_cities_list.dart';
import 'country_details_page.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<VisitedCitiesCubit>(
          create: (context) => VisitedCitiesCubit(
            repository: context.read<CityVisitsRepository>(),
          )..load(),
        ),
        BlocProvider<ResidencesCubit>(
          create: (context) =>
              ResidencesCubit(repository: context.read<ResidenceRepository>())
                ..load(),
        ),
        BlocProvider<WishlistCubit>(
          create: (context) =>
              WishlistCubit(repository: context.read<WishlistRepository>())
                ..load(),
        ),
        BlocProvider<ExploreCitiesCubit>(
          create: (context) => ExploreCitiesCubit(
            cityRepository: context.read<CityRepository>(),
          ),
        ),
      ],
      child: const _ExploreView(),
    );
  }
}

class _ExploreView extends StatefulWidget {
  const _ExploreView();

  @override
  State<_ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<_ExploreView> {
  VisitedCitiesState? _lastAggregatedVisits;
  ResidencesState? _lastAggregatedResidences;
  WishlistState? _lastAggregatedWishlist;
  final ScrollController _scrollController = ScrollController();

  bool _showFloatingAddButton = false;
  double? _headerButtonExitOffset;

  static const double _mobileBreakpoint = 800;

  final GlobalKey _headerAddButtonKey = GlobalKey();

  void _updateFloatingAddButton() {
    if (!_scrollController.hasClients) return;

    final buttonContext = _headerAddButtonKey.currentContext;
    if (buttonContext == null) return;

    final buttonRenderObject = buttonContext.findRenderObject();

    if (buttonRenderObject is! RenderBox || !buttonRenderObject.attached) {
      return;
    }

    final scrollOffset = _scrollController.offset;

    final buttonBottomInContent =
        buttonRenderObject.localToGlobal(Offset.zero).dy +
        buttonRenderObject.size.height +
        scrollOffset;

    _headerButtonExitOffset ??= buttonBottomInContent;

    final shouldShow = scrollOffset >= _headerButtonExitOffset! - 12;

    if (shouldShow != _showFloatingAddButton && mounted) {
      setState(() {
        _showFloatingAddButton = shouldShow;
      });
    }
  }

  void _synchronizeExploreCities() {
    if (!mounted) return;

    final visitedCities = context.read<VisitedCitiesCubit>().state;
    final residences = context.read<ResidencesCubit>().state;
    final wishlist = context.read<WishlistCubit>().state;
    final exploreCitiesCubit = context.read<ExploreCitiesCubit>();

    if (exploreCitiesCubit.isClosed) return;

    final allReady =
        visitedCities.phase == VisitedCitiesPhase.ready &&
        residences.phase == ResidencesPhase.ready &&
        wishlist.phase == WishlistPhase.ready;

    if (!allReady) {
      _lastAggregatedVisits = null;
      _lastAggregatedResidences = null;
      _lastAggregatedWishlist = null;

      if (exploreCitiesCubit.state.phase != ExploreCitiesPhase.initial) {
        unawaited(
          exploreCitiesCubit.load(
            visitedCities: visitedCities,
            residences: residences,
            wishlist: wishlist,
          ),
        );
      }
      return;
    }

    final unchanged =
        identical(_lastAggregatedVisits, visitedCities) &&
        identical(_lastAggregatedResidences, residences) &&
        identical(_lastAggregatedWishlist, wishlist);

    if (unchanged) return;

    _lastAggregatedVisits = visitedCities;
    _lastAggregatedResidences = residences;
    _lastAggregatedWishlist = wishlist;

    unawaited(
      exploreCitiesCubit.load(
        visitedCities: visitedCities,
        residences: residences,
        wishlist: wishlist,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateFloatingAddButton);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _synchronizeExploreCities();
    });
  }

  Future<void> _refreshExploreData() async {
    final exploreCubit = context.read<ExploreCubit>();
    final visitedCitiesCubit = context.read<VisitedCitiesCubit>();
    final residencesCubit = context.read<ResidencesCubit>();
    final wishlistCubit = context.read<WishlistCubit>();

    await Future.wait([
      if (!exploreCubit.isClosed) exploreCubit.refresh(),
      if (!visitedCitiesCubit.isClosed) visitedCitiesCubit.load(),
      if (!residencesCubit.isClosed) residencesCubit.refresh(),
      if (!wishlistCubit.isClosed) wishlistCubit.refresh(),
    ]);
  }

  Future<void> _addDestination() async {
    final created = await showAddDestination(context);
    if (!created || !mounted) return;
    await _refreshExploreData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<VisitedCitiesCubit, VisitedCitiesState>(
          listener: (context, state) => _synchronizeExploreCities(),
        ),
        BlocListener<ResidencesCubit, ResidencesState>(
          listener: (context, state) => _synchronizeExploreCities(),
        ),
        BlocListener<WishlistCubit, WishlistState>(
          listener: (context, state) => _synchronizeExploreCities(),
        ),
      ],
      child: BlocBuilder<ExploreCubit, ExploreState>(
        builder: (context, state) {
          if (state.phase == ExplorePhase.initial ||
              (state.phase == ExplorePhase.loading &&
                  !state.hasData &&
                  state.countries.isEmpty &&
                  state.visits.isEmpty)) {
            return const AppLoadingState(
              message: 'Loading your travel history...',
            );
          }

          if (state.phase == ExplorePhase.failure &&
              state.countries.isEmpty &&
              state.visits.isEmpty) {
            return AppErrorState(
              title: 'Unable to load Explore',
              message:
                  state.errorMessage ??
                  'Something went wrong while loading your travel history.',
              onRetry: context.read<ExploreCubit>().load,
            );
          }

          final isMobile = MediaQuery.sizeOf(context).width < _mobileBreakpoint;
          final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
          final floatingButtonBottom = isIOS ? 60.0 : 20.0;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _updateFloatingAddButton();
          });

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: _refreshExploreData,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      sliver: SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 960),
                            child: _ExploreContent(
                              state: state,
                              onAddDestination: _addDestination,
                              addButtonKey: _headerAddButtonKey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isMobile)
                Positioned(
                  right: 20,
                  bottom: floatingButtonBottom,
                  child: AnimatedScale(
                    scale: _showFloatingAddButton ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: _showFloatingAddButton ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: IgnorePointer(
                        ignoring: !_showFloatingAddButton,
                        child: FloatingActionButton(
                          key: const Key('exploreFloatingAddButton'),
                          tooltip: 'Add Destination',
                          heroTag: 'exploreFloatingAddButton',
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          onPressed: _addDestination,
                          child: const Icon(Icons.add_rounded, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A consistent, fully loaded country presentation snapshot.
///
/// Aggregated statuses and visit summaries always originate
/// from the same set of ready source states.
class _CountryTravelSnapshot {
  const _CountryTravelSnapshot({
    required this.entries,
    required this.visitSummaries,
  });

  final List<ExploreCountryEntry> entries;

  final Map<String, CountryVisitSummary> visitSummaries;
}

class _ExploreContent extends StatefulWidget {
  const _ExploreContent({
    required this.state,
    required this.onAddDestination,
    required this.addButtonKey,
  });

  final ExploreState state;
  final Future<void> Function() onAddDestination;
  final GlobalKey addButtonKey;

  @override
  State<_ExploreContent> createState() => _ExploreContentState();
}

class _ExploreContentState extends State<_ExploreContent> {
  String _query = '';
  int _selectedHistoryTab = 0;
  ExploreDestinationFilter _filter = ExploreDestinationFilter.all;
  ExploreDestinationSort _sort = ExploreDestinationSort.nameAscending;
  _CountryTravelSnapshot? _lastCompleteCountrySnapshot;

  @override
  Widget build(BuildContext context) {
    final useCupertinoSearch =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final state = widget.state;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final residencesState = context.watch<ResidencesCubit>().state;
    final wishlistState = context.watch<WishlistCubit>().state;

    final countrySourcesReady =
        state.phase == ExplorePhase.ready &&
        residencesState.phase == ResidencesPhase.ready &&
        wishlistState.phase == WishlistPhase.ready;

    // Only publish a new aggregate when all sources are ready.
    //
    // During loading or failure, keep the last complete snapshot.
    // An empty snapshot is still valid data.
    if (countrySourcesReady) {
      final entries = aggregateExploreCountries(
        explore: state,
        residences: residencesState,
        wishlist: wishlistState,
      );

      final visitSummaries = <String, CountryVisitSummary>{
        for (final entry in entries)
          entry.country.code: summarizeCountryVisits(
            state.visitsForCountry(entry.country.code),
          ),
      };

      _lastCompleteCountrySnapshot = _CountryTravelSnapshot(
        entries: entries,
        visitSummaries: Map.unmodifiable(visitSummaries),
      );
    }

    final snapshot = _lastCompleteCountrySnapshot;

    final hasCompleteCountrySnapshot = snapshot != null;

    final allCountryEntries =
        snapshot?.entries ?? const <ExploreCountryEntry>[];

    final countrySourcesLoading =
        state.phase == ExplorePhase.loading ||
        residencesState.phase == ResidencesPhase.loading ||
        wishlistState.phase == WishlistPhase.loading;

    final countrySourcesFailed =
        residencesState.phase == ResidencesPhase.failure ||
        wishlistState.phase == WishlistPhase.failure;

    final countries = filterExploreCountries(
      allCountryEntries,
      options: ExploreCountriesFilterOptions(
        query: _query,
        filter: _filter,
        sort: _sort,
      ),
    );

    final hasAnyCountryDestination = allCountryEntries.any(
      (entry) => entry.summary.hasAnyStatus,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BeenAround',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            IconButton.filled(
              key: widget.addButtonKey,
              tooltip: 'Add Destination',
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: widget.onAddDestination,
              icon: const Icon(Icons.add, size: 26),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 600;
            final horizontalOverflow = isCompact ? 20.0 : 0.0;
            final mapWidth = constraints.maxWidth + horizontalOverflow * 2;

            return SizedBox(
              height: mapWidth / 1.9,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -horizontalOverflow,
                    width: mapWidth,
                    height: mapWidth / 1.9,
                    child: WorldOverviewMap(
                      visitedCountryCodes: state.visitedCountryCodes,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _CompactStatistic(
                  icon: Icons.public_outlined,
                  value: '${state.visitedCountryCount}',
                  label: 'Countries visited',
                ),
              ),
              Container(width: 1, height: 40, color: colors.outlineVariant),
              Expanded(
                child: _CompactStatistic(
                  icon: Icons.place_outlined,
                  value: '${state.totalVisits}',
                  label: 'Total visits',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<int>(
                key: const Key('exploreHistoryTabs'),
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('Countries'),
                    icon: Icon(Icons.public_outlined),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Cities'),
                    icon: Icon(Icons.location_city_outlined),
                  ),
                ],
                selected: {_selectedHistoryTab},
                onSelectionChanged: (selection) {
                  setState(() => _selectedHistoryTab = selection.first);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Your Travel History',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (_selectedHistoryTab == 0)
              PopupMenuButton<ExploreDestinationSort>(
                key: const Key('visitedCountriesSort'),
                tooltip: 'Sort countries',
                initialValue: _sort,
                icon: const Icon(Icons.tune_rounded),
                onSelected: (value) => setState(() => _sort = value),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: ExploreDestinationSort.nameAscending,
                    child: Text('Name A–Z'),
                  ),
                  PopupMenuItem(
                    value: ExploreDestinationSort.nameDescending,
                    child: Text('Name Z–A'),
                  ),
                  PopupMenuItem(
                    value: ExploreDestinationSort.mostVisited,
                    child: Text('Most visited'),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedHistoryTab == 0) ...[
          if (useCupertinoSearch)
            CupertinoSearchTextField(
              key: const Key('visitedCountriesSearch'),
              placeholder: 'Search visited countries...',
              onChanged: (value) => setState(() => _query = value),
            )
          else
            TextField(
              key: const Key('visitedCountriesSearch'),
              decoration: InputDecoration(
                hintText: 'Search visited countries...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in ExploreDestinationFilter.values)
                ChoiceChip(
                  key: Key('countryFilter-${filter.name}'),
                  label: Text(switch (filter) {
                    ExploreDestinationFilter.all => 'All',
                    ExploreDestinationFilter.been => 'Been',
                    ExploreDestinationFilter.lived => 'Lived',
                    ExploreDestinationFilter.wish => 'Wish',
                    ExploreDestinationFilter.multipleVisits =>
                      'Multiple visits',
                  }),
                  selected: _filter == filter,
                  showCheckmark: false,
                  selectedColor: colors.secondary,
                  backgroundColor: colors.surfaceContainerLow,
                  side: BorderSide(
                    color: _filter == filter
                        ? Colors.transparent
                        : colors.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  labelStyle: TextStyle(
                    color: _filter == filter
                        ? colors.onSecondary
                        : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  onSelected: (_) => setState(() => _filter = filter),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // ------------------------------------------------------------
          // Country loading
          // ------------------------------------------------------------
          if (countrySourcesLoading && hasCompleteCountrySnapshot)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(),
            ),

          // ------------------------------------------------------------
          // Country visit refresh error
          // ------------------------------------------------------------
          if (state.phase == ExplorePhase.failure)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _RefreshError(
                message:
                    state.errorMessage ??
                    'Unable to refresh your travel history.',
                onRetry: context.read<ExploreCubit>().refresh,
              ),
            ),

          // ------------------------------------------------------------
          // Residence / Wishlist refresh error
          // ------------------------------------------------------------
          if (countrySourcesFailed && hasCompleteCountrySnapshot)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _RefreshError(
                message: 'Some travel statuses could not be refreshed.',
                onRetry: () {
                  if (residencesState.phase == ResidencesPhase.failure) {
                    unawaited(context.read<ResidencesCubit>().refresh());
                  }

                  if (wishlistState.phase == WishlistPhase.failure) {
                    unawaited(context.read<WishlistCubit>().refresh());
                  }
                },
              ),
            ),

          // ------------------------------------------------------------
          // Country results
          // ------------------------------------------------------------
          if (!hasCompleteCountrySnapshot) ...[
            if (countrySourcesFailed)
              AppErrorState(
                title: 'Unable to load destinations',
                message: 'Some travel statuses could not be loaded.',
                onRetry: () {
                  if (residencesState.phase == ResidencesPhase.failure) {
                    unawaited(context.read<ResidencesCubit>().refresh());
                  }

                  if (wishlistState.phase == WishlistPhase.failure) {
                    unawaited(context.read<WishlistCubit>().refresh());
                  }
                },
              )
            else
              const AppLoadingState(message: 'Loading your destinations...'),
          ] else if (countries.isEmpty) ...[
            if (!hasAnyCountryDestination)
              const AppEmptyState(
                title: 'No destinations yet',
                message:
                    'Countries you have visited, lived in or added '
                    'to your wishlist will appear here.',
                icon: Icons.travel_explore_outlined,
              )
            else
              const AppEmptyState(
                title: 'No matching countries',
                message: 'Try changing your search or filters.',
                icon: Icons.search_off_outlined,
              ),
          ] else ...[
            ...countries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CountryCard(
                  country: entry.country,
                  summary: snapshot!.visitSummaries[entry.country.code]!,
                  travelSummary: entry.summary,
                ),
              ),
            ),
          ],
        ] else ...[
          const VisitedCitiesList(),
        ],
      ],
    );
  }
}

class _CountryCard extends StatelessWidget {
  const _CountryCard({
    required this.country,
    required this.summary,
    required this.travelSummary,
  });

  final Country country;
  final CountryVisitSummary summary;
  final ExploreCountrySummary travelSummary;

  String get _subtitle {
    if (summary.visitCount == 0) {
      return [
        if (travelSummary.hasLived) 'Lived',
        if (travelSummary.isWishlisted) 'Wish',
      ].join(' · ');
    }

    final count = summary.visitCount;
    final visitsLabel = '$count ${count == 1 ? 'visit' : 'visits'}';
    final lastVisited = summary.lastVisitedOn;

    if (lastVisited == null) return visitsLabel;

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
    final dateLabel = '${months[lastVisited.month - 1]} ${lastVisited.year}';
    return '$visitsLabel · Last visited $dateLabel';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final exploreCubit = context.read<ExploreCubit>();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BlocProvider.value(
                value: exploreCubit,
                child: CountryDetailsPage(country: country),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              CountryFlag(countryCode: country.code),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      country.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefreshError extends StatelessWidget {
  const _RefreshError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _CompactStatistic extends StatelessWidget {
  const _CompactStatistic({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
