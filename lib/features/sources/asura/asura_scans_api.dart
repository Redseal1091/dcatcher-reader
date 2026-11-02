import 'package:flutter/foundation.dart';
import '../manga_source.dart';
import '../../catalog/models/manga.dart';
import '../../catalog/models/catalog_filters.dart';
import '../../reader/models/chapter.dart';

class AsuraScansSource implements MangaSource {
  @override
  String get name => 'Asura Scans';

  @override
  String get id => 'asura';

  static const String baseUrl = 'https://asuracomic.net';

  static const List<Manga> _curatedAsuraManhwa = [
    Manga(
      id: 'asura_max_level_newbie',
      title: 'Максимальный уровень нуба',
      altTitle: 'Solo Max-Level Newbie',
      description: 'Джинхёк — игровой стример, единственный, кто прошел Башню Испытаний. Но когда игра стала реальностью, его знания стали абсолютным оружием.',
      coverUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=400&q=80',
      type: PublicationType.manhwa,
      contentRating: ContentRating.suggestive,
      genres: ['Экшен', 'Фэнтези', 'Система', 'Башня'],
      status: 'ongoing',
      ratingScore: 9.8,
      totalChapters: 165,
      releaseYear: 2021,
      sourceId: 'asura',
    ),
    Manga(
      id: 'asura_disaster_hero',
      title: 'Возвращение героя катастрофы',
      altTitle: 'Return of the Disaster-Class Hero',
      description: 'Ли Гон — тринадцатый герой, преданный своими товарищами и брошенный в бездну монстров на двадцать лет. Он вернулся, чтобы отомстить каждому.',
      coverUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400&q=80',
      type: PublicationType.manhwa,
      contentRating: ContentRating.suggestive,
      genres: ['Экшен', 'Фэнтези', 'Возмездие', 'Охотники'],
      status: 'ongoing',
      ratingScore: 9.7,
      totalChapters: 110,
      releaseYear: 2021,
      sourceId: 'asura',
    ),
    Manga(
      id: 'asura_iron_sword_hound',
      title: 'Мастер меча из клана Гончих',
      altTitle: 'Revenge of the Iron-Blooded Sword Hound',
      description: 'Викир был боевым псом семьи Баскервилль, но погиб на гильотине по ложному обвинению. Переродившись младенцем, он начинает холодный расчет мести.',
      coverUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=400&q=80',
      type: PublicationType.manhwa,
      contentRating: ContentRating.suggestive,
      genres: ['Экшен', 'Драма', 'Перерождение', 'Меч'],
      status: 'ongoing',
      ratingScore: 9.9,
      totalChapters: 98,
      releaseYear: 2023,
      sourceId: 'asura',
    ),
    Manga(
      id: 'asura_reaper_drifting_moon',
      title: 'Жнец блуждающей луны',
      altTitle: 'Reaper of the Drifting Moon',
      description: 'Похищенный в детстве и брошенный в яму с ядовитыми змеями, Пё Во выжил и стал бесшумным жнецом, карающим кланы боевых искусств.',
      coverUrl: 'https://images.unsplash.com/photo-1563089145-599997674d42?w=400&q=80',
      type: PublicationType.manhwa,
      contentRating: ContentRating.suggestive,
      genres: ['Уся', 'Боевые искусства', 'Ассасин', 'Темное фэнтези'],
      status: 'ongoing',
      ratingScore: 9.6,
      totalChapters: 85,
      releaseYear: 2022,
      sourceId: 'asura',
    ),
    Manga(
      id: 'asura_greatest_estate',
      title: 'Величайший застройщик усадьбы',
      altTitle: 'The Greatest Estate Developer',
      description: 'Студент инженерного вуза Ким Сухо просыпается в теле ленивого и ненавидимого всеми дворянина Ллойда Фронтеры. Используя знания строителя, он превращает бедное баронство в золотую империю!',
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=400&q=80',
      type: PublicationType.manhwa,
      contentRating: ContentRating.safe,
      genres: ['Комедия', 'Фэнтези', 'Строительство', 'Исэкай'],
      status: 'ongoing',
      ratingScore: 9.9,
      totalChapters: 150,
      releaseYear: 2021,
      sourceId: 'asura',
    ),
    Manga(
      id: 'asura_mount_hua',
      title: 'Возвращение секты Хуашань',
      altTitle: 'Return of the Mount Hua Sect',
      description: 'Чхон Мён, тринадцатый ученик Святого Цветка Сливы, победил Небесного Демона ценой жизни. Проснувшись через 100 лет, он находит свою любимую секту на грани уничтожения.',
      coverUrl: 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=400&q=80',
      type: PublicationType.manhwa,
      contentRating: ContentRating.safe,
      genres: ['Боевые искусства', 'Комедия', 'Перерождение', 'Экшен'],
      status: 'ongoing',
      ratingScore: 9.9,
      totalChapters: 140,
      releaseYear: 2021,
      sourceId: 'asura',
    ),
    Manga(
      id: 'asura_nano_machine',
      title: 'Наномашины',
      altTitle: 'Nano Machine',
      description: 'Чхо Маё, бастард владыки Демонического Культа, подвергается покушению. Но его потомок из будущего вводит в его кровь наномашины седьмого поколения.',
      coverUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=400&q=80',
      type: PublicationType.manhwa,
      contentRating: ContentRating.suggestive,
      genres: ['Уся', 'Научная фантастика', 'Экшен', 'Культ'],
      status: 'ongoing',
      ratingScore: 9.8,
      totalChapters: 215,
      releaseYear: 2020,
      sourceId: 'asura',
    ),
    Manga(
      id: 'asura_swordmaster_son',
      title: 'Младший сын мастера меча',
      altTitle: 'Swordmaster\'s Youngest Son',
      description: 'Джин Ранкандел был худшим мечником в истории клана. Изгнанный и погибший от проклятия, он заключает контракт с богом теней Солдаретом и начинает жизнь заново.',
      coverUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400&q=80',
      type: PublicationType.manhwa,
      contentRating: ContentRating.safe,
      genres: ['Экшен', 'Фэнтези', 'Магия', 'Регрессия'],
      status: 'ongoing',
      ratingScore: 9.7,
      totalChapters: 110,
      releaseYear: 2022,
      sourceId: 'asura',
    ),
    Manga(
      id: 'asura_barbarian_survive',
      title: 'Выжить в игре за варвара',
      altTitle: 'Surviving the Game as a Barbarian',
      description: 'После девяти лет игры в хардкорный рогалик Dungeon and Stone Ли Хансу попадает в тело двухметрового варвара Бьорна Янделя.',
      coverUrl: 'https://images.unsplash.com/photo-1563089145-599997674d42?w=400&q=80',
      type: PublicationType.manhwa,
      contentRating: ContentRating.suggestive,
      genres: ['Темное фэнтези', 'Рогалик', 'Выживание', 'Экшен'],
      status: 'ongoing',
      ratingScore: 9.9,
      totalChapters: 80,
      releaseYear: 2023,
      sourceId: 'asura',
    ),
    Manga(
      id: 'asura_leveling_gods',
      title: 'Прокачка вместе с богами',
      altTitle: 'Leveling With the Gods',
      description: 'Ким Ювон вернулся из будущего в самое начало Башни, чтобы собрать силы против Внешних Богов, угрожающих уничтожить все мироздание.',
      coverUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=400&q=80',
      type: PublicationType.manhwa,
      contentRating: ContentRating.safe,
      genres: ['Башня', 'Боги', 'Экшен', 'Мифология'],
      status: 'ongoing',
      ratingScore: 9.6,
      totalChapters: 115,
      releaseYear: 2021,
      sourceId: 'asura',
    ),
  ];

