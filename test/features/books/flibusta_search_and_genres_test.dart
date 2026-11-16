import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/books/models/book_item.dart';
import 'package:manga_reader_app/features/books/screens/books_catalog_screen.dart';
import 'package:manga_reader_app/features/books/services/books_repository.dart';
import 'package:manga_reader_app/features/books/services/flibusta_opds_parser.dart';
import 'package:manga_reader_app/features/books/services/flibusta_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/empty_book_offline_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Token-based multi-term search matching', () {
    const book1 = BookItem(
      id: '1',
      title: 'Пикник на обочине',
      author: 'Аркадий и Борис Стругацкие',
      genre: 'Фантастика',
      year: 1972,
      coverUrl: '',
      description: 'Сталкер Рэдрик Шухарт отправляется в опаснейшую Зону.',
      chapters: [],
    );

    const book2 = BookItem(
      id: '2',
      title: 'Война и мир',
      author: 'Толстой Лев Николаевич',
      genre: 'Классическая проза',
      year: 1869,
      coverUrl: '',
      description: 'Великая эпопея о войне 1812 года.',
      chapters: [],
    );

    test('matches single word substring in title and author', () {
      expect(BooksRepository.matchesSearch(book1, 'пикник'), isTrue);
      expect(BooksRepository.matchesSearch(book1, 'стругацкие'), isTrue);
      expect(BooksRepository.matchesSearch(book2, 'толстой'), isTrue);
      expect(BooksRepository.matchesSearch(book2, 'мир'), isTrue);
    });

    test('matches multi-token query across title and author (author + title combination)', () {
      expect(BooksRepository.matchesSearch(book1, 'стругацкие пикник'), isTrue);
      expect(BooksRepository.matchesSearch(book1, 'пикник стругацкие'), isTrue);
      expect(BooksRepository.matchesSearch(book1, 'рэдрик зона'), isTrue);
      expect(BooksRepository.matchesSearch(book2, 'толстой война и мир'), isTrue);
    });

    test('matches inverted author names (first name + last name vs last name + first name)', () {
      expect(BooksRepository.matchesSearch(book2, 'лев толстой'), isTrue);
      expect(BooksRepository.matchesSearch(book2, 'толстой лев'), isTrue);
    });

    test('rejects non-matching queries', () {
      expect(BooksRepository.matchesSearch(book1, 'достоевский'), isFalse);
      expect(BooksRepository.matchesSearch(book2, 'стругацкие'), isFalse);
      expect(BooksRepository.matchesSearch(book1, 'пикник топор'), isFalse);
    });
  });

  group('Smart genre matching in BooksRepository', () {
    const sciFiBook = BookItem(
      id: '10',
      title: 'Звёздный десант',
      author: 'Роберт Хайнлайн',
      genre: 'Научная фантастика',
      year: 1959,
      coverUrl: '',
      description: '',
      chapters: [],
    );

    const sfActionBook = BookItem(
      id: '11',
      title: 'Стальная Крыса',
      author: 'Гарри Гаррисон',
      genre: 'sf_action',
      year: 1961,
      coverUrl: '',
      description: '',
      chapters: [],
    );

    const fantasyBook = BookItem(
      id: '12',
      title: 'Властелин Колец',
      author: 'Дж. Р. Р. Толкин',
      genre: 'Эпическое фэнтези',
      year: 1954,
      coverUrl: '',
      description: '',
      chapters: [],
    );

    const detectiveBook = BookItem(
      id: '13',
      title: 'Убийство в Восточном экспрессе',
      author: 'Агата Кристи',
      genre: 'Детективы / Триллер',
      year: 1934,
      coverUrl: '',
      description: '',
      chapters: [],
    );

    const classicBook = BookItem(
      id: '14',
      title: 'Анна Каренина',
      author: 'Лев Толстой',
      genre: 'Классическая литература',
      year: 1877,
      coverUrl: '',
      description: '',
      chapters: [],
    );

    test('genre "Все" matches any book', () {
      expect(BooksRepository.matchesGenre(sciFiBook, 'Все'), isTrue);
      expect(BooksRepository.matchesGenre(detectiveBook, 'Все'), isTrue);
    });

    test('genre "Фантастика" matches subgenres, terms, and fantasy', () {
      expect(BooksRepository.matchesGenre(sciFiBook, 'Фантастика'), isTrue);
      expect(BooksRepository.matchesGenre(sfActionBook, 'Фантастика'), isTrue);
      expect(BooksRepository.matchesGenre(fantasyBook, 'Фантастика'), isTrue);
      expect(BooksRepository.matchesGenre(detectiveBook, 'Фантастика'), isFalse);
    });

    test('genre "Детектив" matches detective variations and terms', () {
      expect(BooksRepository.matchesGenre(detectiveBook, 'Детектив'), isTrue);
      expect(BooksRepository.matchesGenre(sciFiBook, 'Детектив'), isFalse);
    });

    test('genre "Классика" matches classic literature variations', () {
      expect(BooksRepository.matchesGenre(classicBook, 'Классика'), isTrue);
      expect(BooksRepository.matchesGenre(sciFiBook, 'Классика'), isFalse);
    });
  });

  group('OPDS category mapping in parseFlibustaOpdsPage', () {
    test('maps technical category terms (sf -> Фантастика, prose_classic -> Классическая проза)', () {
      const atomXml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Feed</title>
  <id>tag:flibusta.site,2026:opds</id>
  <entry>
    <title>Sci-Fi Book</title>
    <author><name>Author 1</name></author>
    <category term="sf" />
    <link href="/b/10001" type="text/html" />
  </entry>
  <entry>
    <title>Classic Book</title>
    <author><name>Author 2</name></author>
    <category term="prose_classic" />
    <link href="/b/10002" type="text/html" />
  </entry>
  <entry>
    <title>Labeled Book</title>
    <author><name>Author 3</name></author>
    <category term="custom_code" label="Авторский жанр" />
    <link href="/b/10003" type="text/html" />
  </entry>
</feed>''';

      final page = parseFlibustaOpdsPage(
        atomXml,
        documentUri: Uri.parse('https://flibusta.site/opds/new/0/new'),
      );

      expect(page.items.length, 3);
      expect(page.items[0].genre, 'Фантастика');
      expect(page.items[1].genre, 'Классическая проза');
      expect(page.items[2].genre, 'Авторский жанр');
    });
  });

  group('BooksRepository.getBooksPage integration with smart search & genre', () {
    const feedXml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Search Feed</title>
  <id>tag:flibusta.site,2026:opds:search</id>
  <entry>
    <title>Пикник на обочине</title>
    <author><name>Аркадий и Борис Стругацкие</name></author>
    <category term="sf" label="Научная фантастика" />
    <link href="/b/5001" type="text/html" />
  </entry>
  <entry>
    <title>Трудно быть богом</title>
    <author><name>Аркадий и Борис Стругацкие</name></author>
    <category term="sf_fantasy" label="Социальная фантастика" />
    <link href="/b/5002" type="text/html" />
  </entry>
</feed>''';

    test('filters by multi-token search without dropping valid author+title results', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          feedXml,
          200,
          headers: {'content-type': 'application/atom+xml; charset=utf-8'},
        );
      });

      final service = FlibustaService(clientFactory: () => mockClient);
      final repo = BooksRepository.withOfflineStore(
        EmptyBookOfflineStore(),
        flibusta: service,
      );

      final page = await repo.getBooksPage(
        source: 'Флибуста (Flibusta.site)',
        search: 'стругацкие пикник',
      );

      expect(page.items.length, 1);
      expect(page.items.first.title, 'Пикник на обочине');
    });

    test('genre chip "Фантастика" retains books with subgenre "Научная фантастика"', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          feedXml,
          200,
          headers: {'content-type': 'application/atom+xml; charset=utf-8'},
        );
      });

      final service = FlibustaService(clientFactory: () => mockClient);
      final repo = BooksRepository.withOfflineStore(
        EmptyBookOfflineStore(),
        flibusta: service,
      );

      final page = await repo.getBooksPage(
        source: 'Флибуста (Flibusta.site)',
        genre: 'Фантастика',
      );

      expect(page.items.length, 2);
    });
  });

  group('BooksCatalogScreen empty filtered page with next link', () {
    testWidgets('shows informative notice and button to continue searching next page', (tester) async {
      const page1Xml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Feed Page 1</title>
  <link rel="next" href="/opds/new/1/new" type="application/atom+xml" />
  <entry>
    <title>Убийство на Ниле</title>
    <author><name>Агата Кристи</name></author>
    <category term="detective" label="Детектив" />
    <link href="/b/6001" type="text/html" />
  </entry>
</feed>''';

      const page2Xml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Feed Page 2</title>
  <entry>
    <title>Солярис</title>
    <author><name>Станислав Лем</name></author>
    <category term="sf" label="Научная фантастика" />
    <link href="/b/6002" type="text/html" />
  </entry>
</feed>''';

      final mockClient = MockClient((request) async {
        if (request.url.path == '/opds/new/1/new') {
          return http.Response(
            page2Xml,
            200,
            headers: {'content-type': 'application/atom+xml; charset=utf-8'},
          );
        }
        return http.Response(
          page1Xml,
          200,
          headers: {'content-type': 'application/atom+xml; charset=utf-8'},
        );
      });

      final service = FlibustaService(clientFactory: () => mockClient);
      final repo = BooksRepository.withOfflineStore(
        EmptyBookOfflineStore(),
        flibusta: service,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BooksCatalogScreen(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap genre "Фантастика" chip
      await tester.tap(find.text('Фантастика').first);
      await tester.pumpAndSettle();

      // Page 1 has detective, so filtered books are empty, but next page link exists
      expect(find.text('Загрузить ещё'), findsOneWidget);

      // Tap "Загрузить ещё" to load page 2
      await tester.tap(find.widgetWithText(TextButton, 'Загрузить ещё'));
      await tester.pumpAndSettle();

      // Page 2 has "Солярис" (Научная фантастика) which matches!
      expect(find.text('Солярис'), findsOneWidget);
    });
  });
}
