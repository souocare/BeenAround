import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/models/partial_visit_date.dart';
import '../../../../core/models/visit_date_precision.dart';

import '../../../explore/presentation/widgets/partial_visit_date_picker.dart';

import '../../application/save_trip_cubit.dart';
import '../../application/save_trip_state.dart';
import '../../domain/trip.dart';
import '../../domain/trip_input.dart';
import '../../domain/trip_repository.dart';
import '../../../explore/data/countries_repository.dart';
import '../../../geography/domain/city_visits_repository.dart';

import 'trip_visit_picker_dialog.dart';
import '../../../explore/domain/country.dart';
import '../../../explore/domain/country_visit.dart';
import '../../../geography/domain/city_visit.dart';

import '../../domain/trip_association_repository.dart';
import '../../application/trip_visit_suggestions.dart';
import '../../domain/trip_status.dart';

import 'inline_trip_visit_suggestions.dart';
import '../../../explore/presentation/widgets/add_destination_sheet.dart';
import '../../../explore/presentation/widgets/show_add_destination.dart';
import '../../../geography/domain/city_repository.dart';

/// Opens the Create/Edit Trip form.
///
/// Uses a bottom sheet on compact screens and a dialog on larger screens.
/// Returns true only when the Trip was successfully persisted.
Future<bool> showTripFormDialog({
  required BuildContext context,
  Trip? trip,
}) async {
  final repository = context.read<TripRepository>();

  final isCreating = trip == null;

  final countriesRepository = isCreating
      ? context.read<CountriesRepository>()
      : null;

  final cityVisitsRepository = isCreating
      ? context.read<CityVisitsRepository>()
      : null;

  final cityRepository = isCreating ? context.read<CityRepository>() : null;

  final associationRepository = isCreating
      ? context.read<TripAssociationRepository>()
      : null;

  final width = MediaQuery.sizeOf(context).width;

  Widget buildContent() {
    final form = BlocProvider(
      create: (_) => SaveTripCubit(
        repository: repository,
        associationRepository: associationRepository,
      ),
      child: TripFormDialog(trip: trip),
    );

    // Editing a Trip does not manage visit associations.
    if (!isCreating) {
      return form;
    }

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CountriesRepository>.value(
          value: countriesRepository!,
        ),
        RepositoryProvider<CityVisitsRepository>.value(
          value: cityVisitsRepository!,
        ),
        RepositoryProvider<CityRepository>.value(value: cityRepository!),
      ],
      child: form,
    );
  }

  if (width >= 800) {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final screenHeight = MediaQuery.sizeOf(dialogContext).height;

        return Dialog(
          child: SizedBox(
            width: 520,
            height: screenHeight * 0.85,
            child: buildContent(),
          ),
        );
      },
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
    builder: (sheetContext) {
      final height = MediaQuery.sizeOf(sheetContext).height * 0.94;

      return AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              const SizedBox(height: 10),

              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      sheetContext,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Expanded(child: buildContent()),
            ],
          ),
        ),
      );
    },
  );

  return result ?? false;
}

/// Shared form used to create and edit Trips.
class TripFormDialog extends StatefulWidget {
  const TripFormDialog({this.trip, super.key});

  final Trip? trip;

  @override
  State<TripFormDialog> createState() => _TripFormDialogState();
}

