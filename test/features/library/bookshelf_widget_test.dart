import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/core/theme/theme_provider.dart';
import 'package:manga_reader_app/features/catalog/state/catalog_provider.dart';
import 'package:manga_reader_app/features/library/models/book_shelf_item.dart';
import 'package:manga_reader_app/features/library/state/library_provider.dart';
import 'package:manga_reader_app/features/library/state/book_shelf_provider.dart';
import 'package:manga_reader_app/features/library/screens/library_screen.dart';
import 'package:manga_reader_app/features/library/screens/widgets/book_shelf_tab.dart';
import 'package:manga_reader_app/features/novel_reader/screens/novel_reader_screen.dart';
import 'package:manga_reader_app/features/books/models/book_item.dart';
import 'package:manga_reader_app/features/books/services/books_repository.dart';
import 'package:manga_reader_app/features/books/services/book_offline_store.dart';

Widget createTestApp({
  required BookShelfProvider bookShelfProvider,
  Widget? child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppSettingsProvider>(create: (_) => AppSettingsProvider()),
      ChangeNotifierProvider<LibraryProvider>(create: (_) => LibraryProvider()),
      ChangeNotifierProvider<CatalogProvider>(create: (_) => CatalogProvider()),
      ChangeNotifierProvider<BookShelfProvider>.value(value: bookShelfProvider),
    ],
    child: MaterialApp(
      home: child ?? const LibraryScreen(),
    ),
  );
}

class _FakeBooksRepository extends BooksRepository {
  final Map<String, List<BookChapter>> fakeChapters;
  int getChaptersCallCount = 0;
  int getBookByIdCallCount = 0;

  _FakeBooksRepository({this.fakeChapters = const {}})
      : super.withOfflineStore(BookOfflineStore());

  @override
  Future<List<BookChapter>> getBookChapters(BookItem book) async {
    getChaptersCallCount++;
    if (book.isPdfOnly) {
      throw const FormatException('Это издание доступно только в PDF. Встроенная читалка пока не поддерживает этот формат.');
    }
    return fakeChapters[book.id] ?? [];
  }

