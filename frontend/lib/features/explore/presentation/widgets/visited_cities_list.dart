import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/widgets/app_empty_state.dart';
import '../../../../app/widgets/app_loading_state.dart';

import '../../application/visited_cities_cubit.dart';
import '../../application/visited_cities_state.dart';
import '../../domain/visited_city.dart';
import '../pages/city_details_page.dart';

class VisitedCitiesList extends StatefulWidget {
  const VisitedCitiesList({super.key});

  @override
  State<VisitedCitiesList> createState() => _VisitedCitiesListState();
}

class _VisitedCitiesListState extends State<VisitedCitiesList> {
  String _query = '';
  bool _multipleVisitsOnly = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final useCupertinoSearch =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return BlocBuilder<VisitedCitiesCubit, VisitedCitiesState>(
      builder: (context, state) {
        final query = _query.trim().toLowerCase();

        final cities = state.visitedCities.where((city) {
          final matchesSearch =
              query.isEmpty ||
              city.cityName.toLowerCase().contains(query) ||
              city.countryName.toLowerCase().contains(query) ||
              city.countryCode.toLowerCase().contains(query);

          final matchesVisits = !_multipleVisitsOnly || city.visitCount > 1;

          return matchesSearch && matchesVisits;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (useCupertinoSearch)
              CupertinoSearchTextField(
                key: const Key('visitedCitiesSearch'),
                placeholder: 'Search visited cities...',
                onChanged: (value) {
                  setState(() => _query = value);
                },
              )
            else
              TextField(
                key: const Key('visitedCitiesSearch'),
                decoration: InputDecoration(
                  hintText: 'Search visited cities...',
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
              children: [
                ChoiceChip(
                  label: const Text('Multiple visits'),
                  selected: _multipleVisitsOnly,
                  showCheckmark: false,
                  selectedColor: colors.secondary,
                  backgroundColor: colors.surfaceContainerLow,
                  onSelected: (value) {
                    setState(() => _multipleVisitsOnly = value);
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (state.phase == VisitedCitiesPhase.loading)
              const LinearProgressIndicator(),

            if (state.phase == VisitedCitiesPhase.failure)
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
                                'Unable to load visited cities.',
                          ),
                        ),
                        TextButton(
                          onPressed: context.read<VisitedCitiesCubit>().load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (state.phase == VisitedCitiesPhase.initial ||
                (state.phase == VisitedCitiesPhase.loading &&
                    state.visits.isEmpty))
              const AppLoadingState(message: 'Loading visited cities...')
            else if (cities.isEmpty) ...[
              if (state.phase != VisitedCitiesPhase.failure)
                state.visitedCityCount == 0
                    ? const AppEmptyState(
                        title: 'No cities visited yet',
                        message:
                            'Your visited cities will appear here once you '
                            'start recording your travels.',
                        icon: Icons.location_city_outlined,
                      )
                    : const AppEmptyState(
                        title: 'No matching cities',
                        message: 'Try changing your search or filters.',
                        icon: Icons.search_off_outlined,
                      ),
            ] else ...[
              ...cities.map(
                (city) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _VisitedCityCard(city: city),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _VisitedCityCard extends StatelessWidget {
  const _VisitedCityCard({required this.city});

  final VisitedCity city;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final cubit = context.read<VisitedCitiesCubit>();

          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BlocProvider.value(
                value: cubit,
                child: CityDetailsPage(city: city),
              ),
            ),
          );
        },
        child: Container(
          key: Key('visitedCityCard-${city.cityId}'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_city_outlined,
                color: colors.primary,
                size: 28,
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city.cityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${city.countryName} · '
                      '${city.visitCount} '
                      '${city.visitCount == 1 ? 'visit' : 'visits'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
