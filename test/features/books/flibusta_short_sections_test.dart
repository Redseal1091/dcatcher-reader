import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/books/services/flibusta_service.dart';

void main() {
  test('fetchBookChapters returns short sections and sections with literary titles', () async {
    const htmlBody = '''
<!DOCTYPE html>
<html>
<body>
  <div class="book-read">
    <h2>ShortSection</h2>
    <p>Short.</p>
    <h2>Книжное братство</h2>
    <p>Synthetic literary paragraph about a harbor and its old library where sailors gathered to read weathered tales across the ancient seas under misty lanterns.</p>
    <h2>LastSection</h2>
    <p>Another very long synthetic paragraph exceeding eighty characters designed to pass legacy length heuristics cleanly and reliably.</p>
  </div>
</body>
</html>
''';

    final mockClient = MockClient((request) async {
      return http.Response(
        htmlBody,
        200,
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    });

    final service = FlibustaService();
    final chapters = await http.runWithClient(
      () => service.fetchBookChapters('123'),
      () => mockClient,
    );

    expect(chapters.length, 3);
    expect(chapters[0].title, 'ShortSection');
    expect(chapters[0].content, 'Short.');
    expect(chapters[1].title, 'Книжное братство');
    expect(chapters[2].title, 'LastSection');
  });
}
