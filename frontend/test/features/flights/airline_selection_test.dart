import 'package:beenaround/features/flights/domain/airline.dart';
import 'package:beenaround/features/flights/domain/airline_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tap = Airline(id: 10, name: 'TAP Air Portugal', iataCode: 'TP');

  test('catalog selection exposes only the airline ID', () {
    final selection = AirlineSelection.catalog(tap);

    expect(selection.isCatalog, isTrue);
    expect(selection.isManual, isFalse);
    expect(selection.airlineId, 10);
    expect(selection.airlineName, isNull);
    expect(selection.displayName, 'TAP Air Portugal');

    expect(selection.toFlightFields(), {
      'airline_id': 10,
      'airline_name': null,
    });
  });

  test('manual selection exposes only the airline name', () {
    final selection = AirlineSelection.manual('  Air Berlin  ');

    expect(selection.isCatalog, isFalse);
    expect(selection.isManual, isTrue);
    expect(selection.airlineId, isNull);
    expect(selection.airlineName, 'Air Berlin');

    expect(selection.toFlightFields(), {
      'airline_id': null,
      'airline_name': 'Air Berlin',
    });
  });

  test('manual selection rejects an empty name', () {
    expect(() => AirlineSelection.manual('   '), throwsArgumentError);
  });
}
