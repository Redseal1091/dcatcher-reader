import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/books/services/books_repository.dart';
import 'package:manga_reader_app/features/books/services/flibusta_service.dart';

void main() {
  test('searchFlibusta returns empty list on valid Atom feed with zero entries and does not fallback to curated books', () async {
    const query = 'hermes-no-match-9274';
    final recordedRequests = <http.Request>[];

    const emptyAtomXml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Flibusta OPDS</title>
  <id>tag:flibusta.site,2024:opds:search</id>
  <updated>2024-01-01T00:00:00Z</updated>
</feed>''';

    final mockClient = MockClient((http.Request request) async {
      recordedRequests.add(request);
      return http.Response(
        emptyAtomXml,
        200,
        headers: {
          'content-type': 'application/atom+xml; charset=utf-8',
        },
      );
    });

    final service = FlibustaService();

    final books = await http.runWithClient(() async {
      return await service.searchFlibusta(query);
    }, () => mockClient);

    expect(recordedRequests, isNotEmpty);
    expect(
      recordedRequests.first.url.toString(),
      '${FlibustaService.baseUrl}/opds/search?searchType=books&searchTerm=${Uri.encodeComponent(query)}',
    );
    expect(books, isEmpty);
  });

  test('searchFlibusta returns empty list on blank query with empty Atom feed', () async {
    final recordedRequests = <http.Request>[];

    const emptyAtomXml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Flibusta OPDS - New</title>
  <id>tag:flibusta.site,2024:opds:new</id>
  <updated>2024-01-01T00:00:00Z</updated>
</feed>''';

    final mockClient = MockClient((http.Request request) async {
      recordedRequests.add(request);
      return http.Response(
        emptyAtomXml,
        200,
        headers: {
          'content-type': 'application/atom+xml; charset=utf-8',
        },
      );
    });

    final service = FlibustaService();

    final books = await http.runWithClient(() async {
      return await service.searchFlibusta('');
    }, () => mockClient);

    expect(recordedRequests, isNotEmpty);
    expect(
      recordedRequests.first.url.toString(),
      '${FlibustaService.baseUrl}/opds/new/0/new',
    );
    expect(books, isEmpty);
  });

  test('searchFlibusta parses synthetic one-entry acquisition feed with book123, Fixture Book, and Fixture Author', () async {
    const query = 'fixture-query';
    final recordedRequests = <http.Request>[];

    const feedXml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Flibusta OPDS Search</title>
  <id>tag:flibusta.site,2024:opds:search</id>
  <updated>2024-01-01T00:00:00Z</updated>
  <entry>
    <title>Fixture Book</title>
    <author>
      <name>Fixture Author</name>
    </author>
    <link href="/b/123" rel="alternate" type="text/html"/>
    <link href="/b/123/download" rel="http://opds-spec.org/acquisition" type="application/fb2+zip"/>
    <content type="text">Fixture Description</content>
  </entry>
</feed>''';

    final mockClient = MockClient((http.Request request) async {
      recordedRequests.add(request);
      return http.Response(
        feedXml,
        200,
        headers: {
          'content-type': 'application/atom+xml; charset=utf-8',
        },
      );
    });

    final service = FlibustaService();

    final books = await http.runWithClient(() async {
      return await service.searchFlibusta(query);
    }, () => mockClient);

    expect(recordedRequests, isNotEmpty);
    expect(books.length, 1);
    expect(books.first.id, '123');
    expect(books.first.title, 'Fixture Book');
    expect(books.first.author, 'Fixture Author');
  });

  test('searchFlibusta throws exception rather than returning fallback on HTML 200 response', () async {
    const query = 'nonexistent-query-control-999';
    final recordedRequests = <http.Request>[];

    const htmlResponse = '''<!DOCTYPE html>
<html>
<head><title>Flibusta Cloudflare Challenge or HTML Page</title></head>
<body>
  <h1>Attention Required!</h1>
</body>
</html>''';

    final mockClient = MockClient((http.Request request) async {
      recordedRequests.add(request);
      return http.Response(
        htmlResponse,
        200,
        headers: {
          'content-type': 'text/html; charset=utf-8',
        },
      );
    });

    final service = FlibustaService();

    await expectLater(
      http.runWithClient(() => service.searchFlibusta(query), () => mockClient),
      throwsA(isA<Exception>()),
    );

    expect(recordedRequests, isNotEmpty);
    expect(
      recordedRequests.first.url.toString(),
      '${FlibustaService.baseUrl}/opds/search?searchType=books&searchTerm=${Uri.encodeComponent(query)}',
    );
  });

  test('searchFlibusta handles selfclosing single-quote Atom empty feed without fallback', () async {
    const query = 'selfclosing-single-quote-query';
    final recordedRequests = <http.Request>[];

    const selfClosingAtomXml = "<?xml version='1.0' encoding='utf-8'?>\n<feed xmlns='http://www.w3.org/2005/Atom' />\n";

    final mockClient = MockClient((http.Request request) async {
      recordedRequests.add(request);
      return http.Response(
        selfClosingAtomXml,
        200,
        headers: {
          'content-type': 'application/atom+xml; charset=utf-8',
        },
      );
    });

    final service = FlibustaService();

    final books = await http.runWithClient(() async {
      return await service.searchFlibusta(query);
    }, () => mockClient);

    expect(recordedRequests, isNotEmpty);
    expect(books, isEmpty);
  });

  test('searchFlibusta throws exception rather than returning fallback on non-Atom root 200 response', () async {
    const query = 'non-atom-root-embedded-feed-control';
    final recordedRequests = <http.Request>[];

    const nonAtomXml = '''<root>
  <feed xmlns="http://www.w3.org/2005/Atom">
    <entry><title>Nested Feed Book</title></entry>
  </feed>
</root>''';

    final mockClient = MockClient((http.Request request) async {
      recordedRequests.add(request);
      return http.Response(
        nonAtomXml,
        200,
        headers: {
          'content-type': 'application/xml; charset=utf-8',
        },
      );
    });

    final service = FlibustaService();

    await expectLater(
      http.runWithClient(() => service.searchFlibusta(query), () => mockClient),
      throwsA(isA<Exception>()),
    );

    expect(recordedRequests, isNotEmpty);
    expect(
      recordedRequests.first.url.toString(),
      '${FlibustaService.baseUrl}/opds/search?searchType=books&searchTerm=${Uri.encodeComponent(query)}',
    );
  });

  test('searchFlibusta throws exception rather than returning fallback on HTTP 503 response', () async {
    const query = 'service-unavailable-query';
    final recordedRequests = <http.Request>[];

    final mockClient = MockClient((http.Request request) async {
      recordedRequests.add(request);
      return http.Response(
        'Service Unavailable',
        503,
        headers: {'content-type': 'text/plain'},
      );
    });

    final service = FlibustaService();

    await expectLater(
      http.runWithClient(() => service.searchFlibusta(query), () => mockClient),
      throwsA(isA<Exception>()),
    );

    expect(recordedRequests, isNotEmpty);
    expect(
      recordedRequests.first.url.toString(),
      '${FlibustaService.baseUrl}/opds/search?searchType=books&searchTerm=${Uri.encodeComponent(query)}',
    );
  });

  test('searchFlibusta throws exception rather than returning fallback on ClientException transport failure', () async {
    const query = 'transport-failure-query';
    final recordedRequests = <http.Request>[];

    final mockClient = MockClient((http.Request request) async {
      recordedRequests.add(request);
      throw http.ClientException('Connection failed');
    });

    final service = FlibustaService();

    await expectLater(
      http.runWithClient(() => service.searchFlibusta(query), () => mockClient),
      throwsA(isA<Exception>()),
    );

    expect(recordedRequests, isNotEmpty);
    expect(
      recordedRequests.first.url.toString(),
      '${FlibustaService.baseUrl}/opds/search?searchType=books&searchTerm=${Uri.encodeComponent(query)}',
    );
  });

  test('BooksRepository.getBooks blank-query Flibusta source propagates exception on HTML 200', () async {
    final recordedRequests = <http.Request>[];

    const htmlResponse = '''<!DOCTYPE html>
<html>
<head><title>Flibusta Error Page</title></head>
<body><h1>Error</h1></body>
</html>''';

    final mockClient = MockClient((http.Request request) async {
      recordedRequests.add(request);
      return http.Response(
        htmlResponse,
        200,
        headers: {
          'content-type': 'text/html; charset=utf-8',
        },
      );
    });

    final repository = BooksRepository();

    await expectLater(
      http.runWithClient(
        () => repository.getBooks(source: 'Флибуста (Flibusta.site)', search: ''),
        () => mockClient,
      ),
      throwsA(isA<Exception>()),
    );

    expect(recordedRequests, isNotEmpty);
    expect(
      recordedRequests.first.url.toString(),
      '${FlibustaService.baseUrl}/opds/new/0/new',
    );
  });
}
