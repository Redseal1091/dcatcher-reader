import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/core/widgets/dcatcher_image.dart';
import 'package:manga_reader_app/features/catalog/models/manga.dart';
import 'package:manga_reader_app/features/library/state/library_provider.dart';
import 'package:manga_reader_app/features/reader/models/chapter.dart';
import 'package:manga_reader_app/features/reader/screens/paged_reader_screen.dart';
import 'package:manga_reader_app/features/reader/screens/webtoon_reader_screen.dart';
import 'package:manga_reader_app/features/sources/manga_source.dart';
import 'package:manga_reader_app/features/sources/source_manager.dart';
import 'package:manga_reader_app/features/extensions/models/keiyoushi_extension.dart';
import 'package:manga_reader_app/features/extensions/services/native_extensions_bridge.dart';

class MockBridgeForRetry extends NativeExtensionsBridge {
  int fetchCallCount = 0;
  bool shouldFail = true;
  final Uint8List validBytes;

  MockBridgeForRetry({required this.validBytes}) : super.forTesting();

  @override
  Future<Uint8List> fetchImage({
    required String sourceId,
    required String url,
  }) async {
    fetchCallCount++;
    if (shouldFail) {
      throw Exception('Network connection timed out');
    }
    return validBytes;
  }
}

class TestMangaSourceWithPages extends MangaSource {
  @override
  final String id;
  @override
  final String name;
  final List<String> pages;

  TestMangaSourceWithPages({
    required this.id,
    required this.name,
    required this.pages,
  });

  @override
  Future<List<Manga>> getCatalog({required dynamic filters, int offset = 0, int limit = 20}) async => [];

  @override
  Future<List<Chapter>> getChapters(String mangaId) async => [];

