import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/visit_date_precision.dart';
import '../../application/residences_cubit.dart';
import '../../application/residences_state.dart';
import '../../domain/residence.dart';
import '../../domain/residence_repository.dart';
import 'show_delete_residence.dart';
import 'show_edit_residence.dart';

Future<void> showResidences({
  required BuildContext context,
  required String destinationName,
  required String countryCode,
  int? cityId,
}) async {
  final residencesCubit = context.read<ResidencesCubit>();
  final repository = context.read<ResidenceRepository>();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => RepositoryProvider<ResidenceRepository>.value(
      value: repository,
      child: BlocProvider<ResidencesCubit>.value(
        value: residencesCubit,
        child: _ResidencesSheet(
          destinationName: destinationName,
          countryCode: countryCode,
          cityId: cityId,
        ),
      ),
    ),
  );
}

class _ResidencesSheet extends StatelessWidget {
  const _ResidencesSheet({
    required this.destinationName,
    required this.countryCode,
    required this.cityId,
  });

  final String destinationName;
  final String countryCode;
  final int? cityId;

  String _formatDate(
    BuildContext context,
    DateTime date,
    VisitDatePrecision precision,
  ) {
    final localization = MaterialLocalizations.of(context);

    if (precision == VisitDatePrecision.month) {
      return localization.formatMonthYear(date);
    }

    return localization.formatMediumDate(date);
  }

  Future<void> _delete(BuildContext context, Residence residence) async {
    final cubit = context.read<ResidencesCubit>();

    final deleted = await showDeleteResidence(
      context: context,
      residence: residence,
    );

    if (!deleted || !context.mounted || cubit.isClosed) return;

    await cubit.refresh();
  }

  Future<void> _edit(BuildContext context, Residence residence) async {
    final cubit = context.read<ResidencesCubit>();

    final updated = await showEditResidence(
      context: context,
      residence: residence,
    );

    if (!updated || !context.mounted || cubit.isClosed) return;

    await cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: BlocBuilder<ResidencesCubit, ResidencesState>(
            builder: (context, state) {
              final residences = cityId == null
                  ? state.residencesForCountry(countryCode)
                  : state.residencesForCity(cityId!);

              final sorted = [...residences]
                ..sort((a, b) => b.startedOn.compareTo(a.startedOn));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Residences in $destinationName',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${sorted.length} ${sorted.length == 1 ? 'period' : 'periods'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),

                  if (state.phase == ResidencesPhase.failure &&
                      state.errorMessage != null) ...[
                    Text(
                      state.errorMessage!,
                      key: const Key('residencesLoadError'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.read<ResidencesCubit>().refresh(),
                      child: const Text('Retry'),
                    ),
                  ],

                  Expanded(
                    child: sorted.isEmpty
                        ? const Center(
                            child: Text('No residence periods found.'),
                          )
                        : ListView.separated(
                            itemCount: sorted.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final residence = sorted[index];

                              final started = _formatDate(
                                context,
                                residence.startedOn,
                                residence.startedOnPrecision,
                              );

                              final ended = _formatDate(
                                context,
                                residence.endedOn,
                                residence.endedOnPrecision,
                              );

                              return Card(
                                key: Key('residence-${residence.id}'),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  title: Text('$started – $ended'),
                                  subtitle:
                                      residence.note == null ||
                                          residence.note!.isEmpty
                                      ? null
                                      : Text(residence.note!),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        key: Key(
                                          'editResidence-${residence.id}',
                                        ),
                                        tooltip: 'Edit residence',
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () =>
                                            _edit(context, residence),
                                      ),
                                      IconButton(
                                        key: Key(
                                          'deleteResidence-${residence.id}',
                                        ),
                                        tooltip: 'Delete residence',
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                        ),
                                        onPressed: () =>
                                            _delete(context, residence),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
