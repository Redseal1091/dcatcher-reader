import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/catalog/models/catalog_filters.dart';
import 'package:manga_reader_app/features/catalog/models/manga.dart';
import 'package:manga_reader_app/features/catalog/state/catalog_provider.dart';
import 'package:manga_reader_app/features/extensions/models/bridge_dtos.dart';
import 'package:manga_reader_app/features/extensions/models/keiyoushi_extension.dart';
import 'package:manga_reader_app/features/extensions/services/native_extensions_bridge.dart';
import 'package:manga_reader_app/features/sources/extension_manga_source.dart';
import 'package:manga_reader_app/features/sources/source_manager.dart';

class MockMappingBridge extends NativeExtensionsBridge {
  final List<ExtensionChapterItem> chapterItems;
  final List<ExtensionCatalogItem> catalogItems;

  MockMappingBridge({
    this.chapterItems = const [],
    this.catalogItems = const [],
  }) : super.forTesting();

  @override
  Future<List<ExtensionChapterItem>> getChapters({
    required String sourceId,
    required String mangaUrl,
  }) async {
    return chapterItems;
  }

  @override
  Future<ExtensionCatalogPage> getCatalog({
    required String sourceId,
    int page = 1,
    String? query,
    String? type,
    String? ordering,
    String? status,
    List<String>? includedGenres,
    List<String>? excludedGenres,
  }) async {
    return ExtensionCatalogPage(
      items: catalogItems,
      hasNextPage: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SourceManager.resetForTesting();
  });

  const sourceId = '1122334455';
  const testSource = KeiyoushiSource(
    id: sourceId,
    name: 'Test Source',
    language: 'ru',
    homeUrl: 'https://test.source',
  );

