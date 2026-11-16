import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/core/widgets/frosted_glass.dart';
import 'package:manga_reader_app/features/novel_reader/models/novel_chapter.dart';
import 'package:manga_reader_app/features/novel_reader/screens/novel_reader_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'novel reader content respects status bar and displays below top frosted glass toolbar',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(top: 64, bottom: 24);

      addTearDown(() {
        tester.view.resetPadding();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final chapter = NovelChapter(
        id: 'safe-chapter-1',
        title: 'SafeChapter',
        chapterNumber: '1',
        content: List.generate(
          20,
          (i) => 'Синтетический абзац безопасной зоны номер $i для проверки отступов и видимости текста под панелью.',
        ).join('\n\n'),
        publishedAt: DateTime(2020),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NovelReaderScreen(
            novelTitle: 'SyntheticBookTitle',
            chapter: chapter,
            allChapters: [chapter],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert ListView layout top is at least 64 (respecting top system padding)
      final listViewFinder = find.byType(ListView);
      expect(listViewFinder, findsOneWidget);
      final listViewTop = tester.getTopLeft(listViewFinder).dy;
      expect(listViewTop, greaterThanOrEqualTo(64.0));

      // Locate top FrostedGlass toolbar ancestor of find.byTooltip('Шрифт и тема')
      final fontSettingsFinder = find.byTooltip('Шрифт и тема');
      expect(fontSettingsFinder, findsOneWidget);
      final topToolbarFinder = find.ancestor(
        of: fontSettingsFinder,
        matching: find.byType(FrostedGlass),
      );
      expect(topToolbarFinder, findsOneWidget);

      final toolbarBottom = tester.getBottomLeft(topToolbarFinder).dy;

      // Assert initial booktitle rect top is strictly below top FrostedGlass toolbar bottom
      final bookTitleFinder = find.text('SyntheticBookTitle');
      expect(bookTitleFinder, findsOneWidget);
      final bookTitleTop = tester.getTopLeft(bookTitleFinder).dy;

      expect(bookTitleTop, greaterThan(toolbarBottom));
    },
  );
}