  @override
  Future<BookItem?> getBookById(String id) async {
    getBookByIdCallCount++;
    if (fakeChapters.containsKey(id)) {
      return BookItem(
        id: id,
        title: 'Тестовая книга',
        author: 'Тестовый автор',
        genre: 'Фантастика',
        coverUrl: '',
        description: 'Описание тестовой книги',
        year: 2026,
        chapters: const [],
        availableFormats: const ['epub', 'fb2'],
      );
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BookShelfTab & LibraryScreen Widget Tests', () {
    testWidgets('LibraryScreen shows Книжная полка tab with count (0) initially', (tester) async {
      final shelf = BookShelfProvider();
      await shelf.loadShelf();

      await tester.pumpWidget(createTestApp(bookShelfProvider: shelf));
      await tester.pumpAndSettle();

      expect(find.textContaining('Книжная полка'), findsOneWidget);
      expect(find.textContaining('(0)'), findsWidgets);
    });

    testWidgets('BookShelfTab shows empty state when no books', (tester) async {
      final shelf = BookShelfProvider();
      await shelf.loadShelf();

      await tester.pumpWidget(
        createTestApp(
          bookShelfProvider: shelf,
          child: const Scaffold(body: BookShelfTab()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Книжная полка пуста'), findsOneWidget);
    });

    testWidgets('BookShelfTab renders book spines with titles and authors', (tester) async {
      final shelf = BookShelfProvider();
      await shelf.loadShelf();

      await shelf.addBook(
        BookShelfItem(
          id: 'item_1',
          title: 'Пикник на обочине',
          author: 'Стругацкие',
          genre: 'Фантастика',
          year: 1972,
          availableFormats: const ['epub', 'fb2'],
          addedAt: DateTime(2026, 1, 1),
        ),
      );

      await shelf.addBook(
        BookShelfItem(
          id: 'item_2',
          title: 'Солярис',
          author: 'Станислав Лем',
          genre: 'НФ',
          year: 1961,
          availableFormats: const ['pdf'],
          addedAt: DateTime(2026, 2, 1),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          bookShelfProvider: shelf,
          child: const Scaffold(body: BookShelfTab()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Пикник на обочине'), findsOneWidget);
      expect(find.text('Солярис'), findsOneWidget);
      expect(find.text('Стругацкие'), findsOneWidget);
      expect(find.text('Станислав Лем'), findsOneWidget);
    });

    testWidgets('BookShelfTab renders at 360px width without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final shelf = BookShelfProvider();
      await shelf.loadShelf();

      for (int i = 1; i <= 8; i++) {
        await shelf.addBook(
          BookShelfItem(
            id: 'book_$i',
            title: 'Книга номер $i с достаточно длинным названием',
            author: 'Автор $i',
            addedAt: DateTime(2026, 1, i),
          ),
        );
      }

      await tester.pumpWidget(
        createTestApp(
          bookShelfProvider: shelf,
          child: const Scaffold(body: BookShelfTab()),
        ),
      );
      await tester.pumpAndSettle();

      // No overflow exceptions should have occurred during pumpAndSettle
      expect(tester.takeException(), isNull);
    });

    testWidgets('BookShelfTab does not use Image.network on shelf', (tester) async {
      final shelf = BookShelfProvider();
      await shelf.loadShelf();

      await shelf.addBook(
        BookShelfItem(
          id: 'item_network_test',
          title: 'Без сетевых картинок',
          author: 'Автор',
          coverUrl: 'https://example.com/cover.jpg',
          addedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          bookShelfProvider: shelf,
          child: const Scaffold(body: BookShelfTab()),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no NetworkImage provider is used in the widget tree
      for (final element in find.byType(Image).evaluate()) {
        final widget = element.widget as Image;
        expect(widget.image is NetworkImage, isFalse,
            reason: 'Book shelf must not network-fetch covers on shelf');
      }
    });

    testWidgets('Spines provide tooltip accessibility', (tester) async {
      final shelf = BookShelfProvider();
      await shelf.loadShelf();

      await shelf.addBook(
        BookShelfItem(
          id: 'item_tooltip',
          title: 'Дозор',
          author: 'Лукьяненко',
          addedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          bookShelfProvider: shelf,
          child: const Scaffold(body: BookShelfTab()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Tooltip), findsWidgets);
      final tooltip = tester.widget<Tooltip>(
        find.widgetWithText(Tooltip, 'Дозор'),
      );
      expect(tooltip.message, contains('Дозор'));
    });

    testWidgets('Tapping spine shows metadata details without chapter fetch', (tester) async {
      final shelf = BookShelfProvider();
      await shelf.loadShelf();

      await shelf.addBook(
        BookShelfItem(
          id: 'item_details',
          title: 'Трудно быть богом',
          author: 'Братья Стругацкие',
          genre: 'Фантастика',
          year: 1964,
          description: 'История дона Руматы Эсторского',
          availableFormats: const ['epub', 'fb2'],
          addedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          bookShelfProvider: shelf,
          child: const Scaffold(body: BookShelfTab()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the spine
      await tester.tap(find.text('Трудно быть богом'));
      await tester.pumpAndSettle();

      // Metadata modal appears
      expect(find.text('Информация о книге'), findsOneWidget);
      expect(find.text('История дона Руматы Эсторского'), findsOneWidget);
      expect(find.textContaining('1964'), findsOneWidget);
      expect(find.textContaining('Фантастика'), findsOneWidget);
    });

    testWidgets('Remove action shows confirmation dialog and removes on confirm', (tester) async {
      final shelf = BookShelfProvider();
      await shelf.loadShelf();

      await shelf.addBook(
        BookShelfItem(
          id: 'item_remove',
          title: 'Книга на удаление',
          author: 'Тестовый автор',
          addedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          bookShelfProvider: shelf,
          child: const Scaffold(body: BookShelfTab()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Книга на удаление'), findsOneWidget);

      // Long press on spine to trigger delete
      await tester.longPress(find.text('Книга на удаление'));
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('Удалить книгу?'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
      expect(find.text('Удалить'), findsOneWidget);

      // Tap Отмена first
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(find.text('Книга на удаление'), findsOneWidget);
      expect(shelf.contains('item_remove'), isTrue);

      // Long press again and confirm
      await tester.longPress(find.text('Книга на удаление'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();

      expect(shelf.contains('item_remove'), isFalse);
      expect(find.text('Книжная полка пуста'), findsOneWidget);
    });

    testWidgets('Tapping spine shows metadata dialog with explicit Read button that opens NovelReaderScreen with real prose via injected repository', (tester) async {
      final shelf = BookShelfProvider();
      await shelf.loadShelf();

      const testBookId = '895694';
      const expectedProseBody = 'Утренний туман медленно опускался над рекой, пока герои готовились к дальней экспедиции через горный хребет.';

      final fakeRepo = _FakeBooksRepository(
        fakeChapters: {
          testBookId: const [
            BookChapter(
              id: '895694_ch1',
              number: '1',
              title: 'Глава 1: Открытие повести',
              content: expectedProseBody,
            ),
          ],
        },
      );

      await shelf.addBook(
        BookShelfItem(
          id: testBookId,
          title: 'Повесть о тайге',
          author: 'Сибирский автор',
          genre: 'Приключения',
          year: 2024,
          availableFormats: const ['epub', 'fb2'],
          addedAt: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          bookShelfProvider: shelf,
          child: Scaffold(body: BookShelfTab(repository: fakeRepo)),
        ),
      );
      await tester.pumpAndSettle();

      // Tap spine
      await tester.tap(find.text('Повесть о тайге'));
      await tester.pumpAndSettle();

      // Metadata modal appears
      expect(find.text('Информация о книге'), findsOneWidget);

      // Lazy check: chapters must NOT have been fetched yet on mere spine tap
      expect(fakeRepo.getChaptersCallCount, 0,
          reason: 'Spine tap must be lazy metadata-only, no chapter fetch yet');
      expect(fakeRepo.getBookByIdCallCount, 0,
          reason: 'Spine tap must not hit repository before user decides to read');

      // Explicit Read button must be present
      final readButton = find.widgetWithText(ElevatedButton, 'Читать');
      expect(readButton, findsOneWidget);

      // Tap Read button
      await tester.tap(readButton);
      await tester.pumpAndSettle();

      // Chapters must have been fetched now
      expect(fakeRepo.getChaptersCallCount, 1,
          reason: 'Read action must fetch chapters via repository');

      // Must open NovelReaderScreen with genuine prose body displayed (not just title/heading)
      expect(find.byType(NovelReaderScreen), findsOneWidget);
      expect(find.textContaining(expectedProseBody), findsOneWidget);
    });

    testWidgets('PDF-only book on shelf shows PDF notice and no Read button', (tester) async {
      final shelf = BookShelfProvider();
      await shelf.loadShelf();

      final fakeRepo = _FakeBooksRepository();

      await shelf.addBook(
        BookShelfItem(
          id: '99001',
          title: 'Документ PDF',
          author: 'Научный сотрудник',
          genre: 'Документы',
          year: 2021,
          availableFormats: const ['application/pdf'],
          addedAt: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          bookShelfProvider: shelf,
          child: Scaffold(body: BookShelfTab(repository: fakeRepo)),
        ),
      );
      await tester.pumpAndSettle();

      // Tap spine
      await tester.tap(find.text('Документ PDF'));
      await tester.pumpAndSettle();

      expect(find.textContaining('доступно только в PDF'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Читать'), findsNothing);
      expect(fakeRepo.getChaptersCallCount, 0,
          reason: 'PDF-only entries must never trigger chapter fetch');
    });
  });
}
