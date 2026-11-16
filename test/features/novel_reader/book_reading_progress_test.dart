import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/books/services/book_progress_service.dart';
import 'package:manga_reader_app/features/library/models/book_shelf_item.dart';
import 'package:manga_reader_app/features/library/state/book_shelf_provider.dart';
import 'package:manga_reader_app/features/novel_reader/models/novel_chapter.dart';
import 'package:manga_reader_app/features/novel_reader/models/reader_settings.dart';
import 'package:manga_reader_app/features/novel_reader/screens/novel_reader_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BookProgressService and Model Tests', () {
    test('saveProgress and getProgress round-trips data accurately', () async {
      final now = DateTime(2026, 11, 15, 12, 0, 0);
      final progress = BookProgress(
        bookId: 'book_123',
        chapterId: 'ch_4',
        chapterTitle: 'Глава 4. Поединок',
        chapterNumber: '4',
        scrollOffset: 1540.5,
        readPercent: 0.65,
        updatedAt: now,
      );

      await BookProgressService.saveProgress(progress);
      final restored = await BookProgressService.getProgress('book_123');

      expect(restored, isNotNull);
      expect(restored!.bookId, 'book_123');
      expect(restored.chapterId, 'ch_4');
      expect(restored.chapterTitle, 'Глава 4. Поединок');
      expect(restored.chapterNumber, '4');
      expect(restored.scrollOffset, 1540.5);
      expect(restored.readPercent, 0.65);
      expect(restored.updatedAt, now);
    });

    test('clearProgress removes stored entry', () async {
      final progress = BookProgress(
        bookId: 'book_to_clear',
        chapterId: 'ch_1',
        updatedAt: DateTime.now(),
      );

      await BookProgressService.saveProgress(progress);
      expect(await BookProgressService.getProgress('book_to_clear'), isNotNull);

      await BookProgressService.clearProgress('book_to_clear');
      expect(await BookProgressService.getProgress('book_to_clear'), isNull);
    });

    test('getProgress returns null on empty or non-existent key', () async {
      expect(await BookProgressService.getProgress(''), isNull);
      expect(await BookProgressService.getProgress('unknown_book'), isNull);
    });
  });

  group('BookShelfItem & BookShelfProvider Progress Integration', () {
    test('BookShelfItem serializes and deserializes progress fields correctly', () {
      final now = DateTime(2026, 11, 15, 10, 30);
      final item = BookShelfItem(
        id: 'shelf_book_1',
        title: 'Война и мир',
        author: 'Л. Н. Толстой',
        addedAt: now,
        lastChapterId: 'ch_10',
        lastChapterTitle: 'Том 1, Часть 2',
        lastScrollOffset: 450.0,
        lastReadPercent: 0.25,
        lastReadAt: now,
      );

      final json = item.toJson();
      final fromJson = BookShelfItem.fromJson(json);

      expect(fromJson.lastChapterId, 'ch_10');
      expect(fromJson.lastChapterTitle, 'Том 1, Часть 2');
      expect(fromJson.lastScrollOffset, 450.0);
      expect(fromJson.lastReadPercent, 0.25);
      expect(fromJson.lastReadAt, now);
    });

    test('BookShelfProvider.updateBookProgress updates item and persists to storage', () async {
      final shelf = BookShelfProvider();
      final item = BookShelfItem(
        id: 'test_book_progress',
        title: 'Пикник на обочине',
        addedAt: DateTime.now(),
      );

      await shelf.addBook(item);
      expect(shelf.getById('test_book_progress')?.lastReadPercent, isNull);

      await shelf.updateBookProgress(
        bookId: 'test_book_progress',
        chapterId: 'ch_2',
        chapterTitle: 'Глава 2',
        scrollOffset: 620.0,
        readPercent: 0.42,
      );

      final updated = shelf.getById('test_book_progress');
      expect(updated, isNotNull);
      expect(updated!.lastChapterId, 'ch_2');
      expect(updated.lastChapterTitle, 'Глава 2');
      expect(updated.lastScrollOffset, 620.0);
      expect(updated.lastReadPercent, 0.42);
      expect(updated.lastReadAt, isNotNull);

      // Verify reloaded shelf has preserved progress
      final reloadedShelf = BookShelfProvider();
      await reloadedShelf.loadShelf();
      final reloadedItem = reloadedShelf.getById('test_book_progress');
      expect(reloadedItem?.lastReadPercent, 0.42);
      expect(reloadedItem?.lastChapterId, 'ch_2');
    });
  });

  group('ReaderSettings Typography Tests', () {
    test('fontFamily and textAlign can be set and persist to SharedPreferences', () async {
      final settings = ReaderSettings();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      settings.setFontFamily('serif');
      settings.setTextAlign(TextAlign.start);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(settings.fontFamily, 'serif');
      expect(settings.textAlign, TextAlign.start);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reader_font_family'), 'serif');
      expect(prefs.getString('reader_text_align'), 'start');

      // Reload into new settings instance
      final newSettings = ReaderSettings();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(newSettings.fontFamily, 'serif');
      expect(newSettings.textAlign, TextAlign.start);
    });
  });

  group('NovelReaderScreen Progress Persistence & Restoration Widget Tests', () {
    final ch1 = NovelChapter(
      id: 'c1',
      title: 'Глава 1. Начало пути',
      chapterNumber: '1',
      content: List.generate(30, (i) => 'Абзац номер $i длинного текста главы 1.').join('\n\n'),
      publishedAt: DateTime(2025),
    );

    final ch2 = NovelChapter(
      id: 'c2',
      title: 'Глава 2. Продолжение пути',
      chapterNumber: '2',
      content: List.generate(30, (i) => 'Абзац номер $i длинного текста главы 2.').join('\n\n'),
      publishedAt: DateTime(2025),
    );

    testWidgets('NovelReaderScreen restores initialScrollOffset upon mounting', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: NovelReaderScreen(
            bookId: 'test_book_offset',
            novelTitle: 'Тестовая книга',
            chapter: ch1,
            allChapters: [ch1, ch2],
            initialScrollOffset: 350.0,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable);
      final scrollableState = tester.state<ScrollableState>(scrollableFinder);
      expect(scrollableState.position.pixels, moreOrLessEquals(350.0, epsilon: 10.0));
    });

    testWidgets('NovelReaderScreen automatically loads and restores progress from BookProgressService', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Pre-seed BookProgressService with saved offset
      await BookProgressService.saveProgress(
        BookProgress(
          bookId: 'seed_book',
          chapterId: 'c1',
          chapterTitle: 'Глава 1. Начало пути',
          scrollOffset: 280.0,
          readPercent: 0.35,
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NovelReaderScreen(
            bookId: 'seed_book',
            novelTitle: 'Тестовая книга',
            chapter: ch1,
            allChapters: [ch1, ch2],
          ),
        ),
      );

      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable);
      final scrollableState = tester.state<ScrollableState>(scrollableFinder);
      expect(scrollableState.position.pixels, equals(280.0));
      expect(find.text('Прочитано: 35%'), findsOneWidget);
    });

    testWidgets('Scrolling and navigating chapters updates saved progress', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final shelf = BookShelfProvider();
      await shelf.addBook(
        BookShelfItem(
          id: 'tracked_book',
          title: 'Отслеживаемая книга',
          addedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<BookShelfProvider>.value(
          value: shelf,
          child: MaterialApp(
            home: NovelReaderScreen(
              bookId: 'tracked_book',
              novelTitle: 'Отслеживаемая книга',
              chapter: ch1,
              allChapters: [ch1, ch2],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll
      final scrollableFinder = find.byType(Scrollable);
      await tester.drag(scrollableFinder, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 500)); // allow debounce timer
      await tester.pumpAndSettle();

      // Verify progress saved to service and shelf
      final serviceProgress = await BookProgressService.getProgress('tracked_book');
      expect(serviceProgress, isNotNull);
      expect(serviceProgress!.chapterId, 'c1');
      expect(serviceProgress.scrollOffset, greaterThan(0.0));

      final shelfItem = shelf.getById('tracked_book');
      expect(shelfItem?.lastChapterId, 'c1');
      expect(shelfItem?.lastScrollOffset, greaterThan(0.0));

      // Navigate to next chapter
      final nextButton = find.widgetWithIcon(IconButton, Icons.chevron_right);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      final progressAfterNav = await BookProgressService.getProgress('tracked_book');
      expect(progressAfterNav?.chapterId, 'c2');
      expect(progressAfterNav?.scrollOffset, equals(0.0));
    });
  });
}
