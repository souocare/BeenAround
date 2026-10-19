import 'package:beenaround/core/config/local_server_config_repository.dart';
import 'package:beenaround/core/config/server_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesAsync preferences;
  late LocalServerConfigRepository repository;

  setUp(() {
    // Each test receives a fresh, isolated in-memory storage.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    preferences = SharedPreferencesAsync();

    repository = LocalServerConfigRepository(preferences: preferences);
  });

  group('LocalServerConfigRepository', () {
    test('returns null when no server is configured', () async {
      final result = await repository.load();

      expect(result, isNull);
    });

    test('saves and loads an HTTPS server', () async {
      final config = ServerConfig.parse('https://travel.example.com')!;

      await repository.save(config);

      final restored = await repository.load();

      expect(restored, isNotNull);
      expect(restored!.baseUrl.toString(), 'https://travel.example.com');
    });

    test('persists configuration across repository instances', () async {
      final config = ServerConfig.parse('https://travel.example.com')!;

      await repository.save(config);

      final anotherRepository = LocalServerConfigRepository(
        preferences: SharedPreferencesAsync(),
      );

      final restored = await anotherRepository.load();

      expect(restored, isNotNull);
      expect(restored!.baseUrl.toString(), 'https://travel.example.com');
    });

    test('overwrites the previously configured server', () async {
      final first = ServerConfig.parse('https://first.example.com')!;

      final second = ServerConfig.parse('https://second.example.com')!;

      await repository.save(first);
      await repository.save(second);

      final restored = await repository.load();

      expect(restored, isNotNull);
      expect(restored!.baseUrl.toString(), 'https://second.example.com');
    });

    test('clears the saved server', () async {
      final config = ServerConfig.parse('https://travel.example.com')!;

      await repository.save(config);
      await repository.clear();

      expect(await repository.load(), isNull);
    });

    test('rejects saving HTTP when not explicitly enabled', () async {
      final config = ServerConfig.parse(
        'http://192.168.1.100:8000',
        allowHttp: true,
      )!;

      await expectLater(repository.save(config), throwsArgumentError);

      expect(await repository.load(), isNull);
    });

    test('allows HTTP when explicitly enabled', () async {
      final httpRepository = LocalServerConfigRepository(
        preferences: preferences,
        allowHttp: true,
      );

      final config = ServerConfig.parse(
        'http://192.168.1.100:8000',
        allowHttp: true,
      )!;

      await httpRepository.save(config);

      final restored = await httpRepository.load();

      expect(restored, isNotNull);
      expect(restored!.baseUrl.toString(), 'http://192.168.1.100:8000');
    });

    test('returns null for an invalid stored URL', () async {
      await preferences.setString(
        LocalServerConfigRepository.storageKey,
        'not-a-valid-server',
      );

      final restored = await repository.load();

      expect(restored, isNull);
    });

    test('rejects stored HTTP when HTTP is disabled', () async {
      await preferences.setString(
        LocalServerConfigRepository.storageKey,
        'http://192.168.1.100:8000',
      );

      final restored = await repository.load();

      expect(restored, isNull);
    });

    test('preserves saved configuration when loading it', () async {
      final config = ServerConfig.parse('https://travel.example.com')!;

      await repository.save(config);

      final firstLoad = await repository.load();
      final secondLoad = await repository.load();

      expect(firstLoad, isNotNull);
      expect(secondLoad, isNotNull);

      expect(firstLoad!.baseUrl, secondLoad!.baseUrl);
    });

    test('clearing an unconfigured server is safe', () async {
      await repository.clear();

      expect(await repository.load(), isNull);
    });
  });
}
