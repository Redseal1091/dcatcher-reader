import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/books/screens/books_catalog_screen.dart';
import 'package:manga_reader_app/features/books/services/books_repository.dart';
import 'package:manga_reader_app/features/novel_reader/models/reader_settings.dart';
import 'package:manga_reader_app/features/novel_reader/screens/novel_reader_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/empty_book_offline_store.dart';

void main() {
  testWidgets(
    'Flibusta reader modal retry flow executes HTTP 503 retry and opens NovelReaderScreen',
    (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final List<Uri> requestedUris = <Uri>[];

    const String atomFeed = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Flibusta New</title>
  <entry>
    <title>Synthetic Modal Retry Book</title>
    <author>
      <name>Fixture Writer</name>
    </author>
    <link href="/b/987654329" type="application/atom+xml;profile=opds-catalog" />
    <content type="text">Fixture description</content>
  </entry>
</feed>''';

    const String retryChapterTitle = 'Retry recovered chapter';
    const String retryProse =
        'This is original synthetic retry prose for the integration fixture.';
    const String syntheticHtml = '''<!DOCTYPE html>
<html>
<head><title>Synthetic Book</title></head>
<body>
  <h2>$retryChapterTitle</h2>
  <p>$retryProse</p>
</body>
</html>''';

    int chapterReadRequestCount = 0;

    final mockClient = MockClient((http.Request request) async {
      requestedUris.add(request.url);

      if (request.url.toString() == 'https://flibusta.site/opds/new/0/new') {
        return http.Response(
          atomFeed,
          200,
          headers: {'content-type': 'application/atom+xml; charset=utf-8'},
        );
      }

      if (request.url.toString() == 'https://flibusta.site/b/987654329/read') {
        chapterReadRequestCount++;
        if (chapterReadRequestCount == 1) {
          return http.Response('Service Unavailable', 503);
        }
        return http.Response(
          syntheticHtml,
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }

      return http.Response('Not Found', 404);
    });

    final realReaderSettings = ReaderSettings();
    final testRepository = BooksRepository.withOfflineStore(EmptyBookOfflineStore());

    await http.runWithClient(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider<ReaderSettings>.value(
          value: realReaderSettings,
          child: MaterialApp(
            home: Scaffold(
              body: BooksCatalogScreen(
                repository: testRepository,
              ),
            ),
          ),
        ),
      );

      // Bounded pumps to allow catalog feed parsing and rendering
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        requestedUris.where(
          (uri) => uri.toString() == 'https://flibusta.site/opds/new/0/new',
        ).length,
        1,
      );

      final bookFinder = find.text('Synthetic Modal Retry Book');
      expect(bookFinder, findsOneWidget);

      await tester.tap(bookFinder);

      // Bounded pumps to allow bottom sheet modal open and chapter fetch
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final unavailableTextFinder = find.text('Текст книги временно недоступен');
      if (unavailableTextFinder.evaluate().isEmpty) {
        final modalListViewFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        );
        if (modalListViewFinder.evaluate().isNotEmpty) {
          await tester.scrollUntilVisible(
            unavailableTextFinder,
            100.0,
            scrollable: modalListViewFinder,
          );
        }
      }

      expect(unavailableTextFinder, findsOneWidget);
      await tester.ensureVisible(unavailableTextFinder);

      expect(
        requestedUris.where(
          (uri) => uri.toString() == 'https://flibusta.site/b/987654329/read',
        ).length,
        1,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Desired-behavior assertion: find visible 'Повторить' text inside modal
      // with ancestor ButtonStyleButton and non-null onPressed.
      final retryTextFinder = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Повторить'),
      );

      final retryButtonFinder = find.ancestor(
        of: retryTextFinder,
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton && widget.onPressed != null,
        ),
      );

      expect(retryButtonFinder, findsOneWidget);

      // Force incidental modal rebuild before retry (MediaQuery metrics update)
      // and assert no extra HTTP requests occur.
      final currentSize = tester.view.physicalSize;
      tester.view.physicalSize = Size(currentSize.width, currentSize.height + 40);
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pump();

      expect(
        requestedUris.where(
          (uri) => uri.toString() == 'https://flibusta.site/b/987654329/read',
        ).length,
        1,
      );

      // Tap real 'Повторить' button
      await tester.tap(retryButtonFinder);

      // Bounded pumps to process chapter retry fetch and update modal state
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Assert read requests count reached 2
      expect(
        requestedUris.where(
          (uri) => uri.toString() == 'https://flibusta.site/b/987654329/read',
        ).length,
        2,
      );

      // Assert safe error text is gone, no spinner, no unhandled exception
      expect(find.text('Текст книги временно недоступен'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);

      // Assert actual chapter title rendered in modal
      final recoveredChapterFinder = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(retryChapterTitle),
      );
      expect(recoveredChapterFinder, findsOneWidget);

      // Tap actual chapter and verify NovelReaderScreen exact original fixture prose
      await tester.tap(recoveredChapterFinder);
      await tester.pumpAndSettle();

      expect(find.byType(NovelReaderScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NovelReaderScreen),
          matching: find.text(retryChapterTitle),
        ),
        findsNWidgets(2),
      );
      expect(find.text(retryProse), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => mockClient);
  });
}

