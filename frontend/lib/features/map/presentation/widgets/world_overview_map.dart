import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/world_country_loader.dart';

class WorldOverviewMap extends StatefulWidget {
  const WorldOverviewMap({required this.visitedCountryCodes, super.key});

  final Set<String> visitedCountryCodes;

  @override
  State<WorldOverviewMap> createState() => _WorldOverviewMapState();
}

class _WorldOverviewMapState extends State<WorldOverviewMap> {
  late final Future<List<WorldCountryGeometry>> _countriesFuture;

  @override
  void initState() {
    super.initState();
    _countriesFuture = const WorldCountryLoader().load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 1.9,
      child: FutureBuilder<List<WorldCountryGeometry>>(
        future: _countriesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Map unavailable',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const SizedBox.expand();
          }

          return CustomPaint(
            key: const Key('worldOverviewMap'),
            painter: _WorldMapPainter(
              countries: snapshot.data!,
              visitedCountryCodes: widget.visitedCountryCodes,
              visitedColor: colors.primary,
              unvisitedColor: colors.surfaceContainerHighest,
              borderColor: colors.outlineVariant,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _WorldMapPainter extends CustomPainter {
  const _WorldMapPainter({
    required this.countries,
    required this.visitedCountryCodes,
    required this.visitedColor,
    required this.unvisitedColor,
    required this.borderColor,
  });

  final List<WorldCountryGeometry> countries;
  final Set<String> visitedCountryCodes;
  final Color visitedColor;
  final Color unvisitedColor;
  final Color borderColor;

  static const List<double> _robinsonX = [
    1.0000,
    0.9986,
    0.9954,
    0.9900,
    0.9822,
    0.9730,
    0.9600,
    0.9427,
    0.9216,
    0.8962,
    0.8679,
    0.8350,
    0.7986,
    0.7597,
    0.7186,
    0.6732,
    0.6213,
    0.5722,
    0.5322,
  ];

  static const List<double> _robinsonY = [
    0.0000,
    0.0620,
    0.1240,
    0.1860,
    0.2480,
    0.3100,
    0.3720,
    0.4340,
    0.4958,
    0.5571,
    0.6176,
    0.6769,
    0.7346,
    0.7903,
    0.8435,
    0.8936,
    0.9394,
    0.9761,
    1.0000,
  ];

  Offset _projectCoordinate(List<double> coordinate, Size size) {
    final longitude = coordinate[0].clamp(-180.0, 180.0);
    final latitude = coordinate[1].clamp(-90.0, 90.0);

    final absoluteLatitude = latitude.abs();
    final position = absoluteLatitude / 5.0;

    final lowerIndex = position.floor().clamp(0, 17);
    final upperIndex = lowerIndex + 1;
    final fraction = position - lowerIndex;

    final xCoefficient =
        _robinsonX[lowerIndex] +
        (_robinsonX[upperIndex] - _robinsonX[lowerIndex]) * fraction;

    final yCoefficient =
        _robinsonY[lowerIndex] +
        (_robinsonY[upperIndex] - _robinsonY[lowerIndex]) * fraction;

    // Robinson projection.
    const xScale = 0.8487;
    const yScale = 1.3523;

    final longitudeRadians = longitude * math.pi / 180.0;

    final projectedX = xScale * longitudeRadians * xCoefficient;

    final projectedY = yScale * (latitude < 0 ? -1.0 : 1.0) * yCoefficient;

    // Projected world extents.
    final horizontalExtent = xScale * math.pi;
    final verticalExtent = yScale;

    // Preserve the projection's proportions.
    final scale = math.min(
      size.width / (horizontalExtent * 2),
      size.height / (verticalExtent * 2),
    );

    return Offset(
      size.width / 2 + projectedX * scale - 10,
      size.height / 2 - projectedY * scale,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    canvas.clipRect(Offset.zero & size);

    Offset project(List<double> coordinate) {
      return _projectCoordinate(coordinate, size);
    }

    for (final country in countries) {
      if (country.countryCode == 'AQ') {
        continue;
      }
      final visited =
          country.countryCode != null &&
          visitedCountryCodes.contains(country.countryCode);

      final fillPaint = Paint()
        ..color = visited ? visitedColor : unvisitedColor
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4;

      for (final polygon in country.polygons) {
        final path = Path()..fillType = PathFillType.evenOdd;

        for (final ring in polygon) {
          if (ring.isEmpty) continue;

          final first = project(ring.first);
          path.moveTo(first.dx, first.dy);

          for (final coordinate in ring.skip(1)) {
            final point = project(coordinate);
            path.lineTo(point.dx, point.dy);
          }

          path.close();
        }

        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, borderPaint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WorldMapPainter oldDelegate) {
    return oldDelegate.countries != countries ||
        !setEquals(oldDelegate.visitedCountryCodes, visitedCountryCodes) ||
        oldDelegate.visitedColor != visitedColor ||
        oldDelegate.unvisitedColor != unvisitedColor ||
        oldDelegate.borderColor != borderColor;
  }
}
