import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/core/widgets/dcatcher_image.dart';
import 'package:manga_reader_app/features/catalog/models/catalog_filters.dart';
import 'package:manga_reader_app/features/catalog/models/manga.dart';
import 'package:manga_reader_app/features/download/download_manager.dart';
import 'package:manga_reader_app/features/extensions/models/keiyoushi_extension.dart';
import 'package:manga_reader_app/features/extensions/services/native_extensions_bridge.dart';
import 'package:manga_reader_app/features/reader/models/chapter.dart';
import 'package:manga_reader_app/features/sources/extension_manga_source.dart';
import 'package:manga_reader_app/features/sources/manga_source.dart';
import 'package:manga_reader_app/features/sources/source_manager.dart';

class MockDownloadBridge extends NativeExtensionsBridge {
  int fetchImageCalls = 0;
  List<String> fetchedUrls = [];
  bool shouldThrow;
  Uint8List? bytesToReturn;

  MockDownloadBridge({
    this.shouldThrow = false,
    this.bytesToReturn,
  }) : super.forTesting();

  @override
  Future<List<String>> getChapterPages({
    required String sourceId,
    required String chapterUrl,
  }) async {
    return [
      'https://manga.test/page1.webp',
      'https://manga.test/page2.webp',
    ];
  }

  @override
  Future<Uint8List> fetchImage({
    required String sourceId,
    required String url,
  }) async {
    fetchImageCalls++;
    fetchedUrls.add(url);
    if (shouldThrow) {
      throw Exception('Native network error during fetchImage');
    }
    return bytesToReturn ?? Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
  }
}

class MockActiveSource extends MangaSource {
  int getChapterPagesCalls = 0;

  @override
  String get id => 'active_source_id';

  @override
  String get name => 'Active Source';

  @override
  Future<List<Manga>> getCatalog({required CatalogFilters filters, int offset = 0, int limit = 20}) async => [];

  @override
  Future<List<Chapter>> getChapters(String mangaId) async => [];

  @override
  Future<List<String>> getChapterPages(String chapterId) async {
    getChapterPagesCalls++;
    return ['https://active.test/page1.jpg'];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DownloadManager downloadManager;
  const MethodChannel pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    // Use Hermes scratch scoped temp fixture
    final scratchDir = Directory('C:/Users/an474/AppData/Local/hermes/cache/scratch/dcatcher-toolchain');
    final baseDir = scratchDir.existsSync()
        ? Directory('${scratchDir.path}/test_download_fixture')
        : Directory.systemTemp.createTempSync('dm_test_');
    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }
    tempDir = baseDir.createTempSync('case_');

