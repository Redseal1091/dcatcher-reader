import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/novel_reader/models/novel_chapter.dart';
import 'package:manga_reader_app/features/novel_reader/services/curated_ranobe_source.dart';
import 'package:manga_reader_app/features/novel_reader/services/novel_repository.dart';
import 'package:manga_reader_app/features/novel_reader/services/ranobehub_source.dart';
import 'package:manga_reader_app/features/novel_reader/services/ranobe_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CuratedRanobeSource Tests', () {
    test('Curated source returns default popular novels', () async {
      final source = CuratedRanobeSource();
      final novels = await source.getPopularNovels();

      expect(novels.isNotEmpty, true);
      expect(novels.any((n) => n.id == 'solo_leveling'), true);
      expect(novels.any((n) => n.id == 'omniscient_reader'), true);
    });

    test('Curated source searches novels by query', () async {
      final source = CuratedRanobeSource();
      final results = await source.searchNovels('одиночку');

      expect(results.length, 1);
      expect(results.first.title, contains('Поднятие уровня в одиночку'));
    });

    test('Curated source returns chapters with content', () async {
      final source = CuratedRanobeSource();
      final chapters = await source.getChapters('solo_leveling');

      expect(chapters.isNotEmpty, true);
      expect(chapters.first.title, contains('Глава 1'));
      expect(chapters.first.content, isNotEmpty);
    });
  });

  group('RanobeCacheService Tests', () {
    test('Saves and retrieves chapter content', () async {
      const chapterId = 'test_ch_123';
      const content = 'Это тестовый текст главы ранобэ для проверки кэша.';

      expect(await RanobeCacheService.getCachedChapterContent(chapterId), isNull);

      await RanobeCacheService.saveChapterContent(chapterId, content);
      final retrieved = await RanobeCacheService.getCachedChapterContent(chapterId);

      expect(retrieved, content);
    });

    test('Saves and retrieves chapters list', () async {
      const novelId = 'test_novel_456';
      final chapters = [
        NovelChapter(
          id: 'ch_1',
          title: 'Глава 1',
          chapterNumber: '1',
          content: 'Текст',
          publishedAt: DateTime(2025, 1, 1),
          volume: 'Том 1',
        ),
      ];

      expect(await RanobeCacheService.getCachedChapters(novelId), isNull);

      await RanobeCacheService.saveChapters(novelId, chapters);
      final cached = await RanobeCacheService.getCachedChapters(novelId);

      expect(cached, isNotNull);
      expect(cached!.length, 1);
      expect(cached.first.id, 'ch_1');
      expect(cached.first.title, 'Глава 1');
      expect(cached.first.volume, 'Том 1');
    });
  });

  group('RanobehubSource Mock Tests', () {
    test('Parses catalog response into NovelBook items', () async {
      const mockCatalogHtml = '''
<!DOCTYPE html>
<html>
<body>
  <div class="book-grid">
    <div class="book-card" data-slot="card">
      <a data-book-transition-id="1034" href="/ranobe/1034-bleach-cant-fear-your-own-world">
        <div class="book-cover">
          <img class="book-cover-image" src="/_next/image?url=%2Fapi%2Fmedia%2F99673&w=3840&q=75" />
          <span class="rating">8.3</span>
          <div class="book-cover-copy">
            <strong>Блич: Нельзя бояться собственного мира</strong>
          </div>
          <div class="book-hover-preview">
            <p>Роман Рёго Нариты расскажет о Сюхэе Хисаги.</p>
          </div>
        </div>
        <div data-slot="card-content">
          <h3 data-book-transition-title="true">Блич: Нельзя бояться собственного мира</h3>
          <p>48 глав</p>
        </div>
      </a>
    </div>
  </div>
</body>
</html>
''';

      final mockClient = MockClient((request) async {
        return http.Response(mockCatalogHtml, 200, headers: {'content-type': 'text/html; charset=utf-8'});
      });

      final source = RanobehubSource(client: mockClient);
      final novels = await source.getPopularNovels(page: 1);

      expect(novels.length, 1);
      final novel = novels.first;
      expect(novel.id, '1034-bleach-cant-fear-your-own-world');
      expect(novel.title, 'Блич: Нельзя бояться собственного мира');
      expect(novel.coverUrl, contains('https://ranobehub.org/_next/image'));
      expect(novel.totalChapters, 48);
      expect(novel.rating, 8.3);
      expect(novel.source, 'RanobeHub');
    });

    test('Parses Next.js embedded JSON for chapter list', () async {
      const mockNovelHtml = r'''
<!DOCTYPE html>
<html>
<body>
  <script>
    self.__next_f.push([1,"3c:[\"$\",\"section\",null,{\"volumes\":[{\"id\":2344,\"number\":1,\"title\":\"Том 1\",\"chapters\":[{\"id\":111698,\"bookId\":393,\"volume\":1,\"number\":0,\"title\":\"Пролог\"},{\"id\":111699,\"bookId\":393,\"volume\":1,\"number\":1,\"title\":\"Глава 1 - Охотник\"}]}]}]"]);
  </script>
</body>
</html>
''';

      final mockClient = MockClient((request) async {
        return http.Response(mockNovelHtml, 200, headers: {'content-type': 'text/html; charset=utf-8'});
      });

      final source = RanobehubSource(client: mockClient);
      final chapters = await source.getChapters('393-solo-leveling');

      expect(chapters.length, 2);
      expect(chapters[0].id, '111698');
      expect(chapters[0].title, 'Пролог');
      expect(chapters[0].volume, 'Том 1');
      expect(chapters[1].id, '111699');
      expect(chapters[1].title, 'Глава 1 - Охотник');
    });

    test('Parses chapter content from reader-content container', () async {
      const mockChapterHtml = '''
<!DOCTYPE html>
<html>
<body>
  <div class="reader-content">
    <p>Сон Джин Ву, Охотник Е-ранга.</p>
    <p>В мире охотников царит строгая иерархия.</p>
  </div>
  <div class="reader-navigation"></div>
</body>
</html>
''';

      final mockClient = MockClient((request) async {
        return http.Response(mockChapterHtml, 200, headers: {'content-type': 'text/html; charset=utf-8'});
      });

      final source = RanobehubSource(client: mockClient);
      final chapter = NovelChapter(
        id: '111699',
        title: 'Глава 1',
        chapterNumber: '1',
        content: '',
        publishedAt: DateTime(2025, 1, 1),
        url: '/ranobe/393-solo-leveling/chapter/111699',
      );

      final content = await source.getChapterContent(chapter);
      expect(content, contains('Сон Джин Ву, Охотник Е-ранга.'));
      expect(content, contains('В мире охотников царит строгая иерархия.'));
    });
  });

  group('NovelRepository Integration Tests', () {
    test('Delegates to correct source based on name', () {
      final repo = NovelRepository();

      expect(repo.getSource('DCatcher Novels'), isA<CuratedRanobeSource>());
      expect(repo.getSource('RanobeHub'), isA<RanobehubSource>());
      expect(repo.getSource('RuLate'), isNot(isA<CuratedRanobeSource>()));
      expect(repo.getSource(null), isA<CuratedRanobeSource>());
    });

    test('findNovelForManga finds match from curated novels', () async {
      final repo = NovelRepository();
      final match = await repo.findNovelForManga('sl', 'Поднятие уровня в одиночку (Solo Leveling)');

      expect(match, isNotNull);
      expect(match!.id, 'solo_leveling');
    });
  });
}
