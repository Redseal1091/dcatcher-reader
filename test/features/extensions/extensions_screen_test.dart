import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/extensions/models/keiyoushi_extension.dart';
import 'package:manga_reader_app/features/extensions/screens/extensions_screen.dart';
import 'package:manga_reader_app/features/extensions/services/keiyoushi_repository.dart';
import 'package:manga_reader_app/features/extensions/services/native_extensions_bridge.dart';
import 'package:manga_reader_app/features/sources/source_manager.dart';

class MockFailingRepoBridge extends NativeExtensionsBridge {
  final List<NativePackageDto> nativePackages;
  int listInstalledCalls = 0;
  int installCalls = 0;

  MockFailingRepoBridge({this.nativePackages = const []}) : super.forTesting();

  @override
  Future<List<NativePackageDto>> listInstalled() async {
    listInstalledCalls++;
    return nativePackages;
  }

  @override
  Future<bool> install({
    required String packageName,
    required String apkUrl,
    required String versionCode,
    required bool trustConfirmed,
  }) async {
    installCalls++;
    return true;
  }
}

class MockFailingStoreRepository extends KeiyoushiRepository {
  final bool failFetch;
  final List<KeiyoushiExtension> extensionsToReturn;

  MockFailingStoreRepository({
    this.failFetch = false,
    this.extensionsToReturn = const [],
  }) : super(installedStore: MemoryInstalledExtensionsStore());

  @override
  Future<List<KeiyoushiExtension>> fetchExtensions({String? repoUrl}) async {
    if (failFetch) {
      throw Exception('Store network unreachable (Offline)');
    }
    return extensionsToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SourceManager.resetForTesting();
  });

  const sampleNativePkg = NativePackageDto(
    packageName: 'eu.kanade.tachiyomi.extension.ru.mangadex',
    versionCode: '205',
    versionName: '1.6.1',
    extensionLib: '1.6',
    sources: [
      KeiyoushiSource(
        id: '2499283573021234567',
        name: 'MangaDex RU',
        language: 'ru',
        homeUrl: 'https://mangadex.org',
      ),
    ],
  );

  group('ExtensionsScreen & Startup Rehydration Tests', () {
    test('SourceManager.initialize() rehydrates native installed packages on startup', () async {
      final mockBridge = MockFailingRepoBridge(nativePackages: [sampleNativePkg]);
      final repo = MockFailingStoreRepository();

      await SourceManager.initialize(repository: repo, bridge: mockBridge);

      expect(SourceManager.isInitialized, isTrue);
      expect(SourceManager.hasSources, isTrue);
      expect(SourceManager.sources.length, equals(1));
      expect(SourceManager.sources.first.id, equals('2499283573021234567'));
      expect(SourceManager.sources.first.name, equals('MangaDex RU'));
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('ExtensionsScreen displays native installed extensions even when store fetch fails (offline)', (tester) async {
      final mockBridge = MockFailingRepoBridge(nativePackages: [sampleNativePkg]);
      final repo = MockFailingStoreRepository(failFetch: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ExtensionsScreen(
            repository: repo,
            bridge: mockBridge,
          ),
        ),
      );

      // Settle async operations in initState (_loadData)
      await tester.pumpAndSettle();

      // Native package must be displayed in the list
      expect(find.text('eu.kanade.tachiyomi.extension.ru.mangadex'), findsOneWidget);
      expect(find.text('MangaDex RU · RU'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget); // delete icon means installed
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
