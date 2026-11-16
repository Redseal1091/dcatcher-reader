import 'dart:typed_data';
import '../catalog/models/manga.dart';
import '../catalog/models/catalog_filters.dart';
import '../catalog/models/catalog_page.dart';
import '../reader/models/chapter.dart';

abstract class MangaSource {
  String get name;
  String get id;

  Future<List<Manga>> getCatalog({
    required CatalogFilters filters,
    int offset = 0,
    int limit = 20,
  });

  /// Backwards-compatible page-aware catalog fetch.
  /// Default implementation delegates to [getCatalog] and assumes no next page.
  Future<CatalogPage> getCatalogPage({
    required CatalogFilters filters,
    int page = 1,
    int limit = 20,
  }) async {
    final items = await getCatalog(
      filters: filters,
      offset: (page - 1) * limit,
      limit: limit,
    );
    return CatalogPage(items: items, hasNextPage: false);
  }

  Future<List<Chapter>> getChapters(String mangaId);

  Future<List<String>> getChapterPages(String chapterId);

  Future<String> getDescription(String mangaId) async => '';

  Future<Map<String, String>> getHeaders() async => const {};

  Future<Uint8List?> fetchImage(String url) async => null;
}
