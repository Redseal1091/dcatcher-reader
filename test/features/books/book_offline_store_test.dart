import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:manga_reader_app/features/books/models/book_item.dart';
import 'package:manga_reader_app/features/books/services/book_offline_store.dart';

void main() {
  group('BookOfflineStore test-first offline persistence contract', () {
    late Directory fixtureDir;

    setUp(() async {
      final baseTmp = Platform.environment['TMPDIR'] ??
          Platform.environment['TEMP'] ??
          Directory.systemTemp.path;
      final tempRoot = Directory(baseTmp);
      fixtureDir = await tempRoot.createTemp('book_store_fixture_');
    });

    tearDown(() async {
      if (await fixtureDir.exists()) {
        await fixtureDir.delete(recursive: true);
      }
    });

    test(
        'save and fresh store load/list preserves metadata and exact ordered chapters',
        () async {
      final store = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );

      final chapters = [
        const BookChapter(
          id: 'chap_990071_1',
          number: '1',
          title: 'Prologue to the Unknown',
          content: 'In the beginning, synthetic offline testing emerged.',
        ),
        const BookChapter(
          id: 'chap_990071_2',
          number: '2',
          title: 'Ascent to Reliability',
          content: 'All offline chapters must preserve exact text and ordering.',
        ),
      ];

      const book = BookItem(
        id: '990071',
        title: 'Synthetic Offline Chronicles',
        author: 'Hermes Automated Test Author',
        genre: 'Sci-Fi / Engineering',
        coverUrl: 'https://example.com/covers/990071.png',
        description:
            'A fully specified synthetic book verifying offline caching behavior.',
        year: 2026,
        rating: 9.85,
        chapters: [],
        isFree: false,
        availableFormats: ['application/pdf', 'application/epub+zip', 'text/plain'],
      );

      await store.save(book, chapters);

      // Fresh store instance operating on the identical fixture directory
      final freshStore = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );

      final loadedBook = await freshStore.load('990071');
      expect(loadedBook, isNotNull);
      expect(loadedBook!.id, '990071');
      expect(loadedBook.title, 'Synthetic Offline Chronicles');
      expect(loadedBook.author, 'Hermes Automated Test Author');
      expect(loadedBook.genre, 'Sci-Fi / Engineering');
      expect(loadedBook.coverUrl, 'https://example.com/covers/990071.png');
      expect(
        loadedBook.description,
        'A fully specified synthetic book verifying offline caching behavior.',
      );
      expect(loadedBook.year, 2026);
      expect(loadedBook.rating, 9.85);
      expect(loadedBook.isFree, false);
      expect(loadedBook.availableFormats, [
        'application/pdf',
        'application/epub+zip',
        'text/plain',
      ]);

      expect(loadedBook.chapters.length, 2);
      expect(loadedBook.chapters[0].id, 'chap_990071_1');
      expect(loadedBook.chapters[0].number, '1');
      expect(loadedBook.chapters[0].title, 'Prologue to the Unknown');
      expect(
        loadedBook.chapters[0].content,
        'In the beginning, synthetic offline testing emerged.',
      );

      expect(loadedBook.chapters[1].id, 'chap_990071_2');
      expect(loadedBook.chapters[1].number, '2');
      expect(loadedBook.chapters[1].title, 'Ascent to Reliability');
      expect(
        loadedBook.chapters[1].content,
        'All offline chapters must preserve exact text and ordering.',
      );

      final listResults = await freshStore.list();
      expect(listResults.any((item) => item.id == '990071'), isTrue);
      final listItem = listResults.firstWhere((item) => item.id == '990071');
      expect(listItem.title, 'Synthetic Offline Chronicles');
      expect(listItem.author, 'Hermes Automated Test Author');
      expect(listItem.rating, 9.85);
      expect(listItem.availableFormats, [
        'application/pdf',
        'application/epub+zip',
        'text/plain',
      ]);
    });

    test(
        'oversize chapter content >16MiB UTF8 rejects save and preserves original snapshot',
        () async {
      final store = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );

      const book = BookItem(
        id: '990071',
        title: 'Synthetic Offline Chronicles',
        author: 'Hermes Automated Test Author',
        genre: 'Sci-Fi / Engineering',
        coverUrl: 'https://example.com/covers/990071.png',
        description:
            'A fully specified synthetic book verifying offline caching behavior.',
        year: 2026,
        rating: 9.85,
        chapters: [],
        isFree: false,
        availableFormats: ['application/pdf', 'application/epub+zip', 'text/plain'],
      );

      final initialChapters = [
        const BookChapter(
          id: 'chap_990071_1',
          number: '1',
          title: 'Prologue to the Unknown',
          content: 'Original completed content preserved.',
        ),
      ];

      await store.save(book, initialChapters);

      final snapshotFile =
          File('${fixtureDir.path}/books_offline_v1/990071.json');
      expect(await snapshotFile.exists(), isTrue);
      final originalSnapshotBytes = await snapshotFile.readAsBytes();

      // >16MiB UTF8 chapter content
      final oversizeContent = 'A' * (16 * 1024 * 1024 + 1024);
      final oversizedChapters = [
        BookChapter(
          id: 'chap_990071_1',
          number: '1',
          title: 'Oversized Chapter',
          content: oversizeContent,
        ),
      ];

      expect(
        () => store.save(book, oversizedChapters),
        throwsA(isA<ArgumentError>()),
      );

      // Verify directory finalized snapshot is still original
      final currentSnapshotBytes = await snapshotFile.readAsBytes();
      expect(currentSnapshotBytes, equals(originalSnapshotBytes));

      // Fresh load preserves old completed text (not null)
      final freshStore = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );
      final loadedBook = await freshStore.load('990071');
      expect(loadedBook, isNotNull);
      expect(loadedBook!.chapters.length, 1);
      expect(
        loadedBook.chapters[0].content,
        'Original completed content preserved.',
      );
    });

    test('tampered version to 99 in finalized JSON results in load null and list empty',
        () async {
      final store = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );

      const book = BookItem(
        id: '990071',
        title: 'Synthetic Offline Chronicles',
        author: 'Hermes Automated Test Author',
        genre: 'Sci-Fi / Engineering',
        coverUrl: 'https://example.com/covers/990071.png',
        description:
            'A fully specified synthetic book verifying offline caching behavior.',
        year: 2026,
        rating: 9.85,
        chapters: [],
        isFree: false,
        availableFormats: ['application/pdf', 'application/epub+zip', 'text/plain'],
      );

      final chapters = [
        const BookChapter(
          id: 'chap_990071_1',
          number: '1',
          title: 'Prologue to the Unknown',
          content: 'In the beginning, synthetic offline testing emerged.',
        ),
      ];

      await store.save(book, chapters);

      final snapshotFile =
          File('${fixtureDir.path}/books_offline_v1/990071.json');
      expect(await snapshotFile.exists(), isTrue);

      final jsonContent = await snapshotFile.readAsString();
      final Map<String, dynamic> data =
          jsonDecode(jsonContent) as Map<String, dynamic>;
      data['version'] = 99;
      await snapshotFile.writeAsString(jsonEncode(data));

      final freshStore = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );
      final loadedBook = await freshStore.load('990071');
      expect(loadedBook, isNull);

      final listResults = await freshStore.list();
      expect(listResults, isEmpty);
    });

    test('replacing chapters with empty list in finalized snapshot results in load null and list empty',
        () async {
      final store = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );

      const book = BookItem(
        id: '990071',
        title: 'Synthetic Offline Chronicles',
        author: 'Hermes Automated Test Author',
        genre: 'Sci-Fi / Engineering',
        coverUrl: 'https://example.com/covers/990071.png',
        description:
            'A fully specified synthetic book verifying offline caching behavior.',
        year: 2026,
        rating: 9.85,
        chapters: [],
        isFree: false,
        availableFormats: ['application/pdf', 'application/epub+zip', 'text/plain'],
      );

      final chapters = [
        const BookChapter(
          id: 'chap_990071_1',
          number: '1',
          title: 'Prologue to the Unknown',
          content: 'In the beginning, synthetic offline testing emerged.',
        ),
      ];

      await store.save(book, chapters);

      final snapshotFile =
          File('${fixtureDir.path}/books_offline_v1/990071.json');
      expect(await snapshotFile.exists(), isTrue);

      final jsonContent = await snapshotFile.readAsString();
      final Map<String, dynamic> data =
          jsonDecode(jsonContent) as Map<String, dynamic>;
      data['chapters'] = [];
      await snapshotFile.writeAsString(jsonEncode(data));

      final freshStore = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );
      final loadedBook = await freshStore.load('990071');
      expect(loadedBook, isNull);

      final listResults = await freshStore.list();
      expect(listResults, isEmpty);
    });

    test(
        'nonempty chapters array with all whitespace contents results in load null and list empty',
        () async {
      final store = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );

      const book = BookItem(
        id: '990074',
        title: 'Whitespace Chapters Chronicle',
        author: 'Hermes Automated Test Author',
        genre: 'Sci-Fi / Engineering',
        coverUrl: 'https://example.com/covers/990074.png',
        description: 'Synthetic book for testing whitespace chapter contents.',
        year: 2026,
        rating: 9.85,
        chapters: [],
        isFree: false,
        availableFormats: ['text/plain'],
      );

      final chapters = [
        const BookChapter(
          id: 'chap_990074_1',
          number: '1',
          title: 'Prologue',
          content: 'Valid content before corrupting snapshot.',
        ),
      ];

      await store.save(book, chapters);

      final snapshotFile =
          File('${fixtureDir.path}/books_offline_v1/990074.json');
      expect(await snapshotFile.exists(), isTrue);

      final jsonContent = await snapshotFile.readAsString();
      final Map<String, dynamic> data =
          jsonDecode(jsonContent) as Map<String, dynamic>;
      data['chapters'] = [
        {
          'id': 'chap_990074_1',
          'number': '1',
          'title': 'Empty whitespace chapter 1',
          'content': '   \n\t   ',
        },
        {
          'id': 'chap_990074_2',
          'number': '2',
          'title': 'Empty whitespace chapter 2',
          'content': '',
        },
      ];
      await snapshotFile.writeAsString(jsonEncode(data));

      final freshStore = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );
      final loadedBook = await freshStore.load('990074');
      expect(loadedBook, isNull);

      final listResults = await freshStore.list();
      expect(listResults, isEmpty);
    });

    test(
        'rating invalid alone in snapshot results in load null and list empty without invented defaults',
        () async {
      final store = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );

      const book = BookItem(
        id: '990075',
        title: 'Rating Invalid Chronicle',
        author: 'Hermes Automated Test Author',
        genre: 'Sci-Fi / Engineering',
        coverUrl: 'https://example.com/covers/990075.png',
        description: 'Synthetic book for testing rating invalid alone.',
        year: 2026,
        rating: 9.85,
        chapters: [],
        isFree: false,
        availableFormats: ['text/plain'],
      );

      final chapters = [
        const BookChapter(
          id: 'chap_990075_1',
          number: '1',
          title: 'Prologue',
          content: 'Valid content that has non-empty body.',
        ),
      ];

      await store.save(book, chapters);

      final snapshotFile =
          File('${fixtureDir.path}/books_offline_v1/990075.json');
      expect(await snapshotFile.exists(), isTrue);

      final jsonContent = await snapshotFile.readAsString();
      final Map<String, dynamic> data =
          jsonDecode(jsonContent) as Map<String, dynamic>;
      final bookMap = data['book'] as Map<String, dynamic>;
      bookMap['rating'] = 'invalid';
      await snapshotFile.writeAsString(jsonEncode(data));

      final freshStore = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );
      final loadedBook = await freshStore.load('990075');
      expect(loadedBook, isNull);

      final listResults = await freshStore.list();
      expect(listResults, isEmpty);
    });

    test(
        'isFree invalid alone in snapshot results in load null and list empty without invented defaults',
        () async {
      final store = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );

      const book = BookItem(
        id: '990076',
        title: 'IsFree Invalid Chronicle',
        author: 'Hermes Automated Test Author',
        genre: 'Sci-Fi / Engineering',
        coverUrl: 'https://example.com/covers/990076.png',
        description: 'Synthetic book for testing isFree invalid alone.',
        year: 2026,
        rating: 9.85,
        chapters: [],
        isFree: false,
        availableFormats: ['text/plain'],
      );

      final chapters = [
        const BookChapter(
          id: 'chap_990076_1',
          number: '1',
          title: 'Prologue',
          content: 'Valid content that has non-empty body.',
        ),
      ];

      await store.save(book, chapters);

      final snapshotFile =
          File('${fixtureDir.path}/books_offline_v1/990076.json');
      expect(await snapshotFile.exists(), isTrue);

      final jsonContent = await snapshotFile.readAsString();
      final Map<String, dynamic> data =
          jsonDecode(jsonContent) as Map<String, dynamic>;
      final bookMap = data['book'] as Map<String, dynamic>;
      bookMap['isFree'] = 'invalid';
      await snapshotFile.writeAsString(jsonEncode(data));

      final freshStore = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );
      final loadedBook = await freshStore.load('990076');
      expect(loadedBook, isNull);

      final listResults = await freshStore.list();
      expect(listResults, isEmpty);
    });

    test(
        'mixed availableFormats (contains non-string) alone in snapshot results in load null and list empty without invented defaults',
        () async {
      final store = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );

      const book = BookItem(
        id: '990077',
        title: 'AvailableFormats Invalid Chronicle',
        author: 'Hermes Automated Test Author',
        genre: 'Sci-Fi / Engineering',
        coverUrl: 'https://example.com/covers/990077.png',
        description: 'Synthetic book for testing availableFormats mixed types alone.',
        year: 2026,
        rating: 9.85,
        chapters: [],
        isFree: false,
        availableFormats: ['text/plain'],
      );

      final chapters = [
        const BookChapter(
          id: 'chap_990077_1',
          number: '1',
          title: 'Prologue',
          content: 'Valid content that has non-empty body.',
        ),
      ];

      await store.save(book, chapters);

      final snapshotFile =
          File('${fixtureDir.path}/books_offline_v1/990077.json');
      expect(await snapshotFile.exists(), isTrue);

      final jsonContent = await snapshotFile.readAsString();
      final Map<String, dynamic> data =
          jsonDecode(jsonContent) as Map<String, dynamic>;
      final bookMap = data['book'] as Map<String, dynamic>;
      bookMap['availableFormats'] = ['text/html', 7];
      await snapshotFile.writeAsString(jsonEncode(data));

      final freshStore = BookOfflineStore(
        directoryProvider: () async => fixtureDir,
      );
      final loadedBook = await freshStore.load('990077');
      expect(loadedBook, isNull);

      final listResults = await freshStore.list();
      expect(listResults, isEmpty);
    });
  });
}
