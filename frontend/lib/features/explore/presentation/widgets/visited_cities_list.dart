import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/widgets/app_empty_state.dart';
import '../../../../app/widgets/app_loading_state.dart';

import '../../application/explore_cities_cubit.dart';
import '../../application/explore_cities_filter.dart';
import '../../application/explore_cities_state.dart';
import '../../application/explore_destination_filter.dart';
import '../../application/visited_cities_cubit.dart';

import '../../../residences/application/residences_cubit.dart';
import '../../../wishlist/application/wishlist_cubit.dart';

import '../pages/city_details_page.dart';
import 'explore_city_card.dart';

class VisitedCitiesList extends StatefulWidget {
  const VisitedCitiesList({super.key});

  @override
  State<VisitedCitiesList> createState() => _VisitedCitiesListState();
}

class _VisitedCitiesListState extends State<VisitedCitiesList> {
  String _query = '';

  ExploreDestinationFilter _filter = ExploreDestinationFilter.all;

  ExploreDestinationSort _sort = ExploreDestinationSort.nameAscending;

  bool get _useCupertinoSearch =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  void _retry(BuildContext context) {
    context.read<ExploreCitiesCubit>().load(
      visitedCities: context.read<VisitedCitiesCubit>().state,
      residences: context.read<ResidencesCubit>().state,
      wishlist: context.read<WishlistCubit>().state,
    );
  }

  void _openCity(BuildContext context, int cityId, bool hasOnlyBeen) {
    final visitedCitiesCubit = context.read<VisitedCitiesCubit>();

    final exploreCities = context.read<ExploreCitiesCubit>().state.cities;

    final entry = exploreCities
        .where((entry) => entry.city.id == cityId)
        .firstOrNull;

    if (entry == null) return;

    final visitedCity = visitedCitiesCubit.state.visitedCities
        .where((city) => city.cityId == cityId)
        .firstOrNull;

    // Preserve the existing navigation behavior for visit-only cities.
    //
    // In particular, deleting the final visit still returns to Explore.
    if (hasOnlyBeen && visitedCity != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider.value(
            value: visitedCitiesCubit,
            child: CityDetailsPage(city: visitedCity),
          ),
        ),
      );

      return;
    }

    // Catalog navigation supports cities with no explicit visits.
    //
    // It also keeps combined-status destinations accessible after
    // deleting their final visit.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: visitedCitiesCubit,
          child: CityDetailsPage.fromCatalog(city: entry.city),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return BlocBuilder<ExploreCitiesCubit, ExploreCitiesState>(
      builder: (context, state) {
        final cities = filterExploreCities(
          state.cities,
          options: ExploreCitiesFilterOptions(
            query: _query,
            filter: _filter,
            sort: _sort,
          ),
        );

        final hasPreviousData = state.cities.isNotEmpty;

        final isInitialLoading =
            (state.phase == ExploreCitiesPhase.initial ||
                state.phase == ExploreCitiesPhase.loading) &&
            !hasPreviousData;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ------------------------------------------------------------
            // Search
            // ------------------------------------------------------------
            if (_useCupertinoSearch)
              CupertinoSearchTextField(
                key: const Key('visitedCitiesSearch'),
                placeholder: 'Search cities...',
                onChanged: (value) {
                  setState(() => _query = value);
                },
              )
            else
              TextField(
                key: const Key('visitedCitiesSearch'),
                decoration: InputDecoration(
                  hintText: 'Search cities...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onChanged: (value) {
                  setState(() => _query = value);
                },
              ),

            const SizedBox(height: 12),

            // ------------------------------------------------------------
            // Filters
            // ------------------------------------------------------------
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in ExploreDestinationFilter.values)
                  ChoiceChip(
                    key: Key('cityFilter-${filter.name}'),
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
                    onSelected: (_) {
                      setState(() => _filter = filter);
                    },
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // ------------------------------------------------------------
            // Sorting
            // ------------------------------------------------------------
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<ExploreDestinationSort>(
                key: const Key('visitedCitiesSort'),
                tooltip: 'Sort cities',
                initialValue: _sort,
                icon: const Icon(Icons.tune_rounded),
                onSelected: (value) {
                  setState(() => _sort = value);
                },
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
            ),

            // ------------------------------------------------------------
            // Loading
            // ------------------------------------------------------------
            if (state.phase == ExploreCitiesPhase.loading && hasPreviousData)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),

            // ------------------------------------------------------------
            // Error
            // ------------------------------------------------------------
            if (state.phase == ExploreCitiesPhase.failure)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: colors.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.errorMessage ??
                                'Unable to load Explore cities.',
                            style: TextStyle(color: colors.onErrorContainer),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _retry(context),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ------------------------------------------------------------
            // Results
            // ------------------------------------------------------------
            if (isInitialLoading)
              const AppLoadingState(message: 'Loading cities...')
            else if (cities.isEmpty &&
                state.phase != ExploreCitiesPhase.failure)
              state.cities.isEmpty
                  ? const AppEmptyState(
                      title: 'No cities visited yet',
                      message:
                          'Your cities will appear here once you '
                          'start recording destinations.',
                      icon: Icons.location_city_outlined,
                    )
                  : const AppEmptyState(
                      title: 'No matching cities',
                      message: 'Try changing your search or filters.',
                      icon: Icons.search_off_outlined,
                    )
            else
              ...cities.map((entry) {
                final summary = entry.summary;

                final hasOnlyBeen =
                    summary.hasBeen &&
                    !summary.hasLived &&
                    !summary.isWishlisted;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ExploreCityCard(
                    entry: entry,
                    onTap: () => _openCity(context, entry.city.id, hasOnlyBeen),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
