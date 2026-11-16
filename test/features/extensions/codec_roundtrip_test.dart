import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_reader_app/features/extensions/models/bridge_dtos.dart';
import 'package:manga_reader_app/features/extensions/models/keiyoushi_extension.dart';

void main() {
  group('StandardMessageCodec round-trip regression tests for Android nested payloads', () {
    const codec = StandardMessageCodec();

    test('NativePackageDto.fromJson handles Map<Object?, Object?> from StandardMessageCodec', () {
      final nativePayload = {
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
      };

      // Simulate real Android MethodChannel serialization round-trip:
      final encoded = codec.encodeMessage(nativePayload);
      final decoded = codec.decodeMessage(encoded) as Map<dynamic, dynamic>;

      final dto = NativePackageDto.fromJson(Map<String, dynamic>.from(decoded));

      // MUST NOT be dropped!
      expect(dto.sources.length, equals(1));
      expect(dto.sources.first.id, equals('2499283573021234567'));
      expect(dto.sources.first.name, equals('MangaDex'));
    });

    test('ExtensionCatalogPage.fromJson handles Map<Object?, Object?> from StandardMessageCodec', () {
      final catalogPayload = {
        'hasNextPage': true,
        'items': [
          {
            'url': '/manga/123',
            'title': 'Test Manga',
            'thumbnailUrl': 'https://example.com/cover.jpg',
            'description': 'Description',
            'genre': 'Action',
            'status': 'ongoing',
            'author': 'Author',
            'artist': 'Artist',
          }
        ],
      };

      final encoded = codec.encodeMessage(catalogPayload);
      final decoded = codec.decodeMessage(encoded) as Map<dynamic, dynamic>;

      final page = ExtensionCatalogPage.fromJson(Map<String, dynamic>.from(decoded));

      // MUST NOT be dropped!
      expect(page.items.length, equals(1));
      expect(page.items.first.title, equals('Test Manga'));
      expect(page.items.first.url, equals('/manga/123'));
    });
  });
}
