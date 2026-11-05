import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/models/partial_visit_date.dart';
import '../../../../core/models/visit_date_precision.dart';

import '../../domain/trip.dart';
import '../../domain/trip_status.dart';

class TripCard extends StatelessWidget {
  const TripCard({required this.trip, this.onEdit, super.key});

  final Trip trip;
  final VoidCallback? onEdit;

  String _formatPartialDate(PartialVisitDate value) {
    final date = value.date;

    const months = [
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

    return switch (value.precision) {
      VisitDatePrecision.day =>
        '${months[date.month - 1]} ${date.day}, ${date.year}',

      VisitDatePrecision.month => '${months[date.month - 1]} ${date.year}',

      VisitDatePrecision.year => '${date.year}',
    };
  }

  String get _dateLabel {
    final start = trip.startedOn;
    final end = trip.endedOn;

    if (start == null && end == null) {
      return 'Dates not specified';
    }

    if (start != null && end == null) {
      return 'From ${_formatPartialDate(start)}';
    }

    if (start == null && end != null) {
      return 'Until ${_formatPartialDate(end)}';
    }

    return '${_formatPartialDate(start!)} – ${_formatPartialDate(end!)}';
  }

  String _statusLabel(TripStatus status) {
    return switch (status) {
      TripStatus.upcoming => 'Upcoming',
      TripStatus.ongoing => 'Ongoing',
      TripStatus.completed => 'Completed',
      TripStatus.undated => 'Dates unknown',
    };
  }

  IconData _statusIcon(TripStatus status) {
    return switch (status) {
      TripStatus.upcoming => Icons.event_outlined,
      TripStatus.ongoing => Icons.explore_outlined,
      TripStatus.completed => Icons.check_circle_outline,
      TripStatus.undated => Icons.help_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final status = resolveTripStatus(trip);

    final statusColor = switch (status) {
      TripStatus.upcoming => colors.primary,
      TripStatus.ongoing => colors.tertiary,
      TripStatus.completed => colors.secondary,
      TripStatus.undated => colors.onSurfaceVariant,
    };

    return Container(
      key: Key('tripCard-${trip.id}'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.luggage_outlined,
                  color: colors.primary,
                  size: 25,
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    if (trip.description != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        trip.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Dates
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 17,
                color: colors.onSurfaceVariant,
              ),

              const SizedBox(width: AppSpacing.sm),

              Expanded(
                child: Text(
                  _dateLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.45),
          ),

          const SizedBox(height: AppSpacing.md),

          // Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(status), size: 15, color: statusColor),

                    const SizedBox(width: AppSpacing.xs),

                    Text(
                      _statusLabel(status),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              if (onEdit != null)
                IconButton(
                  key: Key('editTrip-${trip.id}'),
                  tooltip: 'Edit Trip',
                  onPressed: onEdit,
                  icon: Icon(
                    Icons.edit_outlined,
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
