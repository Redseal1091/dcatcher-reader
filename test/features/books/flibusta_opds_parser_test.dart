import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/books/services/flibusta_service.dart';

void main() {
  group('Flibusta OPDS Parser Regressions', () {
    test(
      'Regression 1: namespaced a:feed/a:entry, xml:lang, CDATA + entities title, Cyrillic author, UTF-8 body without charset header, exact ID/title/author',
      () async {
        // Synthetic OPDS feed using Atom prefix 'a:', entry xml:lang, CDATA title with entities, Cyrillic author
        const xml = '''<?xml version="1.0"?>
<a:feed xmlns:a="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/terms/">
  <a:title>Synthetic Feed</a:title>
  <a:id>tag:flibusta.site,2024:test:feed1</a:id>
  <a:updated>2024-05-01T00:00:00Z</a:updated>
  <a:entry xml:lang="ru">
    <a:title><![CDATA[Война ]]>&amp;<![CDATA[ Мир <Том 1>]]></a:title>
    <a:author>
      <a:name>Лев Николаевич Толстой</a:name>
    </a:author>
    <a:id>tag:flibusta.site,2024:book:54321</a:id>
    <a:link rel="alternate" href="/b/54321" type="text/html"/>
    <a:link rel="http://opds-spec.org/acquisition" href="/b/54321/download" type="application/fb2+zip"/>
    <a:content type="text">Синтетическое описание книги.</a:content>
  </a:entry>
</a:feed>''';

        // Response without charset in content-type header (Response.bytes utf8)
        final mockClient = MockClient((http.Request request) async {
          return http.Response.bytes(
            utf8.encode(xml),
            200,
            headers: {
              'content-type': 'application/atom+xml',
            },
          );
        });

        final service = FlibustaService();
        final books = await http.runWithClient(
          () => service.searchFlibusta('tolstoy'),
          () => mockClient,
        );

        expect(books.length, 1);
        final book = books.first;
        expect(book.id, '54321');
        expect(book.title, 'Война & Мир <Том 1>');
        expect(book.author, 'Лев Николаевич Толстой');
      },
    );

    test(
      'Regression 2: default feed mixing navigation-only entry (no /b/) and one book entry returns ONLY the book and never generated timestamp ID',
      () async {
        // Feed mixing an author navigation entry (/opds/author123) without /b/ acquisition/details
        // and one actual catalog book entry (/b/777). Also preserves old fixtures book links without rel.
        const xml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Catalog Feed with Navigation</title>
  <id>tag:flibusta.site,2024:opds:mix</id>
  <updated>2024-05-01T00:00:00Z</updated>
  <entry>
    <title>Navigation Entry: Author Catalog</title>
    <id>tag:flibusta.site,2024:nav:123</id>
    <link href="/opds/author123" type="application/atom+xml;profile=opds-catalog"/>
    <content type="text">Список книг данного автора</content>
  </entry>
  <entry>
    <title>Book Entry Without Rel In Links</title>
    <id>tag:flibusta.site,2024:book:777</id>
    <author>
      <name>Synthetic Author</name>
    </author>
    <!-- Backward compatibility: book links without rel attribute -->
    <link href="/b/777" type="text/html"/>
    <link href="/b/777/download" type="application/fb2+zip"/>
    <content type="text">Описание книги номер 777</content>
  </entry>
</feed>''';

        final mockClient = MockClient((http.Request request) async {
          return http.Response.bytes(
            utf8.encode(xml),
            200,
            headers: {
              'content-type': 'application/atom+xml; charset=utf-8',
            },
          );
        });

        final service = FlibustaService();
        final books = await http.runWithClient(
          () => service.searchFlibusta('catalog-query'),
          () => mockClient,
        );

        expect(books.length, 1);
        final book = books.first;
        expect(book.id, '777');
        expect(book.id, isNot(contains('_')));
        expect(int.tryParse(book.id), 777);
        expect(book.title, 'Book Entry Without Rel In Links');
        expect(book.author, 'Synthetic Author');
      },
    );

    test(
      'Regression 3: cover link rel BEFORE href with single quotes, xml:base relative resolution at feed root, and stable book ID from validated same-origin /b/123 not external/misleading text',
      () async {
        // Attributes order reversed: rel before href, single quotes used.
        // Feed has xml:base="https://flibusta.site/catalog/"
        // Content contains misleading mentions of other URLs and external IDs.
        const xml = """<?xml version='1.0' encoding='utf-8'?>
<feed xmlns='http://www.w3.org/2005/Atom' xml:base='https://flibusta.site/catalog/'>
  <title>Feed with Relative Base and Reversed Cover Attributes</title>
  <id>tag:flibusta.site,2024:opds:covertest</id>
  <updated>2024-05-01T00:00:00Z</updated>
  <entry>
    <title>Cover and Base Resolution Book</title>
    <author>
      <name>Author Name</name>
    </author>
    <id>tag:flibusta.site,2024:book:123</id>
    <link rel='http://opds-spec.org/image' href='covers/123.jpg' type='image/jpeg'/>
    <link rel='alternate' href='/b/123' type='text/html'/>
    <link rel='http://opds-spec.org/acquisition' href='/b/123/download' type='application/epub+zip'/>
    <content type='text'>Misleading text mentioning https://external.site/b/99999 and fake id /b/88888 inside content.</content>
  </entry>
</feed>""";

        final mockClient = MockClient((http.Request request) async {
          return http.Response.bytes(
            utf8.encode(xml),
            200,
            headers: {
              'content-type': 'application/atom+xml',
            },
          );
        });

        final service = FlibustaService();
        final books = await http.runWithClient(
          () => service.searchFlibusta('cover-test'),
          () => mockClient,
        );

        expect(books.length, 1);
        final book = books.first;
        expect(book.id, '123');
        expect(book.coverUrl, isNot(contains('unsplash.com')));
        expect(book.coverUrl, 'https://flibusta.site/catalog/covers/123.jpg');
      },
    );

    test(
      'Regression 4: malformed XML envelope looking like Atom with unclosed entry throws FormatException with safe error and no query/URL leak',
      () async {
        const secretQuery = 'sensitive-personal-query-4815162342';
        const malformedXml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Atom Search Feed</title>
  <entry>
    <title>Unclosed Entry Book</title>
    <link href="/b/999" rel="alternate"/>
</feed>''';

        final mockClient = MockClient((http.Request request) async {
          return http.Response.bytes(
            utf8.encode(malformedXml),
            200,
            headers: {
              'content-type': 'application/atom+xml',
            },
          );
        });

        final service = FlibustaService();

        try {
          await http.runWithClient(
            () => service.searchFlibusta(secretQuery),
            () => mockClient,
          );
          fail('Expected FormatException for malformed XML with unclosed entry');
        } catch (e) {
          expect(e, isA<FormatException>());
          final errorMsg = e.toString();
          expect(errorMsg, isNot(contains(secretQuery)));
          expect(errorMsg, isNot(contains('searchTerm=')));
          expect(errorMsg, isNot(contains('flibusta.site/opds')));
        }
      },
    );

    test(
      'Regression 5: external host, non-443 port, and userinfo book links are rejected while valid same-origin book is retained; DOCTYPE is rejected; missing metadata defaults year=0, rating=0.0, and no invented cover',
      () async {
        // Test DOCTYPE rejection
        const doctypeXml = '''<?xml version="1.0"?>
<!DOCTYPE feed [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Feed with DOCTYPE</title>
  <entry>
    <title>Book 1</title>
    <link href="/b/1" rel="alternate"/>
  </entry>
</feed>''';

        final doctypeClient = MockClient((http.Request request) async {
          return http.Response.bytes(
            utf8.encode(doctypeXml),
            200,
            headers: {'content-type': 'application/atom+xml'},
          );
        });

        final service = FlibustaService();
        expect(
          () => http.runWithClient(
            () => service.searchFlibusta('test'),
            () => doctypeClient,
          ),
          throwsA(isA<FormatException>()),
        );

        // Feed with multiple entries:
        // 1. External host book link -> rejected
        // 2. Non-443 port book link -> rejected
        // 3. Userinfo in book link -> rejected
        // 4. Valid same-origin book without year or cover -> retained, year=0, rating=0.0, coverUrl='' (no invented cover)
        const mixedXml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Origin and Security Feed</title>
  <id>tag:flibusta.site,2024:opds:security</id>
  <updated>2024-05-01T00:00:00Z</updated>
  <entry>
    <title>External Host Book</title>
    <id>tag:flibusta.site,2024:book:101</id>
    <link href="https://evil.site/b/101" rel="alternate"/>
    <link href="https://evil.site/b/101/download" type="application/fb2+zip"/>
  </entry>
  <entry>
    <title>Non-443 Port Book</title>
    <id>tag:flibusta.site,2024:book:102</id>
    <link href="https://flibusta.site:8080/b/102" rel="alternate"/>
    <link href="https://flibusta.site:8080/b/102/download" type="application/fb2+zip"/>
  </entry>
  <entry>
    <title>UserInfo Book</title>
    <id>tag:flibusta.site,2024:book:103</id>
    <link href="https://user:pass@flibusta.site/b/103" rel="alternate"/>
    <link href="https://user:pass@flibusta.site/b/103/download" type="application/fb2+zip"/>
  </entry>
  <entry>
    <title>Valid Same Origin Book Missing Metadata</title>
    <id>tag:flibusta.site,2024:book:104</id>
    <author>
      <name>Valid Author</name>
    </author>
    <!-- Has external/userinfo cover link which should also be rejected -->
    <link rel="http://opds-spec.org/image" href="https://evil.site/cover.jpg" type="image/jpeg"/>
    <link href="/b/104" rel="alternate"/>
    <link href="/b/104/download" type="application/fb2+zip"/>
  </entry>
</feed>''';

        final mixedClient = MockClient((http.Request request) async {
          return http.Response.bytes(
            utf8.encode(mixedXml),
            200,
            headers: {'content-type': 'application/atom+xml'},
          );
        });

        final books = await http.runWithClient(
          () => service.searchFlibusta('security-test'),
          () => mixedClient,
        );

        // Only the valid same-origin book (104) should be parsed
        expect(books.length, 1);
        final book = books.first;
        expect(book.id, '104');
        expect(book.title, 'Valid Same Origin Book Missing Metadata');
        expect(book.author, 'Valid Author');
        expect(book.year, 0);
        expect(book.rating, 0.0);
        expect(book.coverUrl, '');
      },
    );
  });
}
