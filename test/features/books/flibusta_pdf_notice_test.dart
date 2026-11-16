import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/books/screens/books_catalog_screen.dart';

void main() {
  testWidgets('PDF-only entry shows notice and avoids eager reader request', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final requestedUris = <Uri>[];

    final mockClient = MockClient((request) async {
      requestedUris.add(request.url);
      final headers = {'content-type': 'application/atom+xml; charset=utf-8'};

      if (request.url.path == '/opds/new/0/new') {
        const rootXml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <id>tag:root</id>
  <title>Root</title>
  <entry>
    <title>Synthetic Scan</title>
    <id>tag:entry:99001</id>
    <author><name>Fixture</name></author>
    <link rel="http://opds-spec.org/acquisition/open-access" type="application/pdf" href="/b/99001/download"/>
    <link rel="alternate" type="text/html" href="/b/99001"/>
  </entry>
</feed>''';
        return http.Response(rootXml, 200, headers: headers);
      }

      return http.Response('Not Found', 404, headers: headers);
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

      final entryFinder = find.text('Synthetic Scan');
      expect(entryFinder, findsOneWidget);

      await tester.tap(entryFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('доступно только в PDF'), findsOneWidget);
      expect(requestedUris.any((uri) => uri.path.contains('/read')), isFalse);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.widgetWithText(TextButton, 'Повторить'), findsNothing);
    }, () => mockClient);
  });
}
