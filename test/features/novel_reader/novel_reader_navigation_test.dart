import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/novel_reader/models/novel_chapter.dart';
import 'package:manga_reader_app/features/novel_reader/screens/novel_reader_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'tapping chevron_right advances reader to the second chapter, resets scroll and progress',
    (WidgetTester tester) async {
      // Set test surface size large enough to avoid unrelated layout overflows
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final firstChapter = NovelChapter(
        id: 'chapter-1',
        title: 'Глава 1: Пробуждение Дракона - Начало',
        chapterNumber: '1',
        content: List.generate(
          40,
          (index) => 'Синтетический абзац первой главы номер $index с длинным текстом для прокрутки.',
        ).join('\n\n'),
        publishedAt: DateTime(2020),
      );

      final secondChapter = NovelChapter(
        id: 'chapter-2',
        title: 'Глава 2: Возвращение Владыки - Финал',
        chapterNumber: '2',
        content: List.generate(
          20,
          (index) => 'Уникальный синтетический маркер второго эпизода номер $index в саге.',
        ).join('\n\n'),
        publishedAt: DateTime(2020),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NovelReaderScreen(
            novelTitle: 'SyntheticBook',
            chapter: firstChapter,
            allChapters: [firstChapter, secondChapter],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify first chapter title and prose are visible initially
      expect(find.text('Глава 1: Пробуждение Дракона - Начало'), findsWidgets);
      expect(find.textContaining('Синтетический абзац первой главы номер 0'), findsOneWidget);
      expect(find.text('Глава 2: Возвращение Владыки - Финал'), findsNothing);

      // Scroll ListView to a non-zero offset
      final scrollableFinder = find.byType(Scrollable);
      expect(scrollableFinder, findsOneWidget);
      await tester.drag(scrollableFinder, const Offset(0, -400));
      await tester.pumpAndSettle();

      final scrollableState = tester.state<ScrollableState>(scrollableFinder);
      expect(scrollableState.position.pixels, greaterThan(0.0));

      // Tap next chapter button
      final nextButtonFinder = find.widgetWithIcon(IconButton, Icons.chevron_right);
      expect(nextButtonFinder, findsOneWidget);
      await tester.tap(nextButtonFinder);
      await tester.pumpAndSettle();

      // Expect distinct second chapter title/prose visible and previous prose absent
      expect(find.text('Глава 2: Возвращение Владыки - Финал'), findsWidgets);
      expect(find.textContaining('Уникальный синтетический маркер второго эпизода номер 0'), findsOneWidget);
      expect(find.textContaining('Синтетический абзац первой главы номер 0'), findsNothing);

      // Verify controller offset is 0 and progress is 0%
      final updatedScrollableState = tester.state<ScrollableState>(scrollableFinder);
      expect(updatedScrollableState.position.pixels, equals(0.0));
      expect(find.text('Прочитано: 0%'), findsOneWidget);
    },
  );

  testWidgets(
    'initial LAST chapter from list [first, last], tap left -> first title/prose visible, LAST prose absent, first previous button disabled',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final firstChapter = NovelChapter(
        id: 'chapter-1',
        title: 'Глава 1: Первое Начало',
        chapterNumber: '1',
        content: 'Уникальный текст первого эпизода для проверки возврата назад.',
        publishedAt: DateTime(2020),
      );

      final lastChapter = NovelChapter(
        id: 'chapter-2',
        title: 'Глава 2: Последняя Часть',
        chapterNumber: '2',
        content: 'Уникальный прозаический текст последнего сегмента истории.',
        publishedAt: DateTime(2020),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NovelReaderScreen(
            novelTitle: 'NavTestBook',
            chapter: lastChapter,
            allChapters: [firstChapter, lastChapter],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify last chapter initially visible
      expect(find.text('Глава 2: Последняя Часть'), findsWidgets);
      expect(find.textContaining('Уникальный прозаический текст последнего сегмента истории.'), findsOneWidget);
      expect(find.text('Глава 1: Первое Начало'), findsNothing);

      // Tap previous chapter button (Icons.chevron_left)
      final prevButtonFinder = find.widgetWithIcon(IconButton, Icons.chevron_left);
      expect(prevButtonFinder, findsOneWidget);
      await tester.tap(prevButtonFinder);
      await tester.pumpAndSettle();

      // Verify first title and prose visible, last prose absent
      expect(find.text('Глава 1: Первое Начало'), findsWidgets);
      expect(find.textContaining('Уникальный текст первого эпизода для проверки возврата назад.'), findsOneWidget);
      expect(find.textContaining('Уникальный прозаический текст последнего сегмента истории.'), findsNothing);

      // Assert first previous IconButton.onPressed is null
      final prevIconButton = tester.widget<IconButton>(prevButtonFinder);
      expect(prevIconButton.onPressed, isNull);
    },
  );

  testWidgets(
    'initial FIRST previous button disabled and initial LAST next disabled',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final firstChapter = NovelChapter(
        id: 'chapter-1',
        title: 'Глава 1',
        chapterNumber: '1',
        content: 'Текст главы 1',
        publishedAt: DateTime(2020),
      );

      final lastChapter = NovelChapter(
        id: 'chapter-2',
        title: 'Глава 2',
        chapterNumber: '2',
        content: 'Текст главы 2',
        publishedAt: DateTime(2020),
      );

      // Case A: Initial FIRST chapter
      await tester.pumpWidget(
        MaterialApp(
          home: NovelReaderScreen(
            novelTitle: 'BoundaryBook',
            chapter: firstChapter,
            allChapters: [firstChapter, lastChapter],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstPrevButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left),
      );
      expect(firstPrevButton.onPressed, isNull);

      // Case B: Initial LAST chapter
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: NovelReaderScreen(
            novelTitle: 'BoundaryBook',
            chapter: lastChapter,
            allChapters: [firstChapter, lastChapter],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lastNextButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(lastNextButton.onPressed, isNull);
    },
  );

  testWidgets(
    'empty allChapters default both callbacks null',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final standaloneChapter = NovelChapter(
        id: 'chapter-isolated',
        title: 'Одиночная Глава',
        chapterNumber: '1',
        content: 'Содержимое изолированной главы без списка остальных.',
        publishedAt: DateTime(2020),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NovelReaderScreen(
            novelTitle: 'EmptyListBook',
            chapter: standaloneChapter,
            allChapters: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final prevButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left),
      );
      final nextButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );

      expect(prevButton.onPressed, isNull);
      expect(nextButton.onPressed, isNull);
    },
  );

  testWidgets(
    'initial chapter ID absent from supplied list both callbacks null, no jumps',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final absentChapter = NovelChapter(
        id: 'absent-chapter',
        title: 'Отсутствующая Глава',
        chapterNumber: 'X',
        content: 'Текст главы, отсутствующей в списке глав книги.',
        publishedAt: DateTime(2020),
      );

      final listChapter1 = NovelChapter(
        id: 'chapter-1',
        title: 'Глава 1',
        chapterNumber: '1',
        content: 'Текст главы списка 1.',
        publishedAt: DateTime(2020),
      );

      final listChapter2 = NovelChapter(
        id: 'chapter-2',
        title: 'Глава 2',
        chapterNumber: '2',
        content: 'Текст главы списка 2.',
        publishedAt: DateTime(2020),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NovelReaderScreen(
            novelTitle: 'MissingIdBook',
            chapter: absentChapter,
            allChapters: [listChapter1, listChapter2],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final prevFinder = find.widgetWithIcon(IconButton, Icons.chevron_left);
      final nextFinder = find.widgetWithIcon(IconButton, Icons.chevron_right);

      final prevButton = tester.widget<IconButton>(prevFinder);
      final nextButton = tester.widget<IconButton>(nextFinder);

      expect(prevButton.onPressed, isNull);
      expect(nextButton.onPressed, isNull);

      // Verify absent chapter prose is intact and no jump occurred
      expect(find.text('Отсутствующая Глава'), findsWidgets);
      expect(find.textContaining('Текст главы, отсутствующей в списке глав книги.'), findsOneWidget);
      expect(find.text('Глава 1'), findsNothing);
      expect(find.text('Глава 2'), findsNothing);
    },
  );
}
