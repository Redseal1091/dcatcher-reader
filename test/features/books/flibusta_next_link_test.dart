import 'package:flutter_test/flutter_test.dart';
import 'package:manga_reader_app/features/books/services/flibusta_opds_parser.dart';

void main() {
  group('parseFlibustaOpdsPage next link tests', () {
    final trustedBase = Uri.parse('https://flibusta.site/opds');

    test(
        'prefixed Atom ROOT link honors root xml:base and link xml:base, query decoded, nested and foreign ignored',
        () {
      const xml = '''<?xml version="1.0" encoding="utf-8"?>
<atom:feed xmlns:atom="http://www.w3.org/2005/Atom"
           xmlns:fake="http://example.com/fake"
           xml:base="/opds/">
  <atom:title>Flibusta Catalog</atom:title>
  <atom:id>tag:flibusta.site:catalog</atom:id>
  <atom:updated>2026-11-05T00:00:00Z</atom:updated>

  <!-- Ignored: foreign namespace link with rel="next" -->
  <fake:link rel="next" href="https://flibusta.site/opds/catalogs/foreign.xml" />

  <!-- Valid root Atom next link with link-level xml:base and query params -->
  <atom:link rel="next"
             type="application/atom+xml;profile=opds-catalog"
             xml:base="catalogs/"
             href="next.xml?cursor=opaque%2B%2F&amp;q=ru" />

  <!-- Direct root Atom entry containing nested next link which must be ignored -->
  <atom:entry>
    <atom:id>tag:flibusta.site:book:1</atom:id>
    <atom:title>Ignored Entry</atom:title>
    <!-- Ignored: nested entry link -->
    <atom:link rel="next" href="https://flibusta.site/opds/catalogs/nested.xml" />
    <atom:link rel="alternate" type="text/html" href="/b/1" />
  </atom:entry>
</atom:feed>''';

      final page = parseFlibustaOpdsPage(xml, documentUri: trustedBase);

      expect(page.nextPageUri, isNotNull);
      expect(
        page.nextPageUri.toString(),
        equals('https://flibusta.site/opds/catalogs/next.xml?cursor=opaque%2B%2F&q=ru'),
      );
    });

    final unsafeTestCases = <String, String>{
      'external domain': 'https://attacker.com/opds/next.xml',
      'insecure http': 'http://flibusta.site/opds/next.xml',
      'fake userinfo': 'https://user:pass@flibusta.site/opds/next.xml',
      'non-default port 8443': 'https://flibusta.site:8443/opds/next.xml',
      'url with fragment': 'https://flibusta.site/opds/next.xml#section',
      'path prefix escape /opdsevil/escape': 'https://flibusta.site/opdsevil/escape',
    };

    unsafeTestCases.forEach((name, href) {
      test('Parameterized unsafe next URL is rejected: $name', () {
        final xml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Catalog</title>
  <id>tag:flibusta.site:catalog</id>
  <updated>2026-11-05T00:00:00Z</updated>
  <link rel="next" href="$href" />
</feed>''';

        final page = parseFlibustaOpdsPage(xml, documentUri: trustedBase);
        expect(page.nextPageUri, isNull,
            reason: 'Unsafe next link ($name: $href) should produce null nextPageUri');
      });
    });
  });
}
