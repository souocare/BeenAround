import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/explore_cubit.dart';
import '../../application/explore_state.dart';
import '../../domain/country.dart';
import '../../domain/country_visit.dart';
import '../widgets/show_edit_country_visit.dart';

class CountryDetailsPage extends StatelessWidget {
  const CountryDetailsPage({required this.country, super.key});

  final Country country;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(country.name)),
      body: BlocBuilder<ExploreCubit, ExploreState>(
        builder: (context, state) {
          final visits = state.visitsForCountry(country.code).toList()
            ..sort(_compareVisits);

          return RefreshIndicator(
            onRefresh: context.read<ExploreCubit>().refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          country.name,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Your travel history',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),

                        const SizedBox(height: 24),

                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${visits.length}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text('Total visits'),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        Text(
                          'Visit history',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(height: 16),

                        if (visits.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No visits recorded for this country.',
                              ),
                            ),
                          )
                        else
                          for (var index = 0; index < visits.length; index++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _VisitCard(
                                visit: visits[index],
                                number: index + 1,
                                onEdit: () async {
                                  final exploreCubit = context
                                      .read<ExploreCubit>();

                                  final updated = await showEditCountryVisit(
                                    context,
                                    country: country,
                                    visit: visits[index],
                                  );

                                  if (updated && !exploreCubit.isClosed) {
                                    await exploreCubit.refresh();
                                  }
                                },
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

  static int _compareVisits(CountryVisit a, CountryVisit b) {
    final aDate = a.startedOn ?? a.endedOn;
    final bDate = b.startedOn ?? b.endedOn;

    if (aDate == null && bDate == null) {
      return b.createdAt.compareTo(a.createdAt);
    }

    if (aDate == null) return 1;
    if (bDate == null) return -1;

    final dateComparison = bDate.compareTo(aDate);

    if (dateComparison != 0) return dateComparison;

    return b.createdAt.compareTo(a.createdAt);
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.visit,
    required this.number,
    required this.onEdit,
  });

  final CountryVisit visit;
  final int number;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('$number')),
        title: Text('Visit $number'),
        subtitle: Text(_formatVisitDates(visit)),
        trailing: IconButton(
          tooltip: 'Edit visit',
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
        ),
        isThreeLine: false,
      ),
    );
  }

  String _formatVisitDates(CountryVisit visit) {
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
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }
}
