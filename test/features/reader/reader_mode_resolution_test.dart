import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/catalog/models/catalog_filters.dart';
import 'package:manga_reader_app/features/catalog/models/manga.dart';
import 'package:manga_reader_app/features/download/download_manager.dart';
import 'package:manga_reader_app/features/reader/models/chapter.dart';
import 'package:manga_reader_app/features/reader/services/chapter_selection.dart';
import 'package:manga_reader_app/features/reader/services/reader_mode.dart';
import 'package:manga_reader_app/features/sources/manga_source.dart';

/// Helper to build minimal synthetic PNG bytes with valid 8-byte PNG signature
/// and 25-byte IHDR chunk containing the specified width and height.
Uint8List makePngHeaderBytes(int width, int height) {
  final bytes = Uint8List(29);
  // PNG signature: 89 50 4E 47 0D 0A 1A 0A
  bytes.setRange(0, 8, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  // IHDR length: 13 (big endian)
  bytes[11] = 13;
  // IHDR chunk type: "IHDR" -> 0x49, 0x48, 0x44, 0x52
  bytes.setRange(12, 16, [0x49, 0x48, 0x44, 0x52]);
  final bdata = ByteData.sublistView(bytes);
  bdata.setUint32(16, width);
  bdata.setUint32(20, height);
  // Bit depth, color type, compression, filter, interlace
  bytes[24] = 8;
  bytes[25] = 6;
  return bytes;
}

class FakeMangaSource extends MangaSource {
  final List<String> pages;
  final Map<String, Uint8List> imageResponses;
  final List<String> requestedImageUrls = [];

  FakeMangaSource({
    required this.pages,
    required this.imageResponses,
  });

  @override
  String get id => 'fake_source';

  @override
  String get name => 'Fake Source';

  @override
  Future<List<Manga>> getCatalog({
    required CatalogFilters filters,
    int offset = 0,
    int limit = 20,
  }) async =>
      [];

  @override
  Future<List<Chapter>> getChapters(String mangaId) async => [];

  @override
  Future<List<String>> getChapterPages(String chapterId) async => pages;

  @override
  Future<Uint8List?> fetchImage(String url) async {
    requestedImageUrls.add(url);
    return imageResponses[url];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DownloadManager.resetForTesting();
    tempDir = await Directory.systemTemp.createTemp('reader_mode_test_');
    DownloadManager.baseDirectoryForTesting = tempDir;
  });

  tearDown(() async {
    DownloadManager.resetForTesting();
    DownloadManager.baseDirectoryForTesting = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ReaderModeResolver remoteprobe regression tests', () {
    test(
        'probe with PublicationType.all probes remote https pages sequentially: first 900x1300 then 900x12000 -> webtoon',
        () async {
      const url1 = 'https://example.com/page1.png';
      const url2 = 'https://example.com/page2.png';

      final source = FakeMangaSource(
        pages: [url1, url2],
        imageResponses: {
          url1: makePngHeaderBytes(900, 1300),
          url2: makePngHeaderBytes(900, 12000),
        },
      );

      const manga = Manga(
        id: 'manga_1',
        title: 'Unknown Comic',
        description: 'Testing remote probe',
        coverUrl: 'https://example.com/cover.png',
        type: PublicationType.all,
        contentRating: ContentRating.safe,
        genres: [],
        sourceId: 'fake_source',
      );

      final resolvedMode = await ReaderModeResolver.resolveEffectiveMode(
        manga: manga,
        source: source,
        sampleChapterId: 'sample_chap_1',
      );

      // Verify fetchImage called with https URLs (not local filesystem)
      expect(source.requestedImageUrls, equals([url1, url2]));
      for (final url in source.requestedImageUrls) {
        expect(url.startsWith('https://'), isTrue);
      }
      expect(resolvedMode, equals(ReaderMode.webtoon));
    });

    test(
        'saved paged override returns paged with no fetchImage calls, preferences isolated by manga and source, saved auto allows probe',
        () async {
      const url1 = 'https://example.com/page1.png';
      const url2 = 'https://example.com/page2.png';

      final source = FakeMangaSource(
        pages: [url1, url2],
        imageResponses: {
          url1: makePngHeaderBytes(900, 12000),
          url2: makePngHeaderBytes(900, 12000),
        },
      );

      const mangaA = Manga(
        id: 'manga_A',
        title: 'Manga A',
        description: '',
        coverUrl: '',
        type: PublicationType.all,
        contentRating: ContentRating.safe,
        genres: [],
        sourceId: 'fake_source',
      );

      const mangaB = Manga(
        id: 'manga_B',
        title: 'Manga B',
        description: '',
        coverUrl: '',
        type: PublicationType.all,
        contentRating: ContentRating.safe,
        genres: [],
        sourceId: 'fake_source',
      );

      const mangaAOtherSource = Manga(
        id: 'manga_A',
        title: 'Manga A',
        description: '',
        coverUrl: '',
        type: PublicationType.all,
        contentRating: ContentRating.safe,
        genres: [],
        sourceId: 'other_source',
      );

      // Save explicit paged override for mangaA on fake_source
      await ReaderModeResolver.savePreference(
        mangaId: mangaA.id,
        sourceId: mangaA.sourceId,
        mode: ReaderMode.paged,
      );

      // 1. mangaA returns paged with ZERO fetchImage calls
      final modeA = await ReaderModeResolver.resolveEffectiveMode(
        manga: mangaA,
        source: source,
        sampleChapterId: 'chap_1',
      );
      expect(modeA, equals(ReaderMode.paged));
      expect(source.requestedImageUrls, isEmpty);

      // 2. Preference isolation: mangaB has no override, should probe and return webtoon
      final modeB = await ReaderModeResolver.resolveEffectiveMode(
        manga: mangaB,
        source: source,
        sampleChapterId: 'chap_1',
      );
      expect(modeB, equals(ReaderMode.webtoon));
      expect(source.requestedImageUrls, equals([url1]));

      // 3. Source isolation: mangaA on 'other_source' is isolated from fake_source
      final otherSource = FakeMangaSource(
        pages: [url1],
        imageResponses: {url1: makePngHeaderBytes(900, 12000)},
      );
      final modeAOther = await ReaderModeResolver.resolveEffectiveMode(
        manga: mangaAOtherSource,
        source: otherSource,
        sampleChapterId: 'chap_1',
      );
      expect(modeAOther, equals(ReaderMode.webtoon));
      expect(otherSource.requestedImageUrls, equals([url1]));

      // 4. Saved auto allows probe
      source.requestedImageUrls.clear();
      await ReaderModeResolver.savePreference(
        mangaId: mangaA.id,
        sourceId: mangaA.sourceId,
        mode: ReaderMode.auto,
      );
      final modeAAuto = await ReaderModeResolver.resolveEffectiveMode(
        manga: mangaA,
        source: source,
        sampleChapterId: 'chap_1',
      );
      expect(modeAAuto, equals(ReaderMode.webtoon));
      expect(source.requestedImageUrls, equals([url1]));
    });

    test(
        'initialChapter helper respects paid status: returns null if all paid, returns first free without bypassing paid chapters',
        () {
      final now = DateTime.now();

      final paidChap1 = Chapter(
        id: 'c1',
        mangaId: 'm1',
        chapterNumber: '1',
        publishedAt: now,
        isPaid: true,
      );
      final paidChap2 = Chapter(
        id: 'c2',
        mangaId: 'm1',
        chapterNumber: '2',
        publishedAt: now.add(const Duration(days: 1)),
        isPaid: true,
      );
      final freeChap3 = Chapter(
        id: 'c3',
        mangaId: 'm1',
        chapterNumber: '3',
        publishedAt: now.add(const Duration(days: 2)),
        isPaid: false,
      );

      // All paid -> returns null (no bypass)
      final allPaid = [paidChap1, paidChap2];
      expect(ChapterSelection.initialChapter(allPaid), isNull);

      // Attempting to resume paid chapter -> returns null when all paid, never bypasses
      expect(
        ChapterSelection.initialChapter(allPaid, resumeChapterId: 'c1'),
        isNull,
      );

      // With free chapter available:
      // Even if resuming paid chapter 'c1', does not bypass paid status and falls back to earliest free chapter
      final mixed = [paidChap1, paidChap2, freeChap3];
      final resumedPaidFallback = ChapterSelection.initialChapter(
        mixed,
        resumeChapterId: 'c1',
      );
      expect(resumedPaidFallback?.id, equals('c3'));

      // Resuming actual free chapter returns that chapter
      final resumedFree = ChapterSelection.initialChapter(
        mixed,
        resumeChapterId: 'c3',
      );
      expect(resumedFree?.id, equals('c3'));

      // Default with mixed list returns earliest free chapter
      final defaultInitial = ChapterSelection.initialChapter(mixed);
      expect(defaultInitial?.id, equals('c3'));
    });
  });
}
