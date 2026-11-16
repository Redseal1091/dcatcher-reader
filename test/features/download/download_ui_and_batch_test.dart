import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/download/download_manager.dart';
import 'package:manga_reader_app/features/library/screens/widgets/downloaded_tab.dart';
import 'package:manga_reader_app/features/sources/source_manager.dart';
import 'package:manga_reader_app/features/sources/extension_manga_source.dart';
import 'package:manga_reader_app/features/extensions/models/keiyoushi_extension.dart';
import 'package:manga_reader_app/features/extensions/services/native_extensions_bridge.dart';

class FastBatchBridge extends NativeExtensionsBridge {
  FastBatchBridge() : super.forTesting();

  @override
  Future<List<String>> getChapterPages({
    required String sourceId,
    required String chapterUrl,
  }) async {
    return [
      'https://manga.test/p1.webp',
      'https://manga.test/p2.webp',
    ];
  }

  @override
  Future<Uint8List> fetchImage({
    required String sourceId,
    required String url,
  }) async {
    return Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DownloadManager dm;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    final scratchDir = Directory('C:/Users/an474/AppData/Local/hermes/cache/scratch/dcatcher-toolchain');
    final baseDir = scratchDir.existsSync()
        ? Directory('${scratchDir.path}/test_download_ui_fixture')
        : Directory.systemTemp.createTempSync('dm_ui_test_');
    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }
    tempDir = baseDir.createTempSync('ui_case_');

    DownloadManager.baseDirectoryForTesting = tempDir;
    DownloadManager.resetForTesting();
    SourceManager.resetForTesting();
    dm = DownloadManager();
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
    DownloadManager.baseDirectoryForTesting = null;
    DownloadManager.resetForTesting();
    SourceManager.resetForTesting();
  });

  group('DownloadManager Active Downloads & Batch Operations Unit Tests', () {
    test('activeDownloads and activeDownloadsCount reflect in-flight downloads and clear upon completion', () async {
      const sourceId = '88888888';
      final bridge = FastBatchBridge();
      final extSource = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: sourceId,
          name: 'Batch Source',
          language: 'ru',
          homeUrl: 'https://manga.test',
        ),
        packageName: 'tachiyomi.batch',
        bridge: bridge,
      );
      SourceManager.setMockSources([extSource]);

      const chapterId = '$sourceId::/ch/1';

      expect(dm.activeDownloadsCount, 0);
      expect(dm.activeDownloads, isEmpty);

      final future = dm.downloadChapter(
        chapterId: chapterId,
        mangaTitle: 'Берсерк',
        chapterNumber: '1',
      );

      // Verify active downloads populated while in flight
      expect(dm.activeDownloadsCount, 1);
      expect(dm.activeDownloads.first.mangaTitle, 'Берсерк');
      expect(dm.activeDownloads.first.chapterNumber, '1');

      final success = await future;
      expect(success, isTrue);

      // Verify active downloads cleared upon success
      expect(dm.activeDownloadsCount, 0);
      expect(dm.activeDownloads, isEmpty);
      expect(dm.isDownloaded(chapterId), isTrue);
    });

    test('batchDelete removes multiple chapters and updates state', () async {
      const sourceId = '88888888';
      final bridge = FastBatchBridge();
      final extSource = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: sourceId,
          name: 'Batch Source',
          language: 'ru',
          homeUrl: 'https://manga.test',
        ),
        packageName: 'tachiyomi.batch',
        bridge: bridge,
      );
      SourceManager.setMockSources([extSource]);

      // Download 3 chapters
      await dm.downloadChapter(chapterId: '$sourceId::/ch/1', mangaTitle: 'Manga', chapterNumber: '1');
      await dm.downloadChapter(chapterId: '$sourceId::/ch/2', mangaTitle: 'Manga', chapterNumber: '2');
      await dm.downloadChapter(chapterId: '$sourceId::/ch/3', mangaTitle: 'Manga', chapterNumber: '3');

      expect(dm.downloadedCount, 3);

      // Batch delete chapter 1 and 3
      await dm.batchDelete(['$sourceId::/ch/1', '$sourceId::/ch/3']);

      expect(dm.downloadedCount, 1);
      expect(dm.isDownloaded('$sourceId::/ch/1'), isFalse);
      expect(dm.isDownloaded('$sourceId::/ch/2'), isTrue);
      expect(dm.isDownloaded('$sourceId::/ch/3'), isFalse);
    });
  });

  group('DownloadedTab Widget Tests (Active Progress & Batch Selection UI)', () {
    testWidgets('DownloadedTab displays active downloads section when in progress', (tester) async {
      dm.setActiveDownloadForTesting(
        'ch_active_1',
        const ActiveDownload(
          chapterId: 'ch_active_1',
          mangaId: 'manga_titan',
          mangaTitle: 'Атака Титанов',
          chapterNumber: '139',
        ),
        0.55,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DownloadedTab(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Expect "Загрузка (1)", manga title, chapter number, and progress visible
      expect(find.text('Загрузка (1)'), findsOneWidget);
      expect(find.textContaining('Атака Титанов'), findsOneWidget);
      expect(find.text('55%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('DownloadedTab batch selection mode allows multi-selection and batch delete', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Seed 2 downloaded chapters using disk fixtures
      final ch1Folder = Directory('${tempDir.path}/manga_offline/ch_1');
      ch1Folder.createSync(recursive: true);
      File('${ch1Folder.path}/meta.json').writeAsStringSync(jsonEncode({
        'mangaId': 'manga_jujutsu',
        'mangaTitle': 'Магическая битва',
        'chapterNumber': '1',
        'downloadedAt': DateTime.now().toIso8601String(),
        'pagesCount': 10,
      }));
      File('${ch1Folder.path}/page_000.webp').writeAsBytesSync([1, 2, 3]);

      final ch2Folder = Directory('${tempDir.path}/manga_offline/ch_2');
      ch2Folder.createSync(recursive: true);
      File('${ch2Folder.path}/meta.json').writeAsStringSync(jsonEncode({
        'mangaId': 'manga_jujutsu',
        'mangaTitle': 'Магическая битва',
        'chapterNumber': '2',
        'downloadedAt': DateTime.now().toIso8601String(),
        'pagesCount': 12,
      }));
      File('${ch2Folder.path}/page_000.webp').writeAsBytesSync([1, 2, 3]);

      dm.addDownloadedChapterForTesting('ch_1');
      dm.addDownloadedChapterForTesting('ch_2');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DownloadedTab(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify stats header
      expect(find.textContaining('Скачано: 2 глав'), findsOneWidget);
      expect(find.text('Выбрать'), findsOneWidget);

      // Enter selection mode
      await tester.tap(find.text('Выбрать'));
      await tester.pumpAndSettle();

      // Checkboxes visible
      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(find.text('Все'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);

      // Tap "Все" to select all
      await tester.tap(find.text('Все'));
      await tester.pumpAndSettle();

      // Verify bottom batch deletion action bar visible
      expect(find.text('Выбрано: 2'), findsOneWidget);
      expect(find.text('Удалить (2)'), findsOneWidget);

      // Tap "Удалить (2)"
      await tester.tap(find.text('Удалить (2)'));
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('Удалить выбранные главы?'), findsOneWidget);
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();

      // Verify all deleted, empty state shown
      expect(dm.downloadedCount, 0);
      expect(find.text('Нет скачанных глав'), findsOneWidget);
    });
  });
}
