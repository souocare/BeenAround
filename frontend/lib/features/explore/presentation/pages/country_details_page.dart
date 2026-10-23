import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/explore_cubit.dart';
import '../../application/explore_state.dart';
import '../../domain/country.dart';
import '../../domain/country_visit.dart';

import '../widgets/country_flag.dart';
import '../widgets/show_add_destination.dart';
import '../widgets/show_delete_country_visit.dart';
import '../widgets/show_edit_country_visit.dart';

enum _CountryTab { overview, visits, cities, trips }

enum _VisitAction { edit, delete }

class CountryDetailsPage extends StatefulWidget {
  const CountryDetailsPage({required this.country, super.key});

  final Country country;

  @override
  State<CountryDetailsPage> createState() => _CountryDetailsPageState();
}

class _CountryDetailsPageState extends State<CountryDetailsPage> {
  _CountryTab _selectedTab = _CountryTab.overview;

  Future<void> _addVisit() async {
    final exploreCubit = context.read<ExploreCubit>();

    final created = await showAddDestination(
      context,
      initialCountry: widget.country,
    );

    if (created && !exploreCubit.isClosed) {
      await exploreCubit.refresh();
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Country Details')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add country visit',
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        onPressed: _addVisit,
        child: const Icon(Icons.add_rounded),
      ),
      body: BlocBuilder<ExploreCubit, ExploreState>(
        builder: (context, state) {
          final visits = state.visitsForCountry(widget.country.code).toList()
            ..sort(_compareVisits);

          final isVisited = visits.isNotEmpty;
          final lastVisited = _lastVisitedDate(visits);

          return RefreshIndicator(
            onRefresh: context.read<ExploreCubit>().refresh,
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

                        const SizedBox(height: 24),

                        // Country map will be integrated here.
                        _CountryMapPlaceholder(
                          countryName: widget.country.name,
                        ),

                        const SizedBox(height: 20),

                        _CountryStatistics(
                          visitCount: visits.length,
                          lastVisited: lastVisited,
                        ),

                        const SizedBox(height: 28),

                        _CountryTabs(
                          selectedTab: _selectedTab,
                          onSelected: (tab) {
                            setState(() {
                              _selectedTab = tab;
                            });
                          },
                        ),

                        const SizedBox(height: 24),

                        switch (_selectedTab) {
                          _CountryTab.overview ||
                          _CountryTab.visits => _VisitHistory(
                            visits: visits,
                            onEdit: _editVisit,
                            onDelete: _deleteVisit,
                          ),

                          _CountryTab.cities => const _EmptySection(
                            icon: Icons.location_city_outlined,
                            title: 'Visited cities',
                            message:
                                'City visits will appear here once city tracking is available.',
                          ),

                          _CountryTab.trips => const _EmptySection(
                            icon: Icons.luggage_outlined,
                            title: 'Associated trips',
                            message:
                                'Trips associated with this country will appear here.',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CountryFlag(countryCode: country.code, size: 72),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    country.name,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        country.alpha3Code,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          letterSpacing: 1.5,
                        ),
                      ),

                      Text(
                        '·',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),

                      Text(
                        country.continent,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isVisited
                    ? colors.primary.withValues(alpha: 0.14)
                    : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVisited
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: isVisited ? colors.primary : colors.onSurfaceVariant,
                  ),

                  const SizedBox(width: 7),

                  Text(
                    isVisited ? 'Visited' : 'Not visited',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isVisited
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$visitCount ${visitCount == 1 ? 'visit' : 'visits'}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Map placeholder
// -----------------------------------------------------------------------------

class _CountryMapPlaceholder extends StatelessWidget {
  const _CountryMapPlaceholder({required this.countryName});

  final String countryName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.public_rounded, size: 38, color: colors.primary),

            const SizedBox(height: 12),

            Text(
              '$countryName map',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 6),

            Text(
              'Country map coming next',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Statistics
// -----------------------------------------------------------------------------

class _CountryStatistics extends StatelessWidget {
  const _CountryStatistics({
    required this.visitCount,
    required this.lastVisited,
  });

  final int visitCount;
  final DateTime? lastVisited;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.explore_outlined,
            value: '$visitCount',
            label: 'Total visits',
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _StatCard(
            icon: Icons.calendar_today_outlined,
            value: lastVisited == null ? '—' : _formatDate(lastVisited!),
            label: 'Last visited',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary, size: 22),

            const SizedBox(height: 14),

            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
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

// -----------------------------------------------------------------------------
// Tabs
// -----------------------------------------------------------------------------

class _CountryTabs extends StatelessWidget {
  const _CountryTabs({required this.selectedTab, required this.onSelected});

  final _CountryTab selectedTab;
  final ValueChanged<_CountryTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in _CountryTab.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(switch (tab) {
                  _CountryTab.overview => 'Overview',
                  _CountryTab.visits => 'Visits',
                  _CountryTab.cities => 'Cities',
                  _CountryTab.trips => 'Trips',
                }),
                selected: selectedTab == tab,
                onSelected: (_) => onSelected(tab),
                selectedColor: colors.primary,
                backgroundColor: colors.surfaceContainerHigh,
                labelStyle: TextStyle(
                  color: selectedTab == tab
                      ? Colors.white
                      : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide.none,
                showCheckmark: false,
              ),
            ),
        ],
      ),
    );
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
  });

  final List<CountryVisit> visits;
  final ValueChanged<CountryVisit> onEdit;
  final ValueChanged<CountryVisit> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Visit history',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 16),

        if (visits.isEmpty)
          const _EmptySection(
            icon: Icons.event_busy_outlined,
            title: 'No visits recorded for this country.',
            message: 'Add your first visit to start your travel history.',
          )
        else
          for (var index = 0; index < visits.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _VisitCard(
                visit: visits[index],
                number: index + 1,
                onEdit: () => onEdit(visits[index]),
                onDelete: () => onDelete(visits[index]),
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
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: colors.primary.withValues(alpha: 0.14),
          foregroundColor: colors.primary,
          child: Text('$number'),
        ),
        title: Text(
          'Visit $number',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_formatVisitDates(visit)),
        trailing: PopupMenuButton<_VisitAction>(
          tooltip: 'Visit actions',
          onSelected: (action) {
            switch (action) {
              case _VisitAction.edit:
                onEdit();

              case _VisitAction.delete:
                onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _VisitAction.edit,
              child: Row(
                children: [
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 12),
                  Text('Edit visit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: _VisitAction.delete,
              child: Row(
                children: [
                  Icon(Icons.delete_outline),
                  SizedBox(width: 12),
                  Text('Delete visit'),
                ],
              ),
            ),
          ],
        ),
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
