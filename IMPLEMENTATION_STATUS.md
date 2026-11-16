# DCatcher Keiyoushi Android Extensions Integration

## Implementation Status & Milestones

### Supervisor & Upstream Architecture Directives
- **Store Protocol**: Official store endpoint `https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.json` (modern schema `extensionList.extensions`) and Protocol Buffers `index.pb` (`mihon://extension-store?url=...`). Deprecate `index.min.json` (sentinel-only entries).
- **Data Integrity**: 64-bit string source IDs (`id`) and `versionCode` preserved as decimal strings without integer precision loss.
- **Security & Origin Validation**:
  - Pinned trusted Keiyoushi certificate SHA256 fingerprint: `9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2`.
  - Rejection of malicious URLs, untrusted origins, and path traversal attempts.
  - Explicit user confirmation dialog before installing and executing third-party code.
  - Initial state: Zero installed extensions (on-demand download & load only).
- **Native Android Runtime (Upcoming / Antigravity Android coder)**:
  - Mihon `source-api` & `core-common` runtime (Apache 2.0).
  - API 1.6 coroutine `suspend` methods (`getPopularManga`, `getSearchManga`, `getMangaUpdate`, `getPageList`).
  - `Injekt` dependency injection exporting `Application`, `Context`, `Json`, `ProtoBuf`, `XML`, `NetworkHelper`, `JavaScriptEngine`.
  - Host interceptors required by `KeiSource`: `UncaughtExceptionInterceptor`, `UserAgentInterceptor`, `CloudflareInterceptor`, plus reflection support for `HttpSource.headers$delegate`.
  - Image fetching client with headers/cookies, page fallback URL resolver.
- **Multi-Source Library & Reader**:
  - Preserve `sourceId` on all library items and reading history across source switches.
  - Route extension-source covers and reader pages through native `fetchImage` bytes (using native interceptors/cookies), while preserving books/non-extension behavior.
  - Truthful unsupported platform notice on Web / non-Android without crashing.

---

### Implementation Milestones

- [x] **Milestone 1: Keiyoushi Store Models & Repository Service (TDD GREEN Completed)**
  - [x] Create comprehensive failing unit tests (`test/features/extensions/keiyoushi_store_test.dart`)
  - [x] Implement `lib/features/extensions/models/keiyoushi_extension.dart`
  - [x] Implement `lib/features/extensions/services/keiyoushi_repository.dart`
  - [x] Reject malformed/missing extensionList (no silent empty list returns)
  - [x] Strict canonical decimal string validation for source ID and versionCode (rejecting precision-loss doubles)
  - [x] Dedicated native installer backend interface `ExtensionInstallerBackend` (list, install, uninstall) with exact error propagation for UI retry
  - [x] Rehydrate installed state from native backend on restart
  - [x] Pre-existing Flutter 3.47 compatibility fix in `lib/core/theme/app_theme.dart:35` (`CardTheme` -> `CardThemeData`)
  - [x] Verify test suite turns GREEN (19/19 tests passing)

- [x] **Milestone 2: Security Validation & Trust Confirmation (Core Validation Complete)**
  - [x] Origin verification (strict check against official Keiyoushi GitHub release endpoints)
  - [x] Validate actual repository signingKey against pinned fingerprint (`9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2`)
  - [x] Security checks: Rejects non-443 ports, query/fragment params, encoded slashes (%2f), encoded backslashes (%5c), raw backslashes, path traversal, credentials, host suffix tricks
  - [x] Forbids arbitrary repoUrl override pointing to untrusted domains
  - [x] HTTP client ownership and disposal management, request timeout and maximum response size bounds (10MB)
  - [x] Real native installer boundary: extension is marked installed ONLY upon native success; rollback on failure; native state rehydration on restart
  - [x] User consent state management & UI confirmation dialog (`_confirmAndInstall` in `ExtensionsScreen`)

- [x] **Milestone 3: Bridge & UI Resolution / Compatibility Alignment**
  - [x] Fixed `catalog_screen.dart`: Safe handling of `catalog.source == null` in popup menu (lines 404, 410, 411) and title (`catalog.source?.name ?? 'Нет источников'`).
  - [x] Added narrow UI entrypoints for `ExtensionsScreen`: Header icon button, section selector menu item, and empty state prompt.
  - [x] Fixed `catalog_filters.dart`: Added compatibility getters/setters (`query`, `includedGenres`, `excludedGenres`).
  - [x] Fixed `extensions_screen.dart`: `ShadcnButton` `label:` -> `text:`, and replaced nonexistent `ShadcnColors.secondary` with `ShadcnColors.surface`.
  - [x] Fixed `library_provider.dart:98`: Safe null check on `existing.sourceId` with fallback to compound ID prefix.
  - [x] Fixed 5 legacy adapters (`AsuraScansSource`, `MangaBuffSource`, `MangaDexSource`, `MangaLibSource`, `RemangaSource`): Implemented `getHeaders` and `fetchImage`.
  - [x] Exported `SecurityException` from `native_extensions_bridge.dart` for direct availability in test suites.

