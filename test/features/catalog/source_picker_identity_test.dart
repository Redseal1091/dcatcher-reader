import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/core/theme/theme_provider.dart';
import 'package:manga_reader_app/features/catalog/screens/catalog_screen.dart';
import 'package:manga_reader_app/features/catalog/state/catalog_provider.dart';
import 'package:manga_reader_app/features/extensions/models/keiyoushi_extension.dart';
import 'package:manga_reader_app/features/extensions/services/native_extensions_bridge.dart';
import 'package:manga_reader_app/features/library/state/library_provider.dart';
import 'package:manga_reader_app/features/sources/extension_manga_source.dart';
import 'package:manga_reader_app/features/sources/source_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String mockChannelName = 'dev.dcatcher/extensions';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SourceManager.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(mockChannelName), null);
    SourceManager.resetForTesting();
  });

  Widget createTestWidget({
    required CatalogProvider catalogProvider,
    required LibraryProvider libraryProvider,
    required AppSettingsProvider settingsProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CatalogProvider>.value(value: catalogProvider),
        ChangeNotifierProvider<LibraryProvider>.value(value: libraryProvider),
        ChangeNotifierProvider<AppSettingsProvider>.value(value: settingsProvider),
      ],
      child: const MaterialApp(
        home: CatalogScreen(),
      ),
    );
  }

  void setupMockBridgeChannel() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(mockChannelName), (MethodCall call) async {
      if (call.method == 'getCatalog') {
        return {
          'hasNextPage': false,
          'items': <Map<String, dynamic>>[],
        };
      }
      if (call.method == 'getSourceAccessInfo') {
        return {
          'hasCloudflare': false,
          'requiresLogin': false,
        };
      }
      return null;
    });
  }

  testWidgets(
    'CatalogScreen source picker displays distinct language tags for same-named sources without 360px overflow and retains other sources',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      setupMockBridgeChannel();
      final bridge = NativeExtensionsBridge.forTesting();

      final mangaPlusEn = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: 'mangaplus_en_101',
          name: 'MANGA Plus by SHUEISHA',
          language: 'en',
          homeUrl: 'https://mangaplus.shueisha.co.jp',
        ),
        packageName: 'eu.kanade.tachiyomi.extension.all.mangaplus',
        bridge: bridge,
      );

      final mangaPlusEs = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: 'mangaplus_es_102',
          name: 'MANGA Plus by SHUEISHA',
          language: 'es',
          homeUrl: 'https://mangaplus.shueisha.co.jp',
        ),
        packageName: 'eu.kanade.tachiyomi.extension.all.mangaplus',
        bridge: bridge,
      );

      final mangaPlusRu = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: 'mangaplus_ru_103',
          name: 'MANGA Plus by SHUEISHA',
          language: 'ru',
          homeUrl: 'https://mangaplus.shueisha.co.jp',
        ),
        packageName: 'eu.kanade.tachiyomi.extension.all.mangaplus',
        bridge: bridge,
      );

      final mangaBuff = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: 'mangabuff_ru_201',
          name: 'MangaBuff',
          language: 'ru',
          homeUrl: 'https://mangabuff.ru',
        ),
        packageName: 'eu.kanade.tachiyomi.extension.ru.mangabuff',
        bridge: bridge,
      );

      SourceManager.setMockSources([mangaPlusEn, mangaPlusEs, mangaPlusRu, mangaBuff]);
      SourceManager.setCurrentSource(mangaPlusEn.id);

      final catalogProvider = CatalogProvider();
      final libraryProvider = LibraryProvider();
      final settingsProvider = AppSettingsProvider();

      await tester.pumpWidget(createTestWidget(
        catalogProvider: catalogProvider,
        libraryProvider: libraryProvider,
        settingsProvider: settingsProvider,
      ));
      await tester.pumpAndSettle();

      final sourcePickerFinder = find.byTooltip('Сменить источник каталога');
      expect(sourcePickerFinder, findsOneWidget);

      await tester.tap(sourcePickerFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify MangaBuff is retained
      expect(find.textContaining('MangaBuff'), findsOneWidget);

      // Distinct language tags must be uniquely included in labels for EN/ES/RU MANGA Plus sources
      expect(find.textContaining('EN'), findsWidgets);
      expect(find.textContaining('ES'), findsWidgets);
      expect(find.textContaining('RU'), findsWidgets);
    },
  );

  testWidgets(
    'Selecting ES source from popup menu persists source ID (not ambiguous name) across AppSettingsProvider and CatalogScreen reloads',
    (WidgetTester tester) async {
      setupMockBridgeChannel();
      final bridge = NativeExtensionsBridge.forTesting();

      final mangaPlusEn = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: 'mangaplus_en_101',
          name: 'MANGA Plus by SHUEISHA',
          language: 'en',
          homeUrl: 'https://mangaplus.shueisha.co.jp',
        ),
        packageName: 'eu.kanade.tachiyomi.extension.all.mangaplus',
        bridge: bridge,
      );

      final mangaPlusEs = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: 'mangaplus_es_102',
          name: 'MANGA Plus by SHUEISHA',
          language: 'es',
          homeUrl: 'https://mangaplus.shueisha.co.jp',
        ),
        packageName: 'eu.kanade.tachiyomi.extension.all.mangaplus',
        bridge: bridge,
      );

      final mangaPlusRu = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: 'mangaplus_ru_103',
          name: 'MANGA Plus by SHUEISHA',
          language: 'ru',
          homeUrl: 'https://mangaplus.shueisha.co.jp',
        ),
        packageName: 'eu.kanade.tachiyomi.extension.all.mangaplus',
        bridge: bridge,
      );

      final mangaBuff = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: 'mangabuff_ru_201',
          name: 'MangaBuff',
          language: 'ru',
          homeUrl: 'https://mangabuff.ru',
        ),
        packageName: 'eu.kanade.tachiyomi.extension.ru.mangabuff',
        bridge: bridge,
      );

      SourceManager.setMockSources([mangaPlusEn, mangaPlusEs, mangaPlusRu, mangaBuff]);
      SourceManager.setCurrentSource(mangaPlusEn.id);

      final catalogProvider = CatalogProvider();
      final libraryProvider = LibraryProvider();
      final settingsProvider = AppSettingsProvider();

      await tester.pumpWidget(createTestWidget(
        catalogProvider: catalogProvider,
        libraryProvider: libraryProvider,
        settingsProvider: settingsProvider,
      ));
      await tester.pumpAndSettle();

      final sourcePickerFinder = find.byTooltip('Сменить источник каталога');
      await tester.tap(sourcePickerFinder);
      await tester.pumpAndSettle();

      // Tap the Spanish (ES) source entry
      final esMenuItem = find.textContaining('ES');
      expect(esMenuItem, findsOneWidget);
      await tester.tap(esMenuItem);
      await tester.pumpAndSettle();

      // Active catalog source must have id 'mangaplus_es_102', not English fallback or ambiguous name
      expect(catalogProvider.source?.id, equals('mangaplus_es_102'));
      expect(settingsProvider.manhwaSource, equals('mangaplus_es_102'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('source_manhwa'), equals('mangaplus_es_102'));

      // Unmount the current widget tree
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      // Reset SourceManager preserving SharedPreferences (do NOT call setMockInitialValues again)
      SourceManager.resetForTesting();

      // Rebuild real installed sources using updateFromExtensions with KeiyoushiExtension fixtures from existing sources
      final extensionFixtures = [
        KeiyoushiExtension(
          name: mangaPlusEn.source.name,
          packageName: mangaPlusEn.packageName,
          versionName: '1.0.0',
          versionCode: '1',
          extensionLib: '1.4',
          apkUrl: 'https://example.com/mangaplus.apk',
          iconUrl: '',
          contentWarning: ContentWarning.safe,
          sources: [mangaPlusEn.source, mangaPlusEs.source, mangaPlusRu.source],
        ),
        KeiyoushiExtension(
          name: mangaBuff.source.name,
          packageName: mangaBuff.packageName,
          versionName: '1.0.0',
          versionCode: '1',
          extensionLib: '1.4',
          apkUrl: 'https://example.com/mangabuff.apk',
          iconUrl: '',
          contentWarning: ContentWarning.safe,
          sources: [mangaBuff.source],
        ),
      ];
      await SourceManager.updateFromExtensions(extensionFixtures, bridge: bridge);

      // Create new providers and mount fresh CatalogScreen
      final freshLibraryProvider = LibraryProvider();
      final freshSettingsProvider = AppSettingsProvider();
      await tester.pumpAndSettle();
      final freshCatalogProvider = CatalogProvider();

      await tester.pumpWidget(createTestWidget(
        catalogProvider: freshCatalogProvider,
        libraryProvider: freshLibraryProvider,
        settingsProvider: freshSettingsProvider,
      ));
      await tester.pumpAndSettle();

      // Assert sourceIDES, settingsES, prefsES unchanged
      expect(SourceManager.currentSource?.id, equals('mangaplus_es_102'));
      expect(freshCatalogProvider.source?.id, equals('mangaplus_es_102'));
      expect(freshSettingsProvider.manhwaSource, equals('mangaplus_es_102'));
      expect(prefs.getString('source_manhwa'), equals('mangaplus_es_102'));
    },
  );

  test(
    'SourceManager.updateFromExtensions deduplicates records with same ID, keeps distinct language IDs, and supports legacy name lookup',
    () async {
      setupMockBridgeChannel();
      final bridge = NativeExtensionsBridge.forTesting();

      const ext1 = KeiyoushiExtension(
        name: 'MANGA Plus',
        packageName: 'eu.kanade.tachiyomi.extension.all.mangaplus',
        versionName: '1.4.0',
        versionCode: '1',
        extensionLib: '',
        apkUrl: '',
        iconUrl: '',
        contentWarning: ContentWarning.safe,
        sources: [
          KeiyoushiSource(
            id: 'mangaplus_en_101',
            name: 'MANGA Plus by SHUEISHA',
            language: 'en',
            homeUrl: 'https://mangaplus.shueisha.co.jp',
          ),
          KeiyoushiSource(
            id: 'mangaplus_es_102',
            name: 'MANGA Plus by SHUEISHA',
            language: 'es',
            homeUrl: 'https://mangaplus.shueisha.co.jp',
          ),
          KeiyoushiSource(
            id: 'mangaplus_ru_103',
            name: 'MANGA Plus by SHUEISHA',
            language: 'ru',
            homeUrl: 'https://mangaplus.shueisha.co.jp',
          ),
        ],
      );

      // ext2 has duplicate source ID 'mangaplus_en_101'
      const ext2 = KeiyoushiExtension(
        name: 'MANGA Plus Duplicate',
        packageName: 'eu.kanade.tachiyomi.extension.all.mangaplus.dup',
        versionName: '1.4.0',
        versionCode: '2',
        extensionLib: '',
        apkUrl: '',
        iconUrl: '',
        contentWarning: ContentWarning.safe,
        sources: [
          KeiyoushiSource(
            id: 'mangaplus_en_101',
            name: 'MANGA Plus by SHUEISHA',
            language: 'en',
            homeUrl: 'https://mangaplus.shueisha.co.jp',
          ),
        ],
      );

      const extMangaBuff = KeiyoushiExtension(
        name: 'MangaBuff',
        packageName: 'eu.kanade.tachiyomi.extension.ru.mangabuff',
        versionName: '1.0.0',
        versionCode: '1',
        extensionLib: '',
        apkUrl: '',
        iconUrl: '',
        contentWarning: ContentWarning.safe,
        sources: [
          KeiyoushiSource(
            id: 'mangabuff_ru_201',
            name: 'MangaBuff',
            language: 'ru',
            homeUrl: 'https://mangabuff.ru',
          ),
        ],
      );

      await SourceManager.updateFromExtensions([ext1, ext2, extMangaBuff], bridge: bridge);

      // Duplicates with same ID must be deduped (ext2's mangaplus_en_101 deduplicated)
      // Total distinct sources: 3 MANGA Plus (en, es, ru) + 1 MangaBuff = 4
      expect(SourceManager.sources.length, equals(4));

      final ids = SourceManager.sources.map((s) => s.id).toList();
      expect(ids, containsAll(['mangaplus_en_101', 'mangaplus_es_102', 'mangaplus_ru_103', 'mangabuff_ru_201']));

      // Legacy name preferences must still lookup correctly
      final legacyLookup = SourceManager.getSourceById('MangaBuff');
      expect(legacyLookup, isNotNull);
      expect(legacyLookup?.id, equals('mangabuff_ru_201'));
    },
  );
}
