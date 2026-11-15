import 'package:beenaround/features/trips/domain/trip.dart';
import 'package:beenaround/features/trips/presentation/widgets/trip_card.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Trip createTrip() {
    return Trip(
      id: 'trip-1',
      name: 'A very long journey across several countries',
      description:
          'A journey with multiple destinations, '
          'flights and memorable experiences.',
      startedOn: null,
      endedOn: null,
      createdAt: DateTime(2026, 11, 5),
      updatedAt: DateTime(2026, 11, 5),
    );
  }

  Future<void> pumpCard(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: TripCard(
              trip: createTrip(),
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    );
  }

  for (final width in <double>[320, 390, 768, 1280]) {
    for (final textScale in <double>[1.0, 1.5, 2.0]) {
      testWidgets(
        'TripCard renders at ${width.toInt()}px with ${textScale}x text',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;

          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await pumpCard(tester, textScale: textScale);

          await tester.pumpAndSettle();

          expect(find.byKey(const Key('tripCard-trip-1')), findsOneWidget);

          expect(find.byKey(const Key('editTrip-trip-1')), findsOneWidget);

          expect(find.byKey(const Key('deleteTrip-trip-1')), findsOneWidget);

          expect(find.text('Dates unknown'), findsOneWidget);

          expect(
            tester.takeException(),
            isNull,
            reason:
                'TripCard overflow at ${width.toInt()}px '
                'with ${textScale}x text.',
          );
        },
      );
    }
  }
}
