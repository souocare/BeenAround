import 'package:flutter/material.dart';

import '../../../../app/widgets/country_flag.dart';
import '../../domain/map_country_preview.dart';
import '../../application/map_country_related_state.dart';
import '../../map_panel_layout.dart';

class MapCountryPanel extends StatelessWidget {
  const MapCountryPanel({
    required this.preview,
    required this.relatedState,
    required this.onClose,
    required this.onViewDetails,
    super.key,
  });

  final MapCountryPreview preview;
  final VoidCallback onClose;
  final MapCountryRelatedState relatedState;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (isLandscape &&
            constraints.maxWidth >= MapPanelLayout.sidePanelBreakpoint) {
          return _buildSidePanel(context, constraints);
        }

        return _buildBottomPanel(context, colors);
      },
    );
  }

  Widget _buildBottomPanel(BuildContext context, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          // Ignore notifications from nested draggable sheets.
          if (notification.depth != 0) {
            return false;
          }

          // Dismiss when the user drags the panel almost completely down.
          if (notification.extent <= 0.02) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                onClose();
              }
            });
          }

          return false;
        },
        child: Align(
          alignment: Alignment.bottomCenter,
          child: DraggableScrollableSheet(
            initialChildSize: MapPanelLayout.initialExtent,
            minChildSize: MapPanelLayout.closedExtent,
            maxChildSize: MapPanelLayout.expandedExtent,
            snap: true,
            snapSizes: const [
              MapPanelLayout.compactExtent,
              MapPanelLayout.initialExtent,
            ],
            snapAnimationDuration: const Duration(milliseconds: 320),
            expand: false,
            builder: (context, scrollController) {
              return Material(
                color: colors.surfaceContainerLow,
                elevation: 16,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: _buildContent(
                  context,
                  scrollController: scrollController,
                  showDragHandle: true,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSidePanel(BuildContext context, BoxConstraints constraints) {
    final colors = Theme.of(context).colorScheme;
    final safeArea = MediaQuery.paddingOf(context);

    final width = (constraints.maxWidth * MapPanelLayout.sidePanelWidthFraction)
        .clamp(
          MapPanelLayout.minSidePanelWidth,
          MapPanelLayout.maxSidePanelWidth,
        )
        .toDouble();

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          0,
          safeArea.top + 12,
          safeArea.right + 12,
          safeArea.bottom + 12,
        ),
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: Material(
            color: colors.surfaceContainerLow,
            elevation: 12,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(24),
            child: _buildContent(
              context,
              scrollController: ScrollController(),
              showDragHandle: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required ScrollController scrollController,
    required bool showDragHandle,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showDragHandle) ...[
                  Center(
                    child: Container(
                      width: 38,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 10),

                // ---------------------------------------------------------
                // Country header
                // ---------------------------------------------------------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CountryFlag(countryCode: preview.countryCode),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preview.countryName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _buildStatusBadges(context),

                              TextButton(
                                key: const Key('mapCountryViewDetails'),
                                onPressed: onViewDetails,
                                style: TextButton.styleFrom(
                                  foregroundColor: colors.onSurfaceVariant,
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 8,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'View details',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      key: const Key('mapCountryPanelClose'),
                      tooltip: 'Close country panel',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ---------------------------------------------------------
                // Statistics
                // ---------------------------------------------------------
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Statistic(
                          value: '${preview.visitCount}',
                          label: 'Visits',
                        ),
                      ),

                      Container(
                        height: 42,
                        width: 1,
                        color: colors.outlineVariant,
                      ),

                      Expanded(
                        child: _Statistic(
                          value: relatedState.hasData
                              ? '${relatedState.cityCount}'
                              : '—',
                          label: 'Cities',
                        ),
                      ),

                      Container(
                        height: 42,
                        width: 1,
                        color: colors.outlineVariant,
                      ),

                      Expanded(
                        child: _Statistic(
                          value: relatedState.hasData
                              ? '${relatedState.tripCount}'
                              : '—',
                          label: 'Trips',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ---------------------------------------------------------
                // Travel history
                // ---------------------------------------------------------
                Text(
                  'Travel history',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 12),

                if (!preview.hasAnyStatus)
                  Text(
                    'You have no travel records for this country yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  )
                else ...[
                  if (preview.hasVisited)
                    _InfoRow(
                      icon: Icons.check_circle_outline,
                      text:
                          '${preview.visitCount} recorded '
                          '${preview.visitCount == 1 ? 'visit' : 'visits'}',
                    ),

                  if (preview.hasLived)
                    _InfoRow(
                      icon: Icons.home_outlined,
                      text:
                          '${preview.residenceCount} '
                          '${preview.residenceCount == 1 ? 'residence period' : 'residence periods'}',
                    ),

                  if (preview.isCountryWishlisted)
                    const _InfoRow(
                      icon: Icons.bookmark_outline,
                      text: 'Country added to wishlist',
                    ),

                  if (preview.hasWishlistedCities)
                    const _InfoRow(
                      icon: Icons.location_city_outlined,
                      text: 'Contains wishlisted cities',
                    ),
                ],

                const SizedBox(height: 20),

                // ---------------------------------------------------------
                // Related cities and Trips
                // ---------------------------------------------------------
                if (relatedState.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  )
                else if (relatedState.phase == MapCountryRelatedPhase.failure)
                  Text(
                    relatedState.errorMessage ??
                        'Unable to load related destinations.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.error,
                    ),
                  )
                else if (relatedState.hasData) ...[
                  if (relatedState.cities.isNotEmpty) ...[
                    Text(
                      'Cities',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 10),

                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      text: relatedState.cities
                          .map((city) => city.cityName)
                          .join(' · '),
                    ),

                    const SizedBox(height: 16),
                  ],

                  if (relatedState.trips.isNotEmpty) ...[
                    Text(
                      'Trips',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 10),

                    _InfoRow(
                      icon: Icons.luggage_outlined,
                      text: relatedState.trips
                          .map((trip) => trip.name)
                          .join(' · '),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadges(BuildContext context) {
    final statuses = <String>[
      if (preview.hasVisited) 'Visited',
      if (preview.hasLived) 'Lived',
      if (preview.appearsInWishlist) 'Wishlist',
    ];

    if (statuses.isEmpty) {
      statuses.add('Not visited');
    }

    final colors = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final status in statuses)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _Statistic extends StatelessWidget {
  const _Statistic({required this.value, required this.label});

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
          style: theme.textTheme.headlineMedium?.copyWith(
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
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
