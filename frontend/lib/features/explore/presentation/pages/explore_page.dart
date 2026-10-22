import 'package:beenaround/features/explore/application/country_visit_summary.dart';
import 'package:beenaround/features/explore/application/visited_countries_filter.dart';
import 'package:beenaround/features/explore/presentation/widgets/country_flag.dart';
import 'package:beenaround/features/explore/presentation/widgets/show_add_destination.dart';
import 'package:beenaround/features/map/presentation/widgets/world_overview_map.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/widgets/app_empty_state.dart';
import '../../../../app/widgets/app_error_state.dart';
import '../../../../app/widgets/app_loading_state.dart';
import '../../../../app/widgets/app_section_header.dart';
import '../../application/explore_cubit.dart';
import '../../application/explore_state.dart';
import '../../domain/country.dart';
import 'country_details_page.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExploreCubit, ExploreState>(
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

        return RefreshIndicator(
          onRefresh: context.read<ExploreCubit>().refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: _ExploreContent(state: state),
                    ),
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

class _ExploreContent extends StatefulWidget {
  const _ExploreContent({required this.state});

  final ExploreState state;

  @override
  State<_ExploreContent> createState() => _ExploreContentState();
}

class _ExploreContentState extends State<_ExploreContent> {
  String _query = '';

  VisitedCountriesFilter _filter = VisitedCountriesFilter.all;

  VisitedCountriesSort _sort = VisitedCountriesSort.nameAscending;

  @override
  Widget build(BuildContext context) {
    final useCupertinoSearch =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final state = widget.state;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final visitedCountries = filterVisitedCountries(
      state,
      options: VisitedCountriesFilterOptions(
        query: _query,
        filter: _filter,
        sort: _sort,
      ),
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
              tooltip: 'Add Destination',
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () async {
                final exploreCubit = context.read<ExploreCubit>();

                final created = await showAddDestination(context);

                if (created && !exploreCubit.isClosed) {
                  await exploreCubit.refresh();
                }
              },
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Travel History',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<VisitedCountriesSort>(
              key: const Key('visitedCountriesSort'),
              tooltip: 'Sort countries',
              initialValue: _sort,
              icon: const Icon(Icons.tune_rounded),
              onSelected: (value) {
                setState(() => _sort = value);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: VisitedCountriesSort.nameAscending,
                  child: Text('Name A–Z'),
                ),
                PopupMenuItem(
                  value: VisitedCountriesSort.nameDescending,
                  child: Text('Name Z–A'),
                ),
                PopupMenuItem(
                  value: VisitedCountriesSort.mostVisited,
                  child: Text('Most visited'),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (useCupertinoSearch)
          CupertinoSearchTextField(
            key: const Key('visitedCountriesSearch'),
            placeholder: 'Search visited countries...',
            onChanged: (value) {
              setState(() => _query = value);
            },
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
            onChanged: (value) {
              setState(() => _query = value);
            },
          ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _filter == VisitedCountriesFilter.all,
              showCheckmark: false,
              selectedColor: colors.secondary,
              backgroundColor: colors.surfaceContainerLow,
              side: BorderSide(
                color: _filter == VisitedCountriesFilter.all
                    ? Colors.transparent
                    : colors.outlineVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              labelStyle: TextStyle(
                color: _filter == VisitedCountriesFilter.all
                    ? Colors.white
                    : colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onSelected: (_) {
                setState(() => _filter = VisitedCountriesFilter.all);
              },
            ),
            ChoiceChip(
              label: const Text('Multiple visits'),
              selected: _filter == VisitedCountriesFilter.multipleVisits,
              showCheckmark: false,
              selectedColor: colors.secondary,
              backgroundColor: colors.surfaceContainerLow,
              side: BorderSide(
                color: _filter == VisitedCountriesFilter.multipleVisits
                    ? Colors.transparent
                    : colors.outlineVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              labelStyle: TextStyle(
                color: _filter == VisitedCountriesFilter.multipleVisits
                    ? Colors.white
                    : colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onSelected: (_) {
                setState(() => _filter = VisitedCountriesFilter.multipleVisits);
              },
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (state.phase == ExplorePhase.loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: LinearProgressIndicator(),
          ),

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

        if (visitedCountries.isEmpty)
          state.visitedCountryCount == 0
              ? const AppEmptyState(
                  title: 'No countries visited yet',
                  message:
                      'Your visited countries will appear here once you start '
                      'recording your travels.',
                  icon: Icons.travel_explore_outlined,
                )
              : const AppEmptyState(
                  title: 'No matching countries',
                  message: 'Try changing your search or filters.',
                  icon: Icons.search_off_outlined,
                )
        else
          ...visitedCountries.map(
            (country) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CountryCard(
                country: country,
                summary: summarizeCountryVisits(
                  state.visitsForCountry(country.code),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CountryCard extends StatelessWidget {
  const _CountryCard({required this.country, required this.summary});

  final Country country;
  final CountryVisitSummary summary;

  String get _subtitle {
    final count = summary.visitCount;

    final visitsLabel = '$count ${count == 1 ? 'visit' : 'visits'}';

    final lastVisited = summary.lastVisitedOn;

    if (lastVisited == null) {
      return visitsLabel;
    }

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
