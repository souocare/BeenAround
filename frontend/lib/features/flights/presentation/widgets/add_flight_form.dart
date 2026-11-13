import 'package:beenaround/features/explore/presentation/widgets/adaptive_visit_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/widgets/country_flag.dart';
import '../../application/save_flight_cubit.dart';
import '../../application/save_flight_state.dart';

import '../../domain/airport.dart';
import '../../domain/airline_selection.dart';
import '../../domain/flight.dart';
import '../../domain/flight_input.dart';

import 'airport_picker.dart';
import 'airline_picker.dart';

import 'dart:async';

import '../../application/flight_airline_detector.dart';
import '../../domain/airline_repository.dart';
import '../../domain/flight_number.dart';
import 'airline_avatar.dart';
import 'adaptive_flight_time_picker.dart';
import 'flight_input_decoration.dart';

/// Form for creating an independent personal flight record.
///
/// Flight creation does not modify visits, countries, cities,
/// Wishlist entries or Trip associations.
class AddFlightForm extends StatefulWidget {
  const AddFlightForm({super.key});

  @override
  State<AddFlightForm> createState() => _AddFlightFormState();
}

class _AddFlightFormState extends State<AddFlightForm> {
  final _formKey = GlobalKey<FormState>();

  final _flightNumberController = TextEditingController();
  final _aircraftTypeController = TextEditingController();
  final _aircraftRegistrationController = TextEditingController();
  final _seatController = TextEditingController();
  final _notesController = TextEditingController();

  Airport? _departureAirport;
  Airport? _arrivalAirport;

  AirlineSelection? _airlineSelection;

  late DateTime _departureDate;
  DateTime? _arrivalDate;

  TimeOfDay? _departureTime;
  TimeOfDay? _arrivalTime;

  FlightStatus _status = FlightStatus.flown;
  FlightCabinClass? _cabinClass;

  bool _showValidationErrors = false;
  bool _showAdditionalDetails = false;
  Timer? _airlineDetectionDebounce;

  int _airlineDetectionGeneration = 0;

  String _lastAirlineCodeSignature = '';

  bool _isDetectingAirline = false;

  @override
  void initState() {
    super.initState();

    _departureDate = DateUtils.dateOnly(DateTime.now());
  }

  @override
  void dispose() {
    _airlineDetectionDebounce?.cancel();
    _airlineDetectionGeneration++;
    _flightNumberController.dispose();
    _aircraftTypeController.dispose();
    _aircraftRegistrationController.dispose();
    _seatController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  bool get _isSaving {
    return context.read<SaveFlightCubit>().state.isSaving;
  }

  String _formatApiDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _formatApiTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _formatDisplayDate(DateTime date) {
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  String _formatDisplayTime(TimeOfDay time) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(time, alwaysUse24HourFormat: true);
  }

  String? _optionalText(TextEditingController controller) {
    final value = controller.text.trim();

    return value.isEmpty ? null : value;
  }

  Future<void> _selectDepartureAirport() async {
    if (_isSaving) return;

    final airport = await showAirportPicker(
      context,
      title: 'Departure Airport',
    );

    if (!mounted || airport == null) return;

    setState(() {
      _departureAirport = airport;
    });
  }

  Future<void> _selectArrivalAirport() async {
    if (_isSaving) return;

    final airport = await showAirportPicker(context, title: 'Arrival Airport');

    if (!mounted || airport == null) return;

    setState(() {
      _arrivalAirport = airport;
    });
  }

  void _swapAirports() {
    if (_isSaving) return;

    setState(() {
      final previousDeparture = _departureAirport;

      _departureAirport = _arrivalAirport;
      _arrivalAirport = previousDeparture;
    });
  }

  Future<void> _selectAirline() async {
    if (_isSaving) return;

    // A pending automatic result must not overwrite
    // a deliberate user selection.
    _invalidateAirlineDetection();

    final selection = await showAirlinePicker(context);

    if (!mounted || selection == null) return;

    setState(() {
      _airlineSelection = selection;
    });
  }

  Future<void> _selectDepartureDate() async {
    if (_isSaving) return;

    final selected = await showAdaptiveVisitDatePicker(
      context: context,
      initialDate: _departureDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _departureDate = DateUtils.dateOnly(selected);
    });
  }

