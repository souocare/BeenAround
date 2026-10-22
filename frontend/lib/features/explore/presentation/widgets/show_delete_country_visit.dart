import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/delete_country_visit_cubit.dart';
import '../../application/explore_cubit.dart';
import '../../domain/country.dart';
import '../../domain/country_visit.dart';
import 'delete_country_visit_dialog.dart';

Future<bool> showDeleteCountryVisit(
  BuildContext context, {
  required Country country,
  required CountryVisit visit,
}) async {
  final repository = context.read<ExploreCubit>().repository;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return BlocProvider<DeleteCountryVisitCubit>(
        create: (_) => DeleteCountryVisitCubit(repository: repository),
        child: DeleteCountryVisitDialog(country: country, visit: visit),
      );
    },
  );

  return result ?? false;
}
