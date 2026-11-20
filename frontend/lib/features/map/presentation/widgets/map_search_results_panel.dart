import 'package:flutter/material.dart';

import '../../application/map_search_results.dart';
import '../../application/map_search_state.dart';
import '../../domain/map_search_destination.dart';
import '../../../../app/widgets/country_flag.dart';

/// Displays geographic search results grouped by destination type.
///
/// This widget is presentation-only:
/// - It does not perform repository requests.
/// - It does not control map selection.
/// - It does not control camera navigation.
class MapSearchResultsPanel extends StatelessWidget {
  const MapSearchResultsPanel({
    required this.state,
    required this.onDestinationSelected,
    required this.onRetry,
    this.maxHeight = 420,
    super.key,
  });

  final MapSearchState state;

  final ValueChanged<MapSearchDestination> onDestinationSelected;

  final VoidCallback onRetry;

  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      key: const Key('mapSearchResultsPanel'),
      color: colors.surfaceContainerLow,
      elevation: 12,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (state.phase) {
      case MapSearchPhase.idle:
        return const SizedBox.shrink();

      case MapSearchPhase.waiting:
      case MapSearchPhase.loading:
        return const _MapSearchLoadingSkeleton();

      case MapSearchPhase.failure:
        return _buildError(context);

      case MapSearchPhase.ready:
        return _buildResults(context);
    }
  }

  Widget _buildResults(BuildContext context) {
    final results = state.results;

    if (results.hasNoResults) {
      return _buildMessage(
        context,
        icon: Icons.search_off_rounded,
        message: 'No destinations found',
      );
    }

    final children = <Widget>[];

    _addSection(children, title: 'Countries', destinations: results.countries);

    _addSection(children, title: 'Cities', destinations: results.cities);

    _addSection(children, title: 'Airports', destinations: results.airports);

    if (results.hasErrors) {
      children.add(_buildPartialError(context));
    }

    return ListView(
      key: const Key('mapSearchResultsList'),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: children,
    );
  }

  void _addSection(
    List<Widget> children, {
    required String title,
    required List<MapSearchDestination> destinations,
  }) {
    if (destinations.isEmpty) return;

    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Builder(
          builder: (context) {
            final colors = Theme.of(context).colorScheme;

            return Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            );
          },
        ),
      ),
    );

    for (final destination in destinations) {
      children.add(_buildDestinationTile(destination));
    }
  }

  Widget _buildDestinationTile(MapSearchDestination destination) {
    final icon = switch (destination.type) {
      MapSearchDestinationType.country => Icons.public_rounded,
      MapSearchDestinationType.city => Icons.location_city_rounded,
      MapSearchDestinationType.airport => Icons.flight_rounded,
    };

    return Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;

        return ListTile(
          key: ValueKey('mapSearchResult:${destination.id}'),
          minTileHeight: 56,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 2,
          ),
          leading: Icon(icon, color: colors.onSurfaceVariant, size: 22),
          title: Text(
            destination.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: _buildDestinationSubtitle(context, destination),
          onTap: () => onDestinationSelected(destination),
        );
      },
    );
  }

  Widget _buildDestinationSubtitle(
    BuildContext context,
    MapSearchDestination destination,
  ) {
    final colors = Theme.of(context).colorScheme;

    final textStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant);

    final countryCode = destination.countryCode?.trim();

    final hasCountryCode =
        countryCode != null && RegExp(r'^[A-Za-z]{2}$').hasMatch(countryCode);

    Widget countryFlag() {
      return CountryFlag(
        countryCode: countryCode!,
        size: 26,
        showBackground: false,
      );
    }

    Widget flexibleText(String text) {
      return Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: textStyle,
        ),
      );
    }

    switch (destination.type) {
      // -----------------------------------------------------------------------
      // Countries
      // -----------------------------------------------------------------------

      case MapSearchDestinationType.country:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasCountryCode) ...[countryFlag(), const SizedBox(width: 8)],
            flexibleText(destination.subtitle),
          ],
        );

      // -----------------------------------------------------------------------
      // Cities
      // -----------------------------------------------------------------------

      case MapSearchDestinationType.city:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasCountryCode) ...[countryFlag(), const SizedBox(width: 8)],
            flexibleText(destination.subtitle),
          ],
        );

      // -----------------------------------------------------------------------
      // Airports
      // -----------------------------------------------------------------------

      case MapSearchDestinationType.airport:
        final airportCode = destination.airportCode;
        final airportLocation = destination.airportLocation;

        // Older manually constructed destinations may not have
        // the structured airport fields populated.
        //
        // Keep their existing subtitle instead of attempting
        // to parse a formatted string.
        if (airportCode == null || airportLocation == null) {
          return Text(
            destination.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              airportCode,
              maxLines: 1,
              style: textStyle?.copyWith(fontWeight: FontWeight.w600),
            ),

            if (hasCountryCode) ...[
              const SizedBox(width: 6),
              Text('·', style: textStyle),
              const SizedBox(width: 6),
              countryFlag(),
            ],

            const SizedBox(width: 6),
            Text('·', style: textStyle),
            const SizedBox(width: 6),

            flexibleText(airportLocation),
          ],
        );
    }
  }

  Widget _buildMessage(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: colors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Unable to search destinations',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }

  Widget _buildPartialError(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Some results could not be loaded.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Compact animated placeholder displayed while geographic
/// search results are being prepared or loaded.
class _MapSearchLoadingSkeleton extends StatefulWidget {
  const _MapSearchLoadingSkeleton();

  @override
  State<_MapSearchLoadingSkeleton> createState() =>
      _MapSearchLoadingSkeletonState();
}

class _MapSearchLoadingSkeletonState extends State<_MapSearchLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _opacity = Tween<double>(
      begin: 0.30,
      end: 0.75,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Searching destinations',
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 23),
        child: FadeTransition(
          opacity: reduceMotion
              ? const AlwaysStoppedAnimation<double>(0.65)
              : _opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLine(colors, widthFactor: 0.75, height: 13),

              const SizedBox(height: 12),

              _buildLine(colors, widthFactor: 0.48, height: 11),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLine(
    ColorScheme colors, {
    required double widthFactor,
    required double height,
  }) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: colors.onSurfaceVariant.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
