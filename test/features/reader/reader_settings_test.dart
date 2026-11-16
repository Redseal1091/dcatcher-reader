import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/catalog/models/manga.dart';
import 'package:manga_reader_app/features/reader/models/chapter.dart';
import 'package:manga_reader_app/features/reader/models/manga_reader_settings.dart';
import 'package:manga_reader_app/features/reader/screens/paged_reader_screen.dart';
import 'package:manga_reader_app/features/reader/screens/webtoon_reader_screen.dart';
import 'package:manga_reader_app/features/reader/widgets/reader_settings_bottom_sheet.dart';
import 'package:manga_reader_app/features/sources/manga_source.dart';
import 'package:manga_reader_app/features/sources/source_manager.dart';
import 'package:manga_reader_app/features/library/state/library_provider.dart';

class MockTestReaderSource extends MangaSource {
  @override
  String get id => 'test_source';
  @override
  String get name => 'Test Source';

  @override
  Future<List<Manga>> getCatalog({required dynamic filters, int offset = 0, int limit = 20}) async => [];

  @override
  Future<List<Chapter>> getChapters(String mangaId) async => [];

  @override
  Future<List<String>> getChapterPages(String chapterId) async {
    return [
      'https://example.com/page1.jpg',
      'https://example.com/page2.jpg',
      'https://example.com/page3.jpg',
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Manga dummyManga;
  late Chapter dummyChapter1;
  late Chapter dummyChapter2;
  late MockTestReaderSource testSource;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    testSource = MockTestReaderSource();
    SourceManager.resetForTesting();

    dummyManga = const Manga(
      id: 'manga_1',
      title: 'Solo Leveling',
      coverUrl: 'https://example.com/cover.jpg',
      description: 'Test manga',
      type: PublicationType.manhwa,
      contentRating: ContentRating.safe,
      genres: ['Action', 'Fantasy'],
      sourceId: 'test_source',
    );

    dummyChapter1 = Chapter(
      id: 'ch_1',
      mangaId: 'manga_1',
      chapterNumber: '1',
      title: 'Глава 1',
      publishedAt: DateTime(2024, 1, 1),
    );

    dummyChapter2 = Chapter(
      id: 'ch_2',
      mangaId: 'manga_1',
      chapterNumber: '2',
      title: 'Глава 2',
      publishedAt: DateTime(2024, 1, 2),
    );
  });

  group('MangaReaderSettings Model Tests', () {
    test('Default values are initialized properly', () {
      final settings = MangaReaderSettings();
      expect(settings.readingMode, MangaReadingMode.pagedRtl);
      expect(settings.theme, MangaReaderTheme.oledBlack);
      expect(settings.imageFit, MangaImageFit.contain);
      expect(settings.pageSpacing, 0.0);
      expect(settings.keepScreenOn, false);
      expect(settings.showPageNumberOverlay, true);
    });

    test('Setters trigger notifyListeners and update state', () {
      final settings = MangaReaderSettings();
      int notifyCount = 0;
      settings.addListener(() => notifyCount++);

      settings.setReadingMode(MangaReadingMode.webtoon);
      expect(settings.readingMode, MangaReadingMode.webtoon);
      expect(notifyCount, 1);

      settings.setTheme(MangaReaderTheme.warmSepia);
      expect(settings.theme, MangaReaderTheme.warmSepia);
      expect(notifyCount, 2);

      settings.setImageFit(MangaImageFit.fitWidth);
      expect(settings.imageFit, MangaImageFit.fitWidth);
      expect(notifyCount, 3);

      settings.setPageSpacing(8.0);
      expect(settings.pageSpacing, 8.0);
      expect(notifyCount, 4);

      settings.setKeepScreenOn(true);
      expect(settings.keepScreenOn, true);
      expect(notifyCount, 5);

      settings.setShowPageNumberOverlay(false);
      expect(settings.showPageNumberOverlay, false);
      expect(notifyCount, 6);
    });

    test('Theme extensions return proper colors and labels', () {
      expect(MangaReaderTheme.oledBlack.backgroundColor, Colors.black);
      expect(MangaReaderTheme.zincDark.backgroundColor, const Color(0xFF09090B));
      expect(MangaReaderTheme.warmSepia.backgroundColor, const Color(0xFF1E1A16));
      expect(MangaReaderTheme.light.backgroundColor, Colors.white);
      expect(MangaReaderTheme.light.textColor, const Color(0xFF09090B));
      expect(MangaReaderTheme.oledBlack.textColor, Colors.white);
    });

    test('Fit extensions return proper BoxFit and labels', () {
      expect(MangaImageFit.contain.boxFit, BoxFit.contain);
      expect(MangaImageFit.fitWidth.boxFit, BoxFit.fitWidth);
      expect(MangaImageFit.fitHeight.boxFit, BoxFit.fitHeight);
      expect(MangaImageFit.cover.boxFit, BoxFit.cover);
      expect(MangaImageFit.fitWidth.label, 'По ширине');
    });

    test('ReadingMode extensions return proper labels and icons', () {
      expect(MangaReadingMode.webtoon.label, 'Вебтун');
      expect(MangaReadingMode.pagedRtl.label, 'Манга (RTL)');
      expect(MangaReadingMode.pagedLtr.label, 'Страницы (LTR)');
      expect(MangaReadingMode.pagedVertical.label, 'Вертикально');
    });
  });

