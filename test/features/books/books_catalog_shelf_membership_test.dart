import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manga_reader_app/features/books/models/book_item.dart';
import 'package:manga_reader_app/features/books/screens/books_catalog_screen.dart';
import 'package:manga_reader_app/features/books/services/book_offline_store.dart';
import 'package:manga_reader_app/features/books/services/books_repository.dart';
import 'package:manga_reader_app/features/library/state/book_shelf_provider.dart';

void main() {
  testWidgets('Catalog details provides explicit add/remove to bookshelf distinct from downloading', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final tempDir = await tester.runAsync(() async {
      final baseTmp = Platform.environment['TMPDIR'] ??
          Platform.environment['TEMP'] ??
          Directory.systemTemp.path;
      return await Directory(baseTmp).createTemp('catalog_shelf_test_');
    });

    addTearDown(() async {
      await tester.runAsync(() async {
        try {
          if (tempDir != null && await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        } catch (_) {}
      });
    });

    final offlineStore = BookOfflineStore(directoryProvider: () async => tempDir!);
    final repository = BooksRepository.withOfflineStore(offlineStore);

    const testChapters = [
      BookChapter(
        id: '895694_ch1',
        number: '1',
        title: 'Chapter 1: Catalog',
        content: 'Prose content for chapter 1.',
      ),
    ];

    const testBook = BookItem(
      id: '895694',
      title: 'Catalog Test Book 895694',
      author: 'Author 895694',
      genre: 'Фантастика',
      year: 2024,
      rating: 9.7,
      coverUrl: 'http://example.invalid/cover895694.jpg',
      description: 'Description for catalog test book 895694',
      chapters: testChapters,
      availableFormats: ['application/epub+zip'],
    );

    await tester.runAsync(() async {
      await offlineStore.save(testBook, testChapters);
    });

    SharedPreferences.setMockInitialValues({
      'books_selected_source_v1': BooksRepository.downloadedSource,
    });

    final shelf = BookShelfProvider();
    await shelf.loadShelf();

    final mockClient = MockClient((request) async {
      throw StateError('Unexpected HTTP call to ${request.url}');
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookShelfProvider>.value(value: shelf),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BooksCatalogScreen(repository: repository),
            ),
          ),
        ),
      );

      // Wait for catalog to load
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('Catalog Test Book 895694').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.text('Catalog Test Book 895694'), findsOneWidget);
      expect(shelf.contains('895694'), isFalse, reason: 'Initially not on user bookshelf');

      // Tap book to open bottom sheet / details
      await tester.tap(find.text('Catalog Test Book 895694'));
      await tester.pump(const Duration(milliseconds: 350));
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 30));
        if (find.text('Удалить с устройства').evaluate().isNotEmpty) {
          break;
        }
      }

      // Both offline action and shelf action must be visible and distinct
      expect(find.text('Удалить с устройства'), findsOneWidget);
      final addShelfButton = find.text('Добавить на книжную полку');
      expect(addShelfButton, findsOneWidget);

      // Tap Add to Shelf
      await tester.tap(addShelfButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Membership is persistent and state updates
      expect(shelf.contains('895694'), isTrue);
      expect(shelf.getById('895694')?.title, 'Catalog Test Book 895694');
      expect(find.text('На книжной полке'), findsOneWidget);

      // Tap Remove from Shelf
      await tester.tap(find.text('На книжной полке'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Membership is removed, book is still downloaded offline
      expect(shelf.contains('895694'), isFalse);
      expect(find.text('Добавить на книжную полку'), findsOneWidget);
      expect(find.text('Удалить с устройства'), findsOneWidget);
    }, () => mockClient);
  });
}
