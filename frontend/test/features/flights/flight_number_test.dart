import 'package:beenaround/features/flights/domain/flight_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes TAP IATA prefix', () {
    expect(FlightNumber.airlineCodeCandidates('TP1019'), ['TP']);
  });

  test('recognizes Iberia IATA prefix', () {
    expect(FlightNumber.airlineCodeCandidates('IB1144'), ['IB']);
  });

  test('recognizes alphanumeric IATA codes', () {
    expect(FlightNumber.airlineCodeCandidates('U27652'), ['U2']);
  });

  test('recognizes easyJet ICAO prefix', () {
    expect(FlightNumber.airlineCodeCandidates('EZY7652'), ['EZY']);
  });

  test('normalizes lowercase input', () {
    expect(FlightNumber.airlineCodeCandidates('tp 1019'), ['TP']);
  });

  test('does not identify an incomplete code', () {
    expect(FlightNumber.airlineCodeCandidates('TP'), isEmpty);
  });

  test('does not identify arbitrary text', () {
    expect(FlightNumber.airlineCodeCandidates('Lisbon'), isEmpty);
  });

  test('does not identify an empty value', () {
    expect(FlightNumber.airlineCodeCandidates(''), isEmpty);
  });
}
