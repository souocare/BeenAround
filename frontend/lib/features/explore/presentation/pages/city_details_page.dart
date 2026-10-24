import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/visited_cities_cubit.dart';
import '../../application/visited_cities_state.dart';
import '../../domain/visited_city.dart';
import '../../../geography/domain/city_visit.dart';
import '../widgets/show_edit_city_visit.dart';
import '../widgets/show_delete_city_visit.dart';

class CityDetailsPage extends StatelessWidget {
  const CityDetailsPage({required this.city, super.key});

  final VisitedCity city;

  Future<void> _editVisit(BuildContext context, CityVisit visit) async {
    final updated = await showEditCityVisit(context, city: city, visit: visit);

    if (!updated || !context.mounted) return;

    await context.read<VisitedCitiesCubit>().load();
  }

  Future<void> _deleteVisit(BuildContext context, CityVisit visit) async {
    final deleted = await showDeleteCityVisit(
      context,
      city: city,
      visit: visit,
    );

    if (!deleted || !context.mounted) return;

    final cubit = context.read<VisitedCitiesCubit>();

    await cubit.load();

    if (!context.mounted) return;

    // A última visita foi eliminada: regressar à lista de cidades.
    if (cubit.state.hasData && cubit.state.visitsForCity(city.cityId).isEmpty) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('City Details')),
      body: BlocBuilder<VisitedCitiesCubit, VisitedCitiesState>(
        builder: (context, state) {
          final visits = state.visitsForCity(city.cityId).toList()
            ..sort(_compareVisits);

          final lastVisited = _lastVisitedDate(visits);

          return RefreshIndicator(
            onRefresh: context.read<VisitedCitiesCubit>().load,
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
                        Row(
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
                                    city.cityName,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    city.countryName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Text(
                                  '${visits.length}',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'VISITS',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const Divider(height: 32),
                                Row(
                                  children: [
                                    Text(
                                      'LAST VISITED',
                                      style: theme.textTheme.labelMedium,
                                    ),
                                    const Spacer(),
                                    Text(
                                      lastVisited == null
                                          ? '—'
                                          : _formatDate(lastVisited),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        Text(
                          'Visit History',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
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
                                for (
                                  var index = 0;
                                  index < visits.length;
                                  index++
                                ) ...[
                                  ListTile(
                                    key: Key('cityVisit-${visits[index].id}'),
                                    leading: const Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                    title: Text('Visit ${index + 1}'),
                                    subtitle: Text(
                                      _formatVisitDates(visits[index]),
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      key: Key(
                                        'cityVisitMenu-${visits[index].id}',
                                      ),
                                      tooltip: 'Visit actions',
                                      onSelected: (action) {
                                        switch (action) {
                                          case 'edit':
                                            _editVisit(context, visits[index]);
                                          case 'delete':
                                            _deleteVisit(
                                              context,
                                              visits[index],
                                            );
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem<String>(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.edit_outlined,
                                                size: 20,
                                              ),
                                              SizedBox(width: 12),
                                              Text('Edit visit'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline_rounded,
                                                size: 20,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Delete visit',
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (index < visits.length - 1)
                                    const Divider(height: 1),
                                ],
                              ],
                            ),
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
