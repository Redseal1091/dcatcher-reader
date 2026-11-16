import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/books/models/book_item.dart';
import 'package:manga_reader_app/features/books/models/book_catalog_page.dart';
import 'package:manga_reader_app/features/books/screens/books_catalog_screen.dart';
import 'package:manga_reader_app/features/books/services/books_repository.dart';
import 'package:manga_reader_app/features/books/services/book_offline_store.dart';

class MockSearchRepo extends BooksRepository {
  final Map<String, List<BookItem>> responses;
  List<String> recordedSearches = [];

  MockSearchRepo({required this.responses})
      : super.withOfflineStore(BookOfflineStore(directoryProvider: () async => throw UnimplementedError()));

  @override
  Future<BookCatalogPage> getBooksPage({
    String source = 'Флибуста (Flibusta.site)',
    String genre = 'Все',
    String search = '',
    Uri? pageUri,
  }) async {
    recordedSearches.add(search);
    final items = responses[search] ?? [];
    return BookCatalogPage(items: items, nextPageUri: null);
  }

  @override
  Future<List<BookItem>> getBooks({
    String source = 'Флибуста (Flibusta.site)',
    String genre = 'Все',
    String search = '',
  }) async {
    return responses[search] ?? [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('BooksCatalogScreen shows query and "Сбросить поиск" button when search returns empty', (tester) async {
    final repo = MockSearchRepo(responses: {
      '': [
        const BookItem(
          id: 'b1',
          title: 'Война и мир',
          author: 'Лев Толстой',
          genre: 'Классика',
          year: 1869,
          rating: 9.5,
          coverUrl: '',
          description: '',
          chapters: [],
        ),
      ],
      'НесуществующаяКнига': [],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BooksCatalogScreen(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial book is displayed
    expect(find.text('Война и мир'), findsOneWidget);

    // Enter search text and submit
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, 'НесуществующаяКнига');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Verify empty state with query quote and reset button
    expect(find.textContaining('По запросу «НесуществующаяКнига» ничего не найдено'), findsOneWidget);
    final resetButton = find.text('Сбросить поиск');
    expect(resetButton, findsOneWidget);

    // Tap reset button
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    // Verify search is cleared and initial book returned
    expect(find.text('Война и мир'), findsOneWidget);
    expect(find.text('НесуществующаяКнига'), findsNothing);
  });

  testWidgets('BooksCatalogScreen shows distinct icon and message for empty downloaded source', (tester) async {
    final repo = MockSearchRepo(responses: {
      '': [],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BooksCatalogScreen(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Downloaded source via popup menu
    await tester.tap(find.byIcon(Icons.library_books));
    await tester.pumpAndSettle();

    await tester.tap(find.text(BooksRepository.downloadedSource).last);
    await tester.pumpAndSettle();

    // Verify offline empty state
    expect(find.text('Нет скачанных книг'), findsOneWidget);
    expect(find.textContaining('сохранённые для офлайн-чтения'), findsOneWidget);
  });
}
