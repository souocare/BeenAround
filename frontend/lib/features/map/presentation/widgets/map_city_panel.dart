import 'package:flutter/material.dart';

import '../../../../app/widgets/country_flag.dart';
import '../../application/map_city_panel_projection.dart';
import 'map_context_panel_shell.dart';

/// Contextual information panel for a selected geographic city.
///
/// The panel receives a read-only presentation projection.
///
/// City identity may originate from the geographic catalog,
/// while personal travel statistics originate from existing
/// visit, residence and wishlist records.
///
/// This widget does not modify travel records or interact
/// directly with MapLibre.
class MapCityPanel extends StatelessWidget {
  const MapCityPanel({
    required this.data,
    required this.onClose,
    this.compactRequestId = 0,
    this.panelScrollController,
    this.showDragHandle = true,
    super.key,
  });

  final MapCityPanelData data;

  final VoidCallback onClose;

  /// Incremented when the parent requests a compact panel.
  ///
  /// Animation and responsive behavior are delegated to
  /// [MapContextPanelShell].
  final int compactRequestId;

  /// Optional controller provided by a shared panel shell.
  final ScrollController? panelScrollController;

  /// Controls the drag handle in embedded mode.
  final bool showDragHandle;

  // ---------------------------------------------------------------------------
  // Presentation
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final externalController = panelScrollController;

    if (externalController != null) {
      return _buildContent(
        context,
        scrollController: externalController,
        showDragHandle: showDragHandle,
      );
    }

    return MapContextPanelShell(
      compactRequestId: compactRequestId,
      onClose: onClose,
      contentBuilder: (context, scrollController, showDragHandle) {
        return _buildContent(
          context,
          scrollController: scrollController,
          showDragHandle: showDragHandle,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // City content
  // ---------------------------------------------------------------------------

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
                // ---------------------------------------------------------
                // Drag handle
                // ---------------------------------------------------------
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
                // City header
                // ---------------------------------------------------------
                _buildHeader(context),

                const SizedBox(height: 20),

                // ---------------------------------------------------------
                // City status badges
                // ---------------------------------------------------------
                _buildStatusBadges(context),

                const SizedBox(height: 24),

                // ---------------------------------------------------------
                // Personal travel statistics
                // ---------------------------------------------------------
                if (data.hasTravelHistory)
                  _buildStatistics(context)
                else if (!data.hasAnyStatus)
                  _buildEmptyState(context),

                // ---------------------------------------------------------
                // Travel history summary
                // ---------------------------------------------------------
                if (data.hasTravelHistory) ...[
                  const SizedBox(height: 24),

                  Text(
                    'Travel history',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (data.hasVisited)
                    _CityInfoRow(
                      icon: Icons.check_circle_outline_rounded,
                      text:
                          '${data.visitCount} recorded '
                          '${data.visitCount == 1 ? 'visit' : 'visits'}',
                    ),

                  if (data.hasLived)
                    _CityInfoRow(
                      icon: Icons.home_outlined,
                      text:
                          '${data.residenceCount} '
                          '${data.residenceCount == 1 ? 'residence period' : 'residence periods'}',
                    ),
                ],

                // ---------------------------------------------------------
                // Wishlist-only information
                // ---------------------------------------------------------
                if (data.isWishlisted && !data.hasTravelHistory) ...[
                  _buildWishlistInformation(context),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // City header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final countryCode = data.countryCode?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.location_city_rounded,
            size: 25,
            color: colors.primary,
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.name,
                key: const Key('mapCityPanelName'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),

              const SizedBox(height: 8),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (countryCode != null && countryCode.isNotEmpty) ...[
                    CountryFlag(
                      countryCode: countryCode,
                      size: 22,
                      showBackground: false,
                    ),

                    const SizedBox(width: 8),
                  ],

                  Expanded(
                    child: Text(
                      data.countryName,
                      key: const Key('mapCityPanelCountry'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        IconButton(
          key: const Key('mapCityPanelClose'),
          tooltip: 'Close city panel',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Status badges
  // ---------------------------------------------------------------------------

  Widget _buildStatusBadges(BuildContext context) {
    final statuses = <_CityStatus>[
      if (data.hasVisited)
        const _CityStatus(
          label: 'Visited',
          icon: Icons.check_circle_outline_rounded,
        ),
      if (data.hasLived)
        const _CityStatus(label: 'Lived', icon: Icons.home_outlined),
      if (data.isWishlisted)
        const _CityStatus(
          label: 'Wishlist',
          icon: Icons.bookmark_outline_rounded,
        ),
    ];

    if (statuses.isEmpty) {
      statuses.add(
        const _CityStatus(
          label: 'Not visited',
          icon: Icons.location_off_outlined,
        ),
      );
    }

    return Wrap(
      key: const Key('mapCityPanelStatuses'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in statuses)
          _CityStatusBadge(label: status.label, icon: status.icon),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Statistics
  // ---------------------------------------------------------------------------

  Widget _buildStatistics(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      key: const Key('mapCityPanelStatistics'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CityStatistic(value: '${data.visitCount}', label: 'Visits'),
          ),

          Container(height: 42, width: 1, color: colors.outlineVariant),

          Expanded(
            child: _CityStatistic(
              value: '${data.residenceCount}',
              label: 'Residences',
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      key: const Key('mapCityPanelEmpty'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 26,
            color: colors.onSurfaceVariant,
          ),

          const SizedBox(height: 12),

          Text(
            'No travel history recorded',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            "You haven't recorded any visits or "
            'residence periods for this city yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Wishlist-only information
  // ---------------------------------------------------------------------------

  Widget _buildWishlistInformation(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      key: const Key('mapCityPanelWishlistInfo'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bookmark_outline_rounded, color: colors.primary, size: 22),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved to wishlist',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'This city is on your wishlist, but you '
                  "haven't recorded any visits or residence "
                  'periods yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
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

// -----------------------------------------------------------------------------
// Status presentation
// -----------------------------------------------------------------------------

class _CityStatus {
  const _CityStatus({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _CityStatusBadge extends StatelessWidget {
  const _CityStatusBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),

          const SizedBox(width: 7),

          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Statistics
// -----------------------------------------------------------------------------

class _CityStatistic extends StatelessWidget {
  const _CityStatistic({required this.value, required this.label});

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
          textAlign: TextAlign.center,
          softWrap: true,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Information row
// -----------------------------------------------------------------------------

class _CityInfoRow extends StatelessWidget {
  const _CityInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.primary),

          const SizedBox(width: 12),

          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
