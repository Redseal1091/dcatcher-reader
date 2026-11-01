import '../manga_source.dart';
import '../../catalog/models/manga.dart';
import '../../catalog/models/catalog_filters.dart';
import '../../reader/models/chapter.dart';

class MangaLibSource implements MangaSource {
  @override
  String get name => 'MangaLib';

  @override
  String get id => 'mangalib';

  static const List<Manga> _curatedMangaLib = [
    Manga(
      id: 'mangalib_attack_on_titan',
      title: 'Атака титанов',
      altTitle: 'Attack on Titan / Shingeki no Kyojin',
      description: 'Сотни лет назад человечество было почти полностью истреблено гигантами. Люди укрылись за тремя концентрическими стенами. Но однажды бронированный титан пробивает внешнюю стену...',
      coverUrl: 'https://images.unsplash.com/photo-1563089145-599997674d42?w=400&q=80',
      type: PublicationType.manga,
      contentRating: ContentRating.suggestive,
      genres: ['Экшен', 'Драма', 'Титаны', 'Военное'],
      status: 'completed',
      ratingScore: 9.9,
      totalChapters: 139,
      releaseYear: 2009,
    ),
    Manga(
      id: 'mangalib_demon_slayer',
      title: 'Клинок, рассекающий демонов',
      altTitle: 'Kimetsu no Yaiba / Demon Slayer',
      description: 'Эпоха Тайсё. Танджиро Камадо возвращается домой и находит семью убитой демоном, а сестру Незуко обращенной в чудовище. Он вступает в ряды истребителей, чтобы спасти ее.',
      coverUrl: 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=400&q=80',
      type: PublicationType.manga,
      contentRating: ContentRating.suggestive,
      genres: ['Экшен', 'Сверхъестественное', 'Самураи', 'Сёнэн'],
      status: 'completed',
      ratingScore: 9.7,
      totalChapters: 205,
      releaseYear: 2016,
    ),
    Manga(
      id: 'mangalib_jujutsu_kaisen',
      title: 'Магическая битва',
      altTitle: 'Jujutsu Kaisen',
      description: 'Юдзи Итадори проглатывает палец древнего короля проклятий Рёмэна Сукуны и попадает в тайный мир магов Токийского магического колледжа.',
      coverUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400&q=80',
      type: PublicationType.manga,
      contentRating: ContentRating.suggestive,
      genres: ['Экшен', 'Мистика', 'Школа', 'Демоны'],
      status: 'completed',
      ratingScore: 9.8,
      totalChapters: 271,
      releaseYear: 2018,
    ),
    Manga(
      id: 'mangalib_one_punch_man',
      title: 'Ванпанчмен',
      altTitle: 'One-Punch Man',
      description: 'Сайтама стал настолько силен, что побеждает любого монстра одним ударом кулака. Теперь его главная проблема — скука и распродажи в супермаркете.',
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=400&q=80',
      type: PublicationType.manga,
      contentRating: ContentRating.safe,
      genres: ['Комедия', 'Супергерои', 'Экшен', 'Пародия'],
      status: 'ongoing',
      ratingScore: 9.8,
      totalChapters: 205,
      releaseYear: 2012,
    ),
    Manga(
      id: 'mangalib_tokyo_ghoul',
      title: 'Токийский гуль',
      altTitle: 'Tokyo Ghoul',
      description: 'Кэн Канэки после нападения гуля переносит пересадку органов чудовища и превращается в полугуля, разрывающегося между миром людей и монстров.',
      coverUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=400&q=80',
      type: PublicationType.manga,
      contentRating: ContentRating.erotica,
      genres: ['Психология', 'Ужасы', 'Сверхъестественное', 'Драма'],
      status: 'completed',
      ratingScore: 9.6,
      totalChapters: 143,
      releaseYear: 2011,
    ),
  ];

  @override
  Future<List<Manga>> getCatalog({
    required CatalogFilters filters,
    int offset = 0,
    int limit = 20,
  }) async {
    return _curatedMangaLib.where((m) {
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
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    return List.generate(
      30,
      (i) => Chapter(
        id: '${mangaId}_ch_${30 - i}',
        mangaId: mangaId,
        chapterNumber: '${30 - i}',
        title: 'Том ${(30 - i) ~/ 10 + 1}. Глава ${30 - i}',
        scanlationGroup: 'MangaLib Team',
        publishedAt: DateTime.now().subtract(Duration(days: i * 4)),
        pagesCount: 22,
        isPaid: false,
      ),
    );
  }

  @override
  Future<List<String>> getChapterPages(String chapterId) async {
    return [
      'https://images.unsplash.com/photo-1563089145-599997674d42?w=1000&q=85',
      'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=1000&q=85',
      'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=1000&q=85',
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1000&q=85',
    ];
  }

  @override
  Future<String> getDescription(String mangaId) async {
    final m = _curatedMangaLib.firstWhere((x) => x.id == mangaId, orElse: () => _curatedMangaLib.first);
    return m.description;
  }
}
