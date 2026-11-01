import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/add_country_visit_cubit.dart';
import '../../application/explore_cubit.dart';
import 'add_destination_sheet.dart';
import '../../domain/country.dart';
import '../../application/add_city_visit_cubit.dart';
import '../../../geography/domain/city_visits_repository.dart';
import '../../../geography/domain/city_repository.dart';
import '../../data/countries_repository.dart';

Future<bool> showAddDestination(
  BuildContext context, {
  Country? initialCountry,
}) async {
  final exploreCubit = context.read<ExploreCubit>();
  final repository = exploreCubit.repository;
  final cityVisitsRepository = context.read<CityVisitsRepository>();
  final cityRepository = context.read<CityRepository>();

  final width = MediaQuery.sizeOf(context).width;

  Widget buildContent(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CityRepository>.value(value: cityRepository),
        RepositoryProvider<CountriesRepository>.value(value: repository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ExploreCubit>.value(value: exploreCubit),
          BlocProvider<AddCountryVisitCubit>(
            create: (_) => AddCountryVisitCubit(repository: repository),
          ),
          BlocProvider<AddCityVisitCubit>(
            create: (_) => AddCityVisitCubit(repository: cityVisitsRepository),
          ),
        ],
        child: AddDestinationSheet(initialCountry: initialCountry),
      ),
    );
  }

  if (width >= 800) {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
        child: SizedBox(height: 700, child: buildContent(context)),
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
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height * 0.94;

      return SizedBox(height: height, child: buildContent(context));
    },
  );

  return result ?? false;
}
