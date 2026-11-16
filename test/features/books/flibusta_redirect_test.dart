import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/books/services/flibusta_service.dart';

void main() {
  group('FlibustaService redirect & request policy tests', () {
    test('searchFlibustaPage on 302 redirect: asserts followRedirects is false, exactly one HTTP request, throws FormatException without unsafe Location in exception message', () async {
      final capturedRequests = <http.Request>[];
      const redirectLocation = 'https://outside.invalid/opds/next';

      final mockClient = MockClient((http.Request request) async {
        capturedRequests.add(request);
        return http.Response(
          'Moved temporarily',
          302,
          headers: {
            'location': redirectLocation,
            'content-type': 'text/plain',
          },
        );
      });

      final service = FlibustaService();

      FormatException? thrownException;
      try {
        await http.runWithClient(() async {
          return await service.searchFlibustaPage('test-query');
        }, () => mockClient);
      } on FormatException catch (e) {
        thrownException = e;
      }

      expect(thrownException, isNotNull);
      expect(thrownException.toString(), isNot(contains(redirectLocation)));
      expect(capturedRequests.length, equals(1));
      expect(capturedRequests.first.followRedirects, isFalse);
    });

    test('searchFlibustaPage on 200 valid empty Atom: captures followRedirects is false and returns empty items', () async {
      final capturedRequests = <http.Request>[];
      const emptyAtomXml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Flibusta OPDS</title>
  <id>tag:flibusta.site,2024:opds:search</id>
  <updated>2024-01-01T00:00:00Z</updated>
</feed>''';

      final mockClient = MockClient((http.Request request) async {
        capturedRequests.add(request);
        return http.Response(
          emptyAtomXml,
          200,
          headers: {
            'content-type': 'application/atom+xml; charset=utf-8',
          },
        );
      });

      final service = FlibustaService();

      final page = await http.runWithClient(() async {
        return await service.searchFlibustaPage('test-query');
      }, () => mockClient);

      expect(capturedRequests.length, equals(1));
      expect(capturedRequests.first.followRedirects, isFalse);
      expect(page.items, isEmpty);
    });
  });
}
