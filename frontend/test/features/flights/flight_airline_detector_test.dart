import 'package:beenaround/features/flights/application/flight_airline_detector.dart';
import 'package:beenaround/features/flights/domain/airline.dart';
import 'package:beenaround/features/flights/domain/airline_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAirlineRepository implements AirlineRepository {
  final Map<String, List<Airline>> results = {};
  final List<String> queries = [];

  @override
  Future<AirlinePage> search({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    final normalized = query ?? '';
    queries.add(normalized);

    final airlines = results[normalized] ?? const <Airline>[];

    return AirlinePage(
      items: airlines,
      total: airlines.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Airline> getAirline({required int airlineId}) {
    throw UnimplementedError();
  }
}

void main() {
  late FakeAirlineRepository repository;
  late FlightAirlineDetector detector;

  setUp(() {
    repository = FakeAirlineRepository();

    detector = FlightAirlineDetector(repository: repository);
  });

  test('detects TAP through IATA code', () async {
    repository.results['TP'] = const [
      Airline(id: 1, name: 'TAP Air Portugal', iataCode: 'TP', icaoCode: 'TAP'),
    ];

    final airline = await detector.detect('TP1019');

    expect(airline?.name, 'TAP Air Portugal');
    expect(repository.queries, ['TP']);
  });

  test('detects Iberia through IATA code', () async {
    repository.results['IB'] = const [
      Airline(id: 2, name: 'Iberia', iataCode: 'IB', icaoCode: 'IBE'),
    ];

    final airline = await detector.detect('IB1144');

    expect(airline?.name, 'Iberia');
  });

  test('detects alphanumeric IATA codes', () async {
    repository.results['U2'] = const [
      Airline(id: 3, name: 'easyJet', iataCode: 'U2', icaoCode: 'EZY'),
    ];

    final airline = await detector.detect('U27652');

    expect(airline?.name, 'easyJet');
  });

  test('detects ICAO airline codes', () async {
    repository.results['EZY'] = const [
      Airline(id: 3, name: 'easyJet', iataCode: 'U2', icaoCode: 'EZY'),
    ];

    final airline = await detector.detect('EZY7652');

    expect(airline?.name, 'easyJet');
  });

  test('ignores partial matches', () async {
    repository.results['TP'] = const [
      Airline(
        id: 4,
        name: 'Example TP Aviation',
        iataCode: 'XX',
        icaoCode: 'XXX',
      ),
    ];

    final airline = await detector.detect('TP1019');

    expect(airline, isNull);
  });

  test('does not choose between ambiguous airlines', () async {
    repository.results['TP'] = const [
      Airline(id: 1, name: 'TAP Air Portugal', iataCode: 'TP'),
      Airline(id: 5, name: 'Historical Airline', iataCode: 'TP'),
    ];

    final airline = await detector.detect('TP1019');

    expect(airline, isNull);
  });

  test('does not query the catalog for incomplete numbers', () async {
    final airline = await detector.detect('TP');

    expect(airline, isNull);
    expect(repository.queries, isEmpty);
  });

  test('does not query the catalog for empty numbers', () async {
    final airline = await detector.detect('');

    expect(airline, isNull);
    expect(repository.queries, isEmpty);
  });

  test('does not choose an airline from partial pagination', () async {
    final partialRepository = _PartialAirlineRepository();

    final partialDetector = FlightAirlineDetector(
      repository: partialRepository,
    );

    final airline = await partialDetector.detect('TP1019');

    expect(airline, isNull);
  });
}

class _PartialAirlineRepository implements AirlineRepository {
  @override
  Future<AirlinePage> search({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    return AirlinePage(
      items: const [Airline(id: 1, name: 'TAP Air Portugal', iataCode: 'TP')],
      total: 150,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Airline> getAirline({required int airlineId}) {
    throw UnimplementedError();
  }
}
