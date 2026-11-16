import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/books/models/book_item.dart';
import 'package:manga_reader_app/features/books/services/flibusta_service.dart';

void main() {
  test('fetchBookChapters throws Exception on HTTP 503 rather than returning placeholder chapters', () async {
    const bookId = '987654321';
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
    expect(capturedError, isA<Exception>());
    expect(returnedChapters, isNull);
  });

  test('fetchBookChapters parses synthetic HTTP 200 HTML body into chapter with Fixture Chapter and prose', () async {
    const bookId = '12345';
    final recordedRequests = <http.Request>[];

    const syntheticProse = 'A wandering archivist examined the forgotten ledger while the lantern flame flickered steadily against the cold night wind.';
    const syntheticHtml = '''<!DOCTYPE html>
<html>
<head><title>Synthetic Book</title></head>
<body>
  <h2>Fixture Chapter</h2>
  <p>$syntheticProse</p>
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
    expect(chapters.length, 1);
    expect(chapters.first.title, 'Fixture Chapter');
    expect(chapters.first.content, syntheticProse);
  });

  test('fetchBookChapters rejects transport failure without returning placeholder chapters', () async {
    const bookId = '987654321';
    final recordedRequests = <http.Request>[];

    final mockClient = MockClient((http.Request request) async {
      recordedRequests.add(request);
      throw http.ClientException('Transport error connecting to https://example.invalid/private?token=fixture-secret');
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
    expect(capturedError, isA<Exception>());
    expect(returnedChapters, isNull);
    final errorString = capturedError?.toString() ?? '';
    expect(errorString.contains('fixture-secret'), isFalse);
    expect(errorString.contains('example.invalid'), isFalse);
  });

  test('fetchBookChapters throws Exception when HTTP 200 response has empty body', () async {
    const bookId = '987654321';
    final recordedRequests = <http.Request>[];

    final mockClient = MockClient((http.Request request) async {
      recordedRequests.add(request);
      return http.Response(
        '',
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
    expect(recordedRequests.first.url.toString(), 'https://flibusta.site/b/987654321/read');
    expect(capturedError, isA<Exception>());
    expect(returnedChapters, isNull);
    final errorString = capturedError?.toString() ?? '';
    expect(errorString.contains('fixture-secret'), isFalse);
  });

  test('fetchBookChapters throws Exception when HTTP 200 response body contains no readable prose', () async {
    const bookId = '987654321';
    final recordedRequests = <http.Request>[];

    const syntheticHtml = '<html><body><script>fixture-secret</script><style>body{}</style> </body></html>';

    final mockClient = MockClient((http.Request request) async {
      recordedRequests.add(request);
      return http.Response(
        syntheticHtml,
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
    expect(recordedRequests.first.url.toString(), 'https://flibusta.site/b/987654321/read');
    expect(capturedError, isA<Exception>());
    expect(returnedChapters, isNull);
    final errorString = capturedError?.toString() ?? '';
    expect(errorString.contains('fixture-secret'), isFalse);
    expect(errorString.contains(syntheticHtml), isFalse);
  });
}
