import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/books/models/book_item.dart';
import 'package:manga_reader_app/features/books/services/books_repository.dart';

void main() {
  test('BooksRepository retries online chapter fetch after initial HTTP 503 error without cache poisoning', () async {
    const bookId = '98765432901';
    const prose = 'A careful archivist recovered the missing manuscript while a steady lantern illuminated every word on the ancient parchment.';
    const syntheticHtml = '<html><body><h2>Retry Fixture</h2><p>$prose</p></body></html>';

    final repository = BooksRepository();
    const book = BookItem(
      id: bookId,
      title: 'Retry Test Book 1',
      author: 'Test Author',
      genre: 'Test Genre',
      coverUrl: 'https://example.com/cover1.jpg',
      description: 'Test Description 1',
      year: 2026,
      chapters: [],
    );

    final recordedRequests = <http.Request>[];

    final mockClient = MockClient((http.Request request) async {
      recordedRequests.add(request);
      if (recordedRequests.length == 1) {
        return http.Response(
          'Service Unavailable',
          503,
          headers: {'content-type': 'text/plain'},
        );
      }
      return http.Response(
        syntheticHtml,
        200,
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    });

    await http.runWithClient(() async {
      // First await: HTTP 503 failure
      Object? capturedError;
      List<BookChapter>? firstChapters;
      try {
        firstChapters = await repository.getBookChapters(book);
      } catch (e) {
        capturedError = e;
      }

      expect(capturedError, isA<Exception>());
      expect(firstChapters, isNull);
      expect(recordedRequests.length, 1);
      expect(recordedRequests[0].url.toString(), 'https://flibusta.site/b/$bookId/read');

      // Second await: retry succeeds and returns exact content
      final secondChapters = await repository.getBookChapters(book);

      expect(recordedRequests.length, 2);
      expect(recordedRequests[1].url.toString(), 'https://flibusta.site/b/$bookId/read');
      expect(secondChapters.length, 1);
      expect(secondChapters.first.title, 'Retry Fixture');
      expect(secondChapters.first.content, prose);

      // Third await: cache hit, no new network requests made
      final thirdChapters = await repository.getBookChapters(book);

      expect(recordedRequests.length, 2);
      expect(thirdChapters.length, 1);
      expect(thirdChapters.first.title, 'Retry Fixture');
      expect(thirdChapters.first.content, prose);
    }, () => mockClient);
  });

  test('BooksRepository retries online chapter fetch after initial unreadable HTTP 200 error without cache poisoning', () async {
    const bookId = '98765432902';
    const prose = 'A careful archivist recovered the missing manuscript while a steady lantern illuminated every word on the ancient parchment.';
    const syntheticHtml = '<html><body><h2>Retry Fixture</h2><p>$prose</p></body></html>';

    final repository = BooksRepository();
    const book = BookItem(
      id: bookId,
      title: 'Retry Test Book 2',
      author: 'Test Author',
      genre: 'Test Genre',
      coverUrl: 'https://example.com/cover2.jpg',
      description: 'Test Description 2',
      year: 2026,
      chapters: [],
    );

    final recordedRequests = <http.Request>[];

    final mockClient = MockClient((http.Request request) async {
      recordedRequests.add(request);
      if (recordedRequests.length == 1) {
        return http.Response(
          '<html><body><script>noop();</script></body></html>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }
      return http.Response(
        syntheticHtml,
        200,
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    });

    await http.runWithClient(() async {
      // First await: Empty body / no readable prose failure
      Object? capturedError;
      List<BookChapter>? firstChapters;
      try {
        firstChapters = await repository.getBookChapters(book);
      } catch (e) {
        capturedError = e;
      }

      expect(capturedError, isA<Exception>());
      expect(firstChapters, isNull);
      expect(recordedRequests.length, 1);
      expect(recordedRequests[0].url.toString(), 'https://flibusta.site/b/$bookId/read');

      // Second await: retry succeeds and returns exact content
      final secondChapters = await repository.getBookChapters(book);

      expect(recordedRequests.length, 2);
      expect(recordedRequests[1].url.toString(), 'https://flibusta.site/b/$bookId/read');
      expect(secondChapters.length, 1);
      expect(secondChapters.first.title, 'Retry Fixture');
      expect(secondChapters.first.content, prose);

      // Third await: cache hit, no new network requests made
      final thirdChapters = await repository.getBookChapters(book);

      expect(recordedRequests.length, 2);
      expect(thirdChapters.length, 1);
      expect(thirdChapters.first.title, 'Retry Fixture');
      expect(thirdChapters.first.content, prose);
    }, () => mockClient);
  });
}
