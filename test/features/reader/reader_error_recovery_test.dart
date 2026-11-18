import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/catalog/models/catalog_filters.dart';
import 'package:manga_reader_app/features/catalog/models/manga.dart';
import 'package:manga_reader_app/features/extensions/services/source_access_bridge.dart';
import 'package:manga_reader_app/features/library/state/library_provider.dart';
import 'package:manga_reader_app/features/reader/models/chapter.dart';
import 'package:manga_reader_app/features/reader/screens/paged_reader_screen.dart';
import 'package:manga_reader_app/features/reader/screens/webtoon_reader_screen.dart';
import 'package:manga_reader_app/features/reader/widgets/reader_error_view.dart';
import 'package:manga_reader_app/features/sources/manga_source.dart';
import 'package:manga_reader_app/features/sources/source_manager.dart';

class FakeTestMangaSource extends MangaSource {
  @override
  final String id;
  @override
  final String name;

  Future<List<String>> Function(String chapterId)? getChapterPagesHandler;

  FakeTestMangaSource({
    this.id = 'test_source',
    this.name = 'Test Source',
    this.getChapterPagesHandler,
  });

  @override
  Future<List<Manga>> getCatalog({required CatalogFilters filters, int offset = 0, int limit = 20}) async => [];

  @override
  Future<List<Chapter>> getChapters(String mangaId) async => [];

  @override
  Future<List<String>> getChapterPages(String chapterId) async {
    if (getChapterPagesHandler != null) {
      return await getChapterPagesHandler!(chapterId);
    }
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testManga = Manga(
    id: 'manga_1',
    title: 'One Piece Test',
    description: 'Test Description',
    coverUrl: 'http://example.com/cover.jpg',
    type: PublicationType.manga,
    contentRating: ContentRating.safe,
    genres: ['Action', 'Adventure'],
    status: 'ongoing',
    sourceId: 'test_source',
  );

  final testChapter = Chapter(
    id: 'ch_1',
    mangaId: 'manga_1',
    chapterNumber: '1',
    title: 'Romance Dawn',
    publishedAt: DateTime(2024, 1, 1),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SourceManager.resetForTesting();
  });

