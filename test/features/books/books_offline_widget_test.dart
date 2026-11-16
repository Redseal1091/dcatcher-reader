import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manga_reader_app/features/books/models/book_item.dart';
import 'package:manga_reader_app/features/books/screens/books_catalog_screen.dart';
import 'package:manga_reader_app/features/books/services/book_offline_store.dart';
import 'package:manga_reader_app/features/books/services/books_repository.dart';
import 'package:manga_reader_app/features/novel_reader/screens/novel_reader_screen.dart';

void main() {
  testWidgets(
      'Offline UI: restored downloadedSource, view saved book, read chapter, delete offline book',
      (WidgetTester tester) async {
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
      return await Directory(baseTmp)
          .createTemp('books_offline_widget_test_');
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

    int httpCallCount = 0;
    final mockClient = MockClient((request) async {
      httpCallCount++;
      throw StateError('Unexpected HTTP call to ${request.url}');
    });

    const testBook = BookItem(
      id: '990073',
      title: 'Synthetic Book 990073',
      author: 'Author 990073',
      genre: 'Фантастика',
      year: 2024,
      rating: 9.7,
      coverUrl: 'http://example.invalid/cover990073.jpg',
      description: 'Short metadata for 990073',
      chapters: [],
    );

    const testChapters = [
      BookChapter(
        id: '990073_ch1',
        number: '1',
        title: 'Chapter 1: The Offline Start',
        content: 'Exact saved prose for chapter 1 of book 990073.',
      ),
      BookChapter(
        id: '990073_ch2',
        number: '2',
        title: 'Chapter 2: The Offline Path',
        content: 'Exact saved prose for chapter 2 of book 990073.',
      ),
    ];

    await tester.runAsync(() async {
      await offlineStore.save(testBook, testChapters);
    });

    SharedPreferences.setMockInitialValues({
      'books_selected_source_v1': BooksRepository.downloadedSource,
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BooksCatalogScreen(repository: repository),
          ),
        ),
      );

      // Bounded settle loop with runAsync for async FS operations
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('Synthetic Book 990073').evaluate().isNotEmpty) {
          break;
        }
      }

      // Restored offline source and visible saved book
      expect(find.text('Synthetic Book 990073'), findsOneWidget);
      expect(httpCallCount, 0, reason: 'Zero HTTP calls allowed for offline catalog');

      // Tap book item to open bottom sheet / details
      await tester.tap(find.text('Synthetic Book 990073'));
      // Finish bottom sheet entering animation
      await tester.pump(const Duration(milliseconds: 350));
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 30));
        if (find.text('Удалить с устройства').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.text('Удалить с устройства'), findsOneWidget);

      final chapterFinder = find.text('Chapter 1: The Offline Start');
      expect(chapterFinder, findsOneWidget);
      await tester.ensureVisible(chapterFinder);
      await tester.pumpAndSettle();

      // Tap first chapter to navigate to NovelReaderScreen
      await tester.tap(chapterFinder);
      // Finish navigation animation
      await tester.pump(const Duration(milliseconds: 350));
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 30));
        if (find.byType(NovelReaderScreen).evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.byType(NovelReaderScreen), findsOneWidget);
      expect(
        find.text('Exact saved prose for chapter 1 of book 990073.'),
        findsOneWidget,
      );
      expect(httpCallCount, 0, reason: 'Zero HTTP calls allowed while reading offline chapter');

      // Back via Icons.arrow_back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump(const Duration(milliseconds: 350));
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 30));
        if (find.byType(NovelReaderScreen).evaluate().isEmpty) {
          break;
        }
      }

      // Reopen book details
      await tester.tap(find.text('Synthetic Book 990073'));
      // Finish bottom sheet entering animation
      await tester.pump(const Duration(milliseconds: 350));
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 30));
        if (find.text('Удалить с устройства').evaluate().isNotEmpty) {
          break;
        }
      }

      // Tap 'Удалить с устройства'
      final deleteFinder = find.text('Удалить с устройства');
      expect(deleteFinder, findsOneWidget);
      await tester.ensureVisible(deleteFinder);
      await tester.pumpAndSettle();
      await tester.tap(deleteFinder);

      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('Synthetic Book 990073').evaluate().isEmpty) {
          break;
        }
      }

      // List is empty of the book
      expect(find.text('Synthetic Book 990073'), findsNothing);

      // Verify fresh store load returns null
      await tester.runAsync(() async {
        final freshStore = BookOfflineStore(directoryProvider: () async => tempDir!);
        final loaded = await freshStore.load('990073');
        expect(loaded, isNull);
      });

      expect(httpCallCount, 0, reason: 'Zero HTTP calls during entire offline flow');
    }, () => mockClient);
  });
}
