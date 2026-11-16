import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/books/screens/books_catalog_screen.dart';
import 'package:manga_reader_app/features/books/services/books_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/empty_book_offline_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const errorText = 'Не удалось загрузить книги';
  const retryButtonText = 'Повторить';

  const emptyAtomXml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Flibusta OPDS - New</title>
  <id>tag:flibusta.site,2024:opds:new</id>
  <updated>2024-01-01T00:00:00Z</updated>
</feed>''';

  const htmlResponse = '''<!DOCTYPE html>
<html>
<head><title>Flibusta Cloudflare Challenge</title></head>
<body>
  <h1>Attention Required!</h1>
</body>
</html>''';

  testWidgets(
    'BooksCatalogScreen shows loading error and retry button on HTML 200 Flibusta response, does not hang in progress indicator or show curated/empty success, and recovers on retry',
    (WidgetTester tester) async {
      final recordedRequests = <http.Request>[];
      int requestCount = 0;

      final mockClient = MockClient((http.Request request) async {
        recordedRequests.add(request);
        requestCount++;
        if (requestCount == 1) {
          return http.Response(
            htmlResponse,
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        } else {
          return http.Response(
            emptyAtomXml,
            200,
            headers: {'content-type': 'application/atom+xml; charset=utf-8'},
          );
        }
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BooksCatalogScreen(
                repository: BooksRepository.withOfflineStore(EmptyBookOfflineStore()),
              ),
            ),
          ),
        );

        // Bounded pumps to let async work finish without hanging on infinite spinners
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Assert mock received actual Flibusta OPDS request
        expect(recordedRequests, isNotEmpty);
        expect(requestCount, 1);
        expect(
          recordedRequests.first.url.toString(),
          'https://flibusta.site/opds/new/0/new',
        );

        expect(tester.takeException(), isNull);

        // 2. Visible source loading error and enabled retry button
        expect(find.text(errorText), findsOneWidget);
        final retryButtonFinder = find.ancestor(
          of: find.text(retryButtonText),
          matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
        );
        expect(retryButtonFinder, findsOneWidget);
        final buttonWidget = tester.widget<ButtonStyleButton>(retryButtonFinder);
        expect(buttonWidget.onPressed, isNotNull);

        // 3. No perpetual CircularProgressIndicator
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // 4. No curated fallback books
        expect(find.text('Мастер и Маргарита'), findsNothing);
        expect(find.text('Этюд в багровых тонах'), findsNothing);
        expect(find.text('Преступление и наказание'), findsNothing);

        // 5. No empty-success copy
        expect(
          find.text('Ничего не найдено в источнике Флибуста (Flibusta.site)'),
          findsNothing,
        );

        // 6. Tap retry and assert next request increments and clears into empty-success
        await tester.tap(retryButtonFinder);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);

        expect(requestCount, 2);
        expect(find.text(errorText), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.text('Ничего не найдено в источнике Флибуста (Flibusta.site)'),
          findsOneWidget,
        );
      }, () => mockClient);
    },
  );

  testWidgets(
    'BooksCatalogScreen handles ClientException transport failure with visible error, retry button, and no infinite spinner',
    (WidgetTester tester) async {
      final recordedRequests = <http.Request>[];
      int requestCount = 0;

      final mockClient = MockClient((http.Request request) async {
        recordedRequests.add(request);
        requestCount++;
        if (requestCount == 1) {
          throw http.ClientException('Connection failed');
        } else {
          return http.Response(
            emptyAtomXml,
            200,
            headers: {'content-type': 'application/atom+xml; charset=utf-8'},
          );
        }
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BooksCatalogScreen(
                repository: BooksRepository.withOfflineStore(EmptyBookOfflineStore()),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Assert mock received actual Flibusta OPDS request
        expect(recordedRequests, isNotEmpty);
        expect(requestCount, 1);
        expect(
          recordedRequests.first.url.toString(),
          'https://flibusta.site/opds/new/0/new',
        );

        expect(tester.takeException(), isNull);

        // 2. Visible source loading error and enabled retry button
        expect(find.text(errorText), findsOneWidget);
        final retryButtonFinder = find.ancestor(
          of: find.text(retryButtonText),
          matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
        );
        expect(retryButtonFinder, findsOneWidget);
        final buttonWidget = tester.widget<ButtonStyleButton>(retryButtonFinder);
        expect(buttonWidget.onPressed, isNotNull);

        // 3. No perpetual CircularProgressIndicator
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // 4. No curated fallback books
        expect(find.text('Мастер и Маргарита'), findsNothing);

        // 5. No empty-success copy
        expect(
          find.text('Ничего не найдено в источнике Флибуста (Flibusta.site)'),
          findsNothing,
        );

        // 6. Tap retry and assert next request increments and clears into empty-success
        await tester.tap(retryButtonFinder);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);

        expect(requestCount, 2);
        expect(find.text(errorText), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.text('Ничего не найдено в источнике Флибуста (Flibusta.site)'),
          findsOneWidget,
        );
      }, () => mockClient);
    },
  );
}
