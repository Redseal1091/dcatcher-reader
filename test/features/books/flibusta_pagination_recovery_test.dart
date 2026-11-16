import 'dart:async';
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
    'Pagination recovery on HTTP 503 error retains first book, displays retry button, retries exact URI, deduplicates by book id, and renders both books once',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final List<Uri> requestedUris = <Uri>[];
      int nextRequestCount = 0;

      const String rootAtomFeed = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Flibusta New</title>
  <link rel="next" href="/opds/next?cursor=fixture%2B" type="application/atom+xml;profile=opds-catalog" />
  <entry>
    <title>SyntheticFirst</title>
    <author>
      <name>Fixture Author 1</name>
    </author>
    <link href="/b/92001" type="application/atom+xml;profile=opds-catalog" />
    <content type="text">Fixture first description</content>
  </entry>
</feed>''';

      const String retryAtomFeed = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Flibusta New</title>
  <entry>
    <title>SyntheticFirst Renamed Duplicate</title>
    <author>
      <name>Fixture Author 1</name>
    </author>
    <link href="/b/92001" type="application/atom+xml;profile=opds-catalog" />
    <content type="text">Duplicate 92001</content>
  </entry>
  <entry>
    <title>SyntheticSecond</title>
    <author>
      <name>Fixture Author 2</name>
    </author>
    <link href="/b/92002" type="application/atom+xml;profile=opds-catalog" />
    <content type="text">Fixture second description</content>
  </entry>
</feed>''';

      final mockClient = MockClient((http.Request request) async {
        requestedUris.add(request.url);

        if (request.url.toString() == 'https://flibusta.site/opds/new/0/new') {
          return http.Response(
            rootAtomFeed,
            200,
            headers: {'content-type': 'application/atom+xml; charset=utf-8'},
          );
        }

        if (request.url.toString() ==
            'https://flibusta.site/opds/next?cursor=fixture%2B') {
          nextRequestCount++;
          if (nextRequestCount == 1) {
            return http.Response('Service Unavailable', 503);
          } else {
            return http.Response(
              retryAtomFeed,
              200,
              headers: {'content-type': 'application/atom+xml; charset=utf-8'},
            );
          }
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

        // Bounded pumps for initial root catalog load
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Initial book rendered
        expect(find.text('SyntheticFirst'), findsOneWidget);

        // Tap initial load more button
        final loadMoreFinder = find.widgetWithText(TextButton, 'Загрузить ещё');
        expect(loadMoreFinder, findsOneWidget);
        await tester.tap(loadMoreFinder);

        // Bounded pumps for next page failing with 503
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Retained first book title and shows TextButton 'Повторить'
        expect(find.text('SyntheticFirst'), findsOneWidget);
        final retryFinder = find.widgetWithText(TextButton, 'Повторить');
        expect(retryFinder, findsOneWidget);

        // Tap retry button
        await tester.tap(retryFinder);

        // Bounded pumps for retry page load
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Old first title wins dedup (original 92001 title kept), new 92002 rendered
        expect(find.text('SyntheticFirst'), findsOneWidget);
        expect(find.text('SyntheticFirst Renamed Duplicate'), findsNothing);
        expect(find.text('SyntheticSecond'), findsOneWidget);

        // Neither 'Загрузить ещё' nor 'Повторить' buttons present (no next link in retry feed)
        expect(find.text('Загрузить ещё'), findsNothing);
        expect(find.text('Повторить'), findsNothing);

        // Assert request counts: root once, next exactly twice
        expect(
          requestedUris
              .where(
                (uri) => uri.toString() == 'https://flibusta.site/opds/new/0/new',
              )
              .length,
          1,
        );
        expect(
          requestedUris
              .where(
                (uri) =>
                    uri.toString() ==
                    'https://flibusta.site/opds/next?cursor=fixture%2B',
              )
              .length,
          2,
        );
      }, () => mockClient);
    },
  );

  testWidgets(
    'Genre change invalidates delayed next page: fresh root book remains, stale book is ignored, and loading indicator stops',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final List<Uri> requestedUris = <Uri>[];
      final Completer<http.Response> staleNextCompleter =
          Completer<http.Response>();

      const String rootAtomFeed = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Flibusta New</title>
  <link rel="next" href="/opds/next?cursor=stale%2B" type="application/atom+xml;profile=opds-catalog" />
  <entry>
    <title>bookOld</title>
    <author>
      <name>Old Author</name>
    </author>
    <link href="/b/93001" type="application/atom+xml;profile=opds-catalog" />
    <content type="text">Old description</content>
  </entry>
</feed>''';

      const String staleAtomFeed = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Flibusta New</title>
  <entry>
    <title>Stale</title>
    <author>
      <name>Stale Author</name>
    </author>
    <link href="/b/93002" type="application/atom+xml;profile=opds-catalog" />
    <content type="text">Stale description</content>
  </entry>
</feed>''';

      const String freshGenreFeed = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Flibusta SciFi</title>
  <entry>
    <title>BookFresh</title>
    <author>
      <name>Fresh Author</name>
    </author>
    <category term="Фантастика" label="Фантастика" />
    <link href="/b/93003" type="application/atom+xml;profile=opds-catalog" />
    <content type="text">Fresh description</content>
  </entry>
</feed>''';

      int rootCallCount = 0;
      final mockClient = MockClient((http.Request request) async {
        requestedUris.add(request.url);

        if (request.url.toString() == 'https://flibusta.site/opds/new/0/new') {
          rootCallCount++;
          if (rootCallCount == 1) {
            return http.Response(
              rootAtomFeed,
              200,
              headers: {'content-type': 'application/atom+xml; charset=utf-8'},
            );
          }
          return http.Response(
            freshGenreFeed,
            200,
            headers: {'content-type': 'application/atom+xml; charset=utf-8'},
          );
        }

        if (request.url.toString() ==
            'https://flibusta.site/opds/next?cursor=stale%2B') {
          return await staleNextCompleter.future;
        }

        // Fresh root when category/genre changed or refreshed
        return http.Response(
          freshGenreFeed,
          200,
          headers: {'content-type': 'application/atom+xml; charset=utf-8'},
        );
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

        // Bounded pumps for initial root catalog load
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Initial bookOld rendered
        expect(find.text('bookOld'), findsOneWidget);

        // Tap load more
        final loadMoreFinder = find.widgetWithText(TextButton, 'Загрузить ещё');
        expect(loadMoreFinder, findsOneWidget);
        await tester.tap(loadMoreFinder);

        // Bounded pump to initiate the next page request without completing completer
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Change genre via existing 'Фантастика' chip
        final genreChipFinder = find.text('Фантастика');
        expect(genreChipFinder, findsWidgets);
        await tester.tap(genreChipFinder.first);

        // Bounded pumps to allow fresh root to load and render
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Fresh book is rendered
        expect(find.text('BookFresh'), findsOneWidget);

        // Now complete the stale next page response
        staleNextCompleter.complete(
          http.Response(
            staleAtomFeed,
            200,
            headers: {'content-type': 'application/atom+xml; charset=utf-8'},
          ),
        );

        // Bounded pumps to process stale completion
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // BookFresh remains, Stale is absent, and loading indicator is not spinning
        expect(find.text('BookFresh'), findsOneWidget);
        expect(find.text('Stale'), findsNothing);
        expect(find.text('bookOld'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      }, () => mockClient);
    },
  );
}
