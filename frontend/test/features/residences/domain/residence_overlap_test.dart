import 'package:beenaround/features/residences/domain/residence_overlap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> location({
    String countryCode = 'PT',
    int? cityId,
    String startedOn = '2020-01-01',
    String endedOn = '2023-12-01',
  }) => {
    'country_code': countryCode,
    'city_id': cityId,
    'started_on': startedOn,
    'started_on_precision': 'month',
    'ended_on': endedOn,
    'ended_on_precision': 'month',
  };

  Map<String, dynamic> overlapResponse({bool includeTarget = false}) => {
    'code': 'RESIDENCE_PERIOD_OVERLAP',
    'message': 'Residence period overlaps existing records.',
    'requested': location(),
    'overlaps': [
      {
        ...location(
          countryCode: 'ES',
          startedOn: '2022-01-01',
          endedOn: '2022-12-01',
        ),
        'residence_id': 'residence-2',
        'kind': 'certain',
      },
    ],
    'expected_target': includeTarget
        ? {...location(), 'residence_id': 'residence-1'}
        : null,
  };

  group('ResidenceOverlapProposal', () {
    test('parses a create overlap proposal', () {
      final proposal = ResidenceOverlapProposal.fromJson(overlapResponse());

      expect(proposal.isCreate, isTrue);
      expect(proposal.isUpdate, isFalse);

      expect(proposal.requested.countryCode, 'PT');
      expect(proposal.requested.startedOn, '2020-01-01');

      expect(proposal.overlaps, hasLength(1));

      expect(proposal.overlaps.single.residenceId, 'residence-2');
      expect(proposal.overlaps.single.kind, 'certain');

      expect(proposal.expectedTarget, isNull);
    });

    test('parses an update overlap proposal', () {
      final proposal = ResidenceOverlapProposal.fromJson(
        overlapResponse(includeTarget: true),
      );

      expect(proposal.isCreate, isFalse);
      expect(proposal.isUpdate, isTrue);

      expect(proposal.expectedTarget, isNotNull);
      expect(proposal.expectedTarget!.residenceId, 'residence-1');
    });

    test('serializes an exact confirmation snapshot', () {
      final response = overlapResponse(includeTarget: true);

      final proposal = ResidenceOverlapProposal.fromJson(response);

      expect(proposal.toConfirmationJson(), {
        'requested': response['requested'],
        'overlaps': response['overlaps'],
        'expected_target': response['expected_target'],
      });
    });

    test('preserves all overlapping residences', () {
      final response = overlapResponse();

      final overlaps = response['overlaps'] as List;

      overlaps.add({
        ...location(
          countryCode: 'FR',
          startedOn: '2021-01-01',
          endedOn: '2021-12-01',
        ),
        'residence_id': 'residence-3',
        'kind': 'possible',
      });

      final proposal = ResidenceOverlapProposal.fromJson(response);

      expect(proposal.overlaps, hasLength(2));

      expect(
        proposal.overlaps.map((entry) => entry.residenceId),
        containsAll(['residence-2', 'residence-3']),
      );

      expect(proposal.toConfirmationJson()['overlaps'], hasLength(2));
    });

    test('rejects a response with no overlaps', () {
      final response = overlapResponse();
      response['overlaps'] = [];

      expect(
        () => ResidenceOverlapProposal.fromJson(response),
        throwsFormatException,
      );
    });

    test('rejects an invalid error code', () {
      final response = overlapResponse();

      response['code'] = 'UNKNOWN_ERROR';

      expect(
        () => ResidenceOverlapProposal.fromJson(response),
        throwsFormatException,
      );
    });

    test('rejects a missing requested state', () {
      final response = overlapResponse();

      response.remove('requested');

      expect(
        () => ResidenceOverlapProposal.fromJson(response),
        throwsFormatException,
      );
    });

    test('rejects a missing expected_target', () {
      final response = overlapResponse();

      response.remove('expected_target');

      expect(
        () => ResidenceOverlapProposal.fromJson(response),
        throwsFormatException,
      );
    });

    test('returns an immutable overlap list', () {
      final proposal = ResidenceOverlapProposal.fromJson(overlapResponse());

      expect(() => proposal.overlaps.clear(), throwsUnsupportedError);
    });
  });

  group('Residence overlap exceptions', () {
    test('required exception contains the proposal', () {
      final proposal = ResidenceOverlapProposal.fromJson(overlapResponse());

      final error = ResidenceOverlapRequired(proposal);

      expect(error.proposal, same(proposal));
    });

    test('stale exception preserves the backend message', () {
      const error = ResidenceOverlapStale(
        'The overlapping residences have changed.',
      );

      expect(error.message, 'The overlapping residences have changed.');
    });
  });
}
