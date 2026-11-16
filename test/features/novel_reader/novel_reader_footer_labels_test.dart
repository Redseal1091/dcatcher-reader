import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_reader_app/features/novel_reader/models/novel_chapter.dart';
import 'package:manga_reader_app/features/novel_reader/models/reader_settings.dart';
import 'package:manga_reader_app/features/novel_reader/screens/novel_reader_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildReader({
    required NovelChapter chapter,
    List<NovelChapter> allChapters = const [],
  }) {
    return ChangeNotifierProvider<ReaderSettings>(
      create: (_) => ReaderSettings(),
      child: MaterialApp(
        home: Scaffold(
          body: NovelReaderScreen(
            novelTitle: 'Test Novel',
            chapter: chapter,
            allChapters: allChapters,
          ),
        ),
      ),
    );
  }

  testWidgets('NovelReaderScreen footer displays "Введение" instead of "Глава 0" for zero/prologue chapter', (tester) async {
    final prologue = NovelChapter(
      id: 'book_prologue',
      title: 'Введение / Пролог',
      chapterNumber: '0',
      content: 'Текст введения книги...',
      publishedAt: DateTime(2024, 1, 1),
    );

    await tester.pumpWidget(buildReader(chapter: prologue));
    await tester.pumpAndSettle();

    // Verify "Глава 0" is NOT displayed
    expect(find.text('Глава 0'), findsNothing);
    // Verify meaningful label is displayed
    expect(find.text('Введение'), findsOneWidget);
  });

  testWidgets('NovelReaderScreen footer displays "Часть 2" instead of "Глава 2" when chapter is a Part', (tester) async {
    final partChapter = NovelChapter(
      id: 'book_part_2',
      title: 'Часть 2: Распивочная',
      chapterNumber: '2',
      content: 'Текст второй части романа...',
      publishedAt: DateTime(2024, 1, 1),
    );

    await tester.pumpWidget(buildReader(chapter: partChapter));
    await tester.pumpAndSettle();

    // Verify "Глава 2" is NOT displayed
    expect(find.text('Глава 2'), findsNothing);
    // Verify "Часть 2" is displayed
    expect(find.text('Часть 2'), findsOneWidget);
  });

  testWidgets('NovelReaderScreen does not display fake/unsupported TTS button in toolbar', (tester) async {
    final ch = NovelChapter(
      id: 'ch_1',
      title: 'Глава 1: Начало',
      chapterNumber: '1',
      content: 'Текст первой главы...',
      publishedAt: DateTime(2024, 1, 1),
    );

    await tester.pumpWidget(buildReader(chapter: ch));
    await tester.pumpAndSettle();

    // Verify TTS button is NOT present in toolbar
    expect(find.byTooltip('Озвучить главу голосом (TTS)'), findsNothing);
    expect(find.byIcon(Icons.volume_up), findsNothing);
    expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
  });
}
