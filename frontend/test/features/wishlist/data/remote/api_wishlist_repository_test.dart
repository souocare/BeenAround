import 'dart:convert';
import 'dart:typed_data';

import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/network/api_client.dart';
import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/wishlist/data/remote/api_wishlist_repository.dart';
import 'package:beenaround/features/wishlist/domain/wishlist_entry_input.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const countryEntryId = '550e8400-e29b-41d4-a716-446655440001';
const cityEntryId = '550e8400-e29b-41d4-a716-446655440002';

const lisbonId = 2267057;

/// Fake HTTP adapter following the existing project testing conventions.
class FakeWishlistHttpAdapter implements HttpClientAdapter {
  FakeWishlistHttpAdapter(this.handler);

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

ResponseBody emptyResponse({int statusCode = 204}) {
  return ResponseBody.fromString('', statusCode);
}

Map<String, dynamic> wishlistEntryResponse({
  String id = countryEntryId,
  String? countryCode = 'PT',
  int? cityId,
  String? note,
}) {
  return {
    'id': id,
    'country_code': countryCode,
    'city_id': cityId,
    'note': note,
    'created_at': '2026-11-03T10:00:00Z',
    'updated_at': '2026-11-03T10:00:00Z',
  };
}

ApiWishlistRepository createRepository(
  ResponseBody Function(RequestOptions options) handler,
) {
  final config = ServerConfig.parse('https://travel.example.com')!;

  final dio = Dio()..httpClientAdapter = FakeWishlistHttpAdapter(handler);

  return ApiWishlistRepository(
    apiClient: ApiClient(serverConfig: config, dio: dio),
  );
}

void main() {
  group('ApiWishlistRepository - listing', () {
    test('loads wishlist entries', () async {
      final repository = createRepository((options) {
        expect(options.method, 'GET');
        expect(options.uri.path, '/api/v1/wishlist');

        return jsonResponse({
          'items': [
            wishlistEntryResponse(note: 'Explore Portugal.'),
            wishlistEntryResponse(
              id: cityEntryId,
              countryCode: null,
              cityId: lisbonId,
            ),
          ],
          'total': 2,
        });
      });

      final entries = await repository.getWishlistEntries();

      expect(entries, hasLength(2));

      expect(entries.first.id, countryEntryId);
      expect(entries.first.countryCode, 'PT');
      expect(entries.first.note, 'Explore Portugal.');

      expect(entries.last.id, cityEntryId);
      expect(entries.last.cityId, lisbonId);
      expect(entries.last.isCity, isTrue);
    });

    test('supports an empty wishlist', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': [], 'total': 0}),
      );

      final entries = await repository.getWishlistEntries();

      expect(entries, isEmpty);
    });

    test('returns an immutable list', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [wishlistEntryResponse()],
          'total': 1,
        }),
      );

      final entries = await repository.getWishlistEntries();

      expect(() => entries.clear(), throwsUnsupportedError);
    });

    test('rejects a response without items', () async {
      final repository = createRepository((_) => jsonResponse({'total': 0}));

      await expectLater(repository.getWishlistEntries(), throwsFormatException);
    });

    test('rejects malformed items', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': 'invalid', 'total': 0}),
      );

      await expectLater(repository.getWishlistEntries(), throwsFormatException);
    });

    test('rejects entries with invalid destinations', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [wishlistEntryResponse(countryCode: null, cityId: null)],
          'total': 1,
        }),
      );

      await expectLater(repository.getWishlistEntries(), throwsFormatException);
    });

    test('maps HTTP 401 to unauthorized', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': 'Authentication required.',
        }, statusCode: 401),
      );

      await expectLater(
        repository.getWishlistEntries(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.unauthorized,
          ),
        ),
      );
    });

    test('maps HTTP 500 to server error', () async {
      final repository = createRepository(
        (_) =>
            jsonResponse({'detail': 'Internal server error.'}, statusCode: 500),
      );

      await expectLater(
        repository.getWishlistEntries(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.server,
          ),
        ),
      );
    });
  });

  group('ApiWishlistRepository - details', () {
    test('retrieves a single wishlist entry', () async {
      final repository = createRepository((options) {
        expect(options.method, 'GET');

        expect(options.uri.path, '/api/v1/wishlist/$countryEntryId');

        return jsonResponse(wishlistEntryResponse(note: 'Visit the Azores.'));
      });

      final entry = await repository.getWishlistEntry(entryId: countryEntryId);

      expect(entry.id, countryEntryId);
      expect(entry.countryCode, 'PT');
      expect(entry.note, 'Visit the Azores.');
    });

    test('maps HTTP 404 to not found', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': 'Wishlist entry not found.',
        }, statusCode: 404),
      );

      await expectLater(
        repository.getWishlistEntry(entryId: countryEntryId),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.notFound,
          ),
        ),
      );
    });

    test('rejects an empty entry ID', () async {
      var requestCount = 0;

      final repository = createRepository((_) {
        requestCount++;

        return jsonResponse(wishlistEntryResponse());
      });

      await expectLater(
        repository.getWishlistEntry(entryId: '   '),
        throwsArgumentError,
      );

      expect(requestCount, 0);
    });
  });

  group('ApiWishlistRepository - creation', () {
    test('creates a country wishlist entry', () async {
      final repository = createRepository((options) {
        expect(options.method, 'POST');
        expect(options.uri.path, '/api/v1/wishlist');

        expect(options.data, {
          'country_code': 'PT',
          'note': 'Explore the Douro Valley.',
        });

        return jsonResponse({
          'created': [wishlistEntryResponse(note: 'Explore the Douro Valley.')],
          'existing': [],
        }, statusCode: 201);
      });

      final result = await repository.addWishlistEntry(
        input: WishlistEntryInput.country(
          countryCode: 'pt',
          note: 'Explore the Douro Valley.',
        ),
      );

      expect(result.created, hasLength(1));
      expect(result.existing, isEmpty);

      expect(result.hasCreatedEntries, isTrue);
      expect(result.allAlreadyExisted, isFalse);

      expect(result.created.single.note, 'Explore the Douro Valley.');
    });

    test('accepts HTTP 200 when the entry already exists', () async {
      final repository = createRepository((options) {
        expect(options.method, 'POST');

        return jsonResponse({
          'created': [],
          'existing': [wishlistEntryResponse(note: 'Original note.')],
        }, statusCode: 200);
      });

      final result = await repository.addWishlistEntry(
        input: WishlistEntryInput.country(
          countryCode: 'PT',
          note: 'Different note.',
        ),
      );

      expect(result.created, isEmpty);
      expect(result.existing, hasLength(1));

      expect(result.allAlreadyExisted, isTrue);

      // POST must not overwrite existing notes.
      expect(result.existing.single.note, 'Original note.');
    });

    test('creates a city and explicitly includes its country', () async {
      final repository = createRepository((options) {
        expect(options.method, 'POST');
        expect(options.uri.path, '/api/v1/wishlist');

        expect(options.data, {
          'city_id': lisbonId,
          'include_country': true,
          'note': 'Explore Alfama.',
        });

        return jsonResponse({
          'created': [
            wishlistEntryResponse(
              id: cityEntryId,
              countryCode: null,
              cityId: lisbonId,
              note: 'Explore Alfama.',
            ),
            wishlistEntryResponse(
              id: countryEntryId,
              countryCode: 'PT',
              note: null,
            ),
          ],
          'existing': [],
        }, statusCode: 201);
      });

      final result = await repository.addWishlistEntry(
        input: WishlistEntryInput.city(
          cityId: lisbonId,
          includeCountry: true,
          note: 'Explore Alfama.',
        ),
      );

      expect(result.created, hasLength(2));

      final city = result.created.singleWhere((entry) => entry.isCity);

      final country = result.created.singleWhere((entry) => entry.isCountry);

      expect(city.note, 'Explore Alfama.');
      expect(country.note, isNull);
    });

    test('supports partially existing destinations', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'created': [
            wishlistEntryResponse(
              id: cityEntryId,
              countryCode: null,
              cityId: lisbonId,
            ),
          ],
          'existing': [wishlistEntryResponse(note: 'Existing country note.')],
        }, statusCode: 201),
      );

      final result = await repository.addWishlistEntry(
        input: WishlistEntryInput.city(cityId: lisbonId, includeCountry: true),
      );

      expect(result.created, hasLength(1));
      expect(result.existing, hasLength(1));

      expect(result.existing.single.note, 'Existing country note.');
    });

    test('rejects malformed creation responses', () async {
      final repository = createRepository(
        (_) => jsonResponse({'created': {}, 'existing': []}),
      );

      await expectLater(
        repository.addWishlistEntry(
          input: WishlistEntryInput.country(countryCode: 'PT'),
        ),
        throwsFormatException,
      );
    });

    test('maps unknown destinations to not found', () async {
      final repository = createRepository(
        (_) => jsonResponse({'detail': 'Country not found.'}, statusCode: 404),
      );

      await expectLater(
        repository.addWishlistEntry(
          input: WishlistEntryInput.country(countryCode: 'PT'),
        ),
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

  group('ApiWishlistRepository - updates', () {
    test('updates an existing note', () async {
      final repository = createRepository((options) {
        expect(options.method, 'PATCH');

        expect(options.uri.path, '/api/v1/wishlist/$countryEntryId');

        expect(options.data, {'note': 'Visit the Azores.'});

        return jsonResponse(wishlistEntryResponse(note: 'Visit the Azores.'));
      });

      final entry = await repository.updateWishlistNote(
        entryId: countryEntryId,
        note: '  Visit the Azores.  ',
      );

      expect(entry.note, 'Visit the Azores.');
    });

    test('clears a note with explicit null', () async {
      final repository = createRepository((options) {
        expect(options.method, 'PATCH');

        expect(options.data, {'note': null});

        return jsonResponse(wishlistEntryResponse(note: null));
      });

      final entry = await repository.updateWishlistNote(
        entryId: countryEntryId,
        note: null,
      );

      expect(entry.note, isNull);
    });

    test('normalizes blank notes to null', () async {
      final repository = createRepository((options) {
        expect(options.data, {'note': null});

        return jsonResponse(wishlistEntryResponse());
      });

      await repository.updateWishlistNote(entryId: countryEntryId, note: '   ');
    });

    test('rejects notes longer than 1000 characters', () async {
      var requestCount = 0;

      final repository = createRepository((_) {
        requestCount++;

        return jsonResponse(wishlistEntryResponse());
      });

      await expectLater(
        repository.updateWishlistNote(
          entryId: countryEntryId,
          note: 'A' * 1001,
        ),
        throwsArgumentError,
      );

      expect(requestCount, 0);
    });

    test('maps HTTP 404 when updating another user entry', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': 'Wishlist entry not found.',
        }, statusCode: 404),
      );

      await expectLater(
        repository.updateWishlistNote(
          entryId: countryEntryId,
          note: 'Unauthorized change.',
        ),
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

  group('ApiWishlistRepository - deletion', () {
    test('deletes an entry with HTTP 204', () async {
      final repository = createRepository((options) {
        expect(options.method, 'DELETE');

        expect(options.uri.path, '/api/v1/wishlist/$countryEntryId');

        return emptyResponse();
      });

      await repository.deleteWishlistEntry(entryId: countryEntryId);
    });

    test('rejects an empty entry ID', () async {
      var requestCount = 0;

      final repository = createRepository((_) {
        requestCount++;

        return emptyResponse();
      });

      await expectLater(
        repository.deleteWishlistEntry(entryId: ''),
        throwsArgumentError,
      );

      expect(requestCount, 0);
    });

    test('maps HTTP 404 to not found', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': 'Wishlist entry not found.',
        }, statusCode: 404),
      );

      await expectLater(
        repository.deleteWishlistEntry(entryId: countryEntryId),
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
