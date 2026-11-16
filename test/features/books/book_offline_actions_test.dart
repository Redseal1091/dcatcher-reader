import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manga_reader_app/features/books/models/book_item.dart';
import 'package:manga_reader_app/features/books/services/book_offline_store.dart';
import 'package:manga_reader_app/features/books/services/books_repository.dart';
import 'package:manga_reader_app/features/books/widgets/book_offline_actions.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    final baseTmp = Platform.environment['TMPDIR'] ??
        Platform.environment['TEMP'] ??
        Directory.systemTemp.path;
    tempDir = await Directory(baseTmp).createTemp('book_offline_actions_test_');
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  testWidgets(
      'Test1 BookOfflineActions save button persists chapters to real store and transitions to Скачано with delete option',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final offlineStore = BookOfflineStore(directoryProvider: () async => tempDir);
    final repository = BooksRepository.withOfflineStore(offlineStore);

    const testBook = BookItem(
      id: '990080',
      title: 'Action Test Book 990080',
      author: 'Action Author',
      genre: 'Фантастика',
      year: 2026,
      rating: 9.3,
      coverUrl: 'https://example.com/cover990080.png',
      description: 'Test description for offline actions',
      chapters: [],
      isFree: true,
      availableFormats: ['text/plain'],
    );

    const syntheticChapters = [
      BookChapter(
        id: '990080_ch1',
        number: '1',
        title: 'Chapter 1: The Offline Action',
        content: 'Synthetic chapter 1 content for action verification.',
      ),
      BookChapter(
        id: '990080_ch2',
        number: '2',
        title: 'Chapter 2: The Action Conclusion',
        content: 'Synthetic chapter 2 content for action verification.',
      ),
    ];

    bool onRemovedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookOfflineActions(
            book: testBook,
            repository: repository,
            loadChapters: () async => syntheticChapters,
            onRemoved: () {
              onRemovedCalled = true;
            },
          ),
        ),
      ),
    );

    // Initial status check
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
      if (find.text('Сохранить офлайн').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Сохранить офлайн'), findsOneWidget);

    // Tap Save
    await tester.tap(find.text('Сохранить офлайн'));

    // Bounded runAsync + pump until 'Скачано' appears
    for (int i = 0; i < 30; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 40));
      if (find.text('Скачано').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Скачано'), findsOneWidget);
    expect(find.text('Удалить с устройства'), findsOneWidget);

    // Verify on disk via a fresh store instance (not in-memory proof)
    await tester.runAsync(() async {
      final freshStore = BookOfflineStore(directoryProvider: () async => tempDir);
      final loaded = await freshStore.load('990080');
      expect(loaded, isNotNull);
      expect(loaded!.chapters.length, 2);
      expect(loaded.chapters[0].id, '990080_ch1');
      expect(
        loaded.chapters[0].content,
        'Synthetic chapter 1 content for action verification.',
      );
      expect(loaded.chapters[1].id, '990080_ch2');
      expect(
        loaded.chapters[1].content,
        'Synthetic chapter 2 content for action verification.',
      );
    });

    expect(onRemovedCalled, isFalse);
  });

  testWidgets(
      'Test2 Real FS failure: directory pointing at existing file shows error SnackBar, no Скачано label, and re-enables save button',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Create an existing fixture file where the directory would be expected
    final blockerFile = File('${tempDir.path}/blocker_as_directory');
    await tester.runAsync(() => blockerFile.writeAsString('fixture file content that cannot be a directory'));

    // directoryProvider returns Directory pointing at the file so storageDir.create fails
    final failingStore = BookOfflineStore(
      directoryProvider: () async => Directory(blockerFile.path),
    );
    final repository = BooksRepository.withOfflineStore(failingStore);

    const testBook = BookItem(
      id: '990081',
      title: 'Failing Action Test Book 990081',
      author: 'Action Author',
      genre: 'Фантастика',
      year: 2026,
      rating: 9.3,
      coverUrl: 'https://example.com/cover990081.png',
      description: 'Test description for failing offline actions',
      chapters: [],
      isFree: true,
      availableFormats: ['text/plain'],
    );

    const syntheticChapters = [
      BookChapter(
        id: '990081_ch1',
        number: '1',
        title: 'Chapter 1: The Failing Path',
        content: 'Synthetic chapter content for failure test.',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookOfflineActions(
            book: testBook,
            repository: repository,
            loadChapters: () async => syntheticChapters,
            onRemoved: () {},
          ),
        ),
      ),
    );

    // Initial status check
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
      if (find.text('Сохранить офлайн').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Сохранить офлайн'), findsOneWidget);

    // Tap Save
    await tester.tap(find.text('Сохранить офлайн'));

    // Wait for failure SnackBar
    for (int i = 0; i < 30; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 40));
      if (find.byType(SnackBar).evaluate().isNotEmpty) {
        break;
      }
    }

    // Expect error SnackBar
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Не удалось сохранить книгу'), findsOneWidget);

    // NO 'Скачано' label
    expect(find.text('Скачано'), findsNothing);

    // Save button enabled again
    expect(find.text('Сохранить офлайн'), findsOneWidget);
    final buttonFinder = find.ancestor(
      of: find.text('Сохранить офлайн'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(buttonFinder, findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(buttonFinder);
    expect(button.onPressed, isNotNull, reason: 'Save button should be enabled again');

    // Fixture file unchanged
    final currentContent = await tester.runAsync(() => blockerFile.readAsString());
    expect(currentContent, 'fixture file content that cannot be a directory');
  });
}
