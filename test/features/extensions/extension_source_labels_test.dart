import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/core/widgets/shadcn_badge.dart';
import 'package:manga_reader_app/core/widgets/shadcn_button.dart';
import 'package:manga_reader_app/features/extensions/models/keiyoushi_extension.dart';
import 'package:manga_reader_app/features/extensions/screens/extensions_screen.dart';
import 'package:manga_reader_app/features/extensions/services/keiyoushi_repository.dart';
import 'package:manga_reader_app/features/extensions/services/native_extensions_bridge.dart';
import 'package:manga_reader_app/features/sources/source_manager.dart';

class _FakeRepoBridge extends NativeExtensionsBridge {
  _FakeRepoBridge() : super.forTesting();

  @override
  Future<List<NativePackageDto>> listInstalled() async {
    return const [];
  }
}

class _FakeStoreRepository extends KeiyoushiRepository {
  final List<KeiyoushiExtension> extensionsToReturn;

  _FakeStoreRepository({
    this.extensionsToReturn = const [],
  }) : super(installedStore: MemoryInstalledExtensionsStore());

  @override
  Future<List<KeiyoushiExtension>> fetchExtensions({String? repoUrl}) async {
    return extensionsToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SourceManager.resetForTesting();
  });

  // Helper to create 28 Dragon Ball Multiverse sources with different IDs and languages
  List<KeiyoushiSource> createDbmSources() {
    final languages = [
      'all', 'en', 'fr', 'ru', 'es', 'de', 'it', 'pt', 'ja', 'zh',
      'ar', 'pl', 'nl', 'ko', 'tr', 'vi', 'id', 'hu', 'cs', 'el',
      'he', 'ca', 'bg', 'ro', 'sv', 'da', 'fi', 'no',
    ];
    return List.generate(28, (index) {
      final lang = languages[index % languages.length];
      return KeiyoushiSource(
        id: '${7000000000000000000 + index}',
        name: 'Dragon Ball Multiverse',
        language: lang,
        homeUrl: 'https://www.dragonball-multiverse.com',
      );
    });
  }

  group('ExtensionsScreen Source Badges and Language Variants', () {
    testWidgets(
      '1 defaultAll: sameNameLanguageVariants produce ONE summary source badge (not 28), metadata IDs unchanged; label includes language codes or group count not ambiguous same bare text',
      (tester) async {
        final dbmSources = createDbmSources();
        final dbmExtension = KeiyoushiExtension(
          name: 'Dragon Ball Multiverse',
          packageName: 'eu.kanade.tachiyomi.extension.all.dragonballmultiverse',
          versionName: '1.4.28',
          versionCode: '28',
          extensionLib: '1.4',
          apkUrl: 'https://example.com/dbm.apk',
          iconUrl: '',
          contentWarning: ContentWarning.safe,
          sources: dbmSources,
        );

        final mockBridge = _FakeRepoBridge();
        final repo = _FakeStoreRepository(extensionsToReturn: [dbmExtension]);

        await tester.pumpWidget(
          MaterialApp(
            home: ExtensionsScreen(
              repository: repo,
              bridge: mockBridge,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify underlying extension metadata IDs remain unchanged
        expect(dbmExtension.sources.length, equals(28));
        final uniqueIds = dbmExtension.sources.map((s) => s.id).toSet();
        expect(uniqueIds.length, equals(28));

        // 2. Find badges rendered inside the extension card
        final badges = tester.widgetList<ShadcnBadge>(find.byType(ShadcnBadge)).toList();
        final sourceBadges = badges.where((b) => b.label != '18+').toList();

        // Under current bug: produces 28 badges with identical bare text "Dragon Ball Multiverse"
        // Expected requirement: exactly ONE summary badge for the same-name group
        expect(
          sourceBadges.length,
          equals(1),
          reason: 'Expected 1 collapsed/summary badge for same-name variants, but found ${sourceBadges.length}',
        );

        final summaryBadge = sourceBadges.first;
        // The summary badge label must NOT be just bare ambiguous "Dragon Ball Multiverse".
        // It must include language codes or group count (e.g., "(28)", "[28]", or language tags like "all, en, fr..." / "28 langs")
        final label = summaryBadge.label;
        final hasCountOrLang = label.contains(RegExp(r'(\d+|\[.*\]|\(.*\)|languages|langs)'));
        expect(
          hasCountOrLang,
          isTrue,
          reason: 'Summary badge label "$label" should include language codes or variant/group count, not bare ambiguous text',
        );
        expect(label, isNot(equals('Dragon Ball Multiverse')));
      },
    );

    testWidgets(
      '2 tap Русский (RU): card badges show only RU and universal language sources, not FR/EN names; preserve underlying records',
      (tester) async {
        final multiSources = [
          const KeiyoushiSource(
            id: '8000000000000000001',
            name: 'MangaDex RU',
            language: 'ru',
            homeUrl: 'https://mangadex.org',
          ),
          const KeiyoushiSource(
            id: '8000000000000000002',
            name: 'MangaDex Universal',
            language: 'all',
            homeUrl: 'https://mangadex.org',
          ),
          const KeiyoushiSource(
            id: '8000000000000000003',
            name: 'MangaDex FR',
            language: 'fr',
            homeUrl: 'https://mangadex.org',
          ),
          const KeiyoushiSource(
            id: '8000000000000000004',
            name: 'MangaDex EN',
            language: 'en',
            homeUrl: 'https://mangadex.org',
          ),
        ];

        final extension = KeiyoushiExtension(
          name: 'MangaDex Multi',
          packageName: 'eu.kanade.tachiyomi.extension.all.mangadex',
          versionName: '1.2.0',
          versionCode: '12',
          extensionLib: '1.4',
          apkUrl: 'https://example.com/mangadex.apk',
          iconUrl: '',
          contentWarning: ContentWarning.safe,
          sources: multiSources,
        );

        final mockBridge = _FakeRepoBridge();
        final repo = _FakeStoreRepository(extensionsToReturn: [extension]);

        await tester.pumpWidget(
          MaterialApp(
            home: ExtensionsScreen(
              repository: repo,
              bridge: mockBridge,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially in "all", all 4 are rendered under current implementation
        // Tap "Русский (RU)" filter chip
        final ruFilterChip = find.widgetWithText(ChoiceChip, 'Русский (RU)');
        expect(ruFilterChip, findsOneWidget);
        await tester.tap(ruFilterChip);
        await tester.pumpAndSettle();

        // Verify underlying records preserved
        expect(extension.sources.length, equals(4));

        // When RU is selected, card badges should only show RU and universal language sources ('all'),
        // and NOT FR or EN sources!
        final badgesAfterFilter = tester.widgetList<ShadcnBadge>(find.byType(ShadcnBadge)).toList();
        final badgeLabels = badgesAfterFilter.map((b) => b.label).toList();

        expect(badgeLabels.any((l) => l.contains('MangaDex FR')), isFalse);
        expect(badgeLabels.any((l) => l.contains('MangaDex EN')), isFalse);
        expect(badgeLabels.any((l) => l.contains('MangaDex RU')), isTrue);
        expect(badgeLabels.any((l) => l.contains('MangaDex Universal')), isTrue);
      },
    );

    testWidgets(
      '3 width 360: extremely long source name + multilingual sameName groups has no RenderFlex overflow; install button still reachable',
      (tester) async {
        // Set narrow screen width (360x800) typical mobile viewport
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final dbmSources = createDbmSources();
        const extremelyLongNamedSource = KeiyoushiSource(
          id: '9999999999999999999',
          name: 'Supercalifragilisticexpialidocious Ultra Long Manga Source Name With Extensive Subtitle And Metadata Info That Wraps Multiple Lines',
          language: 'ru',
          homeUrl: 'https://example.com',
        );

        final extension = KeiyoushiExtension(
          name: 'Massive Multilingual Extension With Very Long Title Header',
          packageName: 'eu.kanade.tachiyomi.extension.all.massivemultilingual',
          versionName: '2.0.0',
          versionCode: '200',
          extensionLib: '1.5',
          apkUrl: 'https://example.com/massive.apk',
          iconUrl: '',
          contentWarning: ContentWarning.safe,
          sources: [extremelyLongNamedSource, ...dbmSources],
        );

        final mockBridge = _FakeRepoBridge();
        final repo = _FakeStoreRepository(extensionsToReturn: [extension]);

        await tester.pumpWidget(
          MaterialApp(
            home: ExtensionsScreen(
              repository: repo,
              bridge: mockBridge,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify that no RenderFlex overflow exception was thrown or logged
        expect(tester.takeException(), isNull);

        // 2. Verify "Установить" button is still reachable and visible in the viewport
        final installButtonFinder = find.widgetWithText(ShadcnButton, 'Установить');
        expect(installButtonFinder, findsOneWidget);

        final installButtonRect = tester.getRect(installButtonFinder);
        expect(installButtonRect.left, greaterThanOrEqualTo(0));
        expect(installButtonRect.right, lessThanOrEqualTo(360));
        expect(installButtonRect.width, greaterThan(0));

        // 3. Verify sameName multilingual sources are summarized so it doesn't span unbounded badges
        final badges = tester.widgetList<ShadcnBadge>(find.byType(ShadcnBadge)).toList();
        final dbmBadges = badges.where((b) => b.label.contains('Dragon Ball Multiverse')).toList();
        expect(
          dbmBadges.length,
          equals(1),
          reason: 'Multilingual sameName group should be grouped into a single badge',
        );
      },
    );
  });
}
