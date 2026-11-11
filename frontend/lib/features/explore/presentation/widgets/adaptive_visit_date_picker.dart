import 'package:cupertino_calendar_picker/cupertino_calendar_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shows a platform-adaptive calendar for selecting an exact date.
///
/// iOS uses a Cupertino-style inline calendar.
/// Android and Web use the Material calendar.
///
/// Returns null when the user cancels.
Future<DateTime?> showAdaptiveVisitDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final useCupertino = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  if (!useCupertino) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      initialEntryMode: DatePickerEntryMode.calendar,
      initialDatePickerMode: DatePickerMode.day,
    );
  }

  return _showCupertinoCalendar(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );
}

Future<DateTime?> _showCupertinoCalendar({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  DateTime selectedDate = DateTime(
    initialDate.year,
    initialDate.month,
    initialDate.day,
  );

  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (popupContext) {
      final theme = Theme.of(popupContext);
      final colors = theme.colorScheme;

      return CupertinoTheme(
        data: CupertinoThemeData(
          brightness: theme.brightness,
          primaryColor: colors.primary,
        ),
        child: CupertinoPopupSurface(
          isSurfacePainted: true,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CupertinoButton(
                        key: const Key('cancelCupertinoCalendar'),
                        onPressed: () {
                          Navigator.of(popupContext).pop();
                        },
                        child: const Text('Cancel'),
                      ),

                      const Spacer(),

                      CupertinoButton(
                        key: const Key('confirmCupertinoCalendar'),
                        onPressed: () {
                          Navigator.of(popupContext).pop(selectedDate);
                        },
                        child: const Text('Done'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  CupertinoCalendar(
                    key: const Key('beenAroundCupertinoCalendar'),
                    mode: CupertinoCalendarMode.date,
                    type: CupertinoCalendarType.inline,
                    minimumDateTime: firstDate,
                    maximumDateTime: lastDate,
                    initialDateTime: selectedDate,
                    currentDateTime: DateTime.now(),
                    mainColor: colors.primary,
                    maxWidth: 400,

                    weekdayDecoration: CalendarWeekdayDecoration(
                      textStyle: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),

                    onDateTimeChanged: (date) {
                      selectedDate = DateTime(date.year, date.month, date.day);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
