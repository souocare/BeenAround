import 'package:flutter/material.dart';

import '../../../flights/presentation/widgets/show_add_flight.dart';
import 'add_destination_sheet.dart';
import 'show_add_destination.dart';

enum AddRecordType { country, city, flight }

class AddRecordResult {
  const AddRecordResult({required this.type, required this.created});

  final AddRecordType type;
  final bool created;

  bool get isFlightCreated => created && type == AddRecordType.flight;
}

/// Entry point for recording countries, cities and flights.
///
/// Each record type retains its own persistence workflow.
Future<AddRecordResult?> showAddRecord(BuildContext context) async {
  final width = MediaQuery.sizeOf(context).width;

  final AddRecordType? selected;

  if (width >= 800) {
    selected = await showDialog<AddRecordType>(
      context: context,
      builder: (_) => const Dialog(
        constraints: BoxConstraints(maxWidth: 440),
        child: _AddRecordSelector(),
      ),
    );
  } else {
    selected = await showModalBottomSheet<AddRecordType>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AddRecordSelector(),
    );
  }

  if (selected == null || !context.mounted) {
    return null;
  }

  final bool created;

  switch (selected) {
    case AddRecordType.country:
      created = await showAddDestination(
        context,
        initialDestinationType: AddDestinationType.country,
      );

    case AddRecordType.city:
      created = await showAddDestination(
        context,
        initialDestinationType: AddDestinationType.city,
      );

    case AddRecordType.flight:
      created = await showAddFlight(context);
  }

  return AddRecordResult(type: selected, created: created);
}

class _AddRecordSelector extends StatelessWidget {
  const _AddRecordSelector();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      primary: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add to BeenAround',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Text(
              'What would you like to record?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 24),

            _AddRecordOption(
              icon: Icons.public_outlined,
              title: 'Country',
              subtitle: 'Record a country you have visited',
              onTap: () => Navigator.of(context).pop(AddRecordType.country),
            ),

            const SizedBox(height: 10),

            _AddRecordOption(
              icon: Icons.location_city_outlined,
              title: 'City',
              subtitle: 'Record a city you have visited',
              onTap: () => Navigator.of(context).pop(AddRecordType.city),
            ),

            const SizedBox(height: 10),

            _AddRecordOption(
              icon: Icons.flight_outlined,
              title: 'Flight',
              subtitle: 'Add a flight to your travel history',
              onTap: () => Navigator.of(context).pop(AddRecordType.flight),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddRecordOption extends StatelessWidget {
  const _AddRecordOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colors.primary),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
