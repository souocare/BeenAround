import 'package:beenaround/features/explore/presentation/widgets/show_add_destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/widgets/app_empty_state.dart';
import '../../../../app/widgets/app_error_state.dart';
import '../../../../app/widgets/app_loading_state.dart';
import '../../../../app/widgets/app_section_header.dart';
import '../../application/explore_cubit.dart';
import '../../application/explore_state.dart';
import '../../domain/country.dart';

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

class _ExploreContent extends StatelessWidget {
  const _ExploreContent({required this.state});

  final ExploreState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final visitedCountries = state.countries
        .where((country) => state.isCountryVisited(country.code))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Explore',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton.filled(
              tooltip: 'Add Destination',
              onPressed: () async {
                final exploreCubit = context.read<ExploreCubit>();

                final created = await showAddDestination(context);

                if (created && !exploreCubit.isClosed) {
                  await exploreCubit.refresh();
                }
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          'Your travel history, all in one place.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 28),

        Row(
          children: [
            Expanded(
              child: _StatisticCard(
                label: 'Countries visited',
                value: '${state.visitedCountryCount}',
                icon: Icons.public_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatisticCard(
                label: 'Total visits',
                value: '${state.totalVisits}',
                icon: Icons.place_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        AppSectionHeader(
          title: 'Visited countries',
          subtitle: state.visitedCountryCount == 0
              ? 'Countries you visit will appear here.'
              : '${state.visitedCountryCount} countries in your history',
        ),

        const SizedBox(height: 16),

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
          const AppEmptyState(
            title: 'No countries visited yet',
            message:
                'Your visited countries will appear here once you start '
                'recording your travels.',
            icon: Icons.travel_explore_outlined,
          )
        else
          ...visitedCountries.map(
            (country) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CountryCard(
                country: country,
                visitCount: state.visitsForCountry(country.code).length,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryCard extends StatelessWidget {
  const _CountryCard({required this.country, required this.visitCount});

  final Country country;
  final int visitCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Text(
            country.code,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(country.name),
        subtitle: Text('$visitCount ${visitCount == 1 ? 'visit' : 'visits'}'),
        trailing: const Icon(Icons.chevron_right),
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
