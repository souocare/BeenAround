import 'package:flutter/material.dart';

import '../../application/explore_destination_filter.dart';

/// Horizontally scrollable filters shared by country and city history.
class DestinationFilterBar extends StatefulWidget {
  const DestinationFilterBar({
    required this.selectedFilter,
    required this.onSelected,
    required this.keyPrefix,
    super.key,
  });

  final ExploreDestinationFilter selectedFilter;
  final ValueChanged<ExploreDestinationFilter> onSelected;
  final String keyPrefix;

  @override
  State<DestinationFilterBar> createState() => _DestinationFilterBarState();
}

class _DestinationFilterBarState extends State<DestinationFilterBar> {
  final ScrollController _scrollController = ScrollController();

  final Map<ExploreDestinationFilter, GlobalKey> _filterKeys = {
    for (final filter in ExploreDestinationFilter.values) filter: GlobalKey(),
  };

  @override
  void didUpdateWidget(covariant DestinationFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedFilter != widget.selectedFilter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureSelectedVisible();
      });
    }
  }

  void _ensureSelectedVisible() {
    final selectedContext = _filterKeys[widget.selectedFilter]?.currentContext;

    if (selectedContext == null || !_scrollController.hasClients) {
      return;
    }

    Scrollable.ensureVisible(
      selectedContext,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      key: const Key('destinationFiltersScroll'),
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in ExploreDestinationFilter.values) ...[
            if (filter != ExploreDestinationFilter.values.first)
              const SizedBox(width: 8),
            KeyedSubtree(
              key: _filterKeys[filter],
              child: ChoiceChip(
                key: Key('${widget.keyPrefix}-${filter.name}'),
                label: Text(switch (filter) {
                  ExploreDestinationFilter.all => 'All',
                  ExploreDestinationFilter.been => 'Been',
                  ExploreDestinationFilter.lived => 'Lived',
                  ExploreDestinationFilter.wish => 'Wish',
                  ExploreDestinationFilter.multipleVisits => 'Multiple visits',
                }),
                selected: widget.selectedFilter == filter,
                showCheckmark: false,
                selectedColor: colors.secondary,
                backgroundColor: colors.surfaceContainerLow,
                side: BorderSide(
                  color: widget.selectedFilter == filter
                      ? Colors.transparent
                      : colors.outlineVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                labelStyle: TextStyle(
                  color: widget.selectedFilter == filter
                      ? colors.onSecondary
                      : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                onSelected: (_) => widget.onSelected(filter),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