  group('End-to-End Mapping & Section Filtering Regressions', () {
    test('1. ExtensionMangaSource maps section/genres and CatalogProvider retains items without empty catalog', () async {
      final mockBridge = MockMappingBridge(
        catalogItems: const [
          ExtensionCatalogItem(
            url: '/manga/manhwa1',
            title: 'Korean Webtoon Title',
            genre: 'Action, Webtoon, Fantasy',
            status: '1', // numeric ongoing
          ),
          ExtensionCatalogItem(
            url: '/manga/manga2',
            title: 'Japanese Manga Title',
            genre: 'Romance, Manga',
            status: '2', // numeric completed
          ),
          ExtensionCatalogItem(
            url: '/manga/universal3',
            title: 'Generic Comic',
            genre: 'Drama',
            status: '6', // numeric hiatus
          ),
        ],
      );

      final extensionSource = ExtensionMangaSource(
        source: testSource,
        packageName: 'tachiyomi.test',
        bridge: mockBridge,
      );

      // Section manhwa filter
      final manhwaFilters = CatalogFilters(
        publicationTypes: {PublicationType.manhwa},
      );

      final catalogList = await extensionSource.getCatalog(filters: manhwaFilters);
      expect(catalogList.length, equals(3));

      // Manhwa item should be determined as manhwa
      expect(catalogList[0].type, equals(PublicationType.manhwa));
      // Manga item should be determined as manga
      expect(catalogList[1].type, equals(PublicationType.manga));
      // Untagged item retains PublicationType.all (NOT invented from active filter tab)
      expect(catalogList[2].type, equals(PublicationType.all));

      // Verify CatalogProvider section filtering does NOT yield empty list
      final provider = CatalogProvider();
      provider.filters.publicationTypes = {PublicationType.manhwa};
      provider.switchSource(extensionSource);

      // Await network load in provider
      await Future.delayed(const Duration(milliseconds: 50));

      // Must contain manhwa item (does NOT yield empty catalog)
      expect(provider.mangaList.isNotEmpty, isTrue);
      expect(provider.mangaList.any((m) => m.title == 'Korean Webtoon Title'), isTrue);
    });

    test('2. Chapter dateUpload Long epoch-ms parsing with bounds', () {
      // 1. Long epoch-ms (1709424000000 = 2024-03-03 00:00:00.000Z)
      final dt1 = ExtensionMangaSource.parseDateUpload('1709424000000');
      expect(dt1.millisecondsSinceEpoch, equals(1709424000000));

      // 2. Epoch seconds (1709424000 -> converts to 1709424000000)
      final dt2 = ExtensionMangaSource.parseDateUpload('1709424000');
      expect(dt2.millisecondsSinceEpoch, equals(1709424000000));

      // 3. ISO 8601 string
      final dt3 = ExtensionMangaSource.parseDateUpload('2026-03-03T00:00:00.000Z');
      expect(dt3.toUtc().year, equals(2026));
      expect(dt3.toUtc().month, equals(3));
      expect(dt3.toUtc().day, equals(3));

      // 4. Empty/whitespace fallback
      final dt4 = ExtensionMangaSource.parseDateUpload('');
      expect(dt4, isNotNull);
    });

    test('3. decodeUrl strictly validates source ID and rejects foreign source compound IDs', () {
      // Valid matching source compound ID: returns stripped URL
      final decoded = ExtensionMangaSource.decodeUrl('sourceA', 'sourceA::/title/123');
      expect(decoded, equals('/title/123'));

      // Plain URL without compound prefix: preserved
      final plain = ExtensionMangaSource.decodeUrl('sourceA', '/title/123');
      expect(plain, equals('/title/123'));

      // Mismatched foreign source ID: MUST throw ArgumentError rather than fetching foreign ID
      expect(
        () => ExtensionMangaSource.decodeUrl('sourceA', 'sourceB::/title/123'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('4. Native status Byte numeric mapping to ongoing/completed/hiatus', () {
      // Tachiyomi SManga constants:
      // 1 = ONGOING, 2 = COMPLETED, 4 = PUBLISHING_FINISHED, 5 = CANCELLED, 6 = ON_HIATUS
      expect(ExtensionCatalogItem.parseStatus('1'), equals('ongoing'));
      expect(ExtensionCatalogItem.parseStatus(1), equals('ongoing'));

      expect(ExtensionCatalogItem.parseStatus('2'), equals('completed'));
      expect(ExtensionCatalogItem.parseStatus(2), equals('completed'));
      expect(ExtensionCatalogItem.parseStatus('4'), equals('completed'));
      expect(ExtensionCatalogItem.parseStatus(4), equals('completed'));

      expect(ExtensionCatalogItem.parseStatus('6'), equals('hiatus'));
      expect(ExtensionCatalogItem.parseStatus(6), equals('hiatus'));
      expect(ExtensionCatalogItem.parseStatus('5'), equals('hiatus'));
      expect(ExtensionCatalogItem.parseStatus(5), equals('hiatus'));

      // Verify Manga statusLabel mapping
      final ongoingManga = Manga(
        id: '1',
        title: 'T1',
        description: '',
        coverUrl: '',
        type: PublicationType.manhwa,
        contentRating: ContentRating.safe,
        status: ExtensionCatalogItem.parseStatus('1'),
      );
      expect(ongoingManga.statusLabel, equals('Онгоинг'));

      final completedManga = Manga(
        id: '2',
        title: 'T2',
        description: '',
        coverUrl: '',
        type: PublicationType.manhwa,
        contentRating: ContentRating.safe,
        status: ExtensionCatalogItem.parseStatus('2'),
      );
      expect(completedManga.statusLabel, equals('Закончен'));

      final hiatusManga = Manga(
        id: '3',
        title: 'T3',
        description: '',
        coverUrl: '',
        type: PublicationType.manhwa,
        contentRating: ContentRating.safe,
        status: ExtensionCatalogItem.parseStatus('6'),
      );
      expect(hiatusManga.statusLabel, equals('Заморожен'));
    });

    test('5. Untagged manga is NOT reclassified as manhwa or manhua just because UI filter tab changed', () {
      // 1. Untagged manga under manhwa filter tab retains PublicationType.all
      final typeUnderManhwaTab = ExtensionMangaSource.determinePublicationType(
        genres: ['Action', 'Drama', 'Fantasy'],
        filterTypes: {PublicationType.manhwa},
        title: 'Untagged Action Series',
      );
      expect(typeUnderManhwaTab, equals(PublicationType.all));

      // 2. Untagged manga under manhua filter tab retains PublicationType.all
      final typeUnderManhuaTab = ExtensionMangaSource.determinePublicationType(
        genres: ['Action', 'Drama', 'Fantasy'],
        filterTypes: {PublicationType.manhua},
        title: 'Untagged Action Series',
      );
      expect(typeUnderManhuaTab, equals(PublicationType.all));

      // 3. Untagged manga under manga filter tab retains PublicationType.all
      final typeUnderMangaTab = ExtensionMangaSource.determinePublicationType(
        genres: ['Action', 'Drama', 'Fantasy'],
        filterTypes: {PublicationType.manga},
        title: 'Untagged Action Series',
      );
      expect(typeUnderMangaTab, equals(PublicationType.all));

      // 4. Genuine manhwa metadata is correctly identified regardless of filter tab
      final genuineManhwa = ExtensionMangaSource.determinePublicationType(
        genres: ['Action', 'Webtoon'],
        filterTypes: {PublicationType.manga}, // Even if active tab is manga
        title: 'Korean Comic',
      );
      expect(genuineManhwa, equals(PublicationType.manhwa));
    });
  });
}
