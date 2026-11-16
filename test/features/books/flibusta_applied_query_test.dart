import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/books/screens/books_catalog_screen.dart';

void main() {
  testWidgets('applied search query is preserved across pagination and ignores unsubmitted drafts',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    const rootAtom = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <link rel="next" href="/opds/next?cursor=abc" type="application/atom+xml"/>
  <entry>
    <title>SyntheticFirst</title>
    <link href="/b/98001" type="application/atom+xml;profile=opds-catalog"/>
  </entry>
</feed>''';

    const nextAtom = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <title>SyntheticSecond</title>
    <link href="/b/98002" type="application/atom+xml;profile=opds-catalog"/>
  </entry>
</feed>''';

    final recordedUris = <Uri>[];
    final mockClient = MockClient((request) async {
      recordedUris.add(request.url);
      final headers = {'content-type': 'application/atom+xml; charset=utf-8'};
      if (request.url.path == '/opds/next' && request.url.queryParameters['cursor'] == 'abc') {
        return http.Response(nextAtom, 200, headers: headers);
      }
      return http.Response(rootAtom, 200, headers: headers);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BooksCatalogScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'draft-unsubmitted-does-not-match',
      );

      await tester.tap(find.widgetWithText(TextButton, 'Загрузить ещё'));
      await tester.pumpAndSettle();
    }, () => mockClient);

    expect(find.text('SyntheticFirst'), findsOneWidget);
    expect(find.text('SyntheticSecond'), findsOneWidget);
    expect(recordedUris.length, 2);
    expect(recordedUris[1].toString(), 'https://flibusta.site/opds/next?cursor=abc');
  });
}
