import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/books/screens/books_catalog_screen.dart';
import 'package:manga_reader_app/features/novel_reader/models/reader_settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'BooksCatalogScreen loads next page when tapping Загрузить ещё',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final List<Uri> requestedUris = <Uri>[];

      const String firstAtomFeed = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Flibusta New</title>
  <link rel="next" href="/opds/new/1/new/?cursor=abc" type="application/atom+xml;profile=opds-catalog" />
  <entry>
    <title>Pagination First</title>
    <author>
      <name>Fixture Author 1</name>
    </author>
    <link href="/b/91001" type="application/atom+xml;profile=opds-catalog" />
    <content type="text">Fixture first description</content>
  </entry>
</feed>''';

      const String secondAtomFeed = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Flibusta New</title>
  <entry>
    <title>Pagination Second</title>
    <author>
      <name>Fixture Author 2</name>
    </author>
    <link href="/b/91002" type="application/atom+xml;profile=opds-catalog" />
    <content type="text">Fixture second description</content>
  </entry>
</feed>''';

      final mockClient = MockClient((http.Request request) async {
        requestedUris.add(request.url);

        if (request.url.toString() == 'https://flibusta.site/opds/new/0/new') {
          return http.Response(
            firstAtomFeed,
            200,
            headers: {'content-type': 'application/atom+xml; charset=utf-8'},
          );
        }

        if (request.url.toString() ==
            'https://flibusta.site/opds/new/1/new/?cursor=abc') {
          return http.Response(
            secondAtomFeed,
            200,
            headers: {'content-type': 'application/atom+xml; charset=utf-8'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final readerSettings = ReaderSettings();

      await http.runWithClient(() async {
        await tester.pumpWidget(
          ChangeNotifierProvider<ReaderSettings>.value(
            value: readerSettings,
            child: const MaterialApp(
              home: Scaffold(
                body: BooksCatalogScreen(),
              ),
            ),
          ),
        );

        // Allow initial catalog feed parsing and rendering
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Assert initial request
        expect(
          requestedUris.where(
            (uri) => uri.toString() == 'https://flibusta.site/opds/new/0/new',
          ).length,
          1,
        );

        // Assert screen shows First
        expect(find.text('Pagination First'), findsOneWidget);

        // Assert button labelled 'Загрузить ещё' exists
        final loadMoreButtonFinder = find.widgetWithText(
          TextButton,
          'Загрузить ещё',
        );
        expect(loadMoreButtonFinder, findsOneWidget);

        // Tap the button
        await tester.tap(loadMoreButtonFinder);

        // Bounded pumps to allow next page fetch and rendering
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Assert request to EXACT linked path+query
        expect(
          requestedUris.where(
            (uri) =>
                uri.toString() ==
                'https://flibusta.site/opds/new/1/new/?cursor=abc',
          ).length,
          1,
        );

        // Assert both titles remain and button disappears
        expect(find.text('Pagination First'), findsOneWidget);
        expect(find.text('Pagination Second'), findsOneWidget);
        expect(find.text('Загрузить ещё'), findsNothing);
      }, () => mockClient);
    },
  );
}
