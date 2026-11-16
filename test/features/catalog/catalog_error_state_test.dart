import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_reader_app/features/catalog/screens/catalog_screen.dart';

void main() {
  testWidgets('CatalogErrorView displays error text, retry button, and handles retry tap', (tester) async {
    const testError = 'SOURCE_RUNTIME_ERROR: Connection timed out';
    int retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogErrorView(
            errorMessage: testError,
            onRetry: () {
              retryCount++;
            },
          ),
        ),
      ),
    );

    // Assert error text is visible
    expect(find.text(testError), findsOneWidget);
    expect(find.text('Ошибка загрузки каталога'), findsOneWidget);

    // Assert retry button is visible
    final retryFinder = find.text('Повторить попытку');
    expect(retryFinder, findsOneWidget);

    // Assert "Ничего не найдено" / "Nothing found" empty state text is absent
    expect(find.text('Ничего не найдено'), findsNothing);
    expect(find.text('Nothing found'), findsNothing);

    // Tap retry button and assert callback invoked exactly once
    await tester.tap(retryFinder);
    await tester.pump();

    expect(retryCount, 1);
  });
}
