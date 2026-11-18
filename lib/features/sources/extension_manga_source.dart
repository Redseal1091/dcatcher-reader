import 'dart:typed_data';
import '../catalog/models/catalog_filters.dart';
import '../catalog/models/catalog_page.dart';
import '../catalog/models/manga.dart';
import '../catalog/models/genre.dart';
import '../extensions/models/keiyoushi_extension.dart';
import '../extensions/models/bridge_dtos.dart';
import '../extensions/services/native_extensions_bridge.dart';
import '../reader/models/chapter.dart';
import 'manga_source.dart';

class ExtensionMangaSource extends MangaSource {
  final KeiyoushiSource source;
  final String packageName;
  final NativeExtensionsBridge _bridge;

  ExtensionMangaSource({
    required this.source,
    required this.packageName,
    NativeExtensionsBridge? bridge,
  }) : _bridge = bridge ?? NativeExtensionsBridge();

  @override
  String get id => source.id;

  @override
  String get name => source.name;

  String get language => source.language;

  /// Helper to encode/extract reversible IDs preserving source identity
  static String encodeId(String sourceId, String url) {
    if (url.startsWith('$sourceId::')) return url;
    return '$sourceId::$url';
  }

  static String decodeUrl(String sourceId, String compoundId) {
    if (compoundId.contains('::')) {
      final prefix = compoundId.split('::').first;
      if (prefix != sourceId) {
        throw ArgumentError(
          'Source ID mismatch in decodeUrl: compound ID belongs to "$prefix" but expected "$sourceId"',
        );
      }
      return compoundId.substring(prefix.length + 2);
    }
    return compoundId;
  }

  static PublicationType determinePublicationType({
    required List<String> genres,
    required Set<PublicationType> filterTypes,
    String? title,
  }) {
    final lowerGenres = genres.map((g) => g.toLowerCase()).toSet();
    final lowerTitle = (title ?? '').toLowerCase();

    if (lowerGenres.contains('manhwa') ||
        lowerGenres.contains('манхва') ||
        lowerGenres.contains('вебтун') ||
        lowerGenres.contains('webtoon') ||
        lowerTitle.contains('вебтун')) {
      return PublicationType.manhwa;
    }
    if (lowerGenres.contains('manhua') ||
        lowerGenres.contains('маньхуа') ||
        lowerGenres.contains('культивация')) {
      return PublicationType.manhua;
    }
    if (lowerGenres.contains('manga') ||
        lowerGenres.contains('манга')) {
      return PublicationType.manga;
    }
    return PublicationType.all;
  }