- [x] **Milestone 4: Native Image Pipeline Integration & Acceptance Criteria**
  - [x] Created `DcatcherImage` widget in `lib/core/widgets/dcatcher_image.dart` routing extension sources through `ExtensionMangaSource.fetchImage`.
  - [x] Enforced strict non-silent fallback on `ExtensionMangaSource.fetchImage`: Throws exception on null/empty bytes, preventing unauthenticated direct HTTP leaks.
  - [x] Integrated `DcatcherImage` across `manga_card.dart`, `manga_detail_screen.dart`, `library_screen.dart`, `paged_reader_screen.dart`, and `webtoon_reader_screen.dart`.
  - [x] Preserved normal `CachedNetworkImage` behavior for books/non-extension sources.
  - [x] Added automated widget and unit tests in `test/features/sources/extension_image_test.dart`.

- [x] **Milestone 5: App Startup & UI Flow Acceptance Fixes**
  - [x] Startup `SourceManager.initialize()` invoked in `lib/main.dart` before `runApp` for immediate native package restoration on app start and restart.
  - [x] Offline resilience: `ExtensionsScreen._loadData` displays native installed packages even when store GitHub fetch fails.
  - [x] Native package integrity: `_executeInstall` and `_uninstall` query actual `_bridge.listInstalled()` rather than synthesizing from catalog metadata.
  - [x] Typed error `MissingExtensionSourceException` in `DcatcherImage` when an extension source is missing/uninstalled (no network fallback leak).
  - [x] Byte-budgeted LRU cache in `DcatcherImage` (32MB budget) preventing memory exhaustion.
  - [x] Automated regression tests in `test/features/extensions/extensions_screen_test.dart` and `test/features/sources/extension_image_test.dart`.

- [x] **Milestone 6: End-to-End Mapping & Data Integrity**
  - [x] Dynamically map `PublicationType` in `ExtensionMangaSource.getCatalog` (genre detection & section filter awareness) instead of hardcoding `all`.
  - [x] Fixed `CatalogProvider.applyLocalFilters`: allows items matching selected publication types or `all`, eliminating empty catalog bug.
  - [x] Chapter `dateUpload` epoch-ms conversion with bounds in `ExtensionMangaSource.parseDateUpload` handling Tachiyomi `Long` timestamps (`1709424000000`).
  - [x] Strict source ID check in `ExtensionMangaSource.decodeUrl`: throws `ArgumentError` when compound prefix belongs to another source.
  - [x] Native status Byte numeric mapping in `ExtensionCatalogItem.parseStatus` (1 -> ongoing, 2/4 -> completed, 5/6 -> hiatus).
  - [x] Automated focused regression tests in `test/features/sources/end_to_end_mapping_test.dart`.

- [x] **Milestone 7: Test Stability, Fail-Closed DTOs & Detail Screen Error Recovery**
  - [x] Fixed `extensions_screen_test.dart` and `extension_image_test.dart`: Added `SharedPreferences.setMockInitialValues({})` and `SourceManager.resetForTesting()` in `setUp()`, eliminating `MissingPluginException` for `getAll` and method channel timeouts.
  - [x] Fixed `MockFailingStoreRepository`: returns `extensionsToReturn` directly instead of calling `super.fetchExtensions()` when `failFetch: false`, completely preventing unmocked live HTTP calls during tests.
  - [x] Fixed `MockNativeBridge.fetchImage` override signature to non-nullable `Future<Uint8List>`.
  - [x] Fail-closed native DTOs: `NativePackageDto.toExtension` strictly uses loaded `sources: sources`, never fabricating active sources from catalog metadata when native reports empty sources.
  - [x] Strict DTO validation: `NativePackageDto.fromJson` rejects missing/empty `packageName`, `versionCode`, or `extensionLib` with `FormatException`.
  - [x] Avoid inventing type from filter: Removed active filter tab fallback (lines 72-74) in `ExtensionMangaSource.determinePublicationType`. Untagged items retain `PublicationType.all` and are not falsely converted to manhwa/forced into webtoon reader.
  - [x] `MangaDetailScreen`: Wrapped `_loadChapters` in `try/catch/finally` ensuring `_isLoadingChapters` is always cleared; surfaces `MissingExtensionSourceException` and native/network errors with retry button; reader routing aligns with metadata via `isWebtoonManga`.
  - [x] Added automated regression tests in `test/features/catalog/manga_detail_screen_test.dart`, `test/features/extensions/keiyoushi_store_test.dart`, and `test/features/sources/end_to_end_mapping_test.dart`.

- [x] **Milestone 8: Download Integrity & Native Routing**
  - [x] `DownloadManager.downloadChapter`: Compound chapter ID with missing source does NOT fall back to active source (`SourceManager.currentSource`); fails typed with `MissingExtensionSourceException`.
  - [x] Routed extension page image downloads strictly through resolved `MangaSource.fetchImage` (native Keiyoushi interceptors/cookies) without unauthenticated direct HTTP fallback.
  - [x] Verified non-empty page bytes; failures during download immediately abort and do NOT mark incomplete chapters as downloaded.
  - [x] Preserved legacy/books non-extension download flow with headers and validation.
  - [x] Added automated TDD regression suite in `test/features/download/download_manager_test.dart` (native bytes verification without Dart HTTP, missing source isolation, and network failure non-success).

---

### Verification Summary
- **Full Flutter Test Suite**: 48/48 tests PASS + 3 new DownloadManager TDD regression tests.
- **Flutter Code Analysis**: 0 errors, 0 warnings (clean analysis without suppressions).
- **Independent APK Build**: `:app:assembleDebug` BUILD SUCCESSFUL (`app-debug.apk` built in 1m22s).
- **Android Final Gate**: 57 tests GREEN (0 failures, 0 errors, 1 skipped); native developer addressing startup `listInstalled`/reload race; no real device execution; no network/global settings touched.
