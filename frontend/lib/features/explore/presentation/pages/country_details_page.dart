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
import '../../../map/presentation/widgets/country_map.dart';

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
                        CountryMap(
                          countryCode: widget.country.code,
                          isVisited: isVisited,
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CountryFlag(countryCode: country.code, size: 64),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                country.name,
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

        const SizedBox(width: 12),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              country.continent,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVisited
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 15,
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

            const SizedBox(height: 8),

            Text(
              '$visitCount ${visitCount == 1 ? 'visit' : 'visits'}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
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

                const Expanded(
                  child: _CountryStatItem(value: '—', label: 'CITIES'),
                ),

                _StatDivider(color: colors.outlineVariant),

                const Expanded(
                  child: _CountryStatItem(value: '—', label: 'TRIPS'),
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
// Tabs
// -----------------------------------------------------------------------------

class _CountryTabs extends StatelessWidget {
  const _CountryTabs({required this.selectedTab, required this.onSelected});

  final _CountryTab selectedTab;
  final ValueChanged<_CountryTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final tab in _CountryTab.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _CountryTabButton(
                  label: switch (tab) {
                    _CountryTab.overview => 'Overview',
                    _CountryTab.visits => 'Visits',
                    _CountryTab.cities => 'Cities',
                    _CountryTab.trips => 'Trips',
                  },
                  selected: selectedTab == tab,
                  onTap: () => onSelected(tab),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountryTabButton extends StatelessWidget {
  const _CountryTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? colors.onPrimary : colors.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
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

          PopupMenuButton<_VisitAction>(
            tooltip: 'Visit actions',
            icon: Icon(Icons.more_vert_rounded, color: colors.onSurfaceVariant),
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
