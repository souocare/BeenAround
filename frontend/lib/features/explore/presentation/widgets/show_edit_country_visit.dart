import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/edit_country_visit_cubit.dart';
import '../../application/explore_cubit.dart';
import '../../domain/country.dart';
import '../../domain/country_visit.dart';
import 'edit_country_visit_sheet.dart';

Future<bool> showEditCountryVisit(
  BuildContext context, {
  required Country country,
  required CountryVisit visit,
}) async {
  final exploreCubit = context.read<ExploreCubit>();
  final repository = exploreCubit.repository;

  final width = MediaQuery.sizeOf(context).width;

  Widget buildContent(BuildContext context) {
    return BlocProvider<EditCountryVisitCubit>(
      create: (_) => EditCountryVisitCubit(repository: repository),
      child: EditCountryVisitSheet(country: country, visit: visit),
    );
  }

  if (width >= 800) {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
        child: SizedBox(height: 580, child: buildContent(context)),
      ),
    );

    return result ?? false;
  }

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height * 0.85;

      return SizedBox(height: height, child: buildContent(context));
    },
  );

  return result ?? false;
}
