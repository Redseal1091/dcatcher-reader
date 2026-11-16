import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/books/models/book_item.dart';
import 'package:manga_reader_app/features/books/services/flibusta_service.dart';

void main() {
  group('FlibustaService reading content extraction', () {
    const bookId = '227805';

    test('extracts chapters strictly from div.book-read inside #main ignoring site header and sidebar', () async {
      final recordedRequests = <http.Request>[];

      // Synthetic navigation text (>100 chars)
      final navProse = 'NavigationOnly ' * 10;
      // Synthetic prose (>80 chars)
      const exactSyntheticProse = 'ExactSyntheticProse detailed narrative prose text strictly meant for reading content verification.';
      // Synthetic sidebar text (>100 chars)
      final sidebarProse = 'SidebarOnly ' * 10;

      final syntheticHtml = '''<!DOCTYPE html>
<html>
<head><title>Synthetic Book Reader</title></head>
<body>
  <header>
    <h1>WebsiteNavigation</h1>
    <p>$navProse</p>
  </header>
  <div id="main">
    <div class="book-read">
      <h2>RealChapter</h2>
      <p>$exactSyntheticProse</p>
    </div>
  </div>
  <aside>
    <h2>AccountSidebar</h2>
    <p>$sidebarProse</p>
  </aside>
</body>
</html>''';

      final mockClient = MockClient((http.Request request) async {
        recordedRequests.add(request);
        return http.Response(
          syntheticHtml,
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });

      final service = FlibustaService();

      final chapters = await http.runWithClient(
        () => service.fetchBookChapters(bookId),
        () => mockClient,
      );

      expect(recordedRequests.length, 1);
      expect(recordedRequests.first.url.toString(), 'https://flibusta.site/b/$bookId/read');

      // Expect exactly one chapter with title RealChapter and content ONLY synthetic prose
      expect(chapters.length, 1);
      expect(chapters.first.title, 'RealChapter');
      expect(chapters.first.content, exactSyntheticProse);
      expect(chapters.first.content.contains('NavigationOnly'), isFalse);
      expect(chapters.first.content.contains('SidebarOnly'), isFalse);

      for (final chapter in chapters) {
        expect(chapter.title.contains('WebsiteNavigation'), isFalse);
        expect(chapter.title.contains('AccountSidebar'), isFalse);
        expect(chapter.content.contains('NavigationOnly'), isFalse);
        expect(chapter.content.contains('SidebarOnly'), isFalse);
      }
    });

    test('throws FormatException when div.book-read is empty despite header and sidebar presence', () async {
      final recordedRequests = <http.Request>[];

      final navProse = 'NavigationOnly ' * 10;
      final sidebarProse = 'SidebarOnly ' * 10;

      final syntheticHtmlNoBookText = '''<!DOCTYPE html>
<html>
<head><title>Synthetic Empty Book</title></head>
<body>
  <header>
    <h1>WebsiteNavigation</h1>
    <p>$navProse</p>
  </header>
  <div id="main">
    <div class="book-read">
    </div>
  </div>
  <aside>
    <h2>AccountSidebar</h2>
    <p>$sidebarProse</p>
  </aside>
</body>
</html>''';

      final mockClient = MockClient((http.Request request) async {
        recordedRequests.add(request);
        return http.Response(
          syntheticHtmlNoBookText,
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });

      final service = FlibustaService();

      Object? capturedError;
      List<BookChapter>? returnedChapters;

      try {
        returnedChapters = await http.runWithClient(
          () => service.fetchBookChapters(bookId),
          () => mockClient,
        );
      } catch (e) {
        capturedError = e;
      }

      expect(recordedRequests.length, 1);
      expect(recordedRequests.first.url.toString(), 'https://flibusta.site/b/$bookId/read');
      expect(returnedChapters, isNull);
      expect(capturedError, isA<FormatException>());
    });

    test('extracts readable chapters from Drupal #main container when .book-read class is absent', () async {
      final recordedRequests = <http.Request>[];

      const drupalHtml = '''<!DOCTYPE html>
<html>
<head><title>Мой светлый ангел (fb2) | Флибуста</title></head>
<body>
  <div id="header">
    <div id="site-name"><a href="/">Флибуста</a></div>
  </div>
  <div id="main" class="clear-block">
    <div class="breadcrumb"><a href="/">Главная</a></div>
    <div id="content-top"></div>
    <h1 class="title">Мой светлый ангел (fb2)</h1>
    <h3 class="book">Глава 1: Пробуждение</h3>
    <p class="book">Начало захватывающей истории в старинной усадьбе. Это настоящий текст романа из читалки.</p>
    <p class="book">Второй абзац текста книги с подробным описанием усадьбы и действующих лиц произведения.</p>
    <h3 class="book">Глава 2: Визит</h3>
    <p class="book">Текст второй главы книги. Появление таинственного гостя меняет всю привычную жизнь дома.</p>
  </div>
  <div id="footer">
    <p>Все права защищены Flibusta</p>
  </div>
</body>
</html>''';

      final mockClient = MockClient((http.Request request) async {
        recordedRequests.add(request);
        return http.Response(
          drupalHtml,
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });

      final service = FlibustaService(clientFactory: () => mockClient);
      final chapters = await service.fetchBookChapters('896079');

      expect(recordedRequests.length, 1);
      expect(chapters.length, 2);
      expect(chapters[0].title, 'Глава 1: Пробуждение');
      expect(chapters[0].content, contains('Начало захватывающей истории в старинной усадьбе.'));
      expect(chapters[1].title, 'Глава 2: Визит');
      expect(chapters[1].content, contains('Появление таинственного гостя меняет всю привычную жизнь дома.'));
    });
  });
}
