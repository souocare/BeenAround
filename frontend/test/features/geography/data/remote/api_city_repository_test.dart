import 'dart:convert';
import 'dart:typed_data';

import 'package:beenaround/core/config/server_config.dart';
import 'package:beenaround/core/network/api_client.dart';
import 'package:beenaround/core/network/api_exception.dart';
import 'package:beenaround/features/geography/data/remote/api_city_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/features/geography/domain/city_sort.dart';

class FakeCitiesHttpAdapter implements HttpClientAdapter {
  FakeCitiesHttpAdapter(this.handler);

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

Map<String, dynamic> cityJson({
  int id = 2267057,
  String name = 'Lisbon',
  String? asciiName = 'Lisbon',
  String countryCode = 'PT',
  String countryName = 'Portugal',
  double latitude = 38.7167,
  double longitude = -9.1333,
  int? population = 517802,
  String featureCode = 'PPLC',
}) {
  return {
    'id': id,
    'name': name,
    'ascii_name': asciiName,
    'country_code': countryCode,
    'country_name': countryName,
    'latitude': latitude,
    'longitude': longitude,
    'population': population,
    'feature_code': featureCode,
  };
}

Map<String, dynamic> citiesResponse(
  List<Map<String, dynamic>> items, {
  int? total,
  int limit = 20,
  int offset = 0,
}) {
  return {
    'items': items,
    'total': total ?? items.length,
    'limit': limit,
    'offset': offset,
  };
}

ApiCityRepository createRepository(
  ResponseBody Function(RequestOptions options) handler,
) {
  final config = ServerConfig.parse('https://travel.example.com')!;

  final dio = Dio()..httpClientAdapter = FakeCitiesHttpAdapter(handler);

  return ApiCityRepository(
    apiClient: ApiClient(serverConfig: config, dio: dio),
  );
}

void main() {
  group('ApiCityRepository', () {
    test('searches cities using the configured API', () async {
      final repository = createRepository((options) {
        expect(options.method, 'GET');
        expect(options.uri.path, '/api/v1/cities');
        expect(options.uri.queryParameters['q'], 'Lisbon');
        expect(options.uri.queryParameters['limit'], '20');
        expect(options.uri.queryParameters['offset'], '0');

        return jsonResponse(citiesResponse([cityJson()]));
      });

      final result = await repository.search(query: 'Lisbon');

      expect(result.total, 1);
      expect(result.items, hasLength(1));
      expect(result.items.single.name, 'Lisbon');
      expect(result.items.single.countryCode, 'PT');
    });

    test('normalizes query whitespace', () async {
      final repository = createRepository((options) {
        expect(options.uri.queryParameters['q'], 'Lisbon');

        return jsonResponse(citiesResponse([cityJson()]));
      });

      final result = await repository.search(query: '  Lisbon  ');

      expect(result.total, 1);
    });

    test('normalizes country codes', () async {
      final repository = createRepository((options) {
        expect(options.uri.queryParameters['country_code'], 'PT');
        expect(options.uri.queryParameters.containsKey('q'), isFalse);

        return jsonResponse(citiesResponse([cityJson()]));
      });

      final result = await repository.search(countryCode: ' pt ');

      expect(result.total, 1);
    });

    test('combines query and country filter', () async {
      final repository = createRepository((options) {
        expect(options.uri.queryParameters['q'], 'Lisbon');
        expect(options.uri.queryParameters['country_code'], 'PT');

        return jsonResponse(citiesResponse([cityJson()]));
      });

      final result = await repository.search(
        query: 'Lisbon',
        countryCode: 'PT',
      );

      expect(result.items.single.countryCode, 'PT');
    });

    test('supports pagination', () async {
      final repository = createRepository((options) {
        expect(options.uri.queryParameters['limit'], '5');
        expect(options.uri.queryParameters['offset'], '10');

        return jsonResponse(
          citiesResponse([cityJson()], total: 35, limit: 5, offset: 10),
        );
      });

      final result = await repository.search(
        query: 'Lisbon',
        limit: 5,
        offset: 10,
      );

      expect(result.total, 35);
      expect(result.limit, 5);
      expect(result.offset, 10);
      expect(result.items, hasLength(1));
    });

    test('supports empty results', () async {
      final repository = createRepository(
        (_) => jsonResponse(citiesResponse([])),
      );

      final result = await repository.search(query: 'NonexistentCity123');

      expect(result.total, 0);
      expect(result.items, isEmpty);
    });

    test('maps all city fields correctly', () async {
      final repository = createRepository(
        (_) => jsonResponse(
          citiesResponse([
            cityJson(
              id: 3448439,
              name: 'São Paulo',
              asciiName: 'Sao Paulo',
              countryCode: 'BR',
              countryName: 'Brazil',
              latitude: -23.5505,
              longitude: -46.6333,
              population: 12325232,
              featureCode: 'PPLA',
            ),
          ]),
        ),
      );

      final result = await repository.search(query: 'Sao');

      final city = result.items.single;

      expect(city.id, 3448439);
      expect(city.name, 'São Paulo');
      expect(city.asciiName, 'Sao Paulo');
      expect(city.countryCode, 'BR');
      expect(city.countryName, 'Brazil');
      expect(city.latitude, -23.5505);
      expect(city.longitude, -46.6333);
      expect(city.population, 12325232);
      expect(city.featureCode, 'PPLA');
    });

    test('supports nullable city fields', () async {
      final repository = createRepository(
        (_) => jsonResponse(
          citiesResponse([cityJson(asciiName: null, population: null)]),
        ),
      );

      final result = await repository.search(query: 'Lisbon');

      expect(result.items.single.asciiName, isNull);
      expect(result.items.single.population, isNull);
    });

    test('rejects missing items', () async {
      final repository = createRepository(
        (_) => jsonResponse({'total': 0, 'limit': 20, 'offset': 0}),
      );

      await expectLater(
        repository.search(query: 'Lisbon'),
        throwsFormatException,
      );
    });

    test('rejects invalid pagination metadata', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [],
          'total': 'invalid',
          'limit': 20,
          'offset': 0,
        }),
      );

      await expectLater(
        repository.search(query: 'Lisbon'),
        throwsFormatException,
      );
    });

    test('rejects malformed city items', () async {
      final repository = createRepository(
        (_) => jsonResponse(
          citiesResponse([
            {'id': 'invalid', 'name': 'Lisbon'},
          ]),
        ),
      );

      await expectLater(
        repository.search(query: 'Lisbon'),
        throwsA(isA<TypeError>()),
      );
    });

    test('rejects searches without query or country', () async {
      final repository = createRepository(
        (_) => throw StateError('HTTP request should not be sent.'),
      );

      await expectLater(repository.search(), throwsArgumentError);
    });

    test('rejects invalid pagination parameters', () async {
      final repository = createRepository(
        (_) => throw StateError('HTTP request should not be sent.'),
      );

      await expectLater(
        repository.search(query: 'Lisbon', limit: 0),
        throwsArgumentError,
      );

      await expectLater(
        repository.search(query: 'Lisbon', limit: 101),
        throwsArgumentError,
      );

      await expectLater(
        repository.search(query: 'Lisbon', offset: -1),
        throwsArgumentError,
      );
    });

    test('maps HTTP 401 to unauthorized', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': 'Authentication required.',
        }, statusCode: 401),
      );

      await expectLater(
        repository.search(query: 'Lisbon'),
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
        repository.search(query: 'Lisbon'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.server,
          ),
        ),
      );
    });
    test('sends alphabetical sorting to the API', () async {
      final repository = createRepository((options) {
        expect(options.method, 'GET');
        expect(options.uri.path, '/api/v1/cities');
        expect(options.uri.queryParameters['country_code'], 'PT');
        expect(options.uri.queryParameters['sort'], 'name');

        return jsonResponse(
          citiesResponse([
            cityJson(id: 1, name: 'Lisbon'),
            cityJson(id: 2, name: 'Porto'),
          ]),
        );
      });

      final result = await repository.search(
        countryCode: 'PT',
        sort: CitySort.name,
      );

      expect(result.items.map((city) => city.name).toList(), [
        'Lisbon',
        'Porto',
      ]);
    });
    test('uses population sorting by default', () async {
      final repository = createRepository((options) {
        expect(options.uri.queryParameters['sort'], 'population');

        return jsonResponse(citiesResponse([cityJson()]));
      });

      await repository.search(query: 'Lisbon');
    });
    test('combines sorting with search and pagination', () async {
      final repository = createRepository((options) {
        expect(options.uri.queryParameters['q'], 'Porto');
        expect(options.uri.queryParameters['country_code'], 'PT');
        expect(options.uri.queryParameters['sort'], 'name');
        expect(options.uri.queryParameters['limit'], '10');
        expect(options.uri.queryParameters['offset'], '20');

        return jsonResponse(
          citiesResponse(
            [cityJson(id: 2, name: 'Porto')],
            total: 35,
            limit: 10,
            offset: 20,
          ),
        );
      });

      final result = await repository.search(
        query: 'Porto',
        countryCode: 'PT',
        sort: CitySort.name,
        limit: 10,
        offset: 20,
      );

      expect(result.total, 35);
      expect(result.limit, 10);
      expect(result.offset, 20);
    });
    test('fetches country city counts', () async {
      final repository = createRepository((options) {
        expect(options.method, 'GET');
        expect(options.uri.path, '/api/v1/cities/countries');

        return jsonResponse({
          'items': [
            {
              'country_code': 'FR',
              'country_name': 'France',
              'city_count': 1200,
            },
            {
              'country_code': 'PT',
              'country_name': 'Portugal',
              'city_count': 850,
            },
          ],
        });
      });

      final countries = await repository.listCountryCityCounts();

      expect(countries, hasLength(2));

      expect(countries[0].countryCode, 'FR');
      expect(countries[0].countryName, 'France');
      expect(countries[0].cityCount, 1200);

      expect(countries[1].countryCode, 'PT');
      expect(countries[1].countryName, 'Portugal');
      expect(countries[1].cityCount, 850);
    });
    test('supports countries with zero cities', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [
            {'country_code': 'IS', 'country_name': 'Iceland', 'city_count': 0},
          ],
        }),
      );

      final countries = await repository.listCountryCityCounts();

      expect(countries.single.countryCode, 'IS');
      expect(countries.single.cityCount, 0);
    });
    test('rejects malformed country city counts response', () async {
      final repository = createRepository(
        (_) => jsonResponse({'items': 'invalid'}),
      );

      await expectLater(
        repository.listCountryCityCounts(),
        throwsFormatException,
      );
    });
    test('rejects malformed country city count items', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'items': [
            {
              'country_code': 'PT',
              'country_name': 'Portugal',
              'city_count': 'invalid',
            },
          ],
        }),
      );

      await expectLater(
        repository.listCountryCityCounts(),
        throwsA(isA<TypeError>()),
      );
    });
    test('maps country city counts HTTP errors', () async {
      final repository = createRepository(
        (_) => jsonResponse({
          'detail': 'Authentication required.',
        }, statusCode: 401),
      );

      await expectLater(
        repository.listCountryCityCounts(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.unauthorized,
          ),
        ),
      );
    });
  });
}
