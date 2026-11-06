import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum CupertinoPeriodPickerMode { monthAndYear, yearOnly }

Future<DateTime?> showCupertinoPartialDateWheelPicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required CupertinoPeriodPickerMode mode,
}) {
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (popupContext) {
      return CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Theme.of(context).brightness,
          primaryColor: Theme.of(context).colorScheme.primary,
        ),
        child: _CupertinoPartialDateWheelPicker(
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          mode: mode,
        ),
      );
    },
  );
}

class _CupertinoPartialDateWheelPicker extends StatefulWidget {
  const _CupertinoPartialDateWheelPicker({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.mode,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final CupertinoPeriodPickerMode mode;

  @override
  State<_CupertinoPartialDateWheelPicker> createState() =>
      _CupertinoPartialDateWheelPickerState();
}

class _CupertinoPartialDateWheelPickerState
    extends State<_CupertinoPartialDateWheelPicker> {
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  late int _selectedMonth;
  late int _selectedYear;

  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _yearController;

  bool get _isMonthAndYear =>
      widget.mode == CupertinoPeriodPickerMode.monthAndYear;

  @override
  void initState() {
    super.initState();

    _selectedMonth = widget.initialDate.month;
    _selectedYear = widget.initialDate.year;

    _monthController = FixedExtentScrollController(
      initialItem: _selectedMonth - 1,
    );

    _yearController = FixedExtentScrollController(
      initialItem: _selectedYear - widget.firstDate.year,
    );
  }

  @override
  void dispose() {
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  bool get _isValidSelection {
    if (!_isMonthAndYear) {
      return _selectedYear >= widget.firstDate.year &&
          _selectedYear <= widget.lastDate.year;
    }

    final monthStart = DateTime(_selectedYear, _selectedMonth);

    final monthEnd = DateTime(_selectedYear, _selectedMonth + 1, 0);

    return !monthEnd.isBefore(widget.firstDate) &&
        !monthStart.isAfter(widget.lastDate);
  }

  void _confirmSelection() {
    if (!_isValidSelection) return;

    final date = _isMonthAndYear
        ? DateTime(_selectedYear, _selectedMonth)
        : DateTime(_selectedYear);

    Navigator.of(context).pop(date);
  }

  Widget _buildMonthPicker() {
    return CupertinoPicker.builder(
      key: const Key('cupertinoMonthPicker'),
      scrollController: _monthController,
      itemExtent: 38,
      selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(),
      onSelectedItemChanged: (index) {
        setState(() {
          _selectedMonth = index + 1;
        });
      },
      childCount: 12,
      itemBuilder: (context, index) {
        return Center(
          child: Text(_months[index], style: const TextStyle(fontSize: 18)),
        );
      },
    );
  }

  Widget _buildYearPicker() {
    final firstYear = widget.firstDate.year;
    final yearCount = widget.lastDate.year - firstYear + 1;

    return CupertinoPicker.builder(
      key: const Key('cupertinoYearPicker'),
      scrollController: _yearController,
      itemExtent: 38,
      selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(),
      onSelectedItemChanged: (index) {
        setState(() {
          _selectedYear = firstYear + index;
        });
      },
      childCount: yearCount,
      itemBuilder: (context, index) {
        return Center(
          child: Text(
            '${firstYear + index}',
            style: const TextStyle(fontSize: 20),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final background = CupertinoColors.systemBackground.resolveFrom(context);
    final secondaryText = CupertinoColors.secondaryLabel.resolveFrom(context);

    final title = _isMonthAndYear ? 'Select month and year' : 'Select year';

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CupertinoButton(
                    key: const Key('cancelCupertinoPeriod'),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),

                  CupertinoButton(
                    key: const Key('confirmCupertinoPeriod'),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: _isValidSelection ? _confirmSelection : null,
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: _isValidSelection
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              SizedBox(
                height: 220,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: _isMonthAndYear ? 340 : 180,
                    ),
                    child: Row(
                      children: [
                        if (_isMonthAndYear) ...[
                          Expanded(flex: 3, child: _buildMonthPicker()),
                          const SizedBox(width: 8),
                        ],
                        Expanded(flex: 2, child: _buildYearPicker()),
                      ],
                    ),
                  ),
                ),
              ),

              if (!_isValidSelection) ...[
                const SizedBox(height: 8),
                Text(
                  'Choose a month within the allowed date range.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryText, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
