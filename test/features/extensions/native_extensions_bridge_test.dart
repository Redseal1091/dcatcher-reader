import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_reader_app/features/catalog/models/catalog_filters.dart';
import 'package:manga_reader_app/features/catalog/models/manga.dart';
import 'package:manga_reader_app/features/extensions/models/keiyoushi_extension.dart';
import 'package:manga_reader_app/features/extensions/services/native_extensions_bridge.dart';
import 'package:manga_reader_app/features/sources/extension_manga_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeExtensionsBridge MethodChannel Tests', () {
    const MethodChannel methodChannel = MethodChannel('dev.dcatcher/extensions');
    final List<MethodCall> log = [];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        log.add(call);
        switch (call.method) {
          case 'listInstalled':
            return [
              {
                'packageName': 'eu.kanade.tachiyomi.extension.all.mangadex',
                'versionCode': '205',
                'versionName': '1.6.1',
                'extensionLib': '1.6',
                'sources': [
                  {
                    'id': '2499283573021234567',
                    'name': 'MangaDex',
                    'language': 'en',
                    'homeUrl': 'https://mangadex.org',
                  }
                ],
              }
            ];
          case 'install':
            return true;
          case 'uninstall':
            return true;
          case 'getCatalog':
            return {
              'hasNextPage': true,
              'items': [
                {
                  'url': '/title/12345',
                  'title': 'Test Manga',
                  'thumbnailUrl': 'https://mangadex.org/cover.jpg',
                  'description': 'A great manga',
                  'genre': 'Action, Fantasy',
                  'status': 'ongoing',
                  'author': 'Author One',
                  'artist': 'Artist One',
                }
              ]
            };
          case 'getMangaDetails':
            return {
              'url': '/title/12345',
              'title': 'Test Manga Detailed',
              'thumbnailUrl': 'https://mangadex.org/cover.jpg',
              'description': 'Full description',
              'genre': 'Action',
              'status': 'ongoing',
              'author': 'Author One',
              'artist': 'Artist One',
            };
          case 'getChapters':
            return [
              {
                'url': '/chapter/c1',
                'name': 'Chapter 1',
                'chapterNumber': '1',
                'dateUpload': '2026-01-01T00:00:00Z',
                'scanlator': 'Group One',
              }
            ];
          case 'getChapterPages':
            return [
              'https://mangadex.org/page1.jpg',
              'https://mangadex.org/page2.jpg',
            ];
          case 'fetchImage':
            return Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
          case 'getHeaders':
            return {
              'User-Agent': 'Tachiyomi/1.6',
              'Referer': 'https://mangadex.org/',
            };
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    });

    test('listInstalled parses native package DTOs with 64-bit string source IDs', () async {
      final bridge = NativeExtensionsBridge.forTesting();
      final installed = await bridge.listInstalled();

      expect(installed.length, equals(1));
      expect(installed.first.packageName, equals('eu.kanade.tachiyomi.extension.all.mangadex'));
      expect(installed.first.versionCode, equals('205'));
      expect(installed.first.sources.first.id, equals('2499283573021234567'));
    });

    test('install requires explicit user trust confirmation', () async {
      final bridge = NativeExtensionsBridge.forTesting();

      expect(
        () => bridge.install(
          packageName: 'eu.kanade.tachiyomi.extension.all.mangadex',
          apkUrl: 'https://github.com/keiyoushi/extensions/releases/download/fc7a827-0/test.apk',
          versionCode: '205',
          trustConfirmed: false,
        ),
        throwsA(isA<SecurityException>()),
      );

      final result = await bridge.install(
        packageName: 'eu.kanade.tachiyomi.extension.all.mangadex',
        apkUrl: 'https://github.com/keiyoushi/extensions/releases/download/fc7a827-0/test.apk',
        versionCode: '205',
        trustConfirmed: true,
      );
      expect(result, isTrue);
      expect(log.last.method, equals('install'));
      expect(log.last.arguments['trustConfirmed'], isTrue);
    });

    test('getCatalog, getChapters, getChapterPages, and fetchImage route properly', () async {
      final bridge = NativeExtensionsBridge.forTesting();

      final catalog = await bridge.getCatalog(sourceId: '2499283573021234567', page: 1);
      expect(catalog.hasNextPage, isTrue);
      expect(catalog.items.length, equals(1));
      expect(catalog.items.first.title, equals('Test Manga'));

      final chapters = await bridge.getChapters(
        sourceId: '2499283573021234567',
        mangaUrl: '/title/12345',
      );
      expect(chapters.length, equals(1));
      expect(chapters.first.chapterNumber, equals('1'));

      final pages = await bridge.getChapterPages(
        sourceId: '2499283573021234567',
        chapterUrl: '/chapter/c1',
      );
      expect(pages.length, equals(2));

      final imageBytes = await bridge.fetchImage(
        sourceId: '2499283573021234567',
        url: 'https://mangadex.org/page1.jpg',
      );
      expect(imageBytes.length, equals(4));

      final headers = await bridge.getHeaders(sourceId: '2499283573021234567');
      expect(headers['Referer'], equals('https://mangadex.org/'));
    });

    test('getCatalog with type passes type argument over bridge', () async {
      final bridge = NativeExtensionsBridge.forTesting();

      await bridge.getCatalog(sourceId: '2499283573021234567', page: 1, type: 'manhwa');
      expect(log.last.method, equals('getCatalog'));
      expect(log.last.arguments['type'], equals('manhwa'));

      await bridge.getCatalog(sourceId: '2499283573021234567', page: 2, type: 'manhua');
      expect(log.last.arguments['type'], equals('manhua'));
      expect(log.last.arguments['page'], equals(2));

      await bridge.getCatalog(sourceId: '2499283573021234567', page: 1, type: 'manga');
      expect(log.last.arguments['type'], equals('manga'));
    });

    test('ExtensionMangaSource passes publication type to bridge', () async {
      final bridge = NativeExtensionsBridge.forTesting();
      final source = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: '2499283573021234567',
          name: 'Test Source',
          language: 'ru',
          homeUrl: 'https://example.com',
        ),
        packageName: 'eu.kanade.tachiyomi.extension.ru.test',
        bridge: bridge,
      );

      final filters = CatalogFilters(
        publicationTypes: {PublicationType.manhwa},
      );

      final page = await source.getCatalogPage(filters: filters, page: 1);
      expect(log.last.arguments['type'], equals('manhwa'));
      expect(page.items.length, equals(1));
    });

    test('ExtensionMangaSource passes ordering and status over bridge', () async {
      final bridge = NativeExtensionsBridge.forTesting();
      final source = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: '2499283573021234567',
          name: 'Test Source',
          language: 'ru',
          homeUrl: 'https://example.com',
        ),
        packageName: 'eu.kanade.tachiyomi.extension.ru.test',
        bridge: bridge,
      );

      final filters = CatalogFilters(
        ordering: '-count_chapters',
        statusFilter: 'completed',
      );

      await source.getCatalogPage(filters: filters, page: 1);
      expect(log.last.arguments['ordering'], equals('-count_chapters'));
      expect(log.last.arguments['status'], equals('completed'));
    });
  });
}
