import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/catalog/state/catalog_provider.dart';
import 'package:manga_reader_app/features/extensions/models/keiyoushi_extension.dart';
import 'package:manga_reader_app/features/extensions/services/native_extensions_bridge.dart';
import 'package:manga_reader_app/features/sources/extension_manga_source.dart';
import 'package:manga_reader_app/features/sources/source_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String mockChannelName = 'dev.dcatcher/extensions';
  const String mockSourceId = '1234567890123456789';
  const String mockPackage = 'keiyoushi.test.extension';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SourceManager.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(mockChannelName), null);
    SourceManager.resetForTesting();
  });

  ExtensionMangaSource createMockExtensionSource(NativeExtensionsBridge bridge, {String id = mockSourceId}) {
    return ExtensionMangaSource(
      source: KeiyoushiSource(
        id: id,
        name: 'Test Source $id',
        language: 'ru',
        homeUrl: 'https://test.local',
      ),
      packageName: mockPackage,
      bridge: bridge,
    );
  }

  group('CatalogProvider Pagination Regression Tests', () {
    test('page1 returns 2 items with hasNextPage=true, loadMore requests page 2, appends distinct items, honours hasNextPage=false, ignores further loads', () async {
      final requestedPages = <int>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(mockChannelName), (MethodCall call) async {
        if (call.method == 'getCatalog') {
          final page = (call.arguments['page'] as num?)?.toInt() ?? 1;
          requestedPages.add(page);

          if (page == 1) {
            return {
              'hasNextPage': true,
              'items': [
                {
                  'url': '/manga/1',
                  'title': 'Item 1',
                  'thumbnailUrl': 'https://img/1.png',
                  'genre': 'action',
                  'status': 'ongoing',
                },
                {
                  'url': '/manga/2',
                  'title': 'Item 2',
                  'thumbnailUrl': 'https://img/2.png',
                  'genre': 'action',
                  'status': 'ongoing',
                },
              ],
            };
          } else if (page == 2) {
            return {
              'hasNextPage': false,
              'items': [
                {
                  'url': '/manga/3',
                  'title': 'Item 3',
                  'thumbnailUrl': 'https://img/3.png',
                  'genre': 'action',
                  'status': 'completed',
                },
              ],
            };
          }
          return {'hasNextPage': false, 'items': []};
        }
        return null;
      });

      final bridge = NativeExtensionsBridge.forTesting();
      final source = createMockExtensionSource(bridge);
      SourceManager.setMockSources([source]);

      final provider = CatalogProvider();
      await Future<void>.delayed(Duration.zero);

      expect(requestedPages, equals([1]));
      expect(provider.isLoading, isFalse);
      expect(provider.mangaList.length, equals(2));
      expect(provider.mangaList.map((m) => m.title).toList(), equals(['Item 1', 'Item 2']));
      expect(provider.hasNextPage, isTrue);
      expect(provider.isLoadingMore, isFalse);

      final loadMoreFuture = provider.loadMore();
      expect(provider.isLoadingMore, isTrue);
      await loadMoreFuture;

      expect(requestedPages, equals([1, 2]));
      expect(provider.isLoadingMore, isFalse);
      expect(provider.mangaList.length, equals(3));
      expect(provider.mangaList.map((m) => m.title).toList(), equals(['Item 1', 'Item 2', 'Item 3']));
      expect(provider.hasNextPage, isFalse);

      // Further loads should be ignored because hasNextPage is false
      await provider.loadMore();
      expect(requestedPages, equals([1, 2]));
      expect(provider.mangaList.length, equals(3));
    });

    test('concurrent loadMore calls do not issue duplicate requests', () async {
      final completer = Completer<Map<String, dynamic>>();
      var callCount = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(mockChannelName), (MethodCall call) async {
        if (call.method == 'getCatalog') {
          final page = (call.arguments['page'] as num?)?.toInt() ?? 1;
          if (page == 1) {
            return {
              'hasNextPage': true,
              'items': [
                {
                  'url': '/manga/1',
                  'title': 'Item 1',
                  'thumbnailUrl': '',
                  'genre': '',
                  'status': 'ongoing',
                },
              ],
            };
          } else if (page == 2) {
            callCount++;
            return await completer.future;
          }
        }
        return null;
      });

      final bridge = NativeExtensionsBridge.forTesting();
      final source = createMockExtensionSource(bridge);
      SourceManager.setMockSources([source]);

      final provider = CatalogProvider();
      await Future<void>.delayed(Duration.zero);

      expect(provider.mangaList.length, equals(1));
      expect(provider.hasNextPage, isTrue);

      // Trigger two concurrent loadMore calls
      final future1 = provider.loadMore();
      final future2 = provider.loadMore();

      expect(provider.isLoadingMore, isTrue);

      completer.complete({
        'hasNextPage': true,
        'items': [
          {
            'url': '/manga/2',
            'title': 'Item 2',
            'thumbnailUrl': '',
            'genre': '',
            'status': 'ongoing',
          },
        ],
      });

      await Future.wait([future1, future2]);

      expect(callCount, equals(1), reason: 'Concurrent loadMore must guard against duplicate page fetches');
      expect(provider.mangaList.length, equals(2));
      expect(provider.isLoadingMore, isFalse);
    });

    test('duplicate manga IDs from next page are deduplicated', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(mockChannelName), (MethodCall call) async {
        if (call.method == 'getCatalog') {
          final page = (call.arguments['page'] as num?)?.toInt() ?? 1;
          if (page == 1) {
            return {
              'hasNextPage': true,
              'items': [
                {
                  'url': '/manga/1',
                  'title': 'Item 1',
                  'thumbnailUrl': '',
                  'genre': '',
                  'status': 'ongoing',
                },
                {
                  'url': '/manga/2',
                  'title': 'Item 2',
                  'thumbnailUrl': '',
                  'genre': '',
                  'status': 'ongoing',
                },
              ],
            };
          } else if (page == 2) {
            return {
              'hasNextPage': false,
              'items': [
                {
                  'url': '/manga/2', // Duplicate from page 1
                  'title': 'Item 2 Duplicate',
                  'thumbnailUrl': '',
                  'genre': '',
                  'status': 'ongoing',
                },
                {
                  'url': '/manga/3',
                  'title': 'Item 3 New',
                  'thumbnailUrl': '',
                  'genre': '',
                  'status': 'ongoing',
                },
              ],
            };
          }
        }
        return null;
      });

      final bridge = NativeExtensionsBridge.forTesting();
      final source = createMockExtensionSource(bridge);
      SourceManager.setMockSources([source]);

      final provider = CatalogProvider();
      await Future<void>.delayed(Duration.zero);

      expect(provider.mangaList.length, equals(2));

      await provider.loadMore();

      // Duplicate /manga/2 should not appear twice
      expect(provider.mangaList.length, equals(3));
      final ids = provider.mangaList.map((m) => m.id).toList();
      expect(ids.toSet().length, equals(ids.length));
      expect(provider.mangaList[1].title, equals('Item 2'));
      expect(provider.mangaList[2].title, equals('Item 3 New'));
    });

    test('failed page 2 preserves page 1 items and retrying requests the same page 2', () async {
      final pageCalls = <int>[];
      var failPage2Once = true;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(mockChannelName), (MethodCall call) async {
        if (call.method == 'getCatalog') {
          final page = (call.arguments['page'] as num?)?.toInt() ?? 1;
          pageCalls.add(page);

          if (page == 1) {
            return {
              'hasNextPage': true,
              'items': [
                {
                  'url': '/manga/1',
                  'title': 'Item 1',
                  'thumbnailUrl': '',
                  'genre': '',
                  'status': 'ongoing',
                },
              ],
            };
          } else if (page == 2) {
            if (failPage2Once) {
              failPage2Once = false;
              throw PlatformException(code: 'ERROR', message: 'Network failed on page 2');
            }
            return {
              'hasNextPage': false,
              'items': [
                {
                  'url': '/manga/2',
                  'title': 'Item 2',
                  'thumbnailUrl': '',
                  'genre': '',
                  'status': 'ongoing',
                },
              ],
            };
          }
        }
        return null;
      });

      final bridge = NativeExtensionsBridge.forTesting();
      final source = createMockExtensionSource(bridge);
      SourceManager.setMockSources([source]);

      final provider = CatalogProvider();
      await Future<void>.delayed(Duration.zero);

      expect(provider.mangaList.length, equals(1));
      expect(provider.hasNextPage, isTrue);

      // Attempt page 2 - fails
      await provider.loadMore();
      expect(provider.isLoadingMore, isFalse);
      expect(provider.mangaList.length, equals(1), reason: 'Page 1 items must be preserved on page 2 failure');
      expect(provider.hasNextPage, isTrue, reason: 'hasNextPage should remain true or permit retry');

      // Retry page 2 - succeeds
      await provider.loadMore();
      expect(pageCalls, equals([1, 2, 2]), reason: 'Retry must request page 2 again, not page 3');
      expect(provider.mangaList.length, equals(2));
      expect(provider.hasNextPage, isFalse);
    });

    test('changing source or filter while previous page request is pending discards stale results', () async {
      final slowPage1Completer = Completer<Map<String, dynamic>>();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(mockChannelName), (MethodCall call) async {
        if (call.method == 'getCatalog') {
          final sourceId = call.arguments['sourceId'] as String;
          final query = call.arguments['query'] as String?;

          if (sourceId == 'source_1' && query == null) {
            return await slowPage1Completer.future;
          } else if (sourceId == 'source_2') {
            return {
              'hasNextPage': false,
              'items': [
                {
                  'url': '/source2/manga/1',
                  'title': 'Source 2 Item',
                  'thumbnailUrl': '',
                  'genre': '',
                  'status': 'ongoing',
                },
              ],
            };
          }
        }
        return null;
      });

      final bridge = NativeExtensionsBridge.forTesting();
      final source1 = createMockExtensionSource(bridge, id: 'source_1');
      final source2 = createMockExtensionSource(bridge, id: 'source_2');
      SourceManager.setMockSources([source1, source2]);

      final provider = CatalogProvider();
      // Initial loadCatalog for source_1 started, pending slowPage1Completer

      // User immediately switches to source2
      provider.switchSource(source2);
      await Future<void>.delayed(Duration.zero);

      expect(provider.mangaList.length, equals(1));
      expect(provider.mangaList.first.title, equals('Source 2 Item'));

      // Now the old slow request for source1 completes
      slowPage1Completer.complete({
        'hasNextPage': true,
        'items': [
          {
            'url': '/source1/stale',
            'title': 'Stale Source 1 Item',
            'thumbnailUrl': '',
            'genre': '',
            'status': 'ongoing',
          },
        ],
      });
      await Future<void>.delayed(Duration.zero);

      // Must remain source 2's items, stale source 1 result discarded
      expect(provider.mangaList.length, equals(1));
      expect(provider.mangaList.first.title, equals('Source 2 Item'));
    });

    test('server hasNextPage=true is honored even if page has few items and local filtering does not wrongly terminate pagination', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(mockChannelName), (MethodCall call) async {
        if (call.method == 'getCatalog') {
          final page = (call.arguments['page'] as num?)?.toInt() ?? 1;
          if (page == 1) {
            // Short page (only 1 item instead of 20), but backend says hasNextPage = true
            return {
              'hasNextPage': true,
              'items': [
                {
                  'url': '/manga/short1',
                  'title': 'Short Page Item 1',
                  'thumbnailUrl': '',
                  'genre': '',
                  'status': 'ongoing',
                },
              ],
            };
          } else if (page == 2) {
            return {
              'hasNextPage': false,
              'items': [
                {
                  'url': '/manga/short2',
                  'title': 'Short Page Item 2',
                  'thumbnailUrl': '',
                  'genre': '',
                  'status': 'ongoing',
                },
              ],
            };
          }
        }
        return null;
      });

      final bridge = NativeExtensionsBridge.forTesting();
      final source = createMockExtensionSource(bridge);
      SourceManager.setMockSources([source]);

      final provider = CatalogProvider();
      await Future<void>.delayed(Duration.zero);

      expect(provider.mangaList.length, equals(1));
      // Even though page 1 had only 1 item (< limit of 20), hasNextPage MUST be true because server said true!
      expect(provider.hasNextPage, isTrue);

      await provider.loadMore();

      expect(provider.mangaList.length, equals(2));
      expect(provider.hasNextPage, isFalse);
    });
  });
}
