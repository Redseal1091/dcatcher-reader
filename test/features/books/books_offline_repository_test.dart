import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/books/models/book_item.dart';
import 'package:manga_reader_app/features/books/services/book_offline_store.dart';
import 'package:manga_reader_app/features/books/services/books_repository.dart';

void main() {
  late Directory tempDir;
  late BookOfflineStore offlineStore;
  late BooksRepository repository;
  late int httpCallCount;
  late http.Client mockClient;

  setUp(() async {
    final baseTmp = Platform.environment['TMPDIR'] ??
        Platform.environment['TEMP'] ??
        Directory.systemTemp.path;
    tempDir = await Directory(baseTmp)
        .createTemp('books_offline_repo_test_');
    offlineStore = BookOfflineStore(directoryProvider: () async => tempDir);
    repository = BooksRepository.withOfflineStore(offlineStore);

    httpCallCount = 0;
    mockClient = MockClient((request) async {
      httpCallCount++;
      throw StateError('Unexpected HTTP call to ${request.url}');
    });

    const testBook = BookItem(
      id: '990072',
      title: 'Synthetic Book 990072',
      author: 'Test Author',
      genre: 'Фантастика',
      year: 2024,
      rating: 9.5,
      coverUrl: 'https://example.com/cover990072.jpg',
      description: 'Synthetic description for book 990072',
      chapters: [],
    );

    const testChapters = [
      BookChapter(
        id: '990072_ch1',
        number: '1',
        title: 'Chapter 1: The Beginning',
        content: 'This is the body of chapter 1 for synthetic book 990072.',
      ),
      BookChapter(
        id: '990072_ch2',
        number: '2',
        title: 'Chapter 2: The Continuation',
        content: 'This is the body of chapter 2 for synthetic book 990072.',
      ),
    ];

    await offlineStore.save(testBook, testChapters);
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  test(
      'Test1 getBooksPage(source: downloadedSource) lists saved metadata/text, next null, zero HTTP',
      () async {
    await http.runWithClient(() async {
      final page = await repository.getBooksPage(
        source: BooksRepository.downloadedSource,
      );

      expect(httpCallCount, 0, reason: 'Expected zero HTTP calls');
      expect(page.nextPageUri, isNull);
      expect(page.items.length, 1);

      final loadedBook = page.items.first;
      expect(loadedBook.id, '990072');
      expect(loadedBook.title, 'Synthetic Book 990072');
      expect(loadedBook.author, 'Test Author');
      expect(loadedBook.chapters.length, 2);
      expect(loadedBook.chapters[0].title, 'Chapter 1: The Beginning');
      expect(
        loadedBook.chapters[0].content,
        'This is the body of chapter 1 for synthetic book 990072.',
      );
    }, () => mockClient);
  });

  test('Test2 getBookChapters(metadataOnlySameID) returns disk chapters, zero HTTP',
      () async {
    await http.runWithClient(() async {
      const metadataOnlyBook = BookItem(
        id: '990072',
        title: 'Synthetic Book 990072',
        author: 'Test Author',
        genre: 'Фантастика',
        year: 2024,
        rating: 9.5,
        coverUrl: 'https://example.com/cover990072.jpg',
        description: 'Synthetic description for book 990072',
        chapters: [],
      );

      final chapters = await repository.getBookChapters(metadataOnlyBook);

      expect(httpCallCount, 0, reason: 'Expected zero HTTP calls');
      expect(chapters.length, 2);
      expect(chapters[0].id, '990072_ch1');
      expect(chapters[0].number, '1');
      expect(chapters[0].title, 'Chapter 1: The Beginning');
      expect(
        chapters[0].content,
        'This is the body of chapter 1 for synthetic book 990072.',
      );
      expect(chapters[1].id, '990072_ch2');
      expect(chapters[1].number, '2');
      expect(chapters[1].title, 'Chapter 2: The Continuation');
      expect(
        chapters[1].content,
        'This is the body of chapter 2 for synthetic book 990072.',
      );
    }, () => mockClient);
  });
}