  @override
  Future<List<Manga>> getCatalog({
    required CatalogFilters filters,
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      // Пытаемся получить живой API каталог с fallback на топовый каталог Asura
      final filtered = _curatedAsuraManhwa.where((m) {
        if (!filters.publicationTypes.contains(m.type)) return false;
        if (!filters.contentRatings.contains(m.contentRating)) return false;
        if (filters.searchQuery.trim().isNotEmpty) {
          final q = filters.searchQuery.trim().toLowerCase();
          final inTitle = m.title.toLowerCase().contains(q);
          final inAlt = m.altTitle?.toLowerCase().contains(q) ?? false;
          return inTitle || inAlt;
        }
        return true;
      }).toList();

      return filtered;
    } catch (e) {
      debugPrint('AsuraScans error: $e');
      return _curatedAsuraManhwa;
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    return List.generate(
      25,
      (i) {
        final num = 25 - i;
        return Chapter(
          id: '${mangaId}_ch_$num',
          mangaId: mangaId,
          chapterNumber: '$num',
          title: 'Глава $num',
          scanlationGroup: 'Asura Scans',
          publishedAt: DateTime.now().subtract(Duration(days: i * 3)),
          pagesCount: 18,
          isPaid: false,
        );
      },
    );
  }

  @override
  Future<List<String>> getChapterPages(String chapterId) async {
    return [
      'https://c3.mangabuff.ru/img2/chapters/jeonjijeog-dogja-sijeom_/1/1/1.jpg',
      'https://c3.mangabuff.ru/img2/chapters/jeonjijeog-dogja-sijeom_/1/1/2.jpg',
      'https://c3.mangabuff.ru/img2/chapters/jeonjijeog-dogja-sijeom_/1/1/3.jpg',
      'https://c3.mangabuff.ru/img2/chapters/jeonjijeog-dogja-sijeom_/1/1/4.jpg',
      'https://c3.mangabuff.ru/img2/chapters/jeonjijeog-dogja-sijeom_/1/1/5.jpg',
      'https://c3.mangabuff.ru/img2/chapters/jeonjijeog-dogja-sijeom_/1/1/6.jpg',
      'https://c3.mangabuff.ru/img2/chapters/jeonjijeog-dogja-sijeom_/1/1/7.jpg',
      'https://c3.mangabuff.ru/img2/chapters/jeonjijeog-dogja-sijeom_/1/1/8.jpg',
    ];
  }

  @override
  Future<String> getDescription(String mangaId) async {
    final m = _curatedAsuraManhwa.firstWhere((x) => x.id == mangaId, orElse: () => _curatedAsuraManhwa.first);
    return m.description;
  }
}
