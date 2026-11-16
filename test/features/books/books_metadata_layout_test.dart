import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/books/screens/books_catalog_screen.dart';

void main() {
  testWidgets('BooksCatalogScreen metadata layout overflow and chapter count check', (tester) async {
    SharedPreferences.setMockInitialValues({});

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const xmlFeed = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <title>Synthetic Metadata Book</title>
    <author><name>SyntheticAuthor</name></author>
    <category term="VERY_LONG_GENRE_REPEATED_FIFTY_TIMES_LONG_LONG_LONG_LONG_LONG_LONG_LONG_LONG_LONG_LONG" />
    <link href="/b/97001" type="application/atom+xml;profile=opds-catalog" />
  </entry>
</feed>''';

    final mockClient = MockClient((request) async {
      return http.Response(
        xmlFeed,
        200,
        headers: {'content-type': 'application/atom+xml;charset=utf-8'},
      );
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

      expect(tester.takeException(), isNull);
      expect(find.text('0 глав'), findsNothing);
      expect(find.text('Synthetic Metadata Book'), findsWidgets);
    }, () => mockClient);
  });
}
