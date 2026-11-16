import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/core/theme/theme_provider.dart';
import 'package:manga_reader_app/features/catalog/screens/catalog_screen.dart';
import 'package:manga_reader_app/features/catalog/state/catalog_provider.dart';
import 'package:manga_reader_app/features/extensions/models/keiyoushi_extension.dart';
import 'package:manga_reader_app/features/extensions/services/native_extensions_bridge.dart';
import 'package:manga_reader_app/features/library/state/library_provider.dart';
import 'package:manga_reader_app/features/sources/extension_manga_source.dart';
import 'package:manga_reader_app/features/sources/source_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String mockChannelName = 'dev.dcatcher/extensions';
  const String mockSourceId = 'widget_test_source_id';
  const String mockPackage = 'keiyoushi.test.extension';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SourceManager.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(mockChannelName), null);
    SourceManager.resetForTesting();
  });

  ExtensionMangaSource createMockSource(NativeExtensionsBridge bridge) {
    return ExtensionMangaSource(
      source: const KeiyoushiSource(
        id: mockSourceId,
        name: 'Widget Test Source',
        language: 'ru',
        homeUrl: 'https://test.local',
      ),
      packageName: mockPackage,
      bridge: bridge,
    );
  }

  Widget createTestWidget({
    required CatalogProvider catalogProvider,
    required LibraryProvider libraryProvider,
    required AppSettingsProvider settingsProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CatalogProvider>.value(value: catalogProvider),
        ChangeNotifierProvider<LibraryProvider>.value(value: libraryProvider),
        ChangeNotifierProvider<AppSettingsProvider>.value(value: settingsProvider),
      ],
      child: const MaterialApp(
        home: CatalogScreen(),
      ),
    );
  }

  testWidgets('CatalogScreen triggers loadMore on scroll near end and renders next page tiles', (WidgetTester tester) async {
    final requestedPages = <int>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(mockChannelName), (MethodCall call) async {
      if (call.method == 'getCatalog') {
        final page = (call.arguments['page'] as num?)?.toInt() ?? 1;
        requestedPages.add(page);

        if (page == 1) {
          return {
            'hasNextPage': true,
            'items': List.generate(
              12,
              (i) => {
                'url': '/manga/p1_$i',
                'title': 'Page 1 Manga $i',
                'thumbnailUrl': '',
                'genre': 'manhwa',
                'status': 'ongoing',
              },
            ),
          };
        } else if (page == 2) {
          return {
            'hasNextPage': false,
            'items': [
              {
                'url': '/manga/p2_0',
                'title': 'Page 2 Unique Item',
                'thumbnailUrl': '',
                'genre': 'manhwa',
                'status': 'ongoing',
              },
            ],
          };
        }
      }
      return null;
    });

    final bridge = NativeExtensionsBridge.forTesting();
    final source = createMockSource(bridge);
    SourceManager.setMockSources([source]);
    SourceManager.setCurrentSource(source.id);

    final catalogProvider = CatalogProvider();
    final libraryProvider = LibraryProvider();
    final settingsProvider = AppSettingsProvider();

    await tester.pumpWidget(createTestWidget(
      catalogProvider: catalogProvider,
      libraryProvider: libraryProvider,
      settingsProvider: settingsProvider,
    ));

    await tester.pumpAndSettle();

    expect(requestedPages, equals([1]));
    expect(find.text('Page 1 Manga 0'), findsOneWidget);

    // Scroll down to near end of CustomScrollView
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(requestedPages, equals([1, 2]));

    // Page 2 Unique Item may be offscreen in lazy SliverGrid, scroll until visible
    await tester.scrollUntilVisible(
      find.text('Page 2 Unique Item'),
      300,
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Page 2 Unique Item'), findsOneWidget);
  });

  testWidgets('CatalogScreen pagination error retains existing tiles and button retry succeeds', (WidgetTester tester) async {
    var failPage2 = true;
    final requestedPages = <int>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(mockChannelName), (MethodCall call) async {
      if (call.method == 'getCatalog') {
        final page = (call.arguments['page'] as num?)?.toInt() ?? 1;
        requestedPages.add(page);

        if (page == 1) {
          return {
            'hasNextPage': true,
            'items': [
              {
                'url': '/manga/1',
                'title': 'Initial Manga 1',
                'thumbnailUrl': '',
                'genre': 'manhwa',
                'status': 'ongoing',
              },
            ],
          };
        } else if (page == 2) {
          if (failPage2) {
            failPage2 = false;
            throw PlatformException(code: 'NET_ERR', message: 'Failed to load page 2');
          }
          return {
            'hasNextPage': false,
            'items': [
              {
                'url': '/manga/2',
                'title': 'Recovered Manga 2',
                'thumbnailUrl': '',
                'genre': 'manhwa',
                'status': 'ongoing',
              },
            ],
          };
        }
      }
      return null;
    });

    final bridge = NativeExtensionsBridge.forTesting();
    final source = createMockSource(bridge);
    SourceManager.setMockSources([source]);
    SourceManager.setCurrentSource(source.id);

    final catalogProvider = CatalogProvider();
    final libraryProvider = LibraryProvider();
    final settingsProvider = AppSettingsProvider();

    await tester.pumpWidget(createTestWidget(
      catalogProvider: catalogProvider,
      libraryProvider: libraryProvider,
      settingsProvider: settingsProvider,
    ));

    await tester.pumpAndSettle();

    expect(find.text('Initial Manga 1'), findsOneWidget);

    // Explicitly invoke loadMore() once to trigger the deterministic page 2 failure
    // without depending on scroll-based autoload triggers.
    await catalogProvider.loadMore();
    await tester.pumpAndSettle();

    expect(catalogProvider.loadMoreError, isNotNull);
    // After failure on page 2: Initial items must still be retained
    expect(find.text('Initial Manga 1'), findsOneWidget);

    final scrollableFinder = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    ).first;

    // Scroll until error message and retry button in the footer are visible
    await tester.scrollUntilVisible(
      find.textContaining('Не удалось загрузить следующие элементы'),
      300,
      scrollable: scrollableFinder,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Не удалось загрузить следующие элементы'), findsOneWidget);

    // Tap retry 'Загрузить ещё'
    expect(find.text('Загрузить ещё'), findsOneWidget);
    await tester.tap(find.text('Загрузить ещё'));
    await tester.pumpAndSettle();

    // Now page 2 items should appear
    expect(find.text('Initial Manga 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Recovered Manga 2'),
      300,
      scrollable: scrollableFinder,
    );
    await tester.pumpAndSettle();
    expect(find.text('Recovered Manga 2'), findsOneWidget);
    expect(requestedPages, equals([1, 2, 2]));
  });

  testWidgets('CatalogScreen empty state with hasNextPage true allows loading more and renders page 2 matching item', (WidgetTester tester) async {
    final requestedPages = <int>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(mockChannelName), (MethodCall call) async {
      if (call.method == 'getCatalog') {
        final page = (call.arguments['page'] as num?)?.toInt() ?? 1;
        requestedPages.add(page);

        if (page == 1) {
          // Page 1 returns items that do not match the section filter (e.g. status completed when section is manhwa ongoing or non-manhwa)
          // Since default active section is manhwa with publicationTypes = {PublicationType.manhwa},
          // returning genre 'manga' or mismatched genre causes it to not match or be filtered out.
          return {
            'hasNextPage': true,
            'items': [
              {
                'url': '/manga/p1_mismatched',
                'title': 'Manga Not Manhwa',
                'thumbnailUrl': '',
                'genre': 'manga',
                'status': 'ongoing',
              },
            ],
          };
        } else if (page == 2) {
          return {
            'hasNextPage': false,
            'items': [
              {
                'url': '/manga/p2_match',
                'title': 'Matching Manhwa Page 2',
                'thumbnailUrl': '',
                'genre': 'manhwa',
                'status': 'ongoing',
              },
            ],
          };
        }
      }
      return null;
    });

    final bridge = NativeExtensionsBridge.forTesting();
    final source = createMockSource(bridge);
    SourceManager.setMockSources([source]);
    SourceManager.setCurrentSource(source.id);

    final catalogProvider = CatalogProvider();
    final libraryProvider = LibraryProvider();
    final settingsProvider = AppSettingsProvider();

    await tester.pumpWidget(createTestWidget(
      catalogProvider: catalogProvider,
      libraryProvider: libraryProvider,
      settingsProvider: settingsProvider,
    ));

    await tester.pumpAndSettle();

    expect(requestedPages, contains(1));
    expect(requestedPages.where((p) => p == 1).length, equals(1));
    // Page 1 has 0 matching items, so empty state is displayed
    expect(find.text('Ничего не найдено'), findsOneWidget);
    expect(find.text('Сбросить фильтры'), findsOneWidget);
    // Since hasNextPage is true, accessible 'Загрузить ещё' button is displayed in empty state!
    expect(find.text('Загрузить ещё'), findsOneWidget);

    // Tap 'Загрузить ещё'
    await tester.tap(find.text('Загрузить ещё'));
    await tester.pumpAndSettle();

    expect(requestedPages, contains(2));
    // Now page 2 matching item should be displayed in the grid, empty state is gone
    expect(find.text('Ничего не найдено'), findsNothing);
    expect(find.text('Matching Manhwa Page 2'), findsOneWidget);
  });
}

// Dummy class matcher helper if needed
typedef ButtonWidgetFallback = Widget;
