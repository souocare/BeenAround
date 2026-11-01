import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/edit_city_visit_cubit.dart';
import '../../data/countries_repository.dart';
import '../../domain/visited_city.dart';
import '../../../geography/domain/city_visit.dart';
import '../../../geography/domain/city_visits_repository.dart';
import 'edit_city_visit_sheet.dart';

Future<bool> showEditCityVisit(
  BuildContext context, {
  required VisitedCity city,
  required CityVisit visit,
}) async {
  final cityVisitsRepository = context.read<CityVisitsRepository>();
  final countriesRepository = context.read<CountriesRepository>();

  final width = MediaQuery.sizeOf(context).width;

  Widget buildContent(BuildContext context) {
    return RepositoryProvider<CountriesRepository>.value(
      value: countriesRepository,
      child: BlocProvider<EditCityVisitCubit>(
        create: (_) => EditCityVisitCubit(repository: cityVisitsRepository),
        child: EditCityVisitSheet(city: city, visit: visit),
      ),
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