  group('ReaderSettingsBottomSheet Widget Tests', () {
    testWidgets('Renders all setting sections, toggles options, and navigates chapters', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = MangaReaderSettings();
      Chapter? selectedChapter;
      MangaReadingMode? selectedMode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    ReaderSettingsBottomSheet.show(
                      context: ctx,
                      settings: settings,
                      currentIndex: 1,
                      totalPages: 10,
                      currentChapter: dummyChapter1,
                      chapters: [dummyChapter1, dummyChapter2],
                      onChapterSelected: (c) => selectedChapter = c,
                      onReadingModeChanged: (m) => selectedMode = m,
                    );
                  },
                  child: const Text('Open Settings'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('Настройки читалки'), findsOneWidget);

      // Verify Page Slider Label
      expect(find.text('2 из 10'), findsOneWidget);

      // Verify Chapter buttons
      expect(find.text('Пред. глава'), findsOneWidget);
      expect(find.text('След. глава'), findsOneWidget);

      // Verify Mode chips
      expect(find.text('Вебтун'), findsOneWidget);
      expect(find.text('Манга (RTL)'), findsOneWidget);
      expect(find.text('Страницы (LTR)'), findsOneWidget);

      // Tap Webtoon chip
      await tester.tap(find.text('Вебтун'));
      await tester.pumpAndSettle();
      expect(settings.readingMode, MangaReadingMode.webtoon);
      expect(selectedMode, MangaReadingMode.webtoon);

      // Verify Theme circles
      expect(find.text('OLED'), findsOneWidget);
      expect(find.text('Zinc'), findsOneWidget);
      expect(find.text('Сепия'), findsOneWidget);
      expect(find.text('Светлый'), findsOneWidget);

      // Tap Sepia Theme
      await tester.tap(find.text('Сепия'));
      await tester.pumpAndSettle();
      expect(settings.theme, MangaReaderTheme.warmSepia);

      // Verify Image Fit chips
      expect(find.text('Целиком'), findsOneWidget);
      expect(find.text('По ширине'), findsOneWidget);

      // Tap 'По ширине'
      await tester.tap(find.text('По ширине'));
      await tester.pumpAndSettle();
      expect(settings.imageFit, MangaImageFit.fitWidth);

      // Verify Spacing chips
      expect(find.text('Без отступа'), findsOneWidget);
      expect(find.text('8 px'), findsOneWidget);

      // Tap '8 px'
      await tester.tap(find.text('8 px'));
      await tester.pumpAndSettle();
      expect(settings.pageSpacing, 8.0);

      // Tap Next Chapter button (closes sheet and notifies)
      await tester.tap(find.text('След. глава'));
      await tester.pumpAndSettle();
      expect(selectedChapter?.id, dummyChapter2.id);
    });
  });

  group('Reader Screen Settings Button Integration', () {
    testWidgets('PagedReaderScreen gear button opens ReaderSettingsBottomSheet', (tester) async {
      final settings = MangaReaderSettings();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MangaReaderSettings>.value(value: settings),
            ChangeNotifierProvider<LibraryProvider>(create: (_) => LibraryProvider()),
          ],
          child: MaterialApp(
            home: PagedReaderScreen(
              manga: dummyManga,
              chapter: dummyChapter1,
              source: testSource,
              chapters: [dummyChapter1, dummyChapter2],
            ),
          ),
        ),
      );

      // Pump through initial load
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find Settings gear button
      final gearButton = find.byIcon(Icons.settings_outlined);
      expect(gearButton, findsOneWidget);

      // Tap Settings gear button
      await tester.tap(gearButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Bottom sheet should be visible
      expect(find.text('Настройки читалки'), findsOneWidget);
      expect(find.text('Режим чтения'), findsOneWidget);
      expect(find.text('Цвет фона'), findsOneWidget);
    });

    testWidgets('WebtoonReaderScreen gear button opens ReaderSettingsBottomSheet', (tester) async {
      final settings = MangaReaderSettings();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MangaReaderSettings>.value(value: settings),
            ChangeNotifierProvider<LibraryProvider>(create: (_) => LibraryProvider()),
          ],
          child: MaterialApp(
            home: WebtoonReaderScreen(
              manga: dummyManga,
              chapter: dummyChapter1,
              source: testSource,
              chapters: [dummyChapter1, dummyChapter2],
            ),
          ),
        ),
      );

      // Pump through initial load
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find Settings gear button
      final gearButtons = find.byIcon(Icons.settings_outlined);
      expect(gearButtons, findsAtLeastNWidgets(1));

      // Tap first Settings gear button
      await tester.tap(gearButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Bottom sheet should be visible
      expect(find.text('Настройки читалки'), findsOneWidget);
      expect(find.text('Режим чтения'), findsOneWidget);
      expect(find.text('Цвет фона'), findsOneWidget);
    });
  });
}
