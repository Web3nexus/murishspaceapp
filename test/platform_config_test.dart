import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/api_client.dart';
import 'package:mobile/providers/platform_provider.dart';

/// Serves a canned JSON body so fetchConfig can be driven without a network.
class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.body, {this.statusCode = 200});

  final String body;
  final int statusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(body, statusCode, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> defaultAuthMethods() {
    return {
      'primary': 'phone_otp',
      'methods': {
        'phone_otp': {'login': true, 'registration': true},
        'email_password': {'login': true, 'registration': true},
      },
    };
  }

  Map<String, dynamic> platformPayload({
    Map<String, dynamic>? authMethods,
    bool includeAuthMethods = true,
  }) {
    return {
      'platform_name': 'MurihSpace',
      'kyc_enabled': true,
      if (includeAuthMethods) 'auth_methods': authMethods ?? defaultAuthMethods(),
    };
  }

  group('PlatformConfig.fromJson', () {
    test('parses enabled methods', () {
      final config = PlatformConfig.fromJson(platformPayload());
      expect(config.isLoginEnabled('phone_otp'), isTrue);
      expect(config.isLoginEnabled('email_password'), isTrue);
      expect(config.primaryMethod, 'phone_otp');
    });

    test('honours a method the admin disabled', () {
      final config = PlatformConfig.fromJson(platformPayload(
        authMethods: {
          'primary': 'phone_otp',
          'methods': {
            'phone_otp': {'login': true, 'registration': true},
            'email_password': {'login': false, 'registration': false},
          },
        },
      ));
      expect(config.isLoginEnabled('phone_otp'), isTrue);
      expect(config.isLoginEnabled('email_password'), isFalse);
    });

    test('unwraps a nested data envelope', () {
      final config = PlatformConfig.fromJson({
        'data': platformPayload(),
      });
      expect(config.isLoginEnabled('phone_otp'), isTrue);
    });

    test('throws instead of silently disabling every method', () {
      // A missing auth_methods map used to fall through to an empty method
      // map, which made every isLoginEnabled() false and locked the user out.
      expect(
        () => PlatformConfig.fromJson(platformPayload(includeAuthMethods: false)),
        throwsFormatException,
      );
    });

    test('throws when auth_methods carries no usable methods', () {
      expect(
        () => PlatformConfig.fromJson(platformPayload(
          authMethods: {'primary': 'phone_otp', 'methods': <String, dynamic>{}},
        )),
        throwsFormatException,
      );
    });

    test('an unavailable config leaves the resilient default in place', () {
      // The screens read `config?.isLoginEnabled(x) ?? true`, so a null config
      // keeps sign-in options visible rather than hiding them all.
      PlatformConfig? config;
      try {
        config = PlatformConfig.fromJson(platformPayload(includeAuthMethods: false));
      } catch (_) {
        config = null;
      }
      expect(config?.isLoginEnabled('email_password') ?? true, isTrue);
    });

    test('keeps a method the admin deliberately switched off', () {
      // A well-formed {false, false} entry must survive, otherwise the app
      // would re-enable a method the admin disabled.
      final config = PlatformConfig.fromJson(platformPayload(
        authMethods: {
          'primary': 'phone_otp',
          'methods': {
            'phone_otp': {'login': true, 'registration': true},
            'email_password': {'login': false, 'registration': false},
          },
        },
      ));
      expect(config.methods.containsKey('email_password'), isTrue);
      expect(config.isLoginEnabled('email_password'), isFalse);
      expect(config.isRegistrationEnabled('email_password'), isFalse);
    });

    test('drops an entry whose flags are missing', () {
      // A malformed entry invalidates the whole map so the UI falls back to its
      // resilient defaults instead of silently hiding that method.
      expect(
        () => PlatformConfig.fromJson(platformPayload(
          authMethods: {
            'primary': 'phone_otp',
            'methods': {
              'phone_otp': {'login': true, 'registration': true},
              'email_password': <String, dynamic>{'login': true},
            },
          },
        )),
        throwsFormatException,
      );
    });

    test('drops an entry whose flags are not booleans', () {
      // A string "true" must not be coerced into an enabled method.
      expect(
        () => PlatformConfig.fromJson(platformPayload(
          authMethods: {
            'primary': 'phone_otp',
            'methods': {
              'phone_otp': {'login': true, 'registration': true},
              'email_password': {'login': 'true', 'registration': 'false'},
            },
          },
        )),
        throwsFormatException,
      );
    });

    test('a malformed entry cannot produce a map with nothing usable', () {
      // The lockout this guards: email_password has a missing flag and
      // phone_otp is valid but switched off. Skipping only the bad entry would
      // leave a map where every method is unusable, which the UI renders as
      // "no sign-in options". The whole map must be rejected so the defaults
      // (everything visible) apply.
      PlatformConfig? config;
      try {
        config = PlatformConfig.fromJson(platformPayload(
          authMethods: {
            'primary': 'phone_otp',
            'methods': {
              'phone_otp': {'login': false, 'registration': false},
              'email_password': <String, dynamic>{'registration': false},
            },
          },
        ));
      } catch (_) {
        config = null;
      }

      expect(config, isNull, reason: 'The map must be rejected, not partially accepted.');
      expect(config?.isLoginEnabled('phone_otp') ?? true, isTrue);
      expect(config?.isLoginEnabled('email_password') ?? true, isTrue);
    });

    test('an entry that is not an object invalidates the whole map', () {
      expect(
        () => PlatformConfig.fromJson(platformPayload(
          authMethods: {
            'primary': 'phone_otp',
            'methods': {
              'phone_otp': {'login': true, 'registration': true},
              'email_password': 'nonsense',
            },
          },
        )),
        throwsFormatException,
      );
    });

    test('throws when every entry is malformed', () {
      expect(
        () => PlatformConfig.fromJson(platformPayload(
          authMethods: {
            'primary': 'phone_otp',
            'methods': {
              'phone_otp': <String, dynamic>{'login': 1, 'registration': 0},
              'email_password': 'nonsense',
            },
          },
        )),
        throwsFormatException,
      );
    });
  });

  group('PlatformNotifier.fetchConfig', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
      // ApiClient's request interceptor reads the auth token from secure
      // storage, which has no platform channel in a unit test.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => null,
      );
    });

    tearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      );
    });

    void serve(String body, {int statusCode = 200}) {
      ApiClient.instance.dio.httpClientAdapter =
          _CannedAdapter(body, statusCode: statusCode);
    }

    Map<String, dynamic> wellFormed(bool login, bool registration) => {
          'data': {
            'auth_methods': {
              'primary': 'phone_otp',
              'methods': {
                'phone_otp': {'login': true, 'registration': true},
                'email_password': {'login': login, 'registration': registration},
              },
            },
          },
        };

    test('a malformed payload clears the previously loaded config', () async {
      // Keeping the stale config is the "disabled method still shows" symptom,
      // so an unparseable payload must drop it.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      serve(jsonEncode(wellFormed(true, true)));
      await container.read(platformProvider.notifier).fetchConfig();
      expect(container.read(platformProvider).config!.isLoginEnabled('email_password'), isTrue);

      serve(jsonEncode({
        'data': {
          'auth_methods': {
            'primary': 'phone_otp',
            'methods': {
              'phone_otp': {'login': true, 'registration': true},
              'email_password': <String, dynamic>{'login': true},
            },
          },
        },
      }));
      await container.read(platformProvider.notifier).fetchConfig();

      final state = container.read(platformProvider);
      expect(state.config, isNull, reason: 'Stale config must be cleared.');
      expect(state.error, isNotNull);
    });

    test('a transport error keeps the last known-good config', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      serve(jsonEncode(wellFormed(true, true)));
      await container.read(platformProvider.notifier).fetchConfig();
      expect(container.read(platformProvider).config, isNotNull);

      serve('{"data":{}}', statusCode: 500);
      await container.read(platformProvider.notifier).fetchConfig();

      final state = container.read(platformProvider);
      expect(state.error, isNotNull);
      expect(state.config, isNotNull, reason: 'A network blip must not wipe good config.');
    });
  });
}