  @override
  Future<List<String>> getChapterPages(String chapterId) async => pages;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final transparentPng = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DcatcherImage.clearCache();
    SourceManager.resetForTesting();
  });

  Widget buildWrapper(Widget child) {
    return ChangeNotifierProvider<LibraryProvider>(
      create: (_) => LibraryProvider(),
      child: MaterialApp(home: child),
    );
  }

  group('DcatcherImage Slide Timeout & Tap-to-Retry', () {
    testWidgets('DcatcherImage invokes errorRetryWidget on error, and recovers when retry() is tapped', (tester) async {
      final mockBridge = MockBridgeForRetry(validBytes: transparentPng);
      const extension = KeiyoushiExtension(
        name: 'Retry Ext',
        packageName: 'tachiyomi.retry',
        versionName: '1.0',
        versionCode: '1',
        extensionLib: '1.6',
        apkUrl: '',
        iconUrl: '',
        contentWarning: ContentWarning.safe,
        sources: [
          KeiyoushiSource(
            id: '99887766',
            name: 'Retry Source',
            language: 'ru',
            homeUrl: 'https://retry.test',
          ),
        ],
      );

      await SourceManager.updateFromExtensions([extension], bridge: mockBridge);

      bool retryInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DcatcherImage(
              imageUrl: 'https://retry.test/p1.png',
              sourceId: '99887766',
              errorRetryWidget: (context, url, error, retry) {
                return TextButton(
                  onPressed: () {
                    retryInvoked = true;
                    mockBridge.shouldFail = false;
                    retry();
                  },
                  child: const Text('Повторить страницу'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Повторить страницу'), findsOneWidget);
      expect(mockBridge.fetchCallCount, 1);

      // Tap retry
      await tester.tap(find.text('Повторить страницу'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(retryInvoked, isTrue);
      expect(mockBridge.fetchCallCount, 2);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Повторить страницу'), findsNothing);
    });

    testWidgets('PagedReaderScreen displays per-page interactive retry widget on failed slide', (tester) async {
      final mockBridge = MockBridgeForRetry(validBytes: transparentPng);
      const extension = KeiyoushiExtension(
        name: 'Retry Ext',
        packageName: 'tachiyomi.retry',
        versionName: '1.0',
        versionCode: '1',
        extensionLib: '1.6',
        apkUrl: '',
        iconUrl: '',
        contentWarning: ContentWarning.safe,
        sources: [
          KeiyoushiSource(
            id: '99887766',
            name: 'Retry Source',
            language: 'ru',
            homeUrl: 'https://retry.test',
          ),
        ],
      );
      await SourceManager.updateFromExtensions([extension], bridge: mockBridge);

      const manga = Manga(
        id: 'retry_manga',
        title: 'Retry Manga',
        description: 'Test',
        coverUrl: '',
        type: PublicationType.manga,
        contentRating: ContentRating.safe,
        genres: [],
        status: 'ongoing',
        sourceId: '99887766',
      );

      final chapter = Chapter(
        id: 'c1',
        mangaId: 'retry_manga',
        chapterNumber: '1',
        title: 'Ch 1',
        publishedAt: DateTime.now(),
      );

      final sourceWithPages = TestMangaSourceWithPages(
        id: '99887766',
        name: 'Retry Source',
        pages: ['https://retry.test/p1.png'],
      );

      await tester.pumpWidget(
        buildWrapper(
          PagedReaderScreen(
            manga: manga,
            chapter: chapter,
            source: sourceWithPages,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Check that PagedReader errorRetryWidget is displayed
      expect(find.text('Ошибка загрузки стр. 1'), findsOneWidget);
      expect(find.text('Нажмите, чтобы повторить'), findsOneWidget);

      // Now let bridge succeed and tap retry
      mockBridge.shouldFail = false;
      await tester.tap(find.text('Нажмите, чтобы повторить'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Successfully loaded image
      expect(find.text('Ошибка загрузки стр. 1'), findsNothing);
      expect(mockBridge.fetchCallCount, 2);
    });

    testWidgets('WebtoonReaderScreen displays per-page interactive retry widget on failed slide', (tester) async {
      final mockBridge = MockBridgeForRetry(validBytes: transparentPng);
      const extension = KeiyoushiExtension(
        name: 'Retry Ext',
        packageName: 'tachiyomi.retry',
        versionName: '1.0',
        versionCode: '1',
        extensionLib: '1.6',
        apkUrl: '',
        iconUrl: '',
        contentWarning: ContentWarning.safe,
        sources: [
          KeiyoushiSource(
            id: '99887766',
            name: 'Retry Source',
            language: 'ru',
            homeUrl: 'https://retry.test',
          ),
        ],
      );
      await SourceManager.updateFromExtensions([extension], bridge: mockBridge);

      const manga = Manga(
        id: 'retry_manga',
        title: 'Retry Manga',
        description: 'Test',
        coverUrl: '',
        type: PublicationType.manhwa,
        contentRating: ContentRating.safe,
        genres: [],
        status: 'ongoing',
        sourceId: '99887766',
      );

      final chapter = Chapter(
        id: 'c1',
        mangaId: 'retry_manga',
        chapterNumber: '1',
        title: 'Ch 1',
        publishedAt: DateTime.now(),
      );

      final sourceWithPages = TestMangaSourceWithPages(
        id: '99887766',
        name: 'Retry Source',
        pages: ['https://retry.test/p1.png'],
      );

      await tester.pumpWidget(
        buildWrapper(
          WebtoonReaderScreen(
            manga: manga,
            chapter: chapter,
            source: sourceWithPages,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Check that Webtoon errorRetryWidget is displayed
      expect(find.text('Стр. 1 не загрузилась'), findsOneWidget);
      expect(find.text('Повторить загрузку'), findsOneWidget);

      // Tap retry with successful bridge
      mockBridge.shouldFail = false;
      await tester.tap(find.text('Повторить загрузку'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Successfully loaded image
      expect(find.text('Стр. 1 не загрузилась'), findsNothing);
      expect(mockBridge.fetchCallCount, 2);
    });
  });
}
