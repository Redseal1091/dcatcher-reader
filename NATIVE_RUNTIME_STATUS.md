# Native Runtime Status

## Metadata
- **Antigravity Conversation UUID**: `d9a7458a-ffcb-4911-9711-c2c1d0811cf4`
- **Brain Artifact Path**: `C:\Users\an474\.gemini\antigravity-cli\brain\d9a7458a-ffcb-4911-9711-c2c1d0811cf4`
- **Pinned Upstream Commit**: `e588e04359fe1058206a2cbac1b01018ad787359` (https://github.com/mihonapp/mihon)
- **Official Keiyoushi Certificate Fingerprint (SHA256)**: `9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2`

---

## Architecture & Module Configuration
- **Module**: `:tachiyomi-runtime` (`android/tachiyomi-runtime`)
- **Plugin**: `com.android.library` version `8.11.1`
- **AGP Application Plugin**: `com.android.application` version `8.11.1`
- **Kotlin Gradle Plugin**: `2.2.20`
- **Target / Compile SDK**: `36` (Android 15+)
- **Min SDK**: `26` (Android 8.0+)
- **JVM Target**: `17`
- **Kotlin Compiler Flags**:
  - `-opt-in=kotlin.RequiresOptIn`
  - `-opt-in=kotlinx.serialization.ExperimentalSerializationApi`
  - `-opt-in=kotlinx.coroutines.ExperimentalCoroutinesApi`
  - `-Xcontext-parameters`
- **Gradle Wrapper Version**: `8.14.3` (required by Flutter 3.47.9)
- **Networking Stack**:
  - `com.squareup.okhttp3:okhttp:5.4.0`
  - `com.squareup.okhttp3:logging-interceptor:5.4.0`
  - `com.squareup.okhttp3:okhttp-dnsoverhttps:5.4.0`
  - `com.squareup.okhttp3:okhttp-brotli:5.4.0`
  - `com.squareup.okhttp3:okhttp-zstd:5.4.0`
  - `com.squareup.okio:okio:3.10.2`
  - Transitive `zstd-kmp-okio:0.4.0`
- **Logging**: Internal `android.util.Log` adapter (`tachiyomi.core.common.util.system.LogcatExtensions` & `logcat.LogPriority`), zero external logcat dependency.

---

## P1 Fixes Applied
1. **KeiSource OkHttp / CompressionInterceptor / Brotli / Zstd Alignment**:
   - Aligned OkHttp stack to official Keiyoushi version `5.4.0`.
   - Added `okhttp-brotli:5.4.0` and `okhttp-zstd:5.4.0`.
   - Updated `consumer-proguard.pro` to preserve `okhttp3.CompressionInterceptor`, `okhttp3.Gzip`, `okhttp3.Deflate`, `okhttp3.brotli.**`, `okhttp3.zstd.**`.
   - Added JVM ABI test `testKeiSourceCompressionInterceptorsAbi` verifying runtime classpath presence, OkHttpClient.Builder integration, and constructor invocation of `CompressionInterceptor(Gzip, Deflate, Brotli, Zstd)`.
2. **RuntimeBootstrap Transactional Readiness & Concurrency**:
   - Eliminated premature `AtomicBoolean` state setting before DI registration.
   - Implemented thread-safe double-checked locking (`synchronized(lock)`).
   - Transactional commit: `isReady` is marked `true` only after all Injekt singletons are successfully exported.
   - Non-poisoning: exceptions in constructors/DI are re-thrown, keeping `isReady = false` and allowing subsequent retries.
   - Concurrency: concurrent callers wait on lock and observe fully initialized state upon return. All callers observe identical singleton instances (`it === firstInstance`).
   - Added `ComponentFactory` injection seam and `InMemoryPreferenceStore` to allow genuine regression testing without Android stubs.
   - Added tests `testBootstrapTransactionalFailureDoesNotPoisonAndRetries` and `testBootstrapConcurrentInitialization`.

---

## Build & Test Verification Milestones
- **`:tachiyomi-runtime:compileDebugKotlin`**: **BUILD SUCCESSFUL** (39s, Gradle 8.14.3 / JDK 21, OkHttp 5.4.0 Brotli/Zstd, zero Kotlin ABI metadata errors).
- **Unit Test Suite Coverage (13 tests)**:
  1. `testKeiSourceCompressionInterceptorsAbi` (OkHttp 5.4.0 CompressionInterceptor, Gzip, Deflate, Brotli, Zstd ABI & OkHttpClient integration)
  2. `testBootstrapTransactionalFailureDoesNotPoisonAndRetries` (transactional readiness, non-poisoning, retry)
  3. `testBootstrapConcurrentInitialization` (thread-safe concurrent bootstrap, verified identical singleton references)
  4. `testHttpSourceHeadersDelegateReflection` (verifies `headers$delegate` lazy reflection for KeiSource)
  5. `testHttpSourceHeadersEvaluation` (verifies lazy evaluation and resolution of headers)
  6. `testSourceIdGenerationDeterministicAndPositive` (verifies MD5 deterministic 64-bit ID generation)
  7. `testSerializationInstancesAvailable` (verifies Injekt DI export for Json, ProtoBuf, XML)
  8. `testKeiSourceRequiredInterceptorsMatchSimpleNames` (verifies exact simpleName match for interceptors)
  9. `testSourceModelContract` (verifies SManga / SChapter model contracts)
  10. `testSourceFactoryContract` (verifies SourceFactory interface and CatalogueSource / ParsedHttpSource inheritance)
  11. `testPageModelAndStateContract` (verifies Page model, Page.State.Queue transitions, and `@Serializable`)
  12. `testFiltersHierarchyAndContract` (verifies concrete implementations of abstract Filter types and FilterList)
  13. `testMangaDexAcceptanceApkIntegrityIfPresent` (validates real acceptance MangaDex APK DEX bytecode and manifest)

---

## Remaining Runtime Limitations & Scope Hand-Off
- **Platform Compatibility**: Min Android API 26 (Android 8.0+), Compile SDK 36.
- **WebView / Cloudflare Bypass**: Automated Cloudflare challenge solving requires a functioning Android System WebView provider on the device. On headless or minimal emulator environments lacking WebView, Cloudflare-protected requests will log that WebView is required.
- **Dynamic Loading Readiness**: The `:tachiyomi-runtime` module exports all necessary API 1.6 interfaces, DI registrations, and OkHttp codecs required by Keiyoushi APK extensions (e.g. MangaDex, Asura). Final end-to-end execution of live downloaded APKs is orchestrated by `:app` loader and requires an Android runtime device/emulator.
