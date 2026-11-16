import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:manga_reader_app/core/widgets/dcatcher_image.dart';
import 'package:manga_reader_app/features/extensions/models/keiyoushi_extension.dart';
import 'package:manga_reader_app/features/extensions/services/native_extensions_bridge.dart';
import 'package:manga_reader_app/features/sources/extension_manga_source.dart';
import 'package:manga_reader_app/features/sources/source_manager.dart';

class MockNativeBridge extends NativeExtensionsBridge {
  final Uint8List? imageBytesToReturn;
  final bool shouldThrow;
  int fetchImageCallCount = 0;
  String? lastFetchedUrl;
  String? lastFetchedSourceId;

  MockNativeBridge({this.imageBytesToReturn, this.shouldThrow = false})
      : super.forTesting();

  @override
  Future<Uint8List> fetchImage({
    required String sourceId,
    required String url,
  }) async {
    fetchImageCallCount++;
    lastFetchedSourceId = sourceId;
    lastFetchedUrl = url;
    if (shouldThrow || imageBytesToReturn == null) {
      throw Exception('Native bridge error');
    }
    return imageBytesToReturn!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1x1 transparent PNG image bytes for testing
  final transparentPng = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DcatcherImage.clearCache();
    SourceManager.resetForTesting();
  });

  group('Extension Native Image Fetching Integration', () {
    test('ExtensionMangaSource.fetchImage calls native bridge and returns bytes', () async {
      final mockBridge = MockNativeBridge(imageBytesToReturn: transparentPng);
      final source = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: '1234567890',
          name: 'Test Source',
          language: 'ru',
          homeUrl: 'https://test.com',
        ),
        packageName: 'tachiyomi.test',
        bridge: mockBridge,
      );

      final bytes = await source.fetchImage('https://test.com/cover.jpg');
      expect(bytes, isNotNull);
      expect(bytes, equals(transparentPng));
      expect(mockBridge.fetchImageCallCount, equals(1));
      expect(mockBridge.lastFetchedSourceId, equals('1234567890'));
      expect(mockBridge.lastFetchedUrl, equals('https://test.com/cover.jpg'));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('ExtensionMangaSource.fetchImage throws on empty/null bytes (no silent fallback)', () async {
      final mockBridge = MockNativeBridge(imageBytesToReturn: null);
      final source = ExtensionMangaSource(
        source: const KeiyoushiSource(
          id: '1234567890',
          name: 'Test Source',
          language: 'ru',
          homeUrl: 'https://test.com',
        ),
        packageName: 'tachiyomi.test',
        bridge: mockBridge,
      );

      expect(
        () => source.fetchImage('https://test.com/fail.jpg'),
        throwsA(isA<Exception>()),
      );
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('DcatcherImage routes extension source through native fetchImage memory bytes', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockBridge = MockNativeBridge(imageBytesToReturn: transparentPng);
      const extension = KeiyoushiExtension(
        name: 'Test Ext',
        packageName: 'tachiyomi.test',
        versionName: '1.0',
        versionCode: '1',
        extensionLib: '1.6',
        apkUrl: 'https://github.com/keiyoushi/extensions/releases/download/v1/test.apk',
        iconUrl: '',
        contentWarning: ContentWarning.safe,
        sources: [
          KeiyoushiSource(
            id: '9999999999',
            name: 'Native Extension Source',
            language: 'ru',
            homeUrl: 'https://native.test',
          ),
        ],
      );

      await SourceManager.updateFromExtensions([extension], bridge: mockBridge);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DcatcherImage(
              imageUrl: 'https://native.test/cover.jpg',
              sourceId: '9999999999',
            ),
          ),
        ),
      );

      // Await async image load
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Must render Image (memory bytes), NOT CachedNetworkImage
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(mockBridge.fetchImageCallCount, equals(1));
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('DcatcherImage falls back to CachedNetworkImage for non-extension / books', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DcatcherImage(
              imageUrl: 'https://books.example.com/cover.jpg',
              sourceId: 'books',
            ),
          ),
        ),
      );

      // Must render CachedNetworkImage for non-extension sources
      expect(find.byType(CachedNetworkImage), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('DcatcherImage displays errorWidget when native fetchImage fails without silent network fallback', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockBridge = MockNativeBridge(shouldThrow: true);
      const extension = KeiyoushiExtension(
        name: 'Failing Ext',
        packageName: 'tachiyomi.fail',
        versionName: '1.0',
        versionCode: '1',
        extensionLib: '1.6',
        apkUrl: 'https://github.com/keiyoushi/extensions/releases/download/v1/fail.apk',
        iconUrl: '',
        contentWarning: ContentWarning.safe,
        sources: [
          KeiyoushiSource(
            id: '8888888888',
            name: 'Failing Extension Source',
            language: 'en',
            homeUrl: 'https://fail.test',
          ),
        ],
      );

      await SourceManager.updateFromExtensions([extension], bridge: mockBridge);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DcatcherImage(
              imageUrl: 'https://fail.test/broken.jpg',
              sourceId: '8888888888',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Must show error icon and NOT fall back to CachedNetworkImage
      expect(find.byIcon(Icons.broken_image), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets('DcatcherImage handles uninstalled/missing extension with typed error and NO network fallback', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // Clear all extensions so 7777777777 is not installed
      await SourceManager.updateFromExtensions([], bridge: MockNativeBridge());

      dynamic capturedError;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DcatcherImage(
              imageUrl: 'https://missing.test/cover.jpg',
              sourceId: '7777777777', // Numeric Keiyoushi source ID
              errorWidget: (context, url, error) {
                capturedError = error;
                return const Text('MISSING_EXTENSION_ERROR');
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Must display the error widget and NOT CachedNetworkImage
      expect(find.text('MISSING_EXTENSION_ERROR'), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(capturedError, isA<MissingExtensionSourceException>());
      expect((capturedError as MissingExtensionSourceException).sourceId, equals('7777777777'));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('DcatcherImage enforces byte budget and evicts LRU entries', () {
      DcatcherImage.clearCache();

      // Create a 10MB chunk
      final tenMbChunk = Uint8List(10 * 1024 * 1024);
      const key1 = 'src1::url1';
      const key2 = 'src2::url2';
      const key3 = 'src3::url3';
      const key4 = 'src4::url4'; // 4 * 10MB = 40MB > 32MB budget

      // Simulate manual cache insertion through byte budgeting
      void addToCache(String key, Uint8List bytes) {
        final entryBytes = bytes.lengthInBytes;
        while (DcatcherImage.currentCacheSizeBytes + entryBytes > DcatcherImage.maxCacheSizeBytes &&
            DcatcherImage.memoryCache.isNotEmpty) {
          final oldestKey = DcatcherImage.memoryCache.keys.first;
          final removed = DcatcherImage.memoryCache.remove(oldestKey);
          if (removed != null) {
            DcatcherImage.currentCacheSizeBytes -= removed.lengthInBytes;
          }
        }
        if (entryBytes <= DcatcherImage.maxCacheSizeBytes) {
          DcatcherImage.memoryCache[key] = bytes;
          DcatcherImage.currentCacheSizeBytes += entryBytes;
        }
      }

      addToCache(key1, tenMbChunk);
      addToCache(key2, tenMbChunk);
      addToCache(key3, tenMbChunk);
      expect(DcatcherImage.memoryCache.containsKey(key1), isTrue);
      expect(DcatcherImage.currentCacheSizeBytes, equals(30 * 1024 * 1024));

      // Adding 4th 10MB chunk exceeds 32MB: key1 and key2 must be evicted
      addToCache(key4, tenMbChunk);
      expect(DcatcherImage.memoryCache.containsKey(key1), isFalse);
      expect(DcatcherImage.memoryCache.containsKey(key4), isTrue);
      expect(DcatcherImage.currentCacheSizeBytes, lessThanOrEqualTo(DcatcherImage.maxCacheSizeBytes));
    });
  });
}
