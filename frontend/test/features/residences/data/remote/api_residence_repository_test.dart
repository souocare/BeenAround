import 'dart:convert';
import 'dart:typed_data';

import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/core/network/api_client.dart';
import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/residences/data/remote/api_residence_repository.dart';
import 'package:beenaround/features/residences/domain/residence_changes.dart';
import 'package:beenaround/features/residences/domain/residence_input.dart';
import 'package:beenaround/features/residences/domain/residence_overlap.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const residenceId = '550e8400-e29b-41d4-a716-446655440001';
const secondResidenceId = '550e8400-e29b-41d4-a716-446655440002';

const lisbonId = 2267057;

class FakeResidenceHttpAdapter implements HttpClientAdapter {
  FakeResidenceHttpAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

ResponseBody emptyResponse() {
  return ResponseBody.fromString('', 204);
}

Map<String, dynamic> residenceResponse({
  String id = residenceId,
  String countryCode = 'PT',
  int? cityId,
  String startedOn = '2020-03-01',
  String endedOn = '2023-08-01',
  String? note,
}) {
  return {
    'id': id,
    'country_code': countryCode,
    'city_id': cityId,
    'started_on': startedOn,
    'started_on_precision': 'month',
    'ended_on': endedOn,
    'ended_on_precision': 'month',
    'note': note,
    'created_at': '2026-11-03T10:00:00Z',
    'updated_at': '2026-11-03T10:00:00Z',
  };
}

Map<String, dynamic> overlapLocation({
  String countryCode = 'PT',
  int? cityId,
  String startedOn = '2020-03-01',
  String endedOn = '2023-08-01',
}) {
  return {
    'country_code': countryCode,
    'city_id': cityId,
    'started_on': startedOn,
    'started_on_precision': 'month',
    'ended_on': endedOn,
    'ended_on_precision': 'month',
  };
}

Map<String, dynamic> overlapDetail({bool includeTarget = false}) {
  return {
    'code': 'RESIDENCE_PERIOD_OVERLAP',
    'message': 'This period overlaps existing residences.',
    'requested': overlapLocation(),
    'overlaps': [
      {
        ...overlapLocation(
          countryCode: 'ES',
          startedOn: '2022-01-01',
          endedOn: '2022-12-01',
        ),
        'residence_id': secondResidenceId,
        'kind': 'certain',
      },
    ],
    'expected_target': includeTarget
        ? {...overlapLocation(), 'residence_id': residenceId}
        : null,
  };
}

ResidenceInput sampleInput() {
  return ResidenceInput(
    countryCode: 'PT',
    startedOn: DateTime(2020, 3),
    startedOnPrecision: VisitDatePrecision.month,
    endedOn: DateTime(2023, 8),
    endedOnPrecision: VisitDatePrecision.month,
    note: 'Studied here.',
  );
}

ApiResidenceRepository createRepository(
  ResponseBody Function(RequestOptions options) handler,
) {
  final config = ServerConfig.parse('https://travel.example.com')!;

  final dio = Dio()..httpClientAdapter = FakeResidenceHttpAdapter(handler);

  return ApiResidenceRepository(
    apiClient: ApiClient(serverConfig: config, dio: dio),
  );
}

void main() {
  group('ApiResidenceRepository - listing', () {
    test('loads historical residences', () async {
      final repository = createRepository((options) {
        expect(options.method, 'GET');
        expect(options.uri.path, '/api/v1/residences');

        return jsonResponse({
          'items': [
            residenceResponse(note: 'Studied here.'),
            residenceResponse(
              id: secondResidenceId,
              cityId: lisbonId,
              note: 'Returned for work.',
            ),
          ],
          'total': 2,
        });
      });

      final residences = await repository.getResidences();

      expect(residences, hasLength(2));

      expect(residences.first.id, residenceId);
      expect(residences.first.countryCode, 'PT');
      expect(residences.first.isCountryResidence, isTrue);
      expect(residences.first.note, 'Studied here.');

      expect(residences.last.cityId, lisbonId);
      expect(residences.last.isCityResidence, isTrue);
      expect(residences.last.note, 'Returned for work.');
    });

    test('supports an empty residence history', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': [], 'total': 0}),
      );

      expect(await repository.getResidences(), isEmpty);
    });

    test('rejects malformed lists', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': 'invalid'}),
      );

      await expectLater(repository.getResidences(), throwsFormatException);
    });

    test('returns immutable lists', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [residenceResponse()],
          'total': 1,
        }),
      );

      final residences = await repository.getResidences();

      expect(() => residences.clear(), throwsUnsupportedError);
    });

    test('maps unauthorized responses', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': 'Authentication required.',
        }, statusCode: 401),
      );

      await expectLater(
        repository.getResidences(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.unauthorized,
          ),
        ),
      );
    });

    test('retrieves a single residence', () async {
      final repository = createRepository((options) {
        expect(options.method, 'GET');
        expect(options.uri.path, '/api/v1/residences/$residenceId');

        return jsonResponse(residenceResponse(note: 'Historical residence.'));
      });

      final residence = await repository.getResidence(residenceId: residenceId);

      expect(residence.id, residenceId);
      expect(residence.note, 'Historical residence.');
    });

    test('maps missing residences to 404', () async {
      final repository = createRepository(
        (_) =>
            jsonResponse({'detail': 'Residence not found.'}, statusCode: 404),
      );

      await expectLater(
        repository.getResidence(residenceId: residenceId),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.notFound,
          ),
        ),
      );
    });
  });
  group('ApiResidenceRepository - creation', () {
    test('creates a residence with month precision and note', () async {
      final repository = createRepository((options) {
        expect(options.method, 'POST');
        expect(options.uri.path, '/api/v1/residences');

        expect(options.data, {
          'country_code': 'PT',
          'city_id': null,
          'started_on': '2020-03-01',
          'started_on_precision': 'month',
          'ended_on': '2023-08-01',
          'ended_on_precision': 'month',
          'note': 'Studied here.',
        });

        return jsonResponse(
          residenceResponse(note: 'Studied here.'),
          statusCode: 201,
        );
      });

      final residence = await repository.createResidence(input: sampleInput());

      expect(residence.id, residenceId);
      expect(residence.note, 'Studied here.');
    });

    test('recognizes a required overlap confirmation', () async {
      final repository = createRepository(
        (_) => jsonResponse({'detail': overlapDetail()}, statusCode: 409),
      );

      await expectLater(
        repository.createResidence(input: sampleInput()),
        throwsA(
          isA<ResidenceOverlapRequired>().having(
            (error) => error.proposal.overlaps.length,
            'overlap count',
            1,
          ),
        ),
      );
    });

    test('sends an explicitly approved overlap snapshot', () async {
      final detail = overlapDetail();

      final proposal = ResidenceOverlapProposal.fromJson(detail);

      final repository = createRepository((options) {
        expect(options.method, 'POST');

        expect(
          options.data['overlap_confirmation'],
          proposal.toConfirmationJson(),
        );

        return jsonResponse(residenceResponse(), statusCode: 201);
      });

      final residence = await repository.createResidence(
        input: sampleInput(),
        overlapConfirmation: proposal,
      );

      expect(residence.id, residenceId);
    });

    test('rejects update proposals during creation', () async {
      var requestCount = 0;

      final proposal = ResidenceOverlapProposal.fromJson(
        overlapDetail(includeTarget: true),
      );

      final repository = createRepository((_) {
        requestCount++;

        return jsonResponse(residenceResponse());
      });

      await expectLater(
        repository.createResidence(
          input: sampleInput(),
          overlapConfirmation: proposal,
        ),
        throwsArgumentError,
      );

      expect(requestCount, 0);
    });

    test('rejects malformed overlap responses safely', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': {
            'code': 'RESIDENCE_PERIOD_OVERLAP',
            'requested': {},
            'overlaps': 'invalid',
          },
        }, statusCode: 409),
      );

      await expectLater(
        repository.createResidence(input: sampleInput()),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            409,
          ),
        ),
      );
    });

    test('recognizes a stale overlap confirmation', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': {
            'code': 'RESIDENCE_OVERLAP_CONFIRMATION_STALE',
            'message': 'The overlapping residences have changed.',
          },
        }, statusCode: 409),
      );

      await expectLater(
        repository.createResidence(input: sampleInput()),
        throwsA(
          isA<ResidenceOverlapStale>().having(
            (error) => error.message,
            'message',
            'The overlapping residences have changed.',
          ),
        ),
      );
    });
  });
  group('ApiResidenceRepository - updates', () {
    test('updates only a residence note', () async {
      final repository = createRepository((options) {
        expect(options.method, 'PATCH');

        expect(options.uri.path, '/api/v1/residences/$residenceId');

        expect(options.data, {'note': 'My first apartment.'});

        return jsonResponse(residenceResponse(note: 'My first apartment.'));
      });

      final residence = await repository.updateResidence(
        residenceId: residenceId,
        changes: ResidenceChanges(
          note: 'My first apartment.',
          updateNote: true,
        ),
      );

      expect(residence.note, 'My first apartment.');
    });

    test('clears a note with explicit null', () async {
      final repository = createRepository((options) {
        expect(options.method, 'PATCH');

        expect(options.data, {'note': null});

        return jsonResponse(residenceResponse());
      });

      final residence = await repository.updateResidence(
        residenceId: residenceId,
        changes: ResidenceChanges(note: null, updateNote: true),
      );

      expect(residence.note, isNull);
    });

    test('updates a residence end date', () async {
      final repository = createRepository((options) {
        expect(options.method, 'PATCH');

        expect(options.data, {
          'ended_on': '2024-06-01',
          'ended_on_precision': 'month',
        });

        return jsonResponse(residenceResponse(endedOn: '2024-06-01'));
      });

      final residence = await repository.updateResidence(
        residenceId: residenceId,
        changes: ResidenceChanges(
          endedOn: DateTime(2024, 6, 23),
          endedOnPrecision: VisitDatePrecision.month,
        ),
      );

      expect(residence.endedOn, DateTime(2024, 6));
    });

    test('sends an update overlap confirmation', () async {
      final proposal = ResidenceOverlapProposal.fromJson(
        overlapDetail(includeTarget: true),
      );

      final repository = createRepository((options) {
        expect(options.method, 'PATCH');

        expect(
          options.data['overlap_confirmation'],
          proposal.toConfirmationJson(),
        );

        expect(options.data['ended_on'], '2024-06-01');

        return jsonResponse(residenceResponse(endedOn: '2024-06-01'));
      });

      final residence = await repository.updateResidence(
        residenceId: residenceId,
        changes: ResidenceChanges(
          endedOn: DateTime(2024, 6),
          endedOnPrecision: VisitDatePrecision.month,
        ),
        overlapConfirmation: proposal,
      );

      expect(residence.id, residenceId);
    });

    test('rejects confirmation on note-only changes', () async {
      var requestCount = 0;

      final proposal = ResidenceOverlapProposal.fromJson(
        overlapDetail(includeTarget: true),
      );

      final repository = createRepository((_) {
        requestCount++;

        return jsonResponse(residenceResponse());
      });

      await expectLater(
        repository.updateResidence(
          residenceId: residenceId,
          changes: ResidenceChanges(note: 'Updated note.', updateNote: true),
          overlapConfirmation: proposal,
        ),
        throwsArgumentError,
      );

      expect(requestCount, 0);
    });

    test('rejects a proposal for another residence', () async {
      var requestCount = 0;

      final detail = overlapDetail(includeTarget: true);

      final target = detail['expected_target'] as Map<String, dynamic>;
      target['residence_id'] = secondResidenceId;

      final proposal = ResidenceOverlapProposal.fromJson(detail);

      final repository = createRepository((_) {
        requestCount++;

        return jsonResponse(residenceResponse());
      });

      await expectLater(
        repository.updateResidence(
          residenceId: residenceId,
          changes: ResidenceChanges(
            endedOn: DateTime(2024, 6),
            endedOnPrecision: VisitDatePrecision.month,
          ),
          overlapConfirmation: proposal,
        ),
        throwsArgumentError,
      );

      expect(requestCount, 0);
    });

    test('recognizes stale confirmations during PATCH', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': {
            'code': 'RESIDENCE_OVERLAP_CONFIRMATION_STALE',
            'message': 'The edited residence has changed.',
          },
        }, statusCode: 409),
      );

      await expectLater(
        repository.updateResidence(
          residenceId: residenceId,
          changes: ResidenceChanges(
            endedOn: DateTime(2024, 6),
            endedOnPrecision: VisitDatePrecision.month,
          ),
        ),
        throwsA(isA<ResidenceOverlapStale>()),
      );
    });
  });
  group('ApiResidenceRepository - deletion', () {
    test('deletes a residence with HTTP 204', () async {
      final repository = createRepository((options) {
        expect(options.method, 'DELETE');

        expect(options.uri.path, '/api/v1/residences/$residenceId');

        return emptyResponse();
      });

      await repository.deleteResidence(residenceId: residenceId);
    });

    test('rejects an empty residence ID', () async {
      var requestCount = 0;

      final repository = createRepository((_) {
        requestCount++;

        return emptyResponse();
      });

      await expectLater(
        repository.deleteResidence(residenceId: '   '),
        throwsArgumentError,
      );

      expect(requestCount, 0);
    });

    test('maps HTTP 404 to not found', () async {
      final repository = createRepository(
        (_) =>
            jsonResponse({'detail': 'Residence not found.'}, statusCode: 404),
      );

      await expectLater(
        repository.deleteResidence(residenceId: residenceId),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.notFound,
          ),
        ),
      );
    });
  });
}
