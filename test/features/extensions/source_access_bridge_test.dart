import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_reader_app/features/extensions/services/source_access_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String channelName = 'dev.dcatcher/source_access';
  const MethodChannel channel = MethodChannel(channelName);
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'getSourceAccessInfo':
          return <String, dynamic>{
            'sourceId': methodCall.arguments['sourceId'],
            'name': 'Test Manga Source',
            'homeUrl': 'https://example.com',
            'supportsSettings': true,
            'hasCookies': true,
            'loginVerified': false,
            // Sensitive fields that must be ignored/never retained in DTO
            'sessionToken': 'sensitive_jwt_token_12345',
            'cookieValue': 'cf_clearance=secret_val; session=xyz',
            'rawHeaders': {'Authorization': 'Bearer secret'},
          };
        case 'openSourceWebView':
          return true;
        case 'openSourceSettings':
          return true;
        case 'clearSourceCookies':
          return null;
        default:
          throw MissingPluginException();
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    log.clear();
  });

  group('SourceAccessBridge channel & platform initialization', () {
    test('default constructor configures default channel dev.dcatcher/source_access', () {
      final bridge = SourceAccessBridge();
      expect(bridge.channel.name, equals('dev.dcatcher/source_access'));
    });

    test('forTesting constructor allows custom MethodChannel and platform guard overrides', () {
      const customChannel = MethodChannel('dev.dcatcher/source_access_test');
      final bridge = SourceAccessBridge.forTesting(
        channel: customChannel,
        isSupported: false,
      );
      expect(bridge.channel.name, equals('dev.dcatcher/source_access_test'));
      expect(bridge.isSupported, isFalse);
    });

    test('isSupported defaults to platform guard check', () {
      final bridge = SourceAccessBridge();
      expect(bridge.isSupported, isA<bool>());
    });

    test('throws UnsupportedError when platform guard isSupported is false', () async {
      final bridge = SourceAccessBridge.forTesting(
        channel: channel,
        isSupported: false,
      );

      expect(() => bridge.getInfo('source_123'), throwsA(isA<UnsupportedError>()));
      expect(() => bridge.openWebView('source_123'), throwsA(isA<UnsupportedError>()));
      expect(() => bridge.openSettings('source_123'), throwsA(isA<UnsupportedError>()));
      expect(() => bridge.clearCookies('source_123', confirmed: true), throwsA(isA<UnsupportedError>()));
      expect(log, isEmpty);
    });
  });

  group('SourceAccessBridge method channel contract & exact names', () {
    test('getInfo calls getSourceAccessInfo with exact 64-bit ID string unchanged', () async {
      final bridge = SourceAccessBridge.forTesting(channel: channel, isSupported: true);
      const large64BitId = '9223372036854775807'; // Max 64-bit signed int as string

      final SourceAccessInfo info = await bridge.getInfo(large64BitId);

      expect(log, hasLength(1));
      expect(log.single.method, equals('getSourceAccessInfo'));
      expect(log.single.arguments, equals(<String, dynamic>{
        'sourceId': large64BitId,
      }));
      expect(info.sourceId, equals(large64BitId));
      expect(info.name, equals('Test Manga Source'));
      expect(info.homeUrl, equals('https://example.com'));
      expect(info.supportsSettings, isTrue);
      expect(info.hasCookies, isTrue);
      expect(info.loginVerified, isFalse);
    });

    test('openWebView calls openSourceWebView with exact args', () async {
      final bridge = SourceAccessBridge.forTesting(channel: channel, isSupported: true);
      const sourceId = 'source_9876543210123456';

      final bool result = await bridge.openWebView(sourceId);

      expect(result, isTrue);
      expect(log, hasLength(1));
      expect(log.single.method, equals('openSourceWebView'));
      expect(log.single.arguments, equals(<String, dynamic>{
        'sourceId': sourceId,
      }));
    });

    test('openSettings calls openSourceSettings with exact args', () async {
      final bridge = SourceAccessBridge.forTesting(channel: channel, isSupported: true);
      const sourceId = 'source_settings_123';

      final bool result = await bridge.openSettings(sourceId);

      expect(result, isTrue);
      expect(log, hasLength(1));
      expect(log.single.method, equals('openSourceSettings'));
      expect(log.single.arguments, equals(<String, dynamic>{
        'sourceId': sourceId,
      }));
    });

    test('clearCookies calls clearSourceCookies with exact args when confirmed=true', () async {
      final bridge = SourceAccessBridge.forTesting(channel: channel, isSupported: true);
      const sourceId = 'source_clear_123';

      await bridge.clearCookies(sourceId, confirmed: true);

      expect(log, hasLength(1));
      expect(log.single.method, equals('clearSourceCookies'));
      expect(log.single.arguments, equals(<String, dynamic>{
        'sourceId': sourceId,
        'confirmed': true,
      }));
    });
  });

  group('Confirmation, fail-closed & security guarantees', () {
    test('clearCookies fail-closed: throws ArgumentError when confirmed is false without invoking channel', () async {
      final bridge = SourceAccessBridge.forTesting(channel: channel, isSupported: true);
      const sourceId = 'source_clear_unconfirmed';

      expect(
        () => bridge.clearCookies(sourceId, confirmed: false),
        throwsA(isA<ArgumentError>()),
      );
      expect(log, isEmpty, reason: 'MethodChannel must not be called when confirmed is false');
    });

    test('SourceAccessInfo DTO ignores and never retains sensitive keys/cookie values', () {
      final rawMap = <String, dynamic>{
        'sourceId': '1234567890123456',
        'name': 'Secure Source',
        'homeUrl': 'https://mangasecure.org',
        'supportsSettings': false,
        'hasCookies': true,
        'loginVerified': false,
        'sessionToken': 'super_secret_jwt',
        'cookieValue': 'session_id=abcdef123456',
        'authToken': 'Bearer 987654',
      };

      final info = SourceAccessInfo.fromMap(rawMap);

      expect(info.sourceId, equals('1234567890123456'));
      expect(info.name, equals('Secure Source'));
      expect(info.homeUrl, equals('https://mangasecure.org'));
      expect(info.supportsSettings, isFalse);
      expect(info.hasCookies, isTrue);
      expect(info.loginVerified, isFalse);

      // Verify serialization does not contain tokens or cookie values
      final serialized = info.toMap();
      expect(serialized.containsKey('sessionToken'), isFalse);
      expect(serialized.containsKey('cookieValue'), isFalse);
      expect(serialized.containsKey('authToken'), isFalse);
      expect(serialized.containsKey('token'), isFalse);
    });

    test('session cookies do NOT imply loginVerified (defaults to false)', () {
      final rawMap = <String, dynamic>{
        'sourceId': 'source_cookies_only',
        'name': 'Cookie Source',
        'homeUrl': 'https://cookiesource.org',
        'supportsSettings': true,
        'hasCookies': true,
        // loginVerified omitted in payload
      };

      final info = SourceAccessInfo.fromMap(rawMap);
      expect(info.hasCookies, isTrue);
      expect(info.loginVerified, isFalse, reason: 'hasCookies=true must not imply loginVerified=true');
    });
  });

  group('Platform / native exceptions propagate without false success', () {
    test('getInfo propagates PlatformException directly', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'SOURCE_NOT_FOUND',
          message: 'The requested source ID does not exist',
        );
      });

      final bridge = SourceAccessBridge.forTesting(channel: channel, isSupported: true);
      expect(
        () => bridge.getInfo('unknown_source'),
        throwsA(isA<PlatformException>().having(
          (e) => e.code,
          'code',
          equals('SOURCE_NOT_FOUND'),
        )),
      );
    });

    test('openWebView propagates PlatformException without returning false or true', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'WEBVIEW_FAILED',
          message: 'Failed to launch WebView',
        );
      });

      final bridge = SourceAccessBridge.forTesting(channel: channel, isSupported: true);
      expect(
        () => bridge.openWebView('failing_source'),
        throwsA(isA<PlatformException>()),
      );
    });

    test('openSettings propagates PlatformException without returning false or true', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'SETTINGS_UNAVAILABLE',
          message: 'Settings view could not be opened',
        );
      });

      final bridge = SourceAccessBridge.forTesting(channel: channel, isSupported: true);
      expect(
        () => bridge.openSettings('failing_source'),
        throwsA(isA<PlatformException>()),
      );
    });

    test('clearCookies propagates PlatformException without silent failure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'CLEAR_FAILED',
          message: 'Native cookie store error',
        );
      });

      final bridge = SourceAccessBridge.forTesting(channel: channel, isSupported: true);
      expect(
        () => bridge.clearCookies('failing_source', confirmed: true),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
