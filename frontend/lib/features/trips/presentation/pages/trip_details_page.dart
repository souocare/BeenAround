import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/models/partial_visit_date.dart';
import '../../../../core/models/visit_date_precision.dart';

import '../../application/trip_details_cubit.dart';
import '../../application/trip_details_state.dart';
import '../../domain/trip.dart';
import '../../domain/trip_repository.dart';
import '../../domain/trip_status.dart';

import '../widgets/trip_form_dialog.dart';
import '../widgets/delete_trip_dialog.dart';

import '../../application/trip_associations_cubit.dart';

import '../../domain/trip_association_repository.dart';

import '../widgets/trip_associated_visits_section.dart';

class TripDetailsPage extends StatelessWidget {
  const TripDetailsPage({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TripDetailsCubit>(
          create: (context) => TripDetailsCubit(
            repository: context.read<TripRepository>(),
            tripId: tripId,
          )..load(),
        ),

        BlocProvider<TripAssociationsCubit>(
          create: (context) => TripAssociationsCubit(
            repository: context.read<TripAssociationRepository>(),
            tripId: tripId,
          )..load(),
        ),
      ],
      child: const _TripDetailsView(),
    );
  }
}

class _TripDetailsView extends StatelessWidget {
  const _TripDetailsView();

  Future<void> _editTrip(BuildContext context, Trip trip) async {
    final cubit = context.read<TripDetailsCubit>();

    final saved = await showTripFormDialog(context: context, trip: trip);

    if (!context.mounted || !saved) return;

    await cubit.refresh();
  }

  Future<void> _deleteTrip(BuildContext context, Trip trip) async {
    final deleted = await showDeleteTripDialog(context: context, trip: trip);

    if (!context.mounted || !deleted) return;

    Navigator.of(context).pop();
  }

  String _formatDate(BuildContext context, PartialVisitDate value) {
    final localization = MaterialLocalizations.of(context);

    return switch (value.precision) {
      VisitDatePrecision.day => localization.formatMediumDate(value.date),
      VisitDatePrecision.month => localization.formatMonthYear(value.date),
      VisitDatePrecision.year => '${value.date.year}',
    };
  }

  String _dateRange(BuildContext context, Trip trip) {
    final start = trip.startedOn;
    final end = trip.endedOn;

    if (start == null && end == null) {
      return 'Dates not specified';
    }

    if (start != null && end == null) {
      return 'From ${_formatDate(context, start)}';
    }

    if (start == null && end != null) {
      return 'Until ${_formatDate(context, end)}';
    }

    return '${_formatDate(context, start!)} – '
        '${_formatDate(context, end!)}';
  }

  String _statusLabel(Trip trip) {
    return switch (resolveTripStatus(trip)) {
      TripStatus.upcoming => 'Upcoming',
      TripStatus.ongoing => 'Ongoing',
      TripStatus.completed => 'Completed',
      TripStatus.undated => 'Dates unknown',
    };
  }

  Widget _buildTripContent(BuildContext context, Trip trip) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.name,
                        key: const Key('tripDetailsName'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      Text(
                        _statusLabel(trip),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: AppSpacing.md),

                IconButton.filledTonal(
                  key: const Key('editTripDetailsButton'),
                  tooltip: 'Edit Trip',
                  onPressed: () => _editTrip(context, trip),
                  icon: const Icon(Icons.edit_outlined),
                ),
                const SizedBox(width: AppSpacing.sm),

                IconButton(
                  key: const Key('deleteTripDetailsButton'),
                  tooltip: 'Delete Trip',
                  onPressed: () => _deleteTrip(context, trip),
                  icon: Icon(Icons.delete_outline, color: colors.error),
                ),
              ],
            ),

            if (trip.description != null &&
                trip.description!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),

              Text(
                trip.description!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: colors.primary),

                  const SizedBox(width: AppSpacing.md),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Travel dates',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xs),

                        Text(
                          _dateRange(context, trip),
                          key: const Key('tripDetailsDates'),
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),

            const SizedBox(height: AppSpacing.xxxl),

            const TripAssociatedVisitsSection(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Details')),
      body: BlocBuilder<TripDetailsCubit, TripDetailsState>(
        builder: (context, state) {
          if (state.phase == TripDetailsPhase.initial ||
              (state.isLoading && !state.hasData)) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.hasError && !state.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    Text(
                      state.errorMessage ?? 'Unable to load this Trip.',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    OutlinedButton.icon(
                      onPressed: () {
                        context.read<TripDetailsCubit>().load();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final trip = state.trip;

          if (trip == null) {
            return const SizedBox.shrink();
          }

          return Column(
            children: [
              if (state.isLoading) const LinearProgressIndicator(),

              if (state.hasError)
                MaterialBanner(
                  content: Text(
                    state.errorMessage ?? 'Unable to refresh this Trip.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        context.read<TripDetailsCubit>().refresh();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),

              Expanded(child: _buildTripContent(context, trip)),
            ],
          );
        },
      ),
    );
  }
}
