import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/books/services/flibusta_service.dart';

void main() {
  group('FlibustaService read request policy tests', () {
    test(
      'fetchBookChapters does not follow redirects and rejects outside redirect safely',
      () async {
        final capturedRequests = <http.BaseRequest>[];

        final mockClient = MockClient((request) async {
          capturedRequests.add(request);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://outside.invalid/b/123/read'},
            request: request,
          );
        });

        await http.runWithClient(() async {
          final service = FlibustaService();

          await expectLater(
            () => service.fetchBookChapters('123'),
            throwsA(isA<FormatException>()),
          );
        }, () => mockClient);

        expect(capturedRequests.length, 1);
        expect(capturedRequests.first.followRedirects, isFalse);
      },
    );

    test(
      'fetchBookChapters rejects malformed bookId before making any HTTP request',
      () async {
        var callCount = 0;

        final mockClient = MockClient((request) async {
          callCount++;
          return http.Response(
            '<div class="book-read"><h2>Chapter</h2><p>${'A' * 200}</p></div>',
            200,
            request: request,
          );
        });

        await http.runWithClient(() async {
          final service = FlibustaService();

          await expectLater(
            () => service.fetchBookChapters('123/../../other'),
            throwsA(isA<FormatException>()),
          );
        }, () => mockClient);

        expect(callCount, 0);
      },
    );

    test(
      'fetchBookChapters rejects binary responses such as application/pdf with FormatException',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            '%PDF-1.7 ${'X' * 400}',
            200,
            headers: {'content-type': 'application/pdf'},
            request: request,
          );
        });

        await http.runWithClient(() async {
          final service = FlibustaService();

          await expectLater(
            () => service.fetchBookChapters('123'),
            throwsFormatException,
          );
        }, () => mockClient);
      },
    );
  });
}