  Future<void> _selectArrivalDate() async {
    if (_isSaving) return;

    final selected = await showAdaptiveVisitDatePicker(
      context: context,
      initialDate: _arrivalDate ?? _departureDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _arrivalDate = DateUtils.dateOnly(selected);
    });
  }

  Future<void> _selectDepartureTime() async {
    if (_isSaving) return;

    final selected = await showAdaptiveFlightTimePicker(
      context: context,
      initialTime: _departureTime ?? const TimeOfDay(hour: 12, minute: 0),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _departureTime = selected;
    });
  }

  Future<void> _selectArrivalTime() async {
    if (_isSaving) return;

    final selected = await showAdaptiveFlightTimePicker(
      context: context,
      initialTime: _arrivalTime ?? const TimeOfDay(hour: 12, minute: 0),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _arrivalTime = selected;
    });
  }

  bool _validateRoute() {
    final departure = _departureAirport;
    final arrival = _arrivalAirport;

    if (departure == null || arrival == null) {
      return false;
    }

    return departure.id != arrival.id;
  }

  void _invalidateAirlineDetection() {
    _airlineDetectionDebounce?.cancel();
    _airlineDetectionGeneration++;

    if (mounted) {
      setState(() {
        _isDetectingAirline = false;
      });
    }
  }

  void _onFlightNumberChanged(String value) {
    if (_isSaving) return;

    final candidates = FlightNumber.airlineCodeCandidates(value);

    final signature = candidates.join('|');

    // A change that does not affect the airline designator
    // must not cause another catalog request.
    if (signature == _lastAirlineCodeSignature) {
      return;
    }

    _lastAirlineCodeSignature = signature;

    _invalidateAirlineDetection();

    // Clearing the flight number must preserve the airline.
    if (candidates.isEmpty) {
      return;
    }

    final generation = _airlineDetectionGeneration;

    _airlineDetectionDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _detectAirline(flightNumber: value, generation: generation),
    );
  }

  Future<void> _detectAirline({
    required String flightNumber,
    required int generation,
  }) async {
    if (!mounted || generation != _airlineDetectionGeneration) {
      return;
    }

    setState(() {
      _isDetectingAirline = true;
    });

    try {
      final detector = FlightAirlineDetector(
        repository: context.read<AirlineRepository>(),
      );

      final airline = await detector.detect(flightNumber);

      if (!mounted || generation != _airlineDetectionGeneration) {
        return;
      }

      setState(() {
        _isDetectingAirline = false;

        // An unknown or ambiguous code must not erase the
        // currently selected airline.
        if (airline != null) {
          _airlineSelection = AirlineSelection.catalog(airline);
        }
      });
    } catch (_) {
      // Automatic detection is optional.
      //
      // A catalog failure must never prevent the user from
      // manually selecting an airline or saving the flight.
      if (!mounted || generation != _airlineDetectionGeneration) {
        return;
      }

      setState(() {
        _isDetectingAirline = false;
      });
    }
  }

  Future<void> _save() async {
    final cubit = context.read<SaveFlightCubit>();

    if (cubit.state.isSaving || cubit.state.isSuccess) {
      return;
    }

    setState(() {
      _showValidationErrors = true;
    });

    final formIsValid = _formKey.currentState?.validate() ?? false;

    if (!_validateRoute() || !formIsValid) {
      return;
    }

    // The backend requires an arrival date whenever an
    // arrival time is provided.
    if (_arrivalTime != null && _arrivalDate == null) {
      return;
    }

    final input = FlightCreateInput(
      departureAirportId: _departureAirport!.id,
      arrivalAirportId: _arrivalAirport!.id,
      departureOn: _formatApiDate(_departureDate),
      status: _status,
      airlineId: _airlineSelection?.airlineId,
      airlineName: _airlineSelection?.airlineName,
      flightNumber: _flightNumberController.text.trim().isEmpty
          ? null
          : FlightNumber.normalize(_flightNumberController.text),
      departureTime: _departureTime == null
          ? null
          : _formatApiTime(_departureTime!),
      arrivalOn: _arrivalDate == null ? null : _formatApiDate(_arrivalDate!),
      arrivalTime: _arrivalTime == null ? null : _formatApiTime(_arrivalTime!),
      cabinClass: _cabinClass,
      aircraftType: _optionalText(_aircraftTypeController),
      aircraftRegistration: _optionalText(_aircraftRegistrationController),
      seat: _optionalText(_seatController),
      notes: _optionalText(_notesController),
    );

    final success = await cubit.save(input);

    if (!mounted || !success) return;

    Navigator.of(context).pop(true);
  }

  Widget _buildInputLabel(String label) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<SaveFlightCubit, SaveFlightState>(
      builder: (context, state) {
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Flight',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Record a flight in your travel history.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: state.isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFlightInformationSection(context),

                      const SizedBox(height: 20),

                      _buildRouteSection(context),

                      const SizedBox(height: 20),

                      _buildDateSection(context),

                      const SizedBox(height: 20),

                      _buildStatusSection(context),

                      const SizedBox(height: 16),

                      _buildAdditionalDetailsSection(context),

                      if (_showValidationErrors &&
                          _arrivalTime != null &&
                          _arrivalDate == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Select an arrival date when an arrival '
                            'time is provided.',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),

                      if (state.hasError) ...[
                        const SizedBox(height: 16),
                        _buildSaveError(context, state),
                      ],
                    ],
                  ),
                ),
              ),

              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: FilledButton.icon(
                    key: const Key('saveFlightButton'),
                    onPressed: state.isSaving ? null : _save,
                    icon: state.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(state.isSaving ? 'Saving...' : 'Save Flight'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildRouteSection(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final routeIsInvalid = _showValidationErrors && !_validateRoute();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Route'),

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _AirportField(
                key: const Key('departureAirportField'),
                label: 'FROM',
                airport: _departureAirport,
                onTap: _selectDepartureAirport,
              ),
            ),

            const SizedBox(width: 4),

            IconButton(
              key: const Key('swapAirportsButton'),
              tooltip: 'Swap airports',
              onPressed: _isSaving ? null : _swapAirports,
              icon: const Icon(Icons.swap_horiz_rounded),
              visualDensity: VisualDensity.compact,
            ),

            const SizedBox(width: 4),

            Expanded(
              child: _AirportField(
                key: const Key('arrivalAirportField'),
                label: 'TO',
                airport: _arrivalAirport,
                onTap: _selectArrivalAirport,
              ),
            ),
          ],
        ),

        if (routeIsInvalid) ...[
          const SizedBox(height: 10),

          Text(
            _departureAirport == null || _arrivalAirport == null
                ? 'Select both departure and arrival airports.'
                : 'Departure and arrival airports must be different.',
            style: TextStyle(color: colors.error),
          ),
        ],
      ],
    );
  }

  Widget _buildDateSection(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget scheduleLabel(String label, String? location) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (location != null && location.isNotEmpty)
              Flexible(
                child: Text(
                  '$location local time',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    String? airportLocation(Airport? airport) {
      if (airport == null) return null;

      final municipality = airport.municipality?.trim();

      if (municipality != null && municipality.isNotEmpty) {
        return municipality;
      }

      return airport.displayCode;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Flight Schedule'),

        // ----------------------------------------------------
        // Departure
        // ----------------------------------------------------
        scheduleLabel('DEPARTURE', airportLocation(_departureAirport)),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _FlightScheduleField(
                key: const Key('departureDateField'),
                label: 'Date',
                icon: Icons.calendar_today_outlined,
                value: _formatDisplayDate(_departureDate),
                onTap: _isSaving ? null : _selectDepartureDate,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _FlightScheduleField(
                key: const Key('departureTimeField'),
                label: 'Time',
                icon: Icons.schedule_outlined,
                value: _departureTime == null
                    ? 'Add time'
                    : _formatDisplayTime(_departureTime!),
                isPlaceholder: _departureTime == null,
                onTap: _isSaving ? null : _selectDepartureTime,
                onClear: _departureTime == null || _isSaving
                    ? null
                    : () {
                        setState(() {
                          _departureTime = null;
                        });
                      },
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // ----------------------------------------------------
        // Arrival
        // ----------------------------------------------------
        scheduleLabel('ARRIVAL', airportLocation(_arrivalAirport)),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _FlightScheduleField(
                key: const Key('arrivalDateField'),
                label: 'Date',
                icon: Icons.calendar_today_outlined,
                value: _arrivalDate == null
                    ? 'Add date'
                    : _formatDisplayDate(_arrivalDate!),
                isPlaceholder: _arrivalDate == null,
                onTap: _isSaving ? null : _selectArrivalDate,
                onClear: _arrivalDate == null || _isSaving
                    ? null
                    : () {
                        setState(() {
                          _arrivalDate = null;
                          _arrivalTime = null;
                        });
                      },
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _FlightScheduleField(
                key: const Key('arrivalTimeField'),
                label: 'Time',
                icon: Icons.schedule_outlined,
                value: _arrivalTime == null
                    ? 'Add time'
                    : _formatDisplayTime(_arrivalTime!),
                isPlaceholder: _arrivalTime == null,
                onTap: _isSaving ? null : _selectArrivalTime,
                onClear: _arrivalTime == null || _isSaving
                    ? null
                    : () {
                        setState(() {
                          _arrivalTime = null;
                        });
                      },
              ),
            ),
          ],
        ),

        // if (_showValidationErrors &&
        //     _arrivalTime != null &&
        //     _arrivalDate == null) ...[
        //   const SizedBox(height: 10),

        //   Text(
        //     'Select an arrival date when an arrival time is provided.',
        //     style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
        //   ),
        // ],
      ],
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Status'),

        SegmentedButton<FlightStatus>(
          segments: const [
            ButtonSegment(
              value: FlightStatus.flown,
              label: Text('Completed'),
              icon: Icon(Icons.check_circle_outline),
            ),
            ButtonSegment(
              value: FlightStatus.planned,
              label: Text('Planned'),
              icon: Icon(Icons.schedule_outlined),
            ),
          ],
          selected: {_status},
          onSelectionChanged: _isSaving
              ? null
              : (selection) {
                  setState(() {
                    _status = selection.first;
                  });
                },
        ),
      ],
    );
  }

  Widget _buildFlightInformationSection(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Flight Information'),

        Text(
          'Flight number',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        TextFormField(
          key: const Key('flightNumberField'),
          controller: _flightNumberController,
          enabled: !_isSaving,
          onChanged: _onFlightNumberChanged,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          maxLength: 30,

          // Keep the character limit without displaying the counter.
          buildCounter:
              (
                context, {
                required currentLength,
                required isFocused,
                required maxLength,
              }) => null,

          decoration: flightInputDecoration(
            context,
            hintText: 'e.g. TP1019',
            prefixIcon: const Icon(Icons.flight_takeoff_rounded),
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Text(
                'Airline',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            if (_isDetectingAirline)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),

        const SizedBox(height: 8),

        _AirlineSelectionField(
          key: const Key('airlineField'),
          selection: _airlineSelection,
          onTap: _selectAirline,
          onClear: _airlineSelection == null || _isSaving
              ? null
              : () {
                  _invalidateAirlineDetection();

                  setState(() {
                    _airlineSelection = null;
                  });
                },
        ),
      ],
    );
  }

  Widget _buildAdditionalDetailsSection(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ------------------------------------------------------
        // Expand / collapse
        // ------------------------------------------------------
        OutlinedButton.icon(
          key: const Key('toggleFlightDetails'),
          onPressed: _isSaving
              ? null
              : () {
                  setState(() {
                    _showAdditionalDetails = !_showAdditionalDetails;
                  });
                },
          icon: Icon(
            _showAdditionalDetails
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded,
          ),
          label: Text(
            _showAdditionalDetails
                ? 'Hide Additional Details'
                : 'Additional Details',
          ),
        ),

        if (_showAdditionalDetails) ...[
          const SizedBox(height: 24),

          _buildSectionTitle('Aircraft & Seat'),

          // ----------------------------------------------------
          // Cabin class
          // ----------------------------------------------------
          _buildInputLabel('Cabin class'),

          DropdownButtonFormField<FlightCabinClass>(
            key: const Key('cabinClassField'),
            initialValue: _cabinClass,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            hint: Text(
              'Select cabin class',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            decoration: flightInputDecoration(context),
            dropdownColor: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            items: const [
              DropdownMenuItem<FlightCabinClass>(
                value: null,
                child: Text('Not specified'),
              ),
              DropdownMenuItem(
                value: FlightCabinClass.economy,
                child: Text('Economy'),
              ),
              DropdownMenuItem(
                value: FlightCabinClass.premiumEconomy,
                child: Text('Premium Economy'),
              ),
              DropdownMenuItem(
                value: FlightCabinClass.business,
                child: Text('Business'),
              ),
              DropdownMenuItem(
                value: FlightCabinClass.first,
                child: Text('First'),
              ),
            ],
            onChanged: _isSaving
                ? null
                : (value) {
                    setState(() {
                      _cabinClass = value;
                    });
                  },
          ),

          const SizedBox(height: 18),

          // ----------------------------------------------------
          // Aircraft type
          // ----------------------------------------------------
          _buildInputLabel('Aircraft type'),

          TextFormField(
            key: const Key('aircraftTypeField'),
            controller: _aircraftTypeController,
            enabled: !_isSaving,
            textInputAction: TextInputAction.next,
            decoration: flightInputDecoration(
              context,
              hintText: 'e.g. Airbus A320',
            ),
          ),

          const SizedBox(height: 18),

          // ----------------------------------------------------
          // Aircraft registration
          // ----------------------------------------------------
          _buildInputLabel('Aircraft registration'),

          TextFormField(
            key: const Key('aircraftRegistrationField'),
            controller: _aircraftRegistrationController,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            decoration: flightInputDecoration(context, hintText: 'e.g. CS-TNV'),
          ),

          const SizedBox(height: 18),

          // ----------------------------------------------------
          // Seat
          // ----------------------------------------------------
          _buildInputLabel('Seat'),

          TextFormField(
            key: const Key('seatField'),
            controller: _seatController,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            decoration: flightInputDecoration(context, hintText: 'e.g. 14A'),
          ),

          const SizedBox(height: 24),

          // ----------------------------------------------------
          // Notes
          // ----------------------------------------------------
          _buildSectionTitle('Notes'),

          TextFormField(
            key: const Key('flightNotesField'),
            controller: _notesController,
            enabled: !_isSaving,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            decoration:
                flightInputDecoration(
                  context,
                  hintText: 'Add memories or details about this flight...',
                ).copyWith(
                  contentPadding: const EdgeInsets.all(16),
                  alignLabelWithHint: true,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildSaveError(BuildContext context, SaveFlightState state) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.errorMessage ?? 'Unable to save your flight.',
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact airport selection field.
/// Compact airport card for horizontal flight routes.
///
/// Displays the airport code prominently and a shortened
/// location description beneath it.
class _AirportField extends StatelessWidget {
  const _AirportField({
    required this.label,
    required this.airport,
    required this.onTap,
    super.key,
  });

  final String label;
  final Airport? airport;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final selected = airport;

    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 156),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 12),

              if (selected == null) ...[
                Icon(
                  Icons.add_circle_outline_rounded,
                  color: colors.primary,
                  size: 28,
                ),

                const SizedBox(height: 6),

                Text(
                  'Select airport',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    CountryFlag(
                      countryCode: selected.countryCode ?? '',
                      size: 30,
                    ),

                    const SizedBox(width: 6),

                    Expanded(
                      child: Text(
                        selected.displayCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  selected.municipality?.trim().isNotEmpty == true
                      ? selected.municipality!
                      : selected.displayLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 4),

                // Reserve two lines for the airport name.
                SizedBox(
                  height: 34,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      selected.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        height: 1.35,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Selectable airline field used by the Add Flight form.
///
/// The selected airline remains editable, including when
/// it was detected automatically from the flight number.
class _AirlineSelectionField extends StatelessWidget {
  const _AirlineSelectionField({
    required this.selection,
    required this.onTap,
    this.onClear,
    super.key,
  });

  final AirlineSelection? selection;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final selected = selection;

    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              AirlineAvatar(airline: selected?.airline, size: 42),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected?.displayName ?? 'Select airline',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    if (selected == null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Optional',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (onClear != null) ...[
                IconButton(
                  tooltip: 'Clear Airline',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],

              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable selection field for dates, times and airline.
class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Clear $label',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                )
              else
                const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact selectable field used in the Flight Schedule.
///
/// The field has a fixed visual structure so departure and
/// arrival rows remain aligned even when values are missing.
class _FlightScheduleField extends StatelessWidget {
  const _FlightScheduleField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
    this.isPlaceholder = false,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 98),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: colors.primary),

                  const SizedBox(width: 6),

                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isPlaceholder
                            ? colors.onSurfaceVariant
                            : colors.onSurface,
                      ),
                    ),
                  ),

                  if (onClear != null)
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        tooltip: 'Clear $label',
                        onPressed: onClear,
                        padding: EdgeInsets.zero,
                        iconSize: 17,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