class _TripFormDialogState extends State<TripFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final Set<String> _selectedCountryVisitIds = {};
  final Set<String> _selectedCityVisitIds = {};
  Map<String, CountryVisit> _countryVisitsById = {};
  Map<String, CityVisit> _cityVisitsById = {};
  Map<String, String> _countryNamesByCode = {};

  bool _isLoadingCountryDetails = false;
  bool _isLoadingCityDetails = false;

  String? _countryDetailsError;
  String? _cityDetailsError;

  int _countryDetailsGeneration = 0;
  int _cityDetailsGeneration = 0;

  PartialVisitDate? _startedOn;
  PartialVisitDate? _endedOn;

  bool get _isEditing => widget.trip != null;

  Future<
    ({
      List<Country> countries,
      List<CountryVisit> countryVisits,
      List<CityVisit> cityVisits,
    })
  >?
  _suggestedVisitsFuture;

  @override
  void initState() {
    super.initState();

    final trip = widget.trip;

    _nameController = TextEditingController(text: trip?.name ?? '');

    _descriptionController = TextEditingController(
      text: trip?.description ?? '',
    );

    _startedOn = trip?.startedOn;
    _endedOn = trip?.endedOn;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  Future<void> _selectDate({required bool isStart}) async {
    final current = isStart ? _startedOn : _endedOn;

    final selected = await showPartialVisitDatePicker(
      context: context,
      initialValue: current,
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _startedOn = selected;
      } else {
        _endedOn = selected;
      }
    });
    _ensureSuggestedVisitsLoaded();
  }

  void _addSuggestedCountryVisit(
    CountryVisit visit,
    Map<String, String> countryNames,
  ) {
    if (_isEditing || context.read<SaveTripCubit>().state.isSubmitting) {
      return;
    }

    if (_selectedCountryVisitIds.contains(visit.id)) {
      return;
    }

    setState(() {
      _selectedCountryVisitIds.add(visit.id);
      _countryVisitsById[visit.id] = visit;
      _countryNamesByCode.addAll(countryNames);

      _countryDetailsError = null;
    });
  }

  void _addSuggestedCityVisit(CityVisit visit) {
    if (_isEditing || context.read<SaveTripCubit>().state.isSubmitting) {
      return;
    }

    if (_selectedCityVisitIds.contains(visit.id)) {
      return;
    }

    setState(() {
      _selectedCityVisitIds.add(visit.id);
      _cityVisitsById[visit.id] = visit;

      _cityDetailsError = null;
    });
  }

  Future<void> _selectCountryVisits() async {
    final selected = await showTripCountryVisitPicker(
      context: context,
      excludedVisitIds: const {},
      initiallySelectedVisitIds: _selectedCountryVisitIds,
      createVisit: () async {
        final result = await showAddDestinationWithResult(
          context,
          destinationType: AddDestinationType.country,
        );

        return result?.visitId;
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedCountryVisitIds
        ..clear()
        ..addAll(selected);
    });

    await _loadSelectedCountryDetails();
  }

  Future<void> _selectCityVisits() async {
    final selected = await showTripCityVisitPicker(
      context: context,
      excludedVisitIds: const {},
      initiallySelectedVisitIds: _selectedCityVisitIds,
      createVisit: () async {
        final result = await showAddDestinationWithResult(
          context,
          destinationType: AddDestinationType.city,
        );

        return result?.visitId;
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedCityVisitIds
        ..clear()
        ..addAll(selected);
    });

    await _loadSelectedCityDetails();
  }

  Future<void> _loadSelectedCountryDetails() async {
    final generation = ++_countryDetailsGeneration;

    if (_selectedCountryVisitIds.isEmpty) {
      setState(() {
        _countryVisitsById = {};
        _countryDetailsError = null;
        _isLoadingCountryDetails = false;
      });

      return;
    }

    final repository = context.read<CountriesRepository>();

    setState(() {
      _isLoadingCountryDetails = true;
      _countryDetailsError = null;
    });

    try {
      final results = await Future.wait<Object>([
        repository.getCountries(),
        repository.getCountryVisits(),
      ]);

      if (!mounted || generation != _countryDetailsGeneration) {
        return;
      }

      final countries = results[0] as List<Country>;
      final visits = results[1] as List<CountryVisit>;

      setState(() {
        _countryNamesByCode = {
          for (final country in countries) country.code: country.name,
        };

        _countryVisitsById = {
          for (final visit in visits)
            if (_selectedCountryVisitIds.contains(visit.id)) visit.id: visit,
        };

        _isLoadingCountryDetails = false;
      });
    } catch (_) {
      if (!mounted || generation != _countryDetailsGeneration) {
        return;
      }

      setState(() {
        _isLoadingCountryDetails = false;
        _countryDetailsError = 'Unable to load country details.';
      });
    }
  }

  Future<void> _loadSelectedCityDetails() async {
    final generation = ++_cityDetailsGeneration;

    if (_selectedCityVisitIds.isEmpty) {
      setState(() {
        _cityVisitsById = {};
        _cityDetailsError = null;
        _isLoadingCityDetails = false;
      });

      return;
    }

    final repository = context.read<CityVisitsRepository>();

    setState(() {
      _isLoadingCityDetails = true;
      _cityDetailsError = null;
    });

    try {
      final visits = await repository.getCityVisits();

      if (!mounted || generation != _cityDetailsGeneration) {
        return;
      }

      setState(() {
        _cityVisitsById = {
          for (final visit in visits)
            if (_selectedCityVisitIds.contains(visit.id)) visit.id: visit,
        };

        _isLoadingCityDetails = false;
      });
    } catch (_) {
      if (!mounted || generation != _cityDetailsGeneration) {
        return;
      }

      setState(() {
        _isLoadingCityDetails = false;
        _cityDetailsError = 'Unable to load city details.';
      });
    }
  }

  Widget _buildDestinationsSection({required bool isSubmitting}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Destinations',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: AppSpacing.xs),

        Text(
          'Connect existing visits to this Trip. '
          'You can also add them later.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        if (!_isEditing) ...[
          _buildSuggestedVisits(isSubmitting: isSubmitting),
          const SizedBox(height: AppSpacing.lg),
        ],

        _buildDestinationSelector(
          title: 'Countries',
          icon: Icons.public_outlined,
          selectedCount: _selectedCountryVisitIds.length,
          enabled: !isSubmitting,
          onAdd: _selectCountryVisits,
          key: const Key('tripFormAddCountriesButton'),
        ),

        _buildSelectedCountryVisits(isSubmitting: isSubmitting),

        const SizedBox(height: AppSpacing.lg),

        _buildDestinationSelector(
          title: 'Cities',
          icon: Icons.location_city_outlined,
          selectedCount: _selectedCityVisitIds.length,
          enabled: !isSubmitting,
          onAdd: _selectCityVisits,
          key: const Key('tripFormAddCitiesButton'),
        ),

        _buildSelectedCityVisits(isSubmitting: isSubmitting),
      ],
    );
  }

  Widget _buildDestinationSelector({
    required String title,
    required IconData icon,
    required int selectedCount,
    required bool enabled,
    required VoidCallback onAdd,
    required Key key,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: colors.primary, size: 20),

            const SizedBox(width: AppSpacing.sm),

            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            TextButton.icon(
              key: key,
              onPressed: enabled ? onAdd : null,
              icon: const Icon(Icons.add),
              label: Text(selectedCount == 0 ? 'Add' : 'Edit'),
            ),
          ],
        ),

        if (selectedCount == 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'No visits selected',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '$selectedCount '
              '${selectedCount == 1 ? 'visit' : 'visits'} selected',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  void _clearDate({required bool isStart}) {
    setState(() {
      if (isStart) {
        _startedOn = null;
      } else {
        _endedOn = null;
      }
    });
  }

  String _formatDate(PartialVisitDate? value) {
    if (value == null) {
      return 'Not specified';
    }

    final date = value.date;
    final localization = MaterialLocalizations.of(context);

    return switch (value.precision) {
      VisitDatePrecision.day => localization.formatMediumDate(date),

      VisitDatePrecision.month => localization.formatMonthYear(date),

      VisitDatePrecision.year => '${date.year}',
    };
  }

  String? _validateName(String? value) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return 'Enter a Trip name.';
    }

    if (normalized.length > 160) {
      return 'Trip name cannot exceed 160 characters.';
    }

    return null;
  }

  String _formatVisitDate(DateTime date, VisitDatePrecision? precision) {
    final localization = MaterialLocalizations.of(context);

    return switch (precision ?? VisitDatePrecision.day) {
      VisitDatePrecision.day => localization.formatMediumDate(date),
      VisitDatePrecision.month => localization.formatMonthYear(date),
      VisitDatePrecision.year => '${date.year}',
    };
  }

  bool get _hasValidSuggestionDates {
    if (_isEditing || _startedOn == null || _endedOn == null) {
      return false;
    }

    final startBounds = tripDateBounds(_startedOn!);
    final endBounds = tripDateBounds(_endedOn!);

    return !startBounds.earliest.isAfter(endBounds.latest);
  }

  Future<
    ({
      List<Country> countries,
      List<CountryVisit> countryVisits,
      List<CityVisit> cityVisits,
    })
  >
  _loadSuggestedVisits() async {
    final countriesRepository = context.read<CountriesRepository>();
    final cityVisitsRepository = context.read<CityVisitsRepository>();

    final results = await Future.wait<Object>([
      countriesRepository.getCountries(),
      countriesRepository.getCountryVisits(),
      cityVisitsRepository.getCityVisits(),
    ]);

    return (
      countries: results[0] as List<Country>,
      countryVisits: results[1] as List<CountryVisit>,
      cityVisits: results[2] as List<CityVisit>,
    );
  }

  void _ensureSuggestedVisitsLoaded() {
    if (!_hasValidSuggestionDates || _suggestedVisitsFuture != null) {
      return;
    }

    setState(() {
      _suggestedVisitsFuture = _loadSuggestedVisits();
    });
  }

  String _formatVisitDateRange({
    required DateTime? startedOn,
    required VisitDatePrecision? startedOnPrecision,
    required DateTime? endedOn,
    required VisitDatePrecision? endedOnPrecision,
  }) {
    if (startedOn == null && endedOn == null) {
      return 'Dates unknown';
    }

    if (startedOn != null && endedOn == null) {
      return 'From ${_formatVisitDate(startedOn, startedOnPrecision)}';
    }

    if (startedOn == null && endedOn != null) {
      return 'Until ${_formatVisitDate(endedOn, endedOnPrecision)}';
    }

    return '${_formatVisitDate(startedOn!, startedOnPrecision)} – '
        '${_formatVisitDate(endedOn!, endedOnPrecision)}';
  }

  Widget _buildSelectedVisitCard({
    required String keyPrefix,
    required String visitId,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSubmitting,
    required VoidCallback onRemove,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      key: Key('$keyPrefix-$visitId'),
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
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

          IconButton(
            key: Key('remove-$keyPrefix-$visitId'),
            tooltip: 'Remove $title',
            onPressed: isSubmitting ? null : onRemove,
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCountryVisits({required bool isSubmitting}) {
    if (_selectedCountryVisitIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isLoadingCountryDetails) const LinearProgressIndicator(),

        if (_countryDetailsError != null)
          TextButton.icon(
            key: const Key('retryTripCountryDetailsButton'),
            onPressed: _loadSelectedCountryDetails,
            icon: const Icon(Icons.refresh),
            label: Text(_countryDetailsError!),
          ),

        for (final visitId in _selectedCountryVisitIds)
          _buildSelectedCountryVisit(
            visitId: visitId,
            isSubmitting: isSubmitting,
          ),
      ],
    );
  }

  Widget _buildSelectedCountryVisit({
    required String visitId,
    required bool isSubmitting,
  }) {
    final visit = _countryVisitsById[visitId];

    final countryName = visit == null
        ? 'Country visit'
        : _countryNamesByCode[visit.countryCode] ?? visit.countryCode;

    final dateLabel = visit == null
        ? 'Visit details unavailable'
        : _formatVisitDateRange(
            startedOn: visit.startedOn,
            startedOnPrecision: visit.startedOnPrecision,
            endedOn: visit.endedOn,
            endedOnPrecision: visit.endedOnPrecision,
          );

    return _buildSelectedVisitCard(
      keyPrefix: 'selectedCountryVisit',
      visitId: visitId,
      title: countryName,
      subtitle: dateLabel,
      icon: Icons.public_outlined,
      isSubmitting: isSubmitting,
      onRemove: () {
        setState(() {
          _selectedCountryVisitIds.remove(visitId);
          _countryVisitsById.remove(visitId);
        });
      },
    );
  }

  Widget _buildSelectedCityVisits({required bool isSubmitting}) {
    if (_selectedCityVisitIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isLoadingCityDetails) const LinearProgressIndicator(),

        if (_cityDetailsError != null)
          TextButton.icon(
            key: const Key('retryTripCityDetailsButton'),
            onPressed: _loadSelectedCityDetails,
            icon: const Icon(Icons.refresh),
            label: Text(_cityDetailsError!),
          ),

        for (final visitId in _selectedCityVisitIds)
          _buildSelectedCityVisit(visitId: visitId, isSubmitting: isSubmitting),
      ],
    );
  }

  Widget _buildSelectedCityVisit({
    required String visitId,
    required bool isSubmitting,
  }) {
    final visit = _cityVisitsById[visitId];

    final title = visit?.cityName ?? 'City visit';

    final subtitle = visit == null
        ? 'Visit details unavailable'
        : '${visit.countryName} · '
              '${_formatVisitDateRange(startedOn: visit.startedOn, startedOnPrecision: visit.startedOnPrecision, endedOn: visit.endedOn, endedOnPrecision: visit.endedOnPrecision)}';

    return _buildSelectedVisitCard(
      keyPrefix: 'selectedCityVisit',
      visitId: visitId,
      title: title,
      subtitle: subtitle,
      icon: Icons.location_on_outlined,
      isSubmitting: isSubmitting,
      onRemove: () {
        setState(() {
          _selectedCityVisitIds.remove(visitId);
          _cityVisitsById.remove(visitId);
        });
      },
    );
  }

  Widget _buildSuggestedVisits({required bool isSubmitting}) {
    final future = _suggestedVisitsFuture;

    if (!_hasValidSuggestionDates || future == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<
      ({
        List<Country> countries,
        List<CountryVisit> countryVisits,
        List<CityVisit> cityVisits,
      })
    >(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;

        final countrySuggestions = findCompatibleCountryVisits(
          visits: data.countryVisits,
          tripStart: _startedOn,
          tripEnd: _endedOn,
          excludedVisitIds: _selectedCountryVisitIds,
        );

        final citySuggestions = findCompatibleCityVisits(
          visits: data.cityVisits,
          tripStart: _startedOn,
          tripEnd: _endedOn,
          excludedVisitIds: _selectedCityVisitIds,
        );

        if (countrySuggestions.isEmpty && citySuggestions.isEmpty) {
          return const SizedBox.shrink();
        }

        final countryNames = {
          for (final country in data.countries) country.code: country.name,
        };

        return InlineTripVisitSuggestions(
          countrySuggestions: countrySuggestions,
          citySuggestions: citySuggestions,
          countryNamesByCode: countryNames,
          enabled: !isSubmitting,
          onCountrySelected: (visit) {
            _addSuggestedCountryVisit(visit, countryNames);
          },
          onCitySelected: _addSuggestedCityVisit,
        );
      },
    );
  }

  void _submit() {
    final cubit = context.read<SaveTripCubit>();

    if (cubit.state.isSubmitting || cubit.state.trip != null) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final input = TripInput(
      name: _nameController.text,
      description: _descriptionController.text,
      startedOn: _startedOn,
      endedOn: _endedOn,
    );

    if (_isEditing) {
      cubit.update(tripId: widget.trip!.id, input: input);
      return;
    }

    cubit.createWithVisits(
      input: input,
      countryVisitIds: _selectedCountryVisitIds.toList(growable: false),
      cityVisitIds: _selectedCityVisitIds.toList(growable: false),
    );
  }

  Widget _buildPartialFailureSection(SaveTripState state) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final pendingCount =
        state.pendingCountryVisitIds.length + state.pendingCityVisitIds.length;

    return Container(
      key: const Key('tripPartialFailureSection'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: colors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Trip created successfully',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            'Your Trip has been saved, but some visits '
            'could not be associated.',
            style: theme.textTheme.bodyMedium,
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            '$pendingCount '
            '${pendingCount == 1 ? 'association' : 'associations'} remaining',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          if (state.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),

            Text(
              state.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          FilledButton.icon(
            key: const Key('retryTripAssociationsButton'),
            onPressed: state.isSubmitting
                ? null
                : () {
                    context.read<SaveTripCubit>().retryPendingAssociations();
                  },
            icon: state.isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(
              state.isSubmitting ? 'Retrying...' : 'Retry associations',
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          OutlinedButton(
            key: const Key('finishPartiallyCreatedTripButton'),
            onPressed: state.isSubmitting
                ? null
                : () => Navigator.of(context).pop(true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required bool isStart,
    required bool isSubmitting,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final value = isStart ? _startedOn : _endedOn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            key: Key(isStart ? 'tripStartDateField' : 'tripEndDateField'),
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: isSubmitting ? null : () => _selectDate(isStart: isStart),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 20,
                    color: colors.primary,
                  ),

                  const SizedBox(width: AppSpacing.md),

                  Expanded(
                    child: Text(
                      _formatDate(value),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: value == null
                            ? colors.onSurfaceVariant
                            : colors.onSurface,
                      ),
                    ),
                  ),

                  if (value != null)
                    IconButton(
                      key: Key(
                        isStart ? 'clearTripStartDate' : 'clearTripEndDate',
                      ),
                      tooltip: 'Remove $label',
                      onPressed: isSubmitting
                          ? null
                          : () => _clearDate(isStart: isStart),
                      icon: const Icon(Icons.close, size: 18),
                    )
                  else
                    Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _tripInputDecoration({required String hint}) {
    final colors = Theme.of(context).colorScheme;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );

    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: colors.surfaceContainerHigh,
      border: border,
      enabledBorder: border,
      focusedBorder: border,
      disabledBorder: border,
      errorBorder: border.copyWith(borderSide: BorderSide(color: colors.error)),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: colors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      counterText: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final state = context.read<SaveTripCubit>().state;

        if (state.isSubmitting) return;

        Navigator.of(context).pop(state.trip != null);
      },
      child: BlocConsumer<SaveTripCubit, SaveTripState>(
        listenWhen: (previous, current) =>
            previous.phase != current.phase &&
            current.phase == SaveTripPhase.success,
        listener: (context, state) {
          Navigator.of(context).pop(true);
        },
        builder: (context, state) {
          final isSubmitting = state.isSubmitting;
          final hasPersistedTrip = state.trip != null;

          final canEditForm = !isSubmitting && !hasPersistedTrip;

          if (state.trip != null && !_isEditing) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: _buildPartialFailureSection(state),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isEditing ? 'Edit Trip' : 'New Trip',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      IconButton(
                        tooltip: 'Close',
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(hasPersistedTrip),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  Text(
                    _isEditing
                        ? 'Update your journey details.'
                        : 'Give your journey a name and organize your travel history.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  TextFormField(
                    key: const Key('tripNameField'),
                    controller: _nameController,
                    enabled: canEditForm,
                    maxLength: 160,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: _validateName,
                    style: theme.textTheme.bodyLarge,
                    decoration: _tripInputDecoration(hint: 'Trip name'),
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    key: const Key('tripDescriptionField'),
                    controller: _descriptionController,
                    enabled: canEditForm,
                    maxLength: 5000,
                    minLines: 2,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    style: theme.textTheme.bodyLarge,
                    decoration: _tripInputDecoration(
                      hint: 'Description (optional)',
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  Text(
                    'When did this trip happen?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  Text(
                    'Dates are optional. You can record an exact day, a month or just a year.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  _buildDateField(
                    label: 'Start date',
                    isStart: true,
                    isSubmitting: !canEditForm,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  _buildDateField(
                    label: 'End date',
                    isStart: false,
                    isSubmitting: !canEditForm,
                  ),

                  if (!_isEditing) ...[
                    const SizedBox(height: AppSpacing.xxxl),

                    _buildDestinationsSection(isSubmitting: !canEditForm),
                  ],

                  if (state.phase == SaveTripPhase.failure) ...[
                    const SizedBox(height: AppSpacing.lg),

                    Container(
                      key: const Key('tripSaveError'),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        state.errorMessage ?? 'Unable to save your Trip.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onErrorContainer,
                        ),
                      ),
                    ),
                  ],

                  if (state.isPartialFailure) ...[
                    const SizedBox(height: AppSpacing.lg),

                    _buildPartialFailureSection(state),
                  ],

                  const SizedBox(height: AppSpacing.xl),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(hasPersistedTrip),
                        child: Text(hasPersistedTrip ? 'Finish' : 'Cancel'),
                      ),

                      const SizedBox(width: AppSpacing.sm),

                      Flexible(
                        child: FilledButton.icon(
                          key: const Key('saveTripButton'),
                          onPressed: canEditForm ? _submit : null,
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(
                            isSubmitting
                                ? 'Saving...'
                                : hasPersistedTrip
                                ? 'Trip created'
                                : _isEditing
                                ? 'Save Changes'
                                : 'Create Trip',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