  Widget buildTestWidget(Widget child) {
    return ChangeNotifierProvider<LibraryProvider>(
      create: (_) => LibraryProvider(),
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('PagedReaderScreen Error & Recovery Tests', () {
    testWidgets('PagedReaderScreen displays error message and retry button on exception, and recovers on retry', (tester) async {
      int fetchAttempts = 0;
      final source = FakeTestMangaSource(
        id: 'test_source',
        getChapterPagesHandler: (chId) async {
          fetchAttempts++;
          if (fetchAttempts == 1) {
            throw Exception('PAGES_ERROR: Network connection failed');
          }
          return ['http://example.com/page1.jpg', 'http://example.com/page2.jpg'];
        },
      );

      await tester.pumpWidget(
        buildTestWidget(
          PagedReaderScreen(
            manga: testManga,
            chapter: testChapter,
            source: source,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Verify no infinite spinner
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Verify error message and retry button visible
      expect(find.textContaining('Ошибка загрузки страниц'), findsOneWidget);
      expect(find.text('Повторить попытку'), findsOneWidget);

      // Tap retry button
      await tester.tap(find.text('Повторить попытку'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify successful recovery: error gone, page counter visible
      expect(find.textContaining('Ошибка загрузки страниц'), findsNothing);
      expect(find.text('Страница 1 из 2'), findsOneWidget);
      expect(fetchAttempts, 2);
    });

    testWidgets('PagedReaderScreen displays clean message on empty pages, avoiding "Страница 1 из 0"', (tester) async {
      final source = FakeTestMangaSource(
        id: 'test_source',
        getChapterPagesHandler: (chId) async => [],
      );

      await tester.pumpWidget(
        buildTestWidget(
          PagedReaderScreen(
            manga: testManga,
            chapter: testChapter,
            source: source,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Verify no infinite spinner
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Verify "Страницы не найдены" view and NO "Страница 1 из 0"
      expect(find.text('Страницы не найдены'), findsOneWidget);
      expect(find.text('Страница 1 из 0'), findsNothing);
      expect(find.text('Повторить попытку'), findsOneWidget);
    });

    testWidgets('PagedReaderScreen handles missing source gracefully with error and retry', (tester) async {
      // SourceManager has NO sources loaded, and no source passed
      await tester.pumpWidget(
        buildTestWidget(
          PagedReaderScreen(
            manga: testManga,
            chapter: testChapter,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('не найден'), findsOneWidget);
      expect(find.text('Повторить попытку'), findsOneWidget);
    });
  });

  group('WebtoonReaderScreen Error & Recovery Tests', () {
    testWidgets('WebtoonReaderScreen displays error message and retry button on exception, and recovers on retry', (tester) async {
      int fetchAttempts = 0;
      final source = FakeTestMangaSource(
        id: 'test_source',
        getChapterPagesHandler: (chId) async {
          fetchAttempts++;
          if (fetchAttempts == 1) {
            throw Exception('PAGES_ERROR: Bridge timeout');
          }
          return ['http://example.com/wpage1.jpg'];
        },
      );

      await tester.pumpWidget(
        buildTestWidget(
          WebtoonReaderScreen(
            manga: testManga,
            chapter: testChapter,
            source: source,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Verify no infinite spinner
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Verify error message and retry button
      expect(find.textContaining('Ошибка загрузки страниц'), findsOneWidget);
      expect(find.text('Повторить попытку'), findsOneWidget);

      // Tap retry button
      await tester.tap(find.text('Повторить попытку'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Recovered successfully
      expect(find.textContaining('Ошибка загрузки страниц'), findsNothing);
      expect(find.textContaining('1 стр.'), findsOneWidget);
      expect(fetchAttempts, 2);
    });
  });

  group('ReaderErrorView Auth & 401/403 Recovery Tests', () {
    testWidgets('ReaderErrorView displays friendly auth UI and WebView button on 401, then retries on success', (tester) async {
      bool webViewOpened = false;
      bool retried = false;

      const testChannel = MethodChannel('dev.dcatcher/test_reader_auth');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        testChannel,
        (call) async {
          if (call.method == 'openSourceWebView') {
            webViewOpened = true;
            return true;
          }
          return null;
        },
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(testChannel, null);
      });

      final testBridge = SourceAccessBridge.forTesting(
        channel: testChannel,
        isSupported: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderErrorView(
              sourceId: '4008409601887986192',
              errorMessage: 'PlatformException(PAGES_ERROR, HTTP error 401, null, null)',
              isPagesEmpty: true,
              defaultMessage: 'Fallback',
              sourceAccessBridge: testBridge,
              onRetry: () => retried = true,
              onBack: () {},
            ),
          ),
        ),
      );

      expect(find.text('Требуется авторизация'), findsOneWidget);
      expect(find.textContaining('HTTP 401'), findsOneWidget);
      expect(find.text('Войти через WebView'), findsOneWidget);
      expect(find.text('Повторить попытку'), findsOneWidget);
      expect(find.textContaining('PlatformException'), findsNothing);

      await tester.tap(find.text('Войти через WebView'));
      await tester.pumpAndSettle();

      expect(webViewOpened, isTrue);
      expect(retried, isTrue);
    });

    test('ReaderErrorView formats raw PlatformException cleanly and classifies 403', () {
      expect(
        ReaderErrorView.formatRawErrorMessage(
          'PlatformException(PAGES_ERROR, Connection timed out, null, null)',
          'Fallback',
        ),
        'Connection timed out',
      );
      expect(
        ReaderErrorView.classifyError('HTTP error 403', isPagesEmpty: true),
        ReaderErrorKind.forbidden,
      );
    });
  });
}
