import '../manga_source.dart';
import '../../catalog/models/manga.dart';
import '../../catalog/models/catalog_filters.dart';
import '../../reader/models/chapter.dart';

class MangaBuffSource implements MangaSource {
  @override
  String get name => 'MangaBuff';

  @override
  String get id => 'mangabuff';

  static const List<Manga> _curatedManhua = [
    Manga(
      id: 'buff_tales_demons_gods',
      title: 'Сказания о демонах и богах',
      altTitle: 'Tales of Demons and Gods / Yaoshenji',
      description: 'Не Сяо, сильнейший заклинатель демонов, погиб в битве с Мудрецом-Императором. Но его душа перенеслась назад во времени в его тринадцатилетнее тело в академии Светозара!',
      coverUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=400&q=80',
      type: PublicationType.manhua,
      contentRating: ContentRating.safe,
      genres: ['Сянься', 'Культивация', 'Боевые искусства', 'Перерождение'],
      status: 'ongoing',
      ratingScore: 9.8,
      totalChapters: 450,
      releaseYear: 2015,
    ),
    Manga(
      id: 'buff_martial_peak',
      title: 'Боевой пик',
      altTitle: 'Martial Peak / Wu Lian巔峰',
      description: 'Путь к вершине боевых искусств одинок и суров. Ян Кай, скромный уборщик павильона Линсяо, находит древнюю черную книгу без единого слова, которая открывает тайны даосизма.',
      coverUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=400&q=80',
      type: PublicationType.manhua,
      contentRating: ContentRating.suggestive,
      genres: ['Культивация', 'Экшен', 'Гарем', 'Приключения'],
      status: 'ongoing',
      ratingScore: 9.6,
      totalChapters: 3600,
      releaseYear: 2018,
    ),
    Manga(
      id: 'buff_magic_emperor',
      title: 'Как демон-император стал дворецким',
      altTitle: 'Magic Emperor / Demonic Emperor',
      description: 'Чжо Ифань, величайший император демонов древности, был предан своим учеником. Возродившись в теле хилого дворецкого падающего клана Ло, он начинает восхождение обратно к трону.',
      coverUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400&q=80',
      type: PublicationType.manhua,
      contentRating: ContentRating.suggestive,
      genres: ['Интриги', 'Антигерой', 'Боевые искусства', 'Фэнтези'],
      status: 'ongoing',
      ratingScore: 9.9,
      totalChapters: 540,
      releaseYear: 2019,
    ),
    Manga(
      id: 'buff_spare_me_lord',
      title: 'Пощади меня, великий господин!',
      altTitle: 'Spare Me, Great Lord!',
      description: 'В мире духовного пробуждения Лу Шу получает странную систему: чем больше он раздражает и троллит окружающих, тем больше очков эмоций получает для прокачки!',
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=400&q=80',
      type: PublicationType.manhua,
      contentRating: ContentRating.safe,
      genres: ['Комедия', 'Система', 'Сверхспособности', 'Школа'],
      status: 'completed',
      ratingScore: 9.7,
      totalChapters: 600,
      releaseYear: 2018,
    ),
  ];

  @override
  Future<List<Manga>> getCatalog({
    required CatalogFilters filters,
    int offset = 0,
    int limit = 20,
  }) async {
    return _curatedManhua.where((m) {
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
      20,
      (i) => Chapter(
        id: '${mangaId}_ch_${20 - i}',
        mangaId: mangaId,
        chapterNumber: '${20 - i}',
        title: 'Глава ${20 - i}',
        scanlationGroup: 'MangaBuff Scan',
        publishedAt: DateTime.now().subtract(Duration(days: i * 2)),
        pagesCount: 16,
        isPaid: false,
      ),
    );
  }

  @override
  Future<List<String>> getChapterPages(String chapterId) async {
    return [
      'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=1000&q=85',
      'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=1000&q=85',
      'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=1000&q=85',
    ];
  }

  @override
  Future<String> getDescription(String mangaId) async {
    final m = _curatedManhua.firstWhere((x) => x.id == mangaId, orElse: () => _curatedManhua.first);
    return m.description;
  }
}
