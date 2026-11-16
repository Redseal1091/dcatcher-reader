import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/books/services/flibusta_service.dart';

void main() {
  test('fetchBookChapters keeps stanza headings inside poems and yields exactly two chapters', () async {
    const syntheticHtml = '''
<!DOCTYPE html>
<html>
<body>
  <div class="book-read">
    <h3>ChapterOne</h3>
    <p>IntroOne</p>
    <div class="poem">
      <h3>I.</h3>
      <p>VerseOneA</p>
      <h3>II.</h3>
      <p>VerseOneB</p>
    </div>
    <h3>ChapterTwo</h3>
    <p>IntroTwo</p>
    <div class="poem">
      <h3>I.</h3>
      <p>VerseTwoA</p>
    </div>
  </div>
</body>
</html>
''';

    final mockClient = MockClient((http.Request request) async {
      expect(request.url.toString(), '${FlibustaService.baseUrl}/b/123/read');
      return http.Response(
        syntheticHtml,
        200,
        headers: {
          'content-type': 'text/html; charset=utf-8',
        },
      );
    });

    final service = FlibustaService();

    final chapters = await http.runWithClient(() async {
      return await service.fetchBookChapters('123');
    }, () => mockClient);

    expect(chapters.length, 2);

    expect(chapters[0].title, 'ChapterOne');
    expect(chapters[0].content, contains('IntroOne'));
    expect(chapters[0].content, contains('I.'));
    expect(chapters[0].content, contains('VerseOneA'));
    expect(chapters[0].content, contains('II.'));
    expect(chapters[0].content, contains('VerseOneB'));
    expect(chapters[0].content, isNot(contains('ChapterTwo')));
    expect(chapters[0].content, isNot(contains('IntroTwo')));
    expect(chapters[0].content, isNot(contains('VerseTwoA')));

    expect(chapters[1].title, 'ChapterTwo');
    expect(chapters[1].content, contains('IntroTwo'));
    expect(chapters[1].content, contains('I.'));
    expect(chapters[1].content, contains('VerseTwoA'));
    expect(chapters[1].content, isNot(contains('ChapterOne')));
    expect(chapters[1].content, isNot(contains('IntroOne')));
    expect(chapters[1].content, isNot(contains('VerseOneA')));
    expect(chapters[1].content, isNot(contains('VerseOneB')));
  });

  test('fetchBookChapters keeps short poem without outer chapter heading as one readable chapter', () async {
    const syntheticHtml = '''
<!DOCTYPE html>
<html>
<body>
  <div class="book-read">
    <div class="poem">
      <h3>I.</h3>
      <p>First tiny verse.</p>
      <h3>II.</h3>
      <p>Last tiny verse.</p>
    </div>
  </div>
</body>
</html>
''';

    final mockClient = MockClient((http.Request request) async {
      expect(request.url.toString(), '${FlibustaService.baseUrl}/b/456/read');
      return http.Response(
        syntheticHtml,
        200,
        headers: {
          'content-type': 'text/html; charset=utf-8',
        },
      );
    });

    final service = FlibustaService();

    final chapters = await http.runWithClient(() async {
      return await service.fetchBookChapters('456');
    }, () => mockClient);

    expect(chapters.length, 1);
    expect(chapters[0].content, contains('I.'));
    expect(chapters[0].content, contains('First tiny verse.'));
    expect(chapters[0].content, contains('II.'));
    expect(chapters[0].content, contains('Last tiny verse.'));
  });
}
