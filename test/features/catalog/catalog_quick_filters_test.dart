import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/core/theme/theme_provider.dart';
import 'package:manga_reader_app/features/catalog/models/catalog_filters.dart';
import 'package:manga_reader_app/features/catalog/models/catalog_page.dart';
import 'package:manga_reader_app/features/catalog/models/manga.dart';
import 'package:manga_reader_app/features/catalog/screens/catalog_screen.dart';
import 'package:manga_reader_app/features/catalog/state/catalog_provider.dart';
import 'package:manga_reader_app/features/extensions/models/bridge_dtos.dart';
import 'package:manga_reader_app/features/library/state/library_provider.dart';
import 'package:manga_reader_app/features/reader/models/chapter.dart';
import 'package:manga_reader_app/features/sources/manga_source.dart';
import 'package:manga_reader_app/features/sources/source_manager.dart';

class RecordingMangaSource extends MangaSource {
  @override
  final String id = 'recording_source';
  @override
  final String name = 'Recording Source';

  final List<CatalogFilters> recordedFilters = [];
  List<Manga> itemsToReturn = const [];

  @override
  Future<List<Manga>> getCatalog({
    required CatalogFilters filters,
    int offset = 0,
    int limit = 20,
  }) async {
    recordedFilters.add(filters.clone());
    return itemsToReturn;
  }

  @override
  Future<CatalogPage> getCatalogPage({
    required CatalogFilters filters,
    int page = 1,
    int limit = 20,
  }) async {
    recordedFilters.add(filters.clone());
    return CatalogPage(items: itemsToReturn, hasNextPage: false);
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async => [];

  @override
  Future<List<String>> getChapterPages(String chapterId) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SourceManager.resetForTesting();
  });

  test('CatalogProvider trusts remote completed results when catalog items have unknown status', () async {
    final source = RecordingMangaSource()
      ..itemsToReturn = [
        Manga(
          id: '1',
          title: 'Completed Unknown Status',
          description: '',
          coverUrl: '',
          type: PublicationType.manhwa,
          contentRating: ContentRating.safe,
          status: ExtensionCatalogItem.parseStatus('0'),
          sourceId: 'recording_source',
        ),
        Manga(
          id: '2',
          title: 'Explicit Ongoing',
          description: '',
          coverUrl: '',
          type: PublicationType.manhwa,
          contentRating: ContentRating.safe,
          status: ExtensionCatalogItem.parseStatus('1'),
          sourceId: 'recording_source',
        ),
        Manga(
          id: '3',
          title: 'Explicit Completed',
          description: '',
          coverUrl: '',
          type: PublicationType.manhwa,
          contentRating: ContentRating.safe,
          status: ExtensionCatalogItem.parseStatus('2'),
          sourceId: 'recording_source',
        ),
      ];

    final provider = CatalogProvider();
    provider.filters.statusFilter = 'completed';
    provider.switchSource(source);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(provider.mangaList.map((m) => m.id).toList(), equals(['1', '3']));
  });

  testWidgets('CatalogScreen quick chips reload catalog with ordering and statusFilter intact', (tester) async {
    final source = RecordingMangaSource();
    final settingsProvider = AppSettingsProvider();
    final catalogProvider = CatalogProvider()..switchSource(source);
    final libraryProvider = LibraryProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CatalogProvider>.value(value: catalogProvider),
          ChangeNotifierProvider<LibraryProvider>.value(value: libraryProvider),
          ChangeNotifierProvider<AppSettingsProvider>.value(value: settingsProvider),
        ],
        child: const MaterialApp(home: CatalogScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Ensure our recording source stays active after initial _switchSection callback
    catalogProvider.switchSource(source, libraryProvider: libraryProvider);
    await tester.pumpAndSettle();
    source.recordedFilters.clear();

    // Drag horizontal quick chip bar left to bring "✅ Завершенные" cleanly into view
    await tester.drag(find.text('✨ Новинки'), const Offset(-450, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('✅ Завершенные'));
    await tester.pumpAndSettle();

    expect(source.recordedFilters.length, equals(1));
    expect(source.recordedFilters.last.statusFilter, equals('completed'));

    // Drag back right to bring "✨ Новинки" into view — must keep statusFilter='completed' AND update ordering='-id'
    await tester.drag(find.text('✅ Завершенные'), const Offset(450, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('✨ Новинки'));
    await tester.pumpAndSettle();

    expect(source.recordedFilters.last.ordering, equals('-id'));
    expect(source.recordedFilters.last.statusFilter, equals('completed'));
  });
}
