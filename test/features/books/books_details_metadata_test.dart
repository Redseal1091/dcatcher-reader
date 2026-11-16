import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/books/models/book_item.dart';
import 'package:manga_reader_app/features/books/screens/books_catalog_screen.dart';
import 'package:manga_reader_app/features/books/services/books_repository.dart';
import 'package:manga_reader_app/features/books/services/book_offline_store.dart';
import 'package:manga_reader_app/features/books/models/book_catalog_page.dart';

class MockDetailsRepository extends BooksRepository {
  final List<BookItem> testBooks;
  final String sourceName;

  MockDetailsRepository({required this.testBooks, this.sourceName = 'Флибуста (Flibusta.site)'})
      : super.withOfflineStore(BookOfflineStore(directoryProvider: () async => throw UnimplementedError()));

  @override
  Future<BookCatalogPage> getBooksPage({
    String source = 'Флибуста (Flibusta.site)',
    String genre = 'Все',
    String search = '',
    Uri? pageUri,
  }) async {
    return BookCatalogPage(items: testBooks, nextPageUri: null);
  }

  @override
  Future<List<BookItem>> getBooks({
    String source = 'Флибуста (Flibusta.site)',
    String genre = 'Все',
    String search = '',
  }) async {
    return testBooks;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BooksCatalogScreen details displays year and rating badges when non-zero, hides 0 year and 0 rating', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const bookWithMetadata = BookItem(
      id: 'book_meta_1',
      title: 'Мастер и Маргарита',
      author: 'Михаил Булгаков',
      genre: 'Классика',
      year: 1940,
      rating: 9.8,
      coverUrl: '',
      description: 'Знаменитый роман',
      chapters: [],
    );

    const bookWithSentinels = BookItem(
      id: 'book_zero_1',
      title: 'Книга с нулевыми метками',
      author: 'Неизвестный автор',
      genre: 'Разное',
      year: 0,
      rating: 0.0,
      coverUrl: '',
      description: 'Описание книги',
      chapters: [],
    );

    final repo = MockDetailsRepository(testBooks: [bookWithMetadata, bookWithSentinels]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BooksCatalogScreen(repository: repo),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Tap book with metadata
    await tester.tap(find.text('Мастер и Маргарита'));
    await tester.pumpAndSettle();

    // Assert badges visible in details modal
    expect(find.text('1940 г.'), findsOneWidget);
    expect(find.text('★ 9.8'), findsOneWidget);

    // Close details
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Tap book with sentinel 0 values
    await tester.tap(find.text('Книга с нулевыми метками'));
    await tester.pumpAndSettle();

    // Assert "0 г." and "★ 0.0" are NOT displayed
    expect(find.text('0 г.'), findsNothing);
    expect(find.text('★ 0.0'), findsNothing);
  });
}