    // Register explicit platform channel mock for path_provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (MethodCall call) async {
      return tempDir.path;
    });

    DownloadManager.baseDirectoryForTesting = tempDir;
    DownloadManager.resetForTesting();
    SourceManager.resetForTesting();
    downloadManager = DownloadManager();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
    DownloadManager.baseDirectoryForTesting = null;
    DownloadManager.resetForTesting();
    SourceManager.resetForTesting();
  });

  group('DownloadManager Extension Routing & Integrity Tests', () {
    test('Extension chapter uses native bytes and overwrites any zero-length page files', () async {
      const sourceId = '1234567890123456789';
      final expectedBytes = Uint8List.fromList([0xAA, 0xBB, 0xCC, 0xDD]);
      final mockBridge = MockDownloadBridge(bytesToReturn: expectedBytes);

      final extensionSource = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: sourceId,
          name: 'Test Native Source',
          language: 'ru',
          homeUrl: 'https://manga.test',
        ),
        packageName: 'tachiyomi.test',
        bridge: mockBridge,
      );

      SourceManager.setMockSources([extensionSource]);

      const chapterId = '$sourceId::/chapter/c10';

      // Simulate a corrupt/partial zero-length page file from a prior crash
      final chapterFolder = Directory('${tempDir.path}/manga_offline/${sourceId}___chapter_c10');
      chapterFolder.createSync(recursive: true);
      final zeroLengthFile = File('${chapterFolder.path}/page_000.webp');
      zeroLengthFile.writeAsBytesSync([]); // 0 bytes
      expect(zeroLengthFile.existsSync(), isTrue);
      expect(zeroLengthFile.lengthSync(), equals(0));

      final success = await downloadManager.downloadChapter(
        chapterId: chapterId,
        mangaTitle: 'Native Manga',
        chapterNumber: '10',
        mangaId: 'manga_1',
      );

      expect(success, isTrue);
      expect(downloadManager.isDownloaded(chapterId), isTrue);
      expect(downloadManager.downloadedChapterIds.contains(chapterId), isTrue);
      expect(mockBridge.fetchImageCalls, equals(2));
      expect(mockBridge.fetchedUrls, equals([
        'https://manga.test/page1.webp',
        'https://manga.test/page2.webp',
      ]));

      // Verify zero-length file was not skipped, but re-downloaded with valid bytes
      final offlinePages = await downloadManager.getOfflinePages(chapterId);
      expect(offlinePages, isNotNull);
      expect(offlinePages!.length, equals(2));

      final firstPageFile = File(offlinePages.first);
      expect(firstPageFile.existsSync(), isTrue);
      expect(firstPageFile.lengthSync(), greaterThan(0));
      expect(firstPageFile.readAsBytesSync(), equals(expectedBytes));
    });

    test('Compound chapter with missing source does NOT fall back to active source and fails typed', () async {
      final activeSource = MockActiveSource();
      // Active source is set as the only loaded source
      SourceManager.setMockSources([
        ExtensionMangaSource(
          source: const KeiyoushiSource(
            id: 'active_source_id',
            name: 'Active Source',
            language: 'ru',
            homeUrl: 'https://active.test',
          ),
          packageName: 'tachiyomi.active',
          bridge: MockDownloadBridge(),
        ),
      ]);

      const missingSourceId = '9876543210987654321';
      const compoundChapterId = '$missingSourceId::/chapter/alien';

      final success = await downloadManager.downloadChapter(
        chapterId: compoundChapterId,
        mangaTitle: 'Alien Manga',
        chapterNumber: '5',
      );

      // Must fail closed
      expect(success, isFalse);
      expect(downloadManager.isDownloaded(compoundChapterId), isFalse);
      expect(downloadManager.downloadedChapterIds.contains(compoundChapterId), isFalse);

      // Active source must NOT have been queried for alien chapter
      expect(activeSource.getChapterPagesCalls, equals(0));

      // Error must be typed MissingExtensionSourceException
      final error = downloadManager.getDownloadError(compoundChapterId);
      expect(error, isA<MissingExtensionSourceException>());
      expect((error as MissingExtensionSourceException).sourceId, equals(missingSourceId));
    });

    test('Network failure on native image fetch reaches fetchImage and does NOT mark chapter as downloaded', () async {
      const sourceId = '5555555555555555555';
      final mockBridge = MockDownloadBridge(shouldThrow: true);

      final extensionSource = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: sourceId,
          name: 'Flaky Source',
          language: 'ru',
          homeUrl: 'https://flaky.test',
        ),
        packageName: 'tachiyomi.flaky',
        bridge: mockBridge,
      );

      SourceManager.setMockSources([extensionSource]);

      const chapterId = '$sourceId::/chapter/fail';
      final success = await downloadManager.downloadChapter(
        chapterId: chapterId,
        mangaTitle: 'Flaky Manga',
        chapterNumber: '1',
      );

      // Verify that download failed
      expect(success, isFalse);
      expect(downloadManager.isDownloaded(chapterId), isFalse);
      expect(downloadManager.downloadedChapterIds.contains(chapterId), isFalse);

      // Verify failure actually reached native fetchImage
      expect(mockBridge.fetchImageCalls, equals(1));
      expect(mockBridge.fetchedUrls, equals(['https://manga.test/page1.webp']));

      // Verify exact error message
      final error = downloadManager.getDownloadError(chapterId);
      expect(error, isNotNull);
      expect(error.toString(), contains('Native network error during fetchImage'));
    });
  });
}
