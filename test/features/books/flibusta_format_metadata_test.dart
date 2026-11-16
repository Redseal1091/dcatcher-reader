import 'package:flutter_test/flutter_test.dart';
import 'package:manga_reader_app/features/books/services/flibusta_opds_parser.dart';

void main() {
  final baseDocumentUri = Uri.parse('https://flibusta.site/opds/new/0/new');

  String feedFixture({
    String feedBase = '',
    String entryBase = '',
    required String additionalLinks,
  }) {
    final feedBaseAttr = feedBase.isNotEmpty ? ' xml:base="$feedBase"' : '';
    final entryBaseAttr = entryBase.isNotEmpty ? ' xml:base="$entryBase"' : '';
    return '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom"$feedBaseAttr>
  <id>tag:flibusta.site:test</id>
  <title>Test Feed</title>
  <updated>2026-11-05T00:00:00Z</updated>
  <entry$entryBaseAttr>
    <id>tag:flibusta.site:book:99001</id>
    <title>Test Book</title>
    <updated>2026-11-05T00:00:00Z</updated>
    <link rel="http://opds-spec.org/acquisition" href="/b/99001/download" type="application/pdf" />
    $additionalLinks
  </entry>
</feed>''';
  }

  test('non-acquisition or mismatched HTML links must not unlock HTML format and keep isPdfOnly true', () {
    final xml = feedFixture(
      additionalLinks: '''
        <link rel="alternate" href="/b/99001" type="text/html" />
        <link rel="http://opds-spec.org/acquisition" href="https://outside.invalid/b/99001/html" type="text/html" />
        <link rel="http://opds-spec.org/acquisition" href="/b/99002/html" type="text/html" />
        <link rel="http://opds-spec.org/acquisition" href="/b/99001/html#bad" type="text/html" />
        <link rel="http://opds-spec.org/acquisitionevil" href="/b/99001/html" type="text/html" />
      ''',
    );

    final page = parseFlibustaOpdsPage(xml, documentUri: baseDocumentUri);
    final book = page.items.single;

    expect(book.availableFormats, contains('application/pdf'));
    expect(book.availableFormats.contains('application/html+zip'), isFalse);
    expect(book.isPdfOnly, isTrue);
  });

  test('valid acquisition / open-access HTML link yields both formats and isPdfOnly false', () {
    final xml = feedFixture(
      additionalLinks: '''
        <link rel="http://opds-spec.org/acquisition/open-access" href="/b/99001/html" type="application/html+zip" />
      ''',
    );

    final page = parseFlibustaOpdsPage(xml, documentUri: baseDocumentUri);
    final book = page.items.single;

    expect(book.availableFormats, containsAll(['application/pdf', 'application/html+zip']));
    expect(book.isPdfOnly, isFalse);
  });

  test('relative paths with feed and entry xml:base resolve to same book and detect both formats', () {
    const xml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:base="https://flibusta.site/b/">
  <id>tag:flibusta.site:test</id>
  <title>Test Feed</title>
  <updated>2026-11-05T00:00:00Z</updated>
  <entry xml:base="99001/">
    <id>tag:flibusta.site:book:99001</id>
    <title>Test Book</title>
    <updated>2026-11-05T00:00:00Z</updated>
    <link rel="http://opds-spec.org/acquisition" href="download" type="application/pdf" />
    <link rel="http://opds-spec.org/acquisition" href="html" type="application/html+zip" />
  </entry>
</feed>''';

    final page = parseFlibustaOpdsPage(xml, documentUri: baseDocumentUri);
    final book = page.items.single;

    expect(book.availableFormats, containsAll(['application/pdf', 'application/html+zip']));
    expect(book.isPdfOnly, isFalse);
  });
}
