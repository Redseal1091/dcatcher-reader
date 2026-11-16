import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/core/theme/theme_provider.dart';
import 'package:manga_reader_app/features/catalog/models/manga.dart';
import 'package:manga_reader_app/features/catalog/screens/manga_detail_screen.dart';
import 'package:manga_reader_app/features/extensions/models/bridge_dtos.dart';
import 'package:manga_reader_app/features/extensions/models/keiyoushi_extension.dart';
import 'package:manga_reader_app/features/extensions/services/native_extensions_bridge.dart';
import 'package:manga_reader_app/features/library/state/library_provider.dart';
import 'package:manga_reader_app/features/reader/screens/webtoon_reader_screen.dart';
import 'package:manga_reader_app/features/reader/services/reader_mode.dart';
import 'package:manga_reader_app/features/sources/extension_manga_source.dart';
import 'package:manga_reader_app/features/sources/source_manager.dart';

class MockIntegrationBridge extends NativeExtensionsBridge {
  final List<ExtensionChapterItem> chapters;

  MockIntegrationBridge({this.chapters = const []}) : super.forTesting();

  @override
  Future<List<ExtensionChapterItem>> getChapters({
    required String sourceId,
    required String mangaUrl,
  }) async {
    return chapters;
  }

  @override
  Future<ExtensionMangaDetails> getMangaDetails({
    required String sourceId,
    required String mangaUrl,
  }) async {
    return ExtensionMangaDetails(
      url: mangaUrl,
      title: 'Solo Leveling Details',
      description: 'Detail description',
      genre: 'Action, Fantasy',
      status: '1',
    );
  }

  @override
  Future<List<String>> getChapterPages({
    required String sourceId,
    required String chapterUrl,
  }) async {
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'reader_mode_pref_mock_ext_source_solo-leveling': 'webtoon',
    });
    SourceManager.resetForTesting();
  });

  testWidgets(
      'MangaDetailScreen action "Читать с начала" invokes WebtoonReaderScreen with chapter 1 when source bridge returns descending chapters',
      (WidgetTester tester) async {
    const sourceId = 'mock_ext_source';
    const mangaId = 'solo-leveling';

    final mockBridge = MockIntegrationBridge(
      chapters: const [
        ExtensionChapterItem(
          url: '/manga/solo/ch187',
          name: 'Chapter 187',
          chapterNumber: '187',
          dateUpload: '1700000000000',
          scanlator: 'Scan Group',
        ),
        ExtensionChapterItem(
          url: '/manga/solo/ch1',
          name: 'Chapter 1',
          chapterNumber: '1',
          dateUpload: '1600000000000',
          scanlator: 'Scan Group',
        ),
      ],
    );

    final extensionSource = ExtensionMangaSource(
      source: const KeiyoushiSource(
        id: sourceId,
        name: 'Mock Extension Source',
        language: 'ru',
        homeUrl: 'https://mock.test',
      ),
      packageName: 'tachiyomi.mock',
      bridge: mockBridge,
    );
    SourceManager.setMockSources([extensionSource]);

    await ReaderModeResolver.savePreference(
      mangaId: mangaId,
      sourceId: sourceId,
      mode: ReaderMode.webtoon,
    );

    final library = LibraryProvider();
    final themeProvider = AppSettingsProvider();

    const manga = Manga(
      id: mangaId,
      title: 'Solo Leveling',
      description: 'Hunter Sung Jinwoo story',
      coverUrl: '',
      type: PublicationType.manhwa,
      contentRating: ContentRating.safe,
      sourceId: sourceId,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettingsProvider>.value(
            value: themeProvider,
          ),
          ChangeNotifierProvider<LibraryProvider>.value(
            value: library,
          ),
        ],
        child: const MaterialApp(
          home: MangaDetailScreen(manga: manga),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final readFromBeginningFinder = find.byTooltip('Читать с начала');
    expect(readFromBeginningFinder, findsOneWidget);

    await tester.tap(readFromBeginningFinder);
    await tester.pumpAndSettle();

    final webtoonScreenFinder = find.byType(WebtoonReaderScreen);
    expect(webtoonScreenFinder, findsOneWidget);

    final webtoonScreenWidget =
        tester.widget<WebtoonReaderScreen>(webtoonScreenFinder);
    expect(webtoonScreenWidget.chapter.chapterNumber, equals('1'));
  });
}
