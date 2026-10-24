import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/delete_city_visit_cubit.dart';
import '../../domain/visited_city.dart';
import '../../../geography/domain/city_visit.dart';
import '../../../geography/domain/city_visits_repository.dart';
import 'delete_city_visit_dialog.dart';

Future<bool> showDeleteCityVisit(
  BuildContext context, {
  required VisitedCity city,
  required CityVisit visit,
}) async {
  final repository = context.read<CityVisitsRepository>();

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return BlocProvider<DeleteCityVisitCubit>(
        create: (_) => DeleteCityVisitCubit(repository: repository),
        child: DeleteCityVisitDialog(city: city, visit: visit),
      );
    },
  );

  return result ?? false;
}
