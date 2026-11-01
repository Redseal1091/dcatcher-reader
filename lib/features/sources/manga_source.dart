import '../catalog/models/manga.dart';
import '../catalog/models/catalog_filters.dart';
import '../reader/models/chapter.dart';

abstract class MangaSource {
  String get name;
  String get id;

  Future<List<Manga>> getCatalog({
    required CatalogFilters filters,
    int offset = 0,
    int limit = 20,
  });

  Future<List<Chapter>> getChapters(String mangaId);

  Future<List<String>> getChapterPages(String chapterId);

  Future<String> getDescription(String mangaId) async => '';
}