  static DateTime parseDateUpload(String raw) {
    if (raw.trim().isEmpty) return DateTime.now();

    final epoch = int.tryParse(raw.trim());
    if (epoch != null && epoch > 0) {
      if (epoch < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(epoch);
    }

    final parsedIso = DateTime.tryParse(raw.trim());
    if (parsedIso != null) {
      return parsedIso;
    }

    return DateTime.now();
  }

  Manga _mapExtensionItemToManga(ExtensionCatalogItem item, CatalogFilters filters) {
    final compoundMangaId = encodeId(id, item.url);
    final genresList = item.genre.isNotEmpty
        ? item.genre
            .split(',')
            .map((g) => g.trim())
            .where((g) => g.isNotEmpty)
            .toList()
        : <String>[];

    final mangaType = determinePublicationType(
      genres: genresList,
      filterTypes: filters.publicationTypes,
      title: item.title,
    );

    final parsedStatus = ExtensionCatalogItem.parseStatus(item.status);
    final effectiveStatus = (parsedStatus == 'unknown' && filters.statusFilter != null)
        ? filters.statusFilter!
        : parsedStatus;

    return Manga(
      id: compoundMangaId,
      title: item.title.isNotEmpty ? item.title : 'Без названия',
      description: item.description,
      coverUrl: item.thumbnailUrl,
      type: mangaType,
      contentRating: ContentRating.safe,
      genres: genresList,
      status: effectiveStatus,
      sourceId: id,
    );
  }

  @override
  Future<List<Manga>> getCatalog({
    required CatalogFilters filters,
    int offset = 0,
    int limit = 20,
  }) async {
    final page = (offset ~/ limit) + 1;
    final pageResult = await getCatalogPage(
      filters: filters,
      page: page,
      limit: limit,
    );
    return pageResult.items;
  }

  @override
  Future<CatalogPage> getCatalogPage({
    required CatalogFilters filters,
    int page = 1,
    int limit = 20,
  }) async {
    String? type;
    if (filters.publicationTypes.isNotEmpty &&
        !filters.publicationTypes.contains(PublicationType.all) &&
        filters.publicationTypes.length == 1) {
      final activeType = filters.publicationTypes.first;
      type = switch (activeType) {
        PublicationType.manhwa => 'manhwa',
        PublicationType.manhua => 'manhua',
        PublicationType.manga => 'manga',
        _ => null,
      };
    }

    final includedKeywords = <String>{};
    for (final incId in filters.selectedGenreIds) {
      final g = MangaGenre.findById(incId);
      if (g != null) {
        includedKeywords.add(g.nameRu);
        includedKeywords.add(g.nameEn);
        includedKeywords.addAll(g.aliases);
      } else {
        includedKeywords.add(incId);
      }
    }

    final excludedKeywords = <String>{};
    for (final excId in filters.excludedGenres) {
      final g = MangaGenre.findById(excId);
      if (g != null) {
        excludedKeywords.add(g.nameRu);
        excludedKeywords.add(g.nameEn);
        excludedKeywords.addAll(g.aliases);
      } else {
        excludedKeywords.add(excId);
      }
    }

    final catalogPage = await _bridge.getCatalog(
      sourceId: id,
      page: page,
      query: filters.searchQuery.isNotEmpty ? filters.searchQuery : null,
      type: type,
      ordering: filters.ordering.isNotEmpty ? filters.ordering : null,
      status: filters.statusFilter,
      includedGenres: includedKeywords.isNotEmpty ? includedKeywords.toList() : null,
      excludedGenres: excludedKeywords.isNotEmpty ? excludedKeywords.toList() : null,
    );

    final items = catalogPage.items
        .map((item) => _mapExtensionItemToManga(item, filters))
        .toList();

    return CatalogPage(
      items: items,
      hasNextPage: catalogPage.hasNextPage,
    );
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    final mangaUrl = decodeUrl(id, mangaId);
    final rawChapters = await _bridge.getChapters(
      sourceId: id,
      mangaUrl: mangaUrl,
    );

    return rawChapters.map((ch) {
      final compoundChapterId = encodeId(id, ch.url);
      final published = parseDateUpload(ch.dateUpload);

      return Chapter(
        id: compoundChapterId,
        mangaId: mangaId,
        chapterNumber: ch.chapterNumber.isNotEmpty ? ch.chapterNumber : '1',
        title: ch.name.isNotEmpty ? ch.name : null,
        language: source.language,
        scanlationGroup: ch.scanlator.isNotEmpty ? ch.scanlator : 'Переводчики',
        publishedAt: published,
      );
    }).toList();
  }

  @override
  Future<List<String>> getChapterPages(String chapterId) async {
    final chapterUrl = decodeUrl(id, chapterId);
    return _bridge.getChapterPages(
      sourceId: id,
      chapterUrl: chapterUrl,
    );
  }

  @override
  Future<Manga?> getMangaDetails(Manga manga) async {
    try {
      final mangaUrl = decodeUrl(id, manga.id);
      final details = await _bridge.getMangaDetails(
        sourceId: id,
        mangaUrl: mangaUrl,
      );
      final genresList = details.genre.isNotEmpty
          ? details.genre
              .split(',')
              .map((g) => g.trim())
              .where((g) => g.isNotEmpty)
              .toList()
          : manga.genres;
      final detectedType = ExtensionMangaSource.determinePublicationType(
        genres: genresList,
        filterTypes: const {},
        title: details.title.isNotEmpty ? details.title : manga.title,
      );
      final effectiveType = detectedType != PublicationType.all ? detectedType : manga.type;
      final parsedStatus = ExtensionCatalogItem.parseStatus(details.status);
      final effectiveStatus = parsedStatus != 'unknown' ? parsedStatus : manga.status;

      return Manga(
        id: manga.id,
        title: details.title.isNotEmpty ? details.title : manga.title,
        altTitle: manga.altTitle,
        description: details.description.isNotEmpty ? details.description : manga.description,
        coverUrl: details.thumbnailUrl.isNotEmpty ? details.thumbnailUrl : manga.coverUrl,
        type: effectiveType,
        contentRating: manga.contentRating,
        genres: genresList,
        status: effectiveStatus,
        ratingScore: manga.ratingScore,
        releaseYear: manga.releaseYear,
        isLicensed: manga.isLicensed,
        totalChapters: manga.totalChapters,
        sourceId: manga.sourceId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> getDescription(String mangaId) async {
    try {
      final mangaUrl = decodeUrl(id, mangaId);
      final details = await _bridge.getMangaDetails(
        sourceId: id,
        mangaUrl: mangaUrl,
      );
      return details.description;
    } catch (_) {
      return '';
    }
  }

  @override
  Future<Map<String, String>> getHeaders() async {
    return _bridge.getHeaders(sourceId: id);
  }

  @override
  Future<Uint8List?> fetchImage(String url) async {
    final bytes = await _bridge.fetchImage(sourceId: id, url: url);
    if (bytes.isEmpty) {
      throw Exception('Native image fetch failed for extension source $id: no bytes returned');
    }
    return bytes;
  }
}
