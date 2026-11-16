import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/catalog/models/manga.dart';
import 'package:manga_reader_app/features/catalog/screens/manga_detail_screen.dart';
import 'package:manga_reader_app/features/extensions/models/bridge_dtos.dart';
import 'package:manga_reader_app/features/extensions/models/keiyoushi_extension.dart';
import 'package:manga_reader_app/features/extensions/services/native_extensions_bridge.dart';
import 'package:manga_reader_app/features/library/state/library_provider.dart';
import 'package:manga_reader_app/features/sources/extension_manga_source.dart';
import 'package:manga_reader_app/features/sources/source_manager.dart';

class MockDetailBridge extends NativeExtensionsBridge {
  bool shouldThrow;
  List<ExtensionChapterItem> chapters;

  MockDetailBridge({this.shouldThrow = false, this.chapters = const []})
      : super.forTesting();

  @override
  Future<List<ExtensionChapterItem>> getChapters({
    required String sourceId,
    required String mangaUrl,
  }) async {
    if (shouldThrow) {
      throw Exception('Simulated native channel failure');
    }
    return chapters;
  }

  @override
  Future<ExtensionMangaDetails> getMangaDetails({
    required String sourceId,
    required String mangaUrl,
  }) async {
    return ExtensionMangaDetails(
      url: mangaUrl,
      title: 'Loaded title',
      description: 'Loaded description',
      genre: 'Action',
      status: '1',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SourceManager.resetForTesting();
  });

  group('MangaDetailScreen - Metadata Webtoon/Paged Reader Routing', () {
    test('isWebtoonManga correctly identifies manhwa and manhua as webtoons', () {
      const manhwa = Manga(
        id: '1',
        title: 'Solo Leveling',
        description: '',
        coverUrl: '',
        type: PublicationType.manhwa,
        contentRating: ContentRating.safe,
      );
      expect(MangaDetailScreen.isWebtoonManga(manhwa), isTrue);

      const manhua = Manga(
        id: '2',
        title: 'Martial Peak',
        description: '',
        coverUrl: '',
        type: PublicationType.manhua,
        contentRating: ContentRating.safe,
      );
      expect(MangaDetailScreen.isWebtoonManga(manhua), isTrue);

      const manga = Manga(
        id: '3',
        title: 'One Piece',
        description: '',
        coverUrl: '',
        type: PublicationType.manga,
        contentRating: ContentRating.safe,
      );
      expect(MangaDetailScreen.isWebtoonManga(manga), isFalse);
    });

    test('isWebtoonManga maps PublicationType.all using genres and title metadata', () {
      // 1. PublicationType.all with Webtoon genre -> true
      const webtoonGenreManga = Manga(
        id: '4',
        title: 'Tower of God',
        description: '',
        coverUrl: '',
        type: PublicationType.all,
        genres: ['Action', 'Fantasy', 'Webtoon'],
        contentRating: ContentRating.safe,
      );
      expect(MangaDetailScreen.isWebtoonManga(webtoonGenreManga), isTrue);

      // 2. PublicationType.all with Russian 'манхва' genre -> true
      const russianManhwa = Manga(
        id: '5',
        title: 'Unknown Title',
        description: '',
        coverUrl: '',
        type: PublicationType.all,
        genres: ['Манхва', 'Драма'],
        contentRating: ContentRating.safe,
      );
      expect(MangaDetailScreen.isWebtoonManga(russianManhwa), isTrue);

      // 3. PublicationType.all with title containing 'вебтун' -> true
      const titleWebtoon = Manga(
        id: '6',
        title: 'Крутой Вебтун: Начало',
        description: '',
        coverUrl: '',
        type: PublicationType.all,
        genres: ['Приключения'],
        contentRating: ContentRating.safe,
      );
      expect(MangaDetailScreen.isWebtoonManga(titleWebtoon), isTrue);

      // 4. PublicationType.all with purely Japanese manga genres -> false
      const standardManga = Manga(
        id: '7',
        title: 'Naruto',
        description: '',
        coverUrl: '',
        type: PublicationType.all,
        genres: ['Shounen', 'Ninja', 'Manga'],
        contentRating: ContentRating.safe,
      );
      expect(MangaDetailScreen.isWebtoonManga(standardManga), isFalse);
    });
  });

  group('MangaDetailScreen - Chapter Loading Error & Retry UI', () {
    testWidgets('Surfaces typed error on missing installed extension source and allows retry', (tester) async {
      final library = LibraryProvider();

      // Ensure test source is NOT in SourceManager
      const missingSourceId = '8451503463765103131'; // Decimal 64-bit Keiyoushi source ID
      SourceManager.resetForTesting();

      const manga = Manga(
        id: 'test_manga_1',
        title: 'Uninstalled Extension Title',
        description: 'Test description',
        coverUrl: '',
        type: PublicationType.manga,
        contentRating: ContentRating.safe,
        sourceId: missingSourceId,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<LibraryProvider>.value(
            value: library,
            child: const MangaDetailScreen(manga: manga),
          ),
        ),
      );

      // Settle async operations in initState (_loadChapters)
      await tester.pumpAndSettle();

      // Scroll CustomScrollView down so offscreen lazy chapters sliver builds into view
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // 1. Loading indicator is gone
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // 2. Shows typed error message for missing installed extension
      expect(find.textContaining('Установленное расширение источника недоступно'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // 3. Must NOT show silent empty state 'Для этого произведения пока нет доступных глав.'
      expect(find.text('Для этого произведения пока нет доступных глав.'), findsNothing);

      // 4. Shows retry button
      expect(find.text('Повторить попытку'), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('Catches native/network exceptions, shows error message, and recovers on retry', (tester) async {
      final library = LibraryProvider();
      const sourceId = 'source_with_flaky_connection';
      final mockBridge = MockDetailBridge(shouldThrow: true);
      final flakySource = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: sourceId,
          name: 'Flaky Source',
          language: 'ru',
          homeUrl: 'https://flaky.test',
        ),
        packageName: 'tachiyomi.flaky',
        bridge: mockBridge,
      );
      SourceManager.setMockSources([flakySource]);

      const manga = Manga(
        id: 'test_manga_flaky',
        title: 'Flaky Connection Manga',
        description: 'Test description',
        coverUrl: '',
        type: PublicationType.manhwa,
        contentRating: ContentRating.safe,
        sourceId: sourceId,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<LibraryProvider>.value(
            value: library,
            child: const MangaDetailScreen(manga: manga),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll CustomScrollView down so offscreen lazy chapters sliver builds into view
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // 1. Loading state reset in finally, error rendered
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Ошибка при загрузке глав'), findsOneWidget);
      expect(find.textContaining('Simulated native channel failure'), findsOneWidget);
      expect(find.text('Повторить попытку'), findsOneWidget);

      // 2. Now simulate network restored
      mockBridge.shouldThrow = false;
      mockBridge.chapters = const [
        ExtensionChapterItem(
          url: '/ch/1',
          name: 'Глава 1: Пробуждение',
          chapterNumber: '1',
          dateUpload: '1709424000000',
          scanlator: 'Команда перевода',
        ),
      ];

      // Tap retry
      await tester.tap(find.text('Повторить попытку'));
      await tester.pumpAndSettle();

      // Scroll down to build the chapter list item if needed
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // 3. Error gone, chapter now visible
      expect(find.textContaining('Ошибка при загрузке глав'), findsNothing);
      expect(find.textContaining('Глава 1: Пробуждение'), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
