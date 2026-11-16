# DCatcher — current state (read this first)

## COMPLETED — Flibusta Book Reading & Chapters Extraction Fix (flibusta-reading-content-fix)
- Milestone flibusta-reading-content-fix COMPLETED & VERIFIED:
  - Root Cause Analysis & Fixes:
    - Flaw 1 (HTML Parser Rejection): In `flibusta_service.dart`, `_extractChaptersFromHtml` previously checked `if (document.querySelector('#main') != null) return const [];` when `.book-read` was missing. On Flibusta's Drupal platform, books are frequently rendered directly inside `<div id="main">` with `<h3 class="book">` and `<p class="book">` without the `.book-read` wrapper, causing all such books to fail with `FormatException('Flibusta content has no readable chapters')`. Fixed by stripping non-content Drupal elements (`header, footer, nav, aside, .breadcrumb, #content-top, .tabs, .block, .help, .feed-icon, form, script, style, #sidebar-left, #sidebar-right, #header, #footer, h1.title`) and extracting readable chapters from `#main` when substantial prose (>150 chars with `<p>`/`.book` tags) is present.
    - Flaw 2 (Subdomain Redirect Rejection): When falling back to FB2 (`/b/$bookId/fb2`), Flibusta issues a 302 redirect to `https://static.flibusta.site/b.fb2/...`. `_getWithSameOriginRedirects` previously had a strict check `nextUri.host == 'flibusta.site'`, rejecting `static.flibusta.site`, returning HTTP 302, and failing FB2 fallback. Fixed by safely allowing `nextUri.host == 'flibusta.site' || nextUri.host.endsWith('.flibusta.site')` with HTTPS scheme.
    - Flaw 3 (Dynamic HTML Timeout Resilience): Flibusta dynamic HTML generator often hangs or times out on server-side rendering for large books. Added dynamic timeout adaptation (10s when FB2/EPUB fallback is available) and safe fallback to FB2/EPUB download.
  - UI Enhancements:
    - Added prominent "Читать книгу" action button directly in the loaded chapters section of `_showBookDetails` in [books_catalog_screen.dart](file:///e:/Projects/DCatcher/lib/features/books/screens/books_catalog_screen.dart).
  - Test suites:
    - [flibusta_reading_content_test.dart](file:///e:/Projects/DCatcher/test/features/books/flibusta_reading_content_test.dart) (extracts readable chapters from Drupal `#main` container when `.book-read` class is absent).
    - [flibusta_formats_fallback_test.dart](file:///e:/Projects/DCatcher/test/features/books/flibusta_formats_fallback_test.dart) (follows safe subdomain redirect to `static.flibusta.site` for FB2 archive and parses FB2).
  - Verification:
    - Full Flutter test suite: 244/244 PASS (100%).
    - Flutter analyze: 0 issues found (clean).
    - Physical device verification on Google Pixel 6a (`32041JEGR01367`): opened Flibusta book ("Мой светлый ангел"), chapters parsed immediately, tapped "Читать книгу", reader opened with full Russian text, navigated between chapters cleanly.

## PREVIOUS COMPLETED — Manga Downloads UI & Batch Operations (download-ui-and-batch)
- Milestone download-ui-and-batch COMPLETED & VERIFIED:
  - DownloadManager reactive active downloads queue:
    - Added `ActiveDownload` model and `activeDownloads`, `activeDownloadsCount` state getters in [download_manager.dart](file:///e:/Projects/DCatcher/lib/features/download/download_manager.dart).
    - Added `batchDelete(Iterable<String> chapterIds)` and `deleteAll()`.
    - Made local file checks and directory metadata reads synchronous to avoid FakeAsync scheduling deadlocks in test zones.
  - DownloadedTab & LibraryScreen UI:
    - Added live in-flight download cards with title, chapter, `LinearProgressIndicator` and percentage in [downloaded_tab.dart](file:///e:/Projects/DCatcher/lib/features/library/screens/widgets/downloaded_tab.dart).
    - Added batch selection mode with checkboxes, "Выбрать", "Все" / "Снять все", and "Отмена".
    - Added floating bottom bar with "Выбрано: N", "Удалить (N)" and safety confirmation dialog.
    - Updated [library_screen.dart](file:///e:/Projects/DCatcher/lib/features/library/screens/library_screen.dart) tab header: `Скачанное (${_dm.downloadedCount} • ↓${_dm.activeDownloadsCount})`.
  - Full test suite: 240/240 PASS (0 failures).
  - Flutter analyze: 0 issues found (clean).
  - Built debug APK, deployed to physical Pixel 6a (`32041JEGR01367`), launched and verified clean UI.

## PREVIOUS COMPLETED — Book Reading Progress Persistence & Typography Settings (book-reading-progress-typography)
- Milestone book-reading-progress-typography COMPLETED & VERIFIED:
  - Progress Persistence:
    - Created [book_progress_service.dart](file:///e:/Projects/DCatcher/lib/features/books/services/book_progress_service.dart) (`BookProgress`, `saveProgress`, `getProgress`, `clearProgress`).
    - Extended [book_shelf_item.dart](file:///e:/Projects/DCatcher/lib/features/library/models/book_shelf_item.dart) and [book_shelf_provider.dart](file:///e:/Projects/DCatcher/lib/features/library/state/book_shelf_provider.dart) with `updateBookProgress`.
    - Added automatic scroll and chapter restoration upon opening [novel_reader_screen.dart](file:///e:/Projects/DCatcher/lib/features/novel_reader/screens/novel_reader_screen.dart) from library bookshelf or catalog.
    - Added 400ms scroll debouncing and flush on `dispose()`, chapter jump, and `PopScope`.
  - Typography & Reader Settings:
    - Extended [reader_settings.dart](file:///e:/Projects/DCatcher/lib/features/novel_reader/models/reader_settings.dart) with `fontFamily` ('Roboto', 'serif', 'monospace') and `textAlign` (`TextAlign.justify`, `TextAlign.start`) with persistence.
    - Added font family and text alignment controls to reader settings sheet.
  - Test suites:
    - [book_reading_progress_test.dart](file:///e:/Projects/DCatcher/test/features/novel_reader/book_reading_progress_test.dart) (9/9 tests GREEN).
  - Full Flutter test suite: 236/236 PASS. Clean build on Pixel 6a.

## PREVIOUS COMPLETED — Manga Reader Slide Retry, Timeout & SSL Warning (reader-slide-retry-ssl)
- Milestone reader-slide-retry-ssl COMPLETED & VERIFIED:
  - Manga Reader Slide Recovery:
    - Added 15s timeout with `TimeoutException` and interactive `errorRetryWidget` in [dcatcher_image.dart](file:///e:/Projects/DCatcher/lib/core/widgets/dcatcher_image.dart).
    - Integrated interactive retry buttons in [paged_reader_screen.dart](file:///e:/Projects/DCatcher/lib/features/reader/screens/paged_reader_screen.dart) and [webtoon_reader_screen.dart](file:///e:/Projects/DCatcher/lib/features/reader/screens/webtoon_reader_screen.dart).
  - MangaBuff Subresource SSL Warning:
    - Differentiated main frame vs subresource SSL warnings in [SourceLoginActivity.kt](file:///e:/Projects/DCatcher/android/app/src/main/kotlin/com/example/manga_reader_app/SourceLoginActivity.kt).
    - Added dismissible warning banner while strictly preserving TLS safety (`handler?.cancel()`).
  - Test suites:
    - [reader_slide_retry_test.dart](file:///e:/Projects/DCatcher/test/features/reader/reader_slide_retry_test.dart) (3/3 tests GREEN).
  - Full Flutter test suite: 227/227 PASS. Clean build on Pixel 6a.

## PREVIOUS COMPLETED — Advanced Multi-token Search, Smart Genre Navigation & Catalog Pagination (flibusta-search-genres-pagination)
- Milestone flibusta-search-genres-pagination COMPLETED & VERIFIED:
  - Smart Multi-token & Inverted Search:
    - Added `BooksRepository.matchesSearch(book, search)` supporting multi-token queries across title, author, genre, and description with Russian noun/adjective inflection support (stemming).
    - Fixed critical bug where author+title queries ("стругацкие пикник", "толстой война", "оруэлл 1984") and inverted names ("лев толстой" vs "Толстой Лев") previously resulted in 0 matches due to strict single-string equality.
  - Smart Genre Navigation:
    - Added `BooksRepository.matchesGenre(book, genre)` with semantic classification for all chips ("Фантастика", "Детектив", "Приключения", "Классика", "Мистика и Ужасы"), matching subgenres (e.g. "Научная фантастика", "Боевая фантастика", "sf_action", "Фэнтези" for "Фантастика", "Классическая литература" for "Классика").
    - Added standard OPDS/FB2 category term mapping in [flibusta_opds_parser.dart](file:///e:/Projects/DCatcher/lib/features/books/services/flibusta_opds_parser.dart) (`sf` -> "Фантастика", `prose_classic` -> "Классическая проза", `detective` -> "Детектив", etc.) and multi-category checking.
  - Pagination & Resilient Network Loading:
    - Extended Flibusta search timeout from 7s to 15s in [flibusta_service.dart](file:///e:/Projects/DCatcher/lib/features/books/services/flibusta_service.dart) to eliminate frequent false timeouts on live slow queries.
    - Added `RefreshIndicator` (pull-to-refresh) in [books_catalog_screen.dart](file:///e:/Projects/DCatcher/lib/features/books/screens/books_catalog_screen.dart).
    - Added empty-filtered-page state with dedicated prompt and "Загрузить ещё" button to continue paginating to subsequent OPDS pages.
  - Test suites:
    - [flibusta_search_and_genres_test.dart](file:///e:/Projects/DCatcher/test/features/books/flibusta_search_and_genres_test.dart) (12/12 tests GREEN).
    - Total books suite: 87/87 tests GREEN.
  - Full Flutter test suite: 224/224 PASS (0 failures).
  - Flutter analyze: 0 issues found (clean).
  - Built debug APK and deployed to physical Pixel 6a (`32041JEGR01367`) via `adb install -r`. App restarted (PID: 24175) and running clean.

## PREVIOUS COMPLETED — FictionBook 2 (FB2 / FB2.zip) & EPUB Parsers with Automatic Fallback (fb2-epub-support)
- Milestone fb2-epub-support COMPLETED & VERIFIED:
  - Added pure-Dart parsers for book formats:
    - [fb2_book_parser.dart](file:///e:/Projects/DCatcher/lib/features/books/services/fb2_book_parser.dart): supports raw XML `.fb2` and compressed `.fb2.zip` archives via `archive` and `xml`. Extracts book metadata (`title`, `authors`, `genres`, `annotation`) and sections/chapters while preserving poetic stanzas.
    - [epub_book_parser.dart](file:///e:/Projects/DCatcher/lib/features/books/services/epub_book_parser.dart): supports standard EPUB archives reading `META-INF/container.xml`, parsing the `.opf` package manifest and spine order, and converting XHTML chapters to clean prose using `html`.
  - Service & Repository Fallback integration:
    - [flibusta_service.dart](file:///e:/Projects/DCatcher/lib/features/books/services/flibusta_service.dart): extended `fetchBookChapters(bookId, {availableFormats})` with transparent fallback. If online reading (`/read`) returns 404 / unavailable, it attempts download and parse of `/epub` (if in formats) or `/fb2` (if in formats), preserving URL redaction in error messages.
    - [books_repository.dart](file:///e:/Projects/DCatcher/lib/features/books/services/books_repository.dart): wires `book.availableFormats` into `flibusta.fetchBookChapters`.
  - Verified with new unit test suites:
    - [fb2_book_parser_test.dart](file:///e:/Projects/DCatcher/test/features/books/fb2_book_parser_test.dart) (4/4 tests GREEN)
    - [epub_book_parser_test.dart](file:///e:/Projects/DCatcher/test/features/books/epub_book_parser_test.dart) (2/2 tests GREEN)
    - [flibusta_formats_fallback_test.dart](file:///e:/Projects/DCatcher/test/features/books/flibusta_formats_fallback_test.dart) (2/2 tests GREEN)
  - Full Flutter test suite: 212/212 PASS (0 failures).
  - Flutter analyze: 0 issues found (clean).
  - Built debug APK and deployed to physical Pixel 6a (`32041JEGR01367`) via `adb install -r`. App restarted (PID: 23809) with 0 crash errors in logcat.

## PREVIOUS COMPLETED — Removed Fake TTS & Verified Clean Reader UI (tts-removal)
- Milestone tts-removal COMPLETED & VERIFIED:
  - Completely excised legacy placeholder TTS from [novel_reader_screen.dart](file:///e:/Projects/DCatcher/lib/features/novel_reader/screens/novel_reader_screen.dart):
    - Removed `_isSpeaking` state variable and navigation resets.
    - Removed `IconButton` for TTS from the reader frosted-glass toolbar.
    - Top bar now contains only Back button, book/chapter title, and Font & Theme settings.
  - Updated test in [novel_reader_footer_labels_test.dart](file:///e:/Projects/DCatcher/test/features/novel_reader/novel_reader_footer_labels_test.dart) asserting zero TTS/volume widgets in toolbar.
  - Rebuilt debug APK and installed to connected Pixel 6a (`32041JEGR01367`) via `adb install -r`. App restarted (PID: 23562) and running clean.
  - Full Flutter test suite: 204/204 PASS (0 failures).
  - Flutter analyze: 0 issues found (clean).

## PREVIOUS COMPLETED — Native 16KB Page Alignment & Live Device Deployment (native-16kb-alignment)
- Milestone native-16kb-alignment COMPLETED & VERIFIED:
  - Root cause resolved: Google Android 15+ 16KB page size requirement caused alignment warning / crash on uncompressed 4KB ELF `libquickjs.so` in APK.
  - Fix applied in [build.gradle.kts](file:///e:/Projects/DCatcher/android/app/build.gradle.kts): enabled `packaging.jniLibs.useLegacyPackaging = true`, generating `android:extractNativeLibs="true"` in AndroidManifest.xml.
  - Verified on physical Pixel 6a (`32041JEGR01367`):
    - Installed via `adb -s 32041JEGR01367 install -r build/app/outputs/flutter-apk/app-debug.apk` without data wipe (Success).
    - Verified extraction: `/data/app/.../lib/arm64/libquickjs.so` (854,224 bytes) physically extracted and page-aligned by the OS package manager.
    - App launched via `am start` (PID: 22776) running cleanly with zero crashes in logcat.
  - Full Flutter test suite: 204/204 PASS (0 failures).
  - Flutter analyze: 0 issues found (clean).

## PREVIOUS COMPLETED — Books Catalog Empty State & Search Reset UX (books-catalog-empty-ux)
- Milestone books-catalog-empty-ux COMPLETED & VERIFIED:
  - BooksCatalogScreen empty states & search UX:
    - Added dedicated empty search state: icon `Icons.search_off_rounded`, explicit quote `'По запросу «$_appliedSearch» ничего не найдено'`, subtitle explanation, and one-tap `'Сбросить поиск'` button.
    - Added dynamic clear button (`Icons.clear`) in search text field with listener integration and proper memory disposal in `dispose()`.
    - Added specialized empty offline state: icon `Icons.download_done_rounded`, `'Нет скачанных книг'` and subtitle `'Книги, сохранённые для офлайн-чтения, появятся здесь'`.
    - Retained source catalog empty notice with genre reset option (`'Показать все жанры'`).
  - Test suite:
    - [books_catalog_search_empty_test.dart](file:///e:/Projects/DCatcher/test/features/books/books_catalog_search_empty_test.dart) (2 tests GREEN)
  - Full Flutter test suite: 204/204 PASS (0 failures).
  - Flutter analyze: 0 issues found (clean).

## PREVIOUS COMPLETED — Books Details Metadata & NovelReader Chapter Labels/TTS (books-metadata-reader-labels)
- Milestone books-metadata-reader-labels COMPLETED & VERIFIED:
  - BooksCatalogScreen details modal:
    - Displays year badge (`${book.year} г.`) only when `book.year > 0`, suppressing misleading `0 г.` sentinel value.
    - Displays rating badge (`★ ${book.rating.toStringAsFixed(1)}`) only when `book.rating > 0`, suppressing `★ 0.0`.
    - Contextualized source badges: "Скачано • Офлайн", "Классика • Свободный доступ", "Моя книга • Локально", "Флибуста • Бесплатно".
  - NovelReaderScreen footer & controls:
    - Smart chapter label formatting: "Введение" / "Пролог" for prologue / chapter '0', "Часть N" for parts, "Глава N" for standard numbered chapters.
    - Honest TTS SnackBar feedback notifying user that text-to-speech is in development instead of silent or fake status.
  - Test suites:
    - [books_details_metadata_test.dart](file:///e:/Projects/DCatcher/test/features/books/books_details_metadata_test.dart) (1 test GREEN)
    - [novel_reader_footer_labels_test.dart](file:///e:/Projects/DCatcher/test/features/novel_reader/novel_reader_footer_labels_test.dart) (3 tests GREEN)
  - Full Flutter test suite: 202/202 PASS (0 failures).
  - Flutter analyze: 0 issues found (clean).

## PREVIOUS COMPLETED — Reader Error Handling & Stalled Chapter Image Recovery (reader-error-recovery)
- Milestone reader-error-recovery COMPLETED & VERIFIED:
  - Root cause resolved: `PagedReaderScreen` and `WebtoonReaderScreen` lacked `try/catch/timeout` blocks in `_loadPages()`, causing infinite spinners on bridge/network exceptions (`PAGES_ERROR`) and displaying "Страница 1 из 0" on empty chapter responses.
  - Added 15s bounded timeout and comprehensive exception catching in `PagedReaderScreen` and `WebtoonReaderScreen`.
  - Added user-facing error & empty-state view with retry button ("Повторить попытку") and "Назад к списку глав".
  - Made reader appbar and back button accessible during error states so users are never trapped.
  - Added optional `source` dependency injection to both reader constructors for clean modularity.
  - New test suite [reader_error_recovery_test.dart](file:///e:/Projects/DCatcher/test/features/reader/reader_error_recovery_test.dart) (4 tests GREEN): exception recovery, retry button tap, clean empty state avoiding "1 из 0", and missing source error handling.
  - Full Flutter test suite: 198/198 PASS (0 failures).
  - Flutter analyze: 0 issues found (clean).
  - Debug APK build: SUCCESS (`build\app\outputs\flutter-apk\app-debug.apk`).

## PREVIOUS COMPLETED — offline feature (flibusta-offline)
- Owner lease flibusta-offline COMPLETED & VERIFIED:
  - BookOfflineStore (8 tests GREEN): real disk fresh-instance rehydration, strict schema/size/empty guards, safe staging/rename.
  - BooksRepository (2 tests GREEN): downloadedSource and getChapters noHTTP.
  - BookOfflineActions widget (2 tests GREEN): save button persists chapters to store, transitions to "Скачано" with delete option, real FS error handling.
  - Offline Catalog & UI flow (books_offline_widget_test.dart GREEN): restore downloaded source, view saved book, zero HTTP calls, bottom sheet action "Удалить с устройства", navigate to NovelReaderScreen and read offline chapter prose, delete offline book and verify empty list.
  - Full Flutter test suite: 194/194 PASS (0 failures).
  - Flutter analyze: 0 errors, 0 warnings.
  - Debug APK build: SUCCESS (`build\app\outputs\flutter-apk\app-debug.apk`).

## Scope / coordination
- Project E:/Projects/DCatcher. User asked to continue implementation, not wait. Coding through Antigravity CLI; Hermes independently reviews, tests, builds and checks Pixel7. Preserve unrelated dirty tree, curated prose, user library/settings. No commits, global installs, credential scraping, SSL/access bypass or data wipes. Account login deferred; MangaBuff is active manga source.
- Milestone owner flibusta-chapter-hierarchy released on completion. Managed AGY proc_134d1576a074 was stopped after its edit; ignore delayed heartbeat. Cron9ee7271edbd7 remains paused. Do not claim unattended continuation.

## Latest verified artifact
- Installed debug APK: build/app/outputs/apk/debug/app-debug.apk.
- Local/installed SHA256 MATCH: c00ee81690ab754117d047946a4bc1bda68c45df4628c70f6c200f3b65d39290. Installed with -r, no wipe. Pixel7 serial35051FDH2004PP; always specify serial on adb.
- Full Flutter160PASS. Analyzer0errors/0warnings/10pre-existing infos (Flutter analyze exits1 for infos; parent parsed actual levels). Gradle :app:assembleDebug SUCCESS. Native109/0failures/1skip is an OLDER result, not rerun for Dart-only increment. git diff --check PASS. No commits.

## Newly completed
1. Poetic stanza headings inside .book-read .poem/.stanza are preserved as paragraph text instead of chapter boundaries. Confirmed real HTML has h3 for BOTH chapter headings and Roman stanza numbers, so tag level alone was insufficient. Two genuine RED->GREEN tests cover two chapters with nested stanza headings, and short standalone poem under200chars. Empty reader still rejects. Source prefix (curated data/HTTPpolicy) and suffix bytes compared to pre-task snapshot and preserved.
2. Captured actual1837 HTML227805 service smoke:12 readable sections instead of384,224922contentchars including retained stanza labels. This includes front/back matter, not exactly12 author-written chapters. Poem grouping and reader navigation received separate independent AGY reviews, both PASS.
3. Real previous/next chapter navigation now implemented; formerly both callbacks were empty. Uses active chapter ID and supplied list order, rejects missing IDs/empty lists, disables first/last boundary buttons. Title/body/footer update; scroll and progress reset; settings provider retained. Five navigation regressions observedRED before GREEN. Existing chooser without allChapters honestly has disabled arrows; main books caller supplies list.
4. Reader Scaffold SafeArea fixes actual Pixel statusbar/title overlap; initial book title no longer hidden behind toolbar. Dedicated top64/bottom24 inset regression observedRED->GREEN. One delegated missing closing paren was caught by parent compiler and fixed before final160PASS/build; never treat initial partial review/failed build as acceptance.

## Real device evidence on FINAL artifact
- Actual online search1837 -> genuine Flibusta entry Евгенiй Онѣгинъ [Евгений Онегин] [1837], authorPushkin, id227805 -> fetched real text -> 12-section TOC -> ГЛАВА ПЕРВАЯ with Мой дядя -> Следующая глава -> ГЛАВА ВТОРАЯ with Деревня -> Предыдущая глава -> ГЛАВА ПЕРВАЯ. Parent assertions and screenshots confirm changed content and progress0. No mocked/replaced app state, VM mutations, injected catalogs or fixture book imported.
- Earlier installed poem-only build also scrolled from stanzaI toII within SAME first chapter. Final nav build shares same verified parser and has better insets.
- Screenshots in scratch/dcatcher-toolchain/device/flibusta-final-reader-chapter1.png and chapter2.png visually inspected. Floating controls can overlay scrolling text by design; tap text hides them. System bar/title clipping fixed.
- Search is intermittent: full Евгений Онегин query timed out on final attempt on BOTH phone and PC(15s). Alternative genuine query1837 succeeded on phone. Keep bounded requests/retry and honest errors, do not declare source always available. Original QWERTY keyboard restored and visually checked after Cyrillic input; phone returned to main Manhwa/MangaBuff. No account interaction.
- One coordinate-input recovery mistap opened another recent book modal and auto-fetch returned unavailable; modal closed. Do not claim only intended metadata request ever occurred. Guard IME visibility before coordinate typing.

## Remaining work / honest boundaries
- Persistent book downloads/cache plus offline cold restart/resume are NOT implemented/proven by this online test. Repository chapter cache is memory-only. Implement a real user-visible offline path, not a hidden fixture/state injection.
- Online Flibusta PDF rendering and acquisition/download/unpacking of EPUB/FB2 archives remain separate features; badges/PDF-only notices do NOT provide those readers. This does not assert anything about pre-existing local imports. Prior live PDF notice on Мышанё Пік and unit zero/read requests remain verified in earlier milestone.
- TTS control is pre-existing snackbar-only placeholder, NOT real speech. Do not describe audio as working. Reader footer currently uses ordinal section number (includes frontmatter), not author's printed chapter numbering; generic section labels would be clearer. Arbitrary nested prose heading hierarchy remains a separate compatibility case; this increment specifically fixes poem/stanza wrappers.
- Other known deferred issues: MANGAPlus chapter images stall; 16KB alignment warning for libquickjs.so (Pixel actual page4096), not hidden; MangaBuff SSL banner cause unverified. Never weaken TLS. Account login explicitly deferred.

## Evidence and next lookup
- Logs scratch/dcatcher-continuous/: flibusta-poem-{red,green,full,analyze,build}.log; flibusta-short-poem-red.log; novel-navigation-{red,edges-red,green,final-focused,review}.log; novel-safe-area-red.log; flibusta-reader-final-{full,analyze,build}.log. Final review JSON parsed passed/empty blocker lists.
- New tests: test/features/books/flibusta_poem_grouping_test.dart; test/features/novel_reader/novel_reader_navigation_test.dart; novel_reader_safe_area_test.dart. Manual captured HTML harness outside CI remains scratch/live_reading_smoke_test.dart.
- Product changes this increment only flibusta_service.dart extraction branch and novel_reader_screen.dart active state/navigation/SafeArea. Pre-task raw source snapshots in scratch. No other source implementation changed.
- Historical auth/source-label/pagination/reading-format details in AUTONOMOUS_NEXT.md; its older counts/hashes are superseded. Do not load giant historical files without a specific question.
- Toolchain scratch/dcatcher-toolchain: Flutter flutter/bin/flutter.bat; Java java/jdk-21.0.13+9; Gradle gradle-8.14.3/bin/gradle.bat; SDK android-sdk; GRADLE_USER_HOME gradle-user-home. Workdir project/android for Gradle, explicit JAVA_HOME and -Dorg.gradle.java.home. Use native C:/ paths; no global tool installs.
