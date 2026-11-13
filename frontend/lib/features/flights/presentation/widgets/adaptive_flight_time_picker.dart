import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Selects a local wall-clock time without timezone conversion.
///
/// Uses the native-style Cupertino picker on iOS and
/// the Material time picker on other platforms.
///
/// Returns null when cancelled.
Future<TimeOfDay?> showAdaptiveFlightTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  final platform = Theme.of(context).platform;

  if (platform == TargetPlatform.iOS) {
    return _showCupertinoFlightTimePicker(
      context: context,
      initialTime: initialTime,
    );
  }

  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      );
    },
  );
}

Future<TimeOfDay?> _showCupertinoFlightTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  var selectedTime = initialTime;

  final initialDateTime = DateTime(
    2020,
    1,
    1,
    initialTime.hour,
    initialTime.minute,
  );

  return showModalBottomSheet<TimeOfDay>(
    context: context,
    useSafeArea: true,
    isScrollControlled: false,
    showDragHandle: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final colors = Theme.of(sheetContext).colorScheme;

      return SafeArea(
        top: false,
        child: SizedBox(
          height: 290,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    CupertinoButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Cancel'),
                    ),

                    const Spacer(),

                    CupertinoButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop(selectedTime);
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: Theme.of(sheetContext).brightness,
                    primaryColor: colors.primary,
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    minuteInterval: 1,
                    initialDateTime: initialDateTime,
                    onDateTimeChanged: (value) {
                      selectedTime = TimeOfDay(
                        hour: value.hour,
                        minute: value.minute,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
