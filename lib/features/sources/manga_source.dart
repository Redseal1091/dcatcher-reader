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

  /// Optional rich metadata fetch (status, genres, description, cover) for detail screens.
  Future<Manga?> getMangaDetails(Manga manga) async => null;

  Future<Map<String, String>> getHeaders() async => const {};

  Future<Uint8List?> fetchImage(String url) async => null;

  /// Applies [CatalogFilters.statusFilter] and [CatalogFilters.ordering] on an
  /// in-memory or fallback manga list uniformly across built-in sources.
  static List<Manga> applyLocalOrderingAndStatus(
    List<Manga> items,
    CatalogFilters filters,
  ) {
    final filtered = items.where((m) {
      if (filters.statusFilter != null) {
        final s = m.status.toLowerCase();
        if (s.isNotEmpty && s != 'unknown') {
          if (filters.statusFilter == 'ongoing' && m.statusLabel != 'Онгоинг') return false;
          if (filters.statusFilter == 'completed' && m.statusLabel != 'Закончен') return false;
          if (filters.statusFilter == 'hiatus' && m.statusLabel != 'Заморожен') return false;
        }
      }
      return true;
    }).toList();

    switch (filters.ordering) {
      case '-id':
        filtered.sort((a, b) => (b.releaseYear ?? 0).compareTo(a.releaseYear ?? 0));
        break;
      case '-count_chapters':
        filtered.sort((a, b) => b.totalChapters.compareTo(a.totalChapters));
        break;
      case '-total_views':
      case '-rating':
      default:
        filtered.sort((a, b) => b.ratingScore.compareTo(a.ratingScore));
        break;
    }
    return filtered;
  }
}
