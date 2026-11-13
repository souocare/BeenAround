import 'package:beenaround/features/flights/presentation/widgets/adaptive_flight_time_picker.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const initialTime = TimeOfDay(hour: 14, minute: 30);

  Future<void> pumpPickerApp(
    WidgetTester tester, {
    required TargetPlatform platform,
    required ValueChanged<TimeOfDay?> onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform, useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  onPressed: () async {
                    final result = await showAdaptiveFlightTimePicker(
                      context: context,
                      initialTime: initialTime,
                    );

                    onResult(result);
                  },
                  child: const Text('Select time'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  group('iOS time picker', () {
    testWidgets('opens CupertinoDatePicker', (tester) async {
      await pumpPickerApp(
        tester,
        platform: TargetPlatform.iOS,
        onResult: (_) {},
      );

      await tester.tap(find.text('Select time'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsOneWidget);

      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );

      expect(picker.mode, CupertinoDatePickerMode.time);

      expect(picker.use24hFormat, isTrue);
      expect(picker.minuteInterval, 1);
    });

    testWidgets('cancel returns null', (tester) async {
      TimeOfDay? result;
      var completed = false;

      await pumpPickerApp(
        tester,
        platform: TargetPlatform.iOS,
        onResult: (value) {
          result = value;
          completed = true;
        },
      );

      await tester.tap(find.text('Select time'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(result, isNull);

      expect(find.byType(CupertinoDatePicker), findsNothing);
    });

    testWidgets('done returns selected time', (tester) async {
      TimeOfDay? result;

      await pumpPickerApp(
        tester,
        platform: TargetPlatform.iOS,
        onResult: (value) {
          result = value;
        },
      );

      await tester.tap(find.text('Select time'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(result, initialTime);
    });

    testWidgets('selected time is preserved without timezone conversion', (
      tester,
    ) async {
      TimeOfDay? result;

      await pumpPickerApp(
        tester,
        platform: TargetPlatform.iOS,
        onResult: (value) {
          result = value;
        },
      );

      await tester.tap(find.text('Select time'));
      await tester.pumpAndSettle();

      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );

      expect(picker.initialDateTime.hour, 14);
      expect(picker.initialDateTime.minute, 30);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(result?.hour, 14);
      expect(result?.minute, 30);
    });
  });

  group('Android time picker', () {
    testWidgets('opens Material time picker', (tester) async {
      await pumpPickerApp(
        tester,
        platform: TargetPlatform.android,
        onResult: (_) {},
      );

      await tester.tap(find.text('Select time'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsNothing);

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('cancel returns null', (tester) async {
      TimeOfDay? result;
      var completed = false;

      await pumpPickerApp(
        tester,
        platform: TargetPlatform.android,
        onResult: (value) {
          result = value;
          completed = true;
        },
      );

      await tester.tap(find.text('Select time'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(result, isNull);
    });
  });
}
