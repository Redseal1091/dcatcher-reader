import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../manga_source.dart';
import '../../catalog/models/manga.dart';
import '../../catalog/models/catalog_filters.dart';
import '../../reader/models/chapter.dart';

class RemangaSource implements MangaSource {
  @override
  String get name => 'Remanga';

  @override
  String get id => 'remanga';

  static const String baseUrl = 'https://api.remanga.org/api/v2';
  static const String siteUrl = 'https://remanga.org';

  static const Map<String, String> defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': '$siteUrl/',
    'Accept': 'application/json',
  };

  @override
  Future<List<Manga>> getCatalog({
    required CatalogFilters filters,
    int offset = 0,
    int limit = 24,
  }) async {
    try {
      final fetchCount = filters.hideLicensed ? 40 : limit;
      final page = (offset ~/ limit) + 1;
      Uri url;

      if (filters.searchQuery.trim().isNotEmpty) {
        // Поиск по названию
        final encodedQuery = Uri.encodeComponent(filters.searchQuery.trim());
        url = Uri.parse('$baseUrl/search/?query=$encodedQuery&page=$page');
      } else {
        // Основной каталог с сортировкой
        final order = filters.ordering.isNotEmpty ? filters.ordering : '-rating';
        url = Uri.parse('$baseUrl/titles/?count=$fetchCount&page=$page&ordering=$order');
      }

      final res = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final List items = data['results'] ?? data['titles'] ?? [];

        final List<Manga> parsed = [];
        for (final item in items) {
          final manga = _parseRemangaItem(item);
          if (_matchesFilters(manga, filters)) {
            parsed.add(manga);
          }
        }
        return parsed;
      } else {
        debugPrint('Remanga API status: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Remanga getCatalog error: $e');
    }

    return [];
  }

  bool _matchesFilters(Manga manga, CatalogFilters filters) {
    // Фильтр лицензирования: скрывать лицензированные тайтлы
    if (filters.hideLicensed && manga.isLicensed) {
      return false;
    }
    // Фильтр типов (Манхва / Манга / Маньхуа)
    if (!filters.publicationTypes.contains(manga.type)) {
      return false;
    }
    // Фильтр возрастного рейтинга
    if (!filters.contentRatings.contains(manga.contentRating)) {
      return false;
    }
    return true;
  }

  Manga _parseRemangaItem(Map<String, dynamic> item) {
    final dir = item['dir'] as String? ?? '${item['id']}';
    final mainName = item['main_name'] as String? ?? 'Без названия';
    final secondaryName = item['secondary_name'] as String?;

    // Проверка на статус лицензирования
    final isLicensed = item['is_licensed'] == true ||
        (item['status'] is Map && item['status']['name'] == 'Лицензировано') ||
        (item['status'] is Map && item['status']['id'] == 6);

    // Тип (Манхва / Манга / Маньхуа)
    final typeObj = item['type'];
    final typeName = (typeObj is Map ? typeObj['name'] : '')?.toString().toLowerCase() ?? '';

    PublicationType type = PublicationType.manga;
    if (typeName.contains('манхва')) {
      type = PublicationType.manhwa;
    } else if (typeName.contains('маньхуа')) {
      type = PublicationType.manhua;
    } else if (typeName.contains('манга')) {
      type = PublicationType.manga;
    } else {
      type = PublicationType.manhwa; // Вебтуны по умолчанию
    }

    // Возрастной рейтинг
    final isErotic = item['is_erotic'] == true || item['is_yaoi'] == true;
    final ageLimit = item['age_limit'] as int? ?? 0;
    ContentRating rating = ContentRating.safe;
    if (isErotic || ageLimit >= 2) {
      rating = ContentRating.erotica;
    } else if (ageLimit == 1) {
      rating = ContentRating.suggestive;
    }

    // Обложка
    String coverUrl = 'https://placehold.co/256x360/18181b/fafafa?text=No+Cover';
    final coverObj = item['cover'] ?? item['img'];
    if (coverObj is Map) {
      final path = coverObj['high'] ?? coverObj['mid'] ?? coverObj['low'];
      if (path != null && path.toString().isNotEmpty) {
        final pathStr = path.toString();
        coverUrl = pathStr.startsWith('http') ? pathStr : '$siteUrl$pathStr';
      }
    }

    // Рейтинг
    final avgRatingStr = item['avg_rating']?.toString() ?? '8.5';
    final ratingScore = double.tryParse(avgRatingStr) ?? 8.5;

    // Количество глав
    final chaptersCount = item['count_chapters'] is int
        ? item['count_chapters'] as int
        : int.tryParse(item['count_chapters']?.toString() ?? '0') ?? 0;

    // Статус перевода / публикации
    String statusStr = 'ongoing';
    if (item['translate_status'] is Map && item['translate_status']['name'] != null) {
      statusStr = item['translate_status']['name'].toString();
    } else if (item['status'] is Map && item['status']['name'] != null) {
      statusStr = item['status']['name'].toString();
    }

    return Manga(
      id: dir,
      title: mainName,
      altTitle: secondaryName,
      description: 'Загрузка описания...',
      coverUrl: coverUrl,
      type: type,
      contentRating: rating,
      genres: [typeName.isNotEmpty ? typeName[0].toUpperCase() + typeName.substring(1) : 'Комикс'],
      status: statusStr,
      ratingScore: ratingScore,
      releaseYear: item['issue_year'] as int?,
      isLicensed: isLicensed,
      totalChapters: chaptersCount,
    );
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      // 1. Получаем инфо о тайтле и ветке переводчиков
      final titleUrl = Uri.parse('$baseUrl/titles/$mangaId/');
      final titleRes = await http.get(titleUrl, headers: defaultHeaders).timeout(const Duration(seconds: 10));

      if (titleRes.statusCode != 200) {
        debugPrint('Remanga title error: ${titleRes.statusCode}');
        return [];
      }

      final titleData = jsonDecode(utf8.decode(titleRes.bodyBytes));
      final branches = titleData['branches'] as List<dynamic>? ?? [];
      if (branches.isEmpty) return [];

      final branchId = branches[0]['id'];

      // 2. Получаем главы по branch_id (начиная с 1 главы)
      final chaptersUrl = Uri.parse(
        '$baseUrl/titles/chapters/?branch_id=$branchId&count=100&page=1&ordering=index',
      );
      final chRes = await http.get(chaptersUrl, headers: defaultHeaders).timeout(const Duration(seconds: 10));

      if (chRes.statusCode == 200) {
        final chData = jsonDecode(utf8.decode(chRes.bodyBytes));
        final List results = chData['results'] ?? [];

        return results.map((c) {
          final chNum = c['chapter']?.toString() ?? '1';
          final chName = c['name']?.toString() ?? '';
          final pubList = c['publishers'] as List<dynamic>? ?? [];
          final pubName = pubList.isNotEmpty ? pubList[0]['name'] : 'Переводчики';
          final isPaid = c['is_paid'] == true;

          return Chapter(
            id: c['id'].toString(),
            mangaId: mangaId,
            chapterNumber: chNum,
            title: chName.isNotEmpty ? chName : null,
            scanlationGroup: pubName.toString(),
            publishedAt: DateTime.tryParse(c['upload_date'] ?? '') ?? DateTime.now(),
            isPaid: isPaid,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Remanga getChapters error: $e');
    }

    return [];
  }

  @override
  Future<List<String>> getChapterPages(String chapterId) async {
    try {
      final url = Uri.parse('$baseUrl/titles/chapters/$chapterId/');
      final res = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final pagesRaw = data['pages'] as List<dynamic>? ?? [];

        final List<String> pageUrls = [];
        for (final item in pagesRaw) {
          if (item is List) {
            for (final sub in item) {
              if (sub is Map && sub['link'] != null) {
                pageUrls.add(sub['link'].toString());
              }
            }
          } else if (item is Map && item['link'] != null) {
            pageUrls.add(item['link'].toString());
          }
        }
        return pageUrls;
      }
    } catch (e) {
      debugPrint('Remanga getChapterPages error: $e');
    }

    return [];
  }

  @override
  Future<String> getDescription(String mangaId) async {
    try {
      final url = Uri.parse('$baseUrl/titles/$mangaId/');
      final res = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final rawDesc = data['description']?.toString() ?? '';
        return rawDesc
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&quot;', '"')
            .trim();
      }
    } catch (_) {}
    return 'Описание недоступно.';
  }
}
