import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_reader_app/features/extensions/models/keiyoushi_extension.dart';
import 'package:manga_reader_app/features/extensions/services/keiyoushi_repository.dart';

void main() {
  group('Keiyoushi Extension Store & Models (Live Schema & Security)', () {
    const liveRepoJson = '''
    {
      "name": "Keiyoushi",
      "badgeLabel": "Official",
      "signingKey": "9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2",
      "contact": "https://discord.gg/keiyoushi",
      "extensionList": {
        "extensions": [
          {
            "name": "MangaDex",
            "packageName": "eu.kanade.tachiyomi.extension.all.mangadex",
            "versionName": "1.6.1",
            "versionCode": "205",
            "extensionLib": "1.6",
            "resources": {
              "apkUrl": "https://github.com/keiyoushi/extensions/releases/download/fc7a827-0/tachiyomi-all.mangadex-v1.6.1.apk",
              "iconUrl": "https://cdn.jsdelivr.net/gh/keiyoushi/extensions@repo/icon/eu.kanade.tachiyomi.extension.all.mangadex.png"
            },
            "contentWarning": "CONTENT_WARNING_MIXED",
            "sources": [
              {
                "id": "2499283573021234567",
                "name": "MangaDex",
                "language": "en",
                "homeUrl": "https://mangadex.org"
              },
              {
                "id": "8923748291039485721",
                "name": "MangaDex (RU)",
                "language": "ru",
                "homeUrl": "https://mangadex.org"
              }
            ]
          },
          {
            "name": "Remanga",
            "packageName": "eu.kanade.tachiyomi.extension.ru.remanga",
            "versionName": "1.6.45",
            "versionCode": "45",
            "extensionLib": "1.6",
            "resources": {
              "apkUrl": "https://github.com/keiyoushi/extensions/releases/download/fc7a827-0/tachiyomi-ru.remanga-v1.6.45.apk",
              "iconUrl": "https://cdn.jsdelivr.net/gh/keiyoushi/extensions@repo/icon/eu.kanade.tachiyomi.extension.ru.remanga.png"
            },
            "contentWarning": "CONTENT_WARNING_NSFW",
            "sources": [
              {
                "id": "6738291048291039485",
                "name": "ReManga",
                "language": "ru",
                "homeUrl": "https://remanga.org"
              }
            ]
          },
          {
            "name": "Komga",
            "packageName": "eu.kanade.tachiyomi.extension.all.komga",
            "versionName": "1.6.10",
            "versionCode": "10",
            "extensionLib": "1.6",
            "resources": {
              "apkUrl": "https://github.com/keiyoushi/extensions/releases/download/fc7a827-0/tachiyomi-all.komga-v1.6.10.apk",
              "iconUrl": "https://cdn.jsdelivr.net/gh/keiyoushi/extensions@repo/icon/eu.kanade.tachiyomi.extension.all.komga.png"
            },
            "contentWarning": "CONTENT_WARNING_SAFE",
            "sources": [
              {
                "id": "3849102938475619283",
                "name": "Komga",
                "language": "all",
                "homeUrl": "https://komga.org"
              }
            ]
          }
        ]
      }
    }
    ''';

    test('Parses live schema with exact field keys and preserves 64-bit string IDs', () {
      final data = jsonDecode(liveRepoJson) as Map<String, dynamic>;
      final extensions = KeiyoushiRepository.parseExtensionsJson(data);

      expect(extensions.length, equals(3));

      final mangadex = extensions[0];
      expect(mangadex.name, equals('MangaDex'));
      expect(mangadex.packageName, equals('eu.kanade.tachiyomi.extension.all.mangadex'));
      expect(mangadex.versionName, equals('1.6.1'));
      expect(mangadex.versionCode, equals('205'));
      expect(mangadex.extensionLib, equals('1.6'));
      expect(mangadex.apkUrl, equals('https://github.com/keiyoushi/extensions/releases/download/fc7a827-0/tachiyomi-all.mangadex-v1.6.1.apk'));
      expect(mangadex.iconUrl, contains('jsdelivr.net'));
      expect(mangadex.contentWarning, equals(ContentWarning.mixed));
      expect(mangadex.isNsfw, isTrue);
      expect(mangadex.sources.length, equals(2));

      expect(mangadex.sources[0].id, equals('2499283573021234567'));
      expect(mangadex.sources[0].name, equals('MangaDex'));
      expect(mangadex.sources[0].language, equals('en'));
      expect(mangadex.sources[0].homeUrl, equals('https://mangadex.org'));

      expect(mangadex.sources[1].id, equals('8923748291039485721'));
      expect(mangadex.sources[1].language, equals('ru'));

      final remanga = extensions[1];
      expect(remanga.name, equals('Remanga'));
      expect(remanga.contentWarning, equals(ContentWarning.nsfw));
      expect(remanga.isNsfw, isTrue);
      expect(remanga.sources[0].id, equals('6738291048291039485'));

      final komga = extensions[2];
      expect(komga.name, equals('Komga'));
      expect(komga.contentWarning, equals(ContentWarning.safe));
      expect(komga.isNsfw, isFalse);
    });

    test('Rejects malformed or missing extensionList instead of returning empty list', () {
      final invalid1 = {'name': 'Keiyoushi', 'signingKey': '9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2'};
      expect(() => KeiyoushiRepository.parseExtensionsJson(invalid1), throwsA(isA<FormatException>()));

      final invalid2 = {
        'name': 'Keiyoushi',
        'signingKey': '9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2',
        'extensionList': 'not_a_map',
      };
      expect(() => KeiyoushiRepository.parseExtensionsJson(invalid2), throwsA(isA<FormatException>()));

      final invalid3 = {
        'name': 'Keiyoushi',
        'signingKey': '9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2',
        'extensionList': {'extensions': 'not_a_list'},
      };
      expect(() => KeiyoushiRepository.parseExtensionsJson(invalid3), throwsA(isA<FormatException>()));
    });

    test('Validates actual response signingKey against pinned fingerprint', () {
      final untrustedKeyJson = {
        'name': 'Keiyoushi',
        'signingKey': 'bad_cert_hash_00112233445566778899aabbccddeeff',
        'extensionList': {'extensions': []},
      };
      expect(
        () => KeiyoushiRepository.parseExtensionsJson(untrustedKeyJson),
        throwsA(isA<SecurityException>()),
      );

      final missingKeyJson = {
        'name': 'Keiyoushi',
        'extensionList': {'extensions': []},
      };
      expect(
        () => KeiyoushiRepository.parseExtensionsJson(missingKeyJson),
        throwsA(isA<SecurityException>()),
      );
    });

    test('Strictly enforces canonical decimal strings for source ID and versionCode', () {
      // 1. Double is rejected because 64-bit precision was already lost
      expect(
        () => KeiyoushiSource.fromJson({
          'id': 2.4992835730212347e+18,
          'name': 'Lossy',
          'language': 'en',
          'homeUrl': 'https://example.com',
        }),
        throwsA(isA<FormatException>()),
      );

      // 2. Non-digit string rejected
      expect(
        () => KeiyoushiSource.fromJson({
          'id': 'abc-123',
          'name': 'Invalid',
          'language': 'en',
          'homeUrl': 'https://example.com',
        }),
        throwsA(isA<FormatException>()),
      );

      // 3. Decimal string accepted
      final validSource = KeiyoushiSource.fromJson({
        'id': '2499283573021234567',
        'name': 'Valid',
        'language': 'en',
        'homeUrl': 'https://example.com',
      });
      expect(validSource.id, equals('2499283573021234567'));

      // 4. Invalid versionCode double rejected
      expect(
        () => KeiyoushiExtension.fromJson({
          'name': 'BadExt',
          'packageName': 'com.bad',
          'versionName': '1.0',
          'versionCode': 105.5,
          'resources': {'apkUrl': 'https://example.com/a.apk'},
          'sources': [],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('Forbids arbitrary repoUrl override pointing to untrusted domain', () {
      final repo = KeiyoushiRepository();
      expect(
        () => repo.fetchExtensions(repoUrl: 'https://evil.com/fake_index.json'),
        throwsA(isA<SecurityException>()),
      );
      repo.dispose();
    });

    test('Initial installed state has zero extensions', () async {
      final repository = KeiyoushiRepository();
      final installed = await repository.getInstalledExtensions();
      expect(installed, isEmpty);
      repository.dispose();
    });

    test('Validates pinned Keiyoushi signing certificate fingerprint', () {
      const trustedFingerprint =
          '9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2';
      expect(
        KeiyoushiRepository.isTrustedCertificate(trustedFingerprint),
        isTrue,
      );
      expect(
        KeiyoushiRepository.isTrustedCertificate('untrusted_cert_hash_1234567890'),
        isFalse,
      );
    });

    test('Native installer boundary: fails does NOT mark installed, success marks installed', () async {
      final repository = KeiyoushiRepository();
      const testExt = KeiyoushiExtension(
        name: 'MangaDex',
        packageName: 'eu.kanade.tachiyomi.extension.all.mangadex',
        versionName: '1.6.1',
        versionCode: '205',
        extensionLib: '1.6',
        apkUrl: 'https://github.com/keiyoushi/extensions/releases/download/fc7a827-0/tachiyomi-all.mangadex-v1.6.1.apk',
        iconUrl: 'https://example.com/icon.png',
        contentWarning: ContentWarning.safe,
        sources: [],
      );

      // 1. When native install fails, state remains not installed
      final failedResult = await repository.installWithNativeInstaller(
        testExt,
        nativeInstaller: (apkUrl) async => false,
      );
      expect(failedResult, isFalse);
      expect(await repository.isInstalled(testExt.packageName), isFalse);
      expect(await repository.getInstalledExtensions(), isEmpty);

      // 2. When native installer throws, state remains not installed
      expect(
        () => repository.installWithNativeInstaller(
          testExt,
          nativeInstaller: (apkUrl) async => throw Exception('APK Verification failed'),
        ),
        throwsA(isA<Exception>()),
      );
      expect(await repository.isInstalled(testExt.packageName), isFalse);

      // 3. When native installer succeeds, it is marked installed
      final successResult = await repository.installWithNativeInstaller(
        testExt,
        nativeInstaller: (apkUrl) async => true,
      );
      expect(successResult, isTrue);
      expect(await repository.isInstalled(testExt.packageName), isTrue);
      expect((await repository.getInstalledExtensions()).length, equals(1));

      // 4. Rehydrate from native state using real DTOs
      await repository.rehydrateFromNativePackages([
        const NativePackageDto(
          packageName: 'different.package',
          versionCode: '12',
          versionName: '1.2.0',
          extensionLib: '1.6',
          sources: [],
        ),
      ]);
      expect(await repository.isInstalled(testExt.packageName), isFalse);
      expect(await repository.isInstalled('different.package'), isTrue);

      repository.dispose();
    });

    test('ExtensionInstallerBackend integration: propagates failure details and handles rehydration', () async {
      final backend = MemoryExtensionInstallerBackend();
      final repository = KeiyoushiRepository(installerBackend: backend);
      const testExt = KeiyoushiExtension(
        name: 'MangaDex',
        packageName: 'eu.kanade.tachiyomi.extension.all.mangadex',
        versionName: '1.6.1',
        versionCode: '205',
        extensionLib: '1.6',
        apkUrl: 'https://github.com/keiyoushi/extensions/releases/download/fc7a827-0/tachiyomi-all.mangadex-v1.6.1.apk',
        iconUrl: 'https://example.com/icon.png',
        contentWarning: ContentWarning.safe,
        sources: [],
      );

      // 1. When native install fails with detailed error, exception is NOT swallowed
      backend.shouldThrow = true;
      backend.errorMessage = 'Signature validation failed: untrusted cert';
      expect(
        () => repository.installExtension(testExt),
        throwsA(predicate((e) => e is Exception && e.toString().contains('Signature validation failed'))),
      );
      expect(await repository.isInstalled(testExt.packageName), isFalse);

      // 2. When native install succeeds, marked installed
      backend.shouldThrow = false;
      await repository.installExtension(testExt);
      expect(await repository.isInstalled(testExt.packageName), isTrue);

      // 3. Uninstall cleans both store and backend
      await repository.uninstallExtension(testExt.packageName);
      expect(await repository.isInstalled(testExt.packageName), isFalse);

      // 4. Rehydrate from backend
      backend.installedPackages.add(
        const NativePackageDto(
          packageName: 'eu.kanade.tachiyomi.extension.ru.remanga',
          versionCode: '45',
          versionName: '1.6.45',
          extensionLib: '1.6',
          sources: [
            KeiyoushiSource(
              id: '6738291048291039485',
              name: 'ReManga',
              language: 'ru',
              homeUrl: 'https://remanga.org',
            ),
          ],
        ),
      );
      await repository.rehydrateFromNative();
      expect(await repository.isInstalled('eu.kanade.tachiyomi.extension.ru.remanga'), isTrue);

      final installedList = await repository.getInstalledExtensions();
      final remanga = installedList.firstWhere((e) => e.packageName == 'eu.kanade.tachiyomi.extension.ru.remanga');
      expect(remanga.versionCode, equals('45'));
      expect(remanga.versionName, equals('1.6.45'));
      expect(remanga.sources.length, equals(1));
      expect(remanga.sources.first.id, equals('6738291048291039485'));
      expect(remanga.apkUrl, isEmpty); // Must NOT fabricate fake v1 URL!

      repository.dispose();
    });

    group('NativePackageDto Fail-Closed & Strict Validation', () {
      test('toExtension fails closed: empty native sources never takes sources from catalog knownExtension', () {
        const catalogExt = KeiyoushiExtension(
          name: 'Catalog Ext',
          packageName: 'com.example.ext',
          versionName: '1.0.0',
          versionCode: '100',
          extensionLib: '1.6',
          apkUrl: 'https://github.com/keiyoushi/extensions/releases/download/fc7a827-0/app.apk',
          iconUrl: 'https://example.com/icon.png',
          contentWarning: ContentWarning.safe,
          sources: [
            KeiyoushiSource(
              id: '999999999999999999',
              name: 'Catalog Source',
              language: 'ru',
              homeUrl: 'https://catalog.source',
            ),
          ],
        );

        // Native runtime reported package with EMPTY loaded sources
        const nativeDto = NativePackageDto(
          packageName: 'com.example.ext',
          versionCode: '100',
          versionName: '1.0.0',
          extensionLib: '1.6',
          sources: [], // No active sources loaded on Android
        );

        final mergedExt = nativeDto.toExtension(knownExtension: catalogExt);

        // MUST FAIL CLOSED: do not fabricate active sources from catalog metadata
        expect(mergedExt.sources, isEmpty);
        expect(mergedExt.packageName, equals('com.example.ext'));
        expect(mergedExt.apkUrl, equals(catalogExt.apkUrl));
      });

      test('fromJson throws FormatException on missing or empty packageName', () {
        expect(
          () => NativePackageDto.fromJson({
            'versionCode': '10',
            'extensionLib': '1.6',
            'sources': [],
          }),
          throwsA(isA<FormatException>()),
        );

        expect(
          () => NativePackageDto.fromJson({
            'packageName': '   ',
            'versionCode': '10',
            'extensionLib': '1.6',
            'sources': [],
          }),
          throwsA(isA<FormatException>()),
        );
      });

      test('fromJson throws FormatException on missing or empty versionCode', () {
        expect(
          () => NativePackageDto.fromJson({
            'packageName': 'com.example.ext',
            'extensionLib': '1.6',
            'sources': [],
          }),
          throwsA(isA<FormatException>()),
        );

        expect(
          () => NativePackageDto.fromJson({
            'packageName': 'com.example.ext',
            'versionCode': '',
            'extensionLib': '1.6',
            'sources': [],
          }),
          throwsA(isA<FormatException>()),
        );
      });

      test('fromJson throws FormatException on missing or empty extensionLib', () {
        expect(
          () => NativePackageDto.fromJson({
            'packageName': 'com.example.ext',
            'versionCode': '10',
            'sources': [],
          }),
          throwsA(isA<FormatException>()),
        );

        expect(
          () => NativePackageDto.fromJson({
            'packageName': 'com.example.ext',
            'versionCode': '10',
            'extensionLib': '  ',
            'sources': [],
          }),
          throwsA(isA<FormatException>()),
        );
      });

      test('fromJson throws FormatException on invalid source shape', () {
        expect(
          () => NativePackageDto.fromJson({
            'packageName': 'com.example.ext',
            'versionCode': '10',
            'extensionLib': '1.6',
            'sources': ['not a map'],
          }),
          throwsA(isA<FormatException>()),
        );
      });

      test('fromJson parses valid payload retaining decimal 64-bit source ID and exact lib version', () {
        final dto = NativePackageDto.fromJson({
          'packageName': 'com.example.ext',
          'versionCode': '42',
          'versionName': '1.2.3',
          'extensionLib': '1.6',
          'sources': [
            {
              'id': '8451503463765103131',
              'name': 'Test Source',
              'language': 'ru',
              'homeUrl': 'https://test.source',
            },
          ],
        });

        expect(dto.packageName, equals('com.example.ext'));
        expect(dto.versionCode, equals('42'));
        expect(dto.versionName, equals('1.2.3'));
        expect(dto.extensionLib, equals('1.6'));
        expect(dto.sources.length, equals(1));
        expect(dto.sources.first.id, equals('8451503463765103131'));
      });
    });

    group('APK URL validation & security checks', () {
      test('Accepts authentic GitHub release download APK URLs', () {
        const validUrl =
            'https://github.com/keiyoushi/extensions/releases/download/fc7a827-0/tachiyomi-all.mangadex-v1.6.1.apk';
        expect(KeiyoushiRepository.validateApkUrl(validUrl), equals(Uri.parse(validUrl)));
      });

      test('Rejects insecure HTTP scheme', () {
        const insecureHttp =
            'http://github.com/keiyoushi/extensions/releases/download/fc7a827-0/tachiyomi-all.mangadex-v1.6.1.apk';
        expect(
          () => KeiyoushiRepository.validateApkUrl(insecureHttp),
          throwsA(isA<SecurityException>()),
        );
      });

      test('Rejects non-443 port', () {
        const non443 =
            'https://github.com:8443/keiyoushi/extensions/releases/download/fc7a827-0/test.apk';
        expect(
          () => KeiyoushiRepository.validateApkUrl(non443),
          throwsA(isA<SecurityException>()),
        );
      });

      test('Rejects query parameters or URL fragments', () {
        const withQuery =
            'https://github.com/keiyoushi/extensions/releases/download/fc7a827-0/test.apk?token=xyz';
        const withFragment =
            'https://github.com/keiyoushi/extensions/releases/download/fc7a827-0/test.apk#payload';

        expect(
          () => KeiyoushiRepository.validateApkUrl(withQuery),
          throwsA(isA<SecurityException>()),
        );
        expect(
          () => KeiyoushiRepository.validateApkUrl(withFragment),
          throwsA(isA<SecurityException>()),
        );
      });

      test('Rejects encoded slashes, encoded backslashes, and raw backslashes', () {
        const encodedSlash =
            'https://github.com/keiyoushi/extensions/releases%2fdownload/fc7a827-0/test.apk';
        const encodedBackslash =
            'https://github.com/keiyoushi/extensions/releases%5cdownload/fc7a827-0/test.apk';
        const rawBackslash =
            'https://github.com/keiyoushi\\extensions/releases/download/fc7a827-0/test.apk';

        expect(
          () => KeiyoushiRepository.validateApkUrl(encodedSlash),
          throwsA(isA<SecurityException>()),
        );
        expect(
          () => KeiyoushiRepository.validateApkUrl(encodedBackslash),
          throwsA(isA<SecurityException>()),
        );
        expect(
          () => KeiyoushiRepository.validateApkUrl(rawBackslash),
          throwsA(isA<SecurityException>()),
        );
      });

      test('Rejects host suffix spoofing (e.g. github.com.attacker.com or attacker-github.com)', () {
        const spoofSuffix =
            'https://github.com.attacker.com/keiyoushi/extensions/releases/download/fc7a827-0/test.apk';
        const spoofPrefix =
            'https://attacker-github.com/keiyoushi/extensions/releases/download/fc7a827-0/test.apk';

        expect(
          () => KeiyoushiRepository.validateApkUrl(spoofSuffix),
          throwsA(isA<SecurityException>()),
        );
        expect(
          () => KeiyoushiRepository.validateApkUrl(spoofPrefix),
          throwsA(isA<SecurityException>()),
        );
      });

      test('Rejects untrusted repository owner or repository name', () {
        const wrongRepo =
            'https://github.com/evil-org/extensions/releases/download/fc7a827-0/test.apk';
        const wrongOrg =
            'https://github.com/keiyoushi/other-repo/releases/download/fc7a827-0/test.apk';

        expect(
          () => KeiyoushiRepository.validateApkUrl(wrongRepo),
          throwsA(isA<SecurityException>()),
        );
        expect(
          () => KeiyoushiRepository.validateApkUrl(wrongOrg),
          throwsA(isA<SecurityException>()),
        );
      });

      test('Rejects embedded credentials in URL', () {
        const withCreds =
            'https://admin:password@github.com/keiyoushi/extensions/releases/download/fc7a827-0/test.apk';
        expect(
          () => KeiyoushiRepository.validateApkUrl(withCreds),
          throwsA(isA<SecurityException>()),
        );
      });

      test('Rejects path traversal and URL-encoded traversal (%2e%2e)', () {
        const pathTraversal =
            'https://github.com/keiyoushi/extensions/releases/download/../secret.apk';
        const encodedTraversal =
            'https://github.com/keiyoushi/extensions/releases/download/%2e%2e/secret.apk';

        expect(
          () => KeiyoushiRepository.validateApkUrl(pathTraversal),
          throwsA(isA<SecurityException>()),
        );
        expect(
          () => KeiyoushiRepository.validateApkUrl(encodedTraversal),
          throwsA(isA<SecurityException>()),
        );
      });

      test('Rejects non-APK asset extensions or script schemes', () {
        const nonApk =
            'https://github.com/keiyoushi/extensions/releases/download/fc7a827-0/payload.dex';
        const scriptScheme =
            'javascript:alert("pwned")';

        expect(
          () => KeiyoushiRepository.validateApkUrl(nonApk),
          throwsA(isA<SecurityException>()),
        );
        expect(
          () => KeiyoushiRepository.validateApkUrl(scriptScheme),
          throwsA(isA<SecurityException>()),
        );
      });
    });
  });
}
