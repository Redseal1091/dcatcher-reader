import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../manga_source.dart';
import '../../catalog/models/manga.dart';
import '../../catalog/models/catalog_filters.dart';
import '../../reader/models/chapter.dart';

class MangaDexSource implements MangaSource {
  @override
  String get name => 'MangaDex';

  @override
  String get id => 'mangadex';

  static const String baseUrl = 'https://api.mangadex.org';

  @override
  Future<List<Manga>> getCatalog({
    required CatalogFilters filters,
    int offset = 0,
    int limit = 24,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': '$limit',
        'offset': '$offset',
        'availableTranslatedLanguage[]': 'ru',
        'includes[]': 'cover_art',
        'order[followedCount]': 'desc',
      };

      if (filters.searchQuery.trim().isNotEmpty) {
        queryParams['title'] = filters.searchQuery.trim();
      }

      // 1. Фильтр по типам (Корея - manhwa, Япония - manga, Китай - manhua)
      final List<String> origLangs = [];
      if (filters.publicationTypes.contains(PublicationType.manhwa)) origLangs.add('ko');
      if (filters.publicationTypes.contains(PublicationType.manga)) origLangs.add('ja');
      if (filters.publicationTypes.contains(PublicationType.manhua)) origLangs.add('zh');

      // 2. Фильтр по возрастному рейтингу
      final List<String> ratings = [];
      for (final r in filters.contentRatings) {
        ratings.add(r.name);
      }

      // Собираем URI с массивами параметров
      final uriBuilder = StringBuffer('$baseUrl/manga?');
      queryParams.forEach((key, val) {
        uriBuilder.write('$key=${Uri.encodeComponent(val.toString())}&');
      });

      for (final lang in origLangs) {
        uriBuilder.write('originalLanguage[]=$lang&');
      }
      for (final r in ratings) {
        uriBuilder.write('contentRating[]=$r&');
      }
      for (final tag in filters.selectedGenreIds) {
        uriBuilder.write('includedTags[]=$tag&');
      }

      final url = Uri.parse(uriBuilder.toString());
      final res = await http.get(url).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List items = data['data'] ?? [];
        return items.map((item) => _parseMangaItem(item)).toList();
      }
    } catch (e) {
      debugPrint('MangaDex API fetch error: $e');
    }

    // Если нет связи с сетью — возвращаем образцовый каталог
    return _getFallbackCatalog(filters);
  }

  Manga _parseMangaItem(Map<String, dynamic> item) {
    final id = item['id'] as String;
    final attrs = item['attributes'] as Map<String, dynamic>;
    final titles = attrs['title'] as Map<String, dynamic>? ?? {};
    final altTitles = (attrs['altTitles'] as List<dynamic>?) ?? [];

    String title = titles['ru'] ?? titles['en'] ?? (titles.isNotEmpty ? titles.values.first : 'Без названия');
    String? altTitle;
    for (final alt in altTitles) {
      if (alt is Map && alt.containsKey('ru')) {
        title = alt['ru'];
      } else if (alt is Map && alt.containsKey('en') && altTitle == null) {
        altTitle = alt['en'];
      }
    }

    final descs = attrs['description'] as Map<String, dynamic>? ?? {};
    final description = descs['ru'] ?? descs['en'] ?? 'Описание отсутствует';

    // Тип по исходному языку
    final origLang = attrs['originalLanguage'] as String? ?? 'ja';
    PublicationType type = PublicationType.manga;
    if (origLang == 'ko') {
      type = PublicationType.manhwa;
    } else if (origLang == 'zh') {
      type = PublicationType.manhua;
    }

    // Возрастной рейтинг
    final ratingStr = attrs['contentRating'] as String? ?? 'safe';
    ContentRating rating = ContentRating.safe;
    if (ratingStr == 'suggestive') rating = ContentRating.suggestive;
    if (ratingStr == 'erotica') rating = ContentRating.erotica;

    // Обложка
    String? fileName;
    final rels = (item['relationships'] as List<dynamic>?) ?? [];
    for (final rel in rels) {
      if (rel['type'] == 'cover_art' && rel['attributes'] != null) {
        fileName = rel['attributes']['fileName'];
        break;
      }
    }

    final coverUrl = fileName != null
        ? 'https://uploads.mangadex.org/covers/$id/$fileName.256.jpg'
        : 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=300';

    // Жанры (теги)
    final tags = (attrs['tags'] as List<dynamic>?) ?? [];
    final List<String> genreList = [];
    for (final t in tags) {
      final tAttrs = t['attributes'] as Map<String, dynamic>?;
      if (tAttrs != null && tAttrs['name'] != null) {
        genreList.add(tAttrs['name']['en'] ?? '');
      }
    }

    return Manga(
      id: id,
      title: title,
      altTitle: altTitle,
      description: description,
      coverUrl: coverUrl,
      type: type,
      contentRating: rating,
      genres: genreList,
      status: attrs['status'] ?? 'ongoing',
      releaseYear: attrs['year'] as int?,
    );
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final url = Uri.parse(
        '$baseUrl/manga/$mangaId/feed?translatedLanguage[]=ru&order[chapter]=desc&limit=100',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List list = data['data'] ?? [];
        return list.map((c) {
          final attrs = c['attributes'];
          return Chapter(
            id: c['id'],
            mangaId: mangaId,
            chapterNumber: attrs['chapter'] ?? '1',
            title: attrs['title'],
            language: 'ru',
            publishedAt: DateTime.tryParse(attrs['publishAt'] ?? '') ?? DateTime.now(),
            pagesCount: attrs['pages'] ?? 20,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching chapters: $e');
    }

    // Образцовые главы для демонстрации
    return List.generate(
      15,
      (i) => Chapter(
        id: 'mock_ch_${15 - i}',
        mangaId: mangaId,
        chapterNumber: '${15 - i}',
        title: 'Глава ${15 - i}',
        publishedAt: DateTime.now().subtract(Duration(days: i * 2)),
      ),
    );
  }

  @override
  Future<List<String>> getChapterPages(String chapterId) async {
    try {
      final url = Uri.parse('$baseUrl/at-home/server/$chapterId');
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final baseUrlHost = data['baseUrl'];
        final chapterData = data['chapter'];
        final hash = chapterData['hash'];
        final List pages = chapterData['data'] ?? [];
        return pages.map((f) => '$baseUrlHost/data/$hash/$f').toList();
      }
    } catch (e) {
      debugPrint('Error fetching chapter pages: $e');
    }

    // Демо-страницы высокого качества (полотно вебтуна)
    return [
      'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800',
      'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=800',
      'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=800',
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800',
    ];
  }

  @override
  Future<String> getDescription(String mangaId) async => '';

  List<Manga> _getFallbackCatalog(CatalogFilters filters) {
    final all = [
      const Manga(
        id: 'solo-leveling',
        title: 'Поднятие уровня в одиночку',
        altTitle: 'Solo Leveling / На' 'едине с богами',
        description: '10 лет назад открылись врата в другие миры, соединив землю с подземельями монстров.',
        coverUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=400',
        type: PublicationType.manhwa,
        contentRating: ContentRating.suggestive,
        genres: ['Экшен', 'Фэнтези', 'Приключения'],
        status: 'completed',
        ratingScore: 9.8,
      ),
      const Manga(
        id: 'omniscient-reader',
        title: 'Всеведущий читатель',
        altTitle: 'Omniscient Reader\'s Viewpoint',
        description: 'Единственный человек, дочитавший бесконечный веб-роман до конца, оказывается внутри этого мира.',
        coverUrl: 'https://images.unsplash.com/photo-1614583225154-5fcdda07019e?w=400',
        type: PublicationType.manhwa,
        contentRating: ContentRating.suggestive,
        genres: ['Экшен', 'Фэнтези', 'Психология'],
        status: 'ongoing',
        ratingScore: 9.7,
      ),
      const Manga(
        id: 'berserk',
        title: 'Берсерк',
        altTitle: 'Berserk',
        description: 'Легендарная темная фэнтези история о мечнике Гатсе, клейме жертвы и поиске возмездия.',
        coverUrl: 'https://images.unsplash.com/photo-1563089145-599997674d42?w=400',
        type: PublicationType.manga,
        contentRating: ContentRating.erotica,
        genres: ['Экшен', 'Драма', 'Ужасы', 'Фэнтези'],
        status: 'ongoing',
        ratingScore: 9.9,
      ),
      const Manga(
        id: 'magic-emperor',
        title: 'Как демон-император стал дворецким',
        altTitle: 'Magic Emperor / Demonic Emperor',
        description: 'Чжо Ифань, сильнейший император демонов, перерождается в теле слуги угасающего клана.',
        coverUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=400',
        type: PublicationType.manhua,
        contentRating: ContentRating.suggestive,
        genres: ['Боевые искусства', 'Фэнтези', 'Экшен'],
        status: 'ongoing',
        ratingScore: 9.4,
      ),
      const Manga(
        id: 'chainsaw-man',
        title: 'Человек-бензопила',
        altTitle: 'Chainsaw Man',
        description: 'Дэндзи живет в крайней нищете, пока не заключает договор с демоном Почитой.',
        coverUrl: 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=400',
        type: PublicationType.manga,
        contentRating: ContentRating.erotica,
        genres: ['Экшен', 'Комедия', 'Сверхъестественное'],
        status: 'ongoing',
        ratingScore: 9.2,
      ),
      const Manga(
        id: 'frieren',
        title: 'Провожающая в последний путь Фрирен',
        altTitle: 'Sousou no Frieren',
        description: 'Приключения бессмертной эльфийки-волшебницы после победы над королем демонов.',
        coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=400',
        type: PublicationType.manga,
        contentRating: ContentRating.safe,
        genres: ['Фэнтези', 'Драма', 'Приключения'],
        status: 'ongoing',
        ratingScore: 9.6,
      ),
    ];

    return all.where((m) {
      if (!filters.publicationTypes.contains(m.type)) return false;
      if (!filters.contentRatings.contains(m.contentRating)) return false;
      if (filters.searchQuery.isNotEmpty &&
          !m.title.toLowerCase().contains(filters.searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }
}
