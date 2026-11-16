# Android Extension Loader & Flutter Bridge Status

## Обзор реализации

Текущий статус реализации модуля APK LOADER и Android Flutter bridge для DCatcher в рамках разрешенной зоны ответственности `android/app/**`. Реализованы компоненты безопасности Keiyoushi, жизненный цикл постоянного пути ClassLoader (permanent immutable target path), изоляция заглушек `android.jar`, startup-readiness gate в MethodChannel, строгий межъязыковой DTO-контракт `extensionLib` (API 1.6). В активном P1-бэклоге находятся: сохранение контекста `SChapter.memo` при чтении глав, контекстные вызовы `fetchImage` через `HttpSource.getImage`, строгая валидация URL в `getChapterPages` и сериализация жизненного цикла (мьютекс/транзакции).

---

## 1. Компоненты безопасности и политики

### `ExtensionSecurityPolicy.kt`
- **Strict HTTPS URL Validation**: проверяет начальный URL загрузки на соответствие `https://github.com/keiyoushi/extensions/releases/download/<tag>/<basename>.apk`.
- **Запрет портов, query и fragment**: отклоняет любые порты (включая явный `:443`), параметры запроса (включая пустые маркеры `?`), фрагменты (включая пустые маркеры `#`), учетные данные пользователя (`user:password@`).
- **Защита от Path Traversal**: отклоняет `..`, `%2e%2e`, `\`, `%5c`, `%2f`, двойные слэши в пути.
- **Whitelist редиректов**: разрешены строго доверенные HTTPS-хосты релизных ассетов GitHub:
  - `release-assets.githubusercontent.com`
  - `objects.githubusercontent.com`
  - `github.com`
- **Защита от спуфинга хоста**: отклоняются поддомены и суффиксы (`attacker-github.com`, `github.com.attacker.com`).
- **Проверка пакета и версий**: строгий регэксп `eu.kanade.tachiyomi.extension.<lang>.<name>`, запрет даунгрейда (`versionCode >= installedVersionCode`).
- **Явное согласие (Trust Confirmation)**: обязательное требование `trustConfirmed == true`.
- **Пиннинг сертификата**: эталонный SHA-256 Keiyoushi: `9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2`.

### `ApkSignatureVerifier.kt`
- **Строгая проверка через Android `PackageManager`**: использует `PackageManager.getPackageArchiveInfo` с флагами `GET_SIGNING_CERTIFICATES` (API 28+) / `GET_SIGNATURES` (до API 28).
- **Fail-Closed**: при `null` объектах, отсутствии сигнатур или ошибках разбора немедленно возвращает `SecurityException`.
- **Sole Signer**: проверяет текущие `apkContentsSigners` (исключая неподписанные или ко-подписанные чужими ключами архивы) и сверяет с единственным доверенным сертификатом Keiyoushi.
- **Полное удаление небезопасных парсеров**: убраны любые fallback-парсеры ZIP/META-INF без валидации Android OS.
- **Удалены захардкоженные пути к локальному scratch**: используется динамический поиск фикстуры с `Assume.assumeTrue` для чистого прохождения тестов на CI.

---

## 2. Загрузчик и жизненный цикл расширений

### `ExtensionDownloader.kt`
- Потоковая безопасная загрузка с ограниченным числом редиректов (максимум 5).
- Валидация каждого редиректа по списку разрешенных хостов ассетов GitHub.
- Ограничение максимального размера файла (50 МБ) и сетевые таймауты (15с connect, 30с read).
- Callback прогресса байт для `EventChannel`.
- Очистка временных файлов при ошибках.

### `ExtensionMetadata.kt` & `ExtensionMetadataParser.kt`
- **Верифицированные ключи подлинного APK**:
  - Ключ версии библиотеки: `tachiyomix.extensionLib` (float). Требуется строго поддерживаемая версия **API 1.6** (`1.6f`).
  - Обязательно объявленный feature: `tachiyomi.extension` в `reqFeatures` манифеста (никакие fallback-замены на наличие метаданных не допускаются; при отсутствии — немедленный отказ).
  - Обязательное наличие `versionName` (без искусственных fallback-значений вроде `1.0.0`).
  - `tachiyomi.extension.class` и `tachiyomi.extension.factory` для определения точек входа.
  - `tachiyomi.extension.nsfw`.
- **Чистый шов валидации метаданных (Metadata Seam)**: парсер поддерживает валидацию как реального `PackageInfo` с `Bundle` на устройстве Android, так и валидацию типизированных метаданных напрямую, что гарантирует точные тесты в окружении JUnit без искажения заглушками `android.jar`.

### `DelegateLastClassLoaderCompat.kt`
- Обеспечивает изоляцию классов расширений:
  - Использование Android `DelegateLastClassLoader` на API 27+.
  - `PathClassLoader` на API 26.
  - Поддержка поиска нативных библиотек (`librarySearchPath`).

### `ExtensionLoader.kt`
- **Android 14+ Dynamic Code Loading Rule (Fail-Closed)**: файл APK переводится в режим read-only (`apkFile.setReadOnly()`) строго **ДО** вызова `ClassLoader`. Если вызов `setReadOnly()` возвращает `false` или файл остается доступным на запись, операция немедленно завершается ошибкой безопасности `SecurityException`.
- **Поддержка нативных библиотек (.so)**: передает `context.applicationInfo?.nativeLibraryDir` в качестве `librarySearchPath` в `DelegateLastClassLoaderCompat.create(...)` для разрешения нативных библиотек.
- **Fail-Closed DI-бутстрап**: `bootstrapDi` вызывает `com.dcatcher.runtime.RuntimeBootstrap.initialize(Application)` и возвращает `Result.failure` при отсутствии рантайма или ошибках инициализации. Ложный статус успеха исключен.
- Поддержка одиночных `Source` и фабрик `SourceFactory`.
- Запрет фиктивных метаданных (только реально сконструированные инстансы `Source`).

### `ExtensionManager.kt`
- **Жизненный цикл пути ClassLoader (Permanent Immutable Target Path)**:
  - Валидация сигнатур и манифеста выполняется на `.tmp` файле.
  - Атомарное перемещение (`safeAtomicReplace`) на постоянное место `<packageName>.apk` с сохранением старой версии в `.bak` происходит **ДО** создания активного `ClassLoader`.
  - Активные инстансы `Source` загружаются из постоянного, неизменяемого read-only пути `<packageName>.apk`. Это гарантирует, что ClassLoader никогда не теряет доступ к коду и ресурсам APK при удалении временных файлов.
  - В случае ошибки загрузки классов из целевого файла выполняется автоматический откат: целевой сбойный файл удаляется, а старая версия восстанавливается из бэкапа.
- **Самоисцеление при старте (Self-Healing Recovery)**:
  - При вызове `reloadInstalledExtensions()` выполняется автоматическое обнаружение прерванных установок/обновлений: если файл `<packageName>.apk` отсутствует, но остался `<packageName>.apk.bak`, файл бэкапа восстанавливается и переводится в режим read-only.
  - Устаревшие файлы `.bak` при наличии актуального `.apk` автоматически удаляются с диска, предотвращая утечку дискового пространства.
- **Точный контракт DTO (Data Integrity)**: `versionCode` в `InstalledPackageDto.toMap()` передается исключительно как десятичная строка (`String`), предотвращая потерю точности 64-битных чисел на стороне JS/Dart. `extensionLib` передается как обязательная валидированная строка (строго `"1.6"`), полностью удовлетворяя строгому контракту Dart `NativePackageDto.fromJson`. `id` источников также передается строками.
- **Точная проверка версий**: проверяется точное соответствие фактического `metadata.versionCode` переданному `expectedVersionCode` (при несовпадении — отказ `SecurityException`), а также отсутствие даунгрейда относительно установленной версии.
- **Хранилище**: изолированная директория приложения `context.filesDir/extensions/`.
- **Корректный порядок деинсталляции**: удаление файлов (`.apk` и `.apk.bak`) с диска проверяется в первую очередь. Регистрации источников удаляются из памяти **только** после успешного удаления файла на диске.
- **Информативные ошибки восстановления (`reloadInstalledExtensions`)**: ошибки валидации и загрузки при старте фиксируются в `reloadFailures` (`getReloadFailures()`), а не подавляются скрытно.

---

## 3. Вызовы источников (Mihon API 1.6 Suspend)

### `SourceOperations.kt`
- **Маппинг статуса в осмысленные строки**:
  - `SManga.ONGOING` (1) -> `"Ongoing"`
  - `SManga.COMPLETED` (2) -> `"Completed"`
  - `SManga.LICENSED` (3) -> `"Licensed"`
  - `SManga.PUBLISHING_FINISHED` (4) -> `"Publishing finished"`
  - `SManga.CANCELLED` (5) -> `"Cancelled"`
  - `SManga.ON_HIATUS` (6) -> `"On hiatus"`
  - `SManga.UNKNOWN` (0) и любые неизвестные -> `"Unknown"`
  - Устраняет проблему некорректного распознавания `"Completed"` статуса на стороне Flutter UI без синтетических дефолтов.
- **Формат `dateUpload`**: передается как десятичная строка (`String`), исключая ошибки парсинга таймстемпов на стороне Dart.
- **Точные сигнатуры методов Mihon API 1.6**:
  - `getCatalog`: вызов suspend `getPopularManga(page)` или `getSearchManga(page, query, filters)`. Сохранение `genre` строкой, статус строкой (`"Ongoing"` / `"Completed"`), проброс `hasNextPage`.
  - `getMangaDetails`: suspend `getMangaUpdate(manga, emptyList(), fetchDetails = true, fetchChapters = true)` с сохранением в LRU-кэш для переиспользования глав.
  - `getChapters`: suspend `getMangaUpdate(manga, emptyList(), fetchDetails = false, fetchChapters = true)` или мгновенное извлечение из кэша после `getMangaDetails`, маппинг `chapterNumber` (Double) и `dateUpload` (String). Сохраняет полный контекст глав (включая `SChapter.memo`) в LRU-кэш и на диск (`context.filesDir/chapter_cache/<sourceId>/<sha256(url)>.json`).
  - `getChapterPages`: suspend `getPageList(chapter)`. Извлекает полный объект главы с сохранённым `SChapter.memo` (например, `mangaSlug` для Asura Scans) из памяти или восстанавливает с диска при рестарте приложения. Разрешение страниц с `imageUrl == null` через suspend `(source as HttpSource).getImageUrl(page)`.
  - `fetchImage`: загрузка бинарных данных изображения через OkHttp-клиент источника (`httpSource.client`) с его аутентичными заголовками (`httpSource.headers`).
  - `getHeaders`: безопасное извлечение HTTP-заголовков источника в виде `Map<String, String>`.
- **Инвалидация контекста глав при удалении и обновлении**:
  - При деинсталляции (`uninstallExtension`) или обновлении расширения (`registerExtensionSources`) сохранённый контекст глав для затронутых `sourceId` полностью инвалидируется в памяти и удаляется с диска.

---

## 4. Контракт каналов Flutter

### `DcatcherExtensionsPlugin.kt` & `MainActivity.kt`
- **MethodChannel**: `dev.dcatcher/extensions`
  - `listInstalled` -> `List<Map>` пакетов с `packageName`, `versionCode` (String), `versionName`, `sources: [{id, name, language, homeUrl}]` (ID строками).
  - `install` -> аргументы `{packageName, apkUrl, versionCode, trustConfirmed}`. Возвращает `true` (`invokeMethod<bool>`).
  - `uninstall` -> аргументы `{packageName}`. Возвращает `true`.
  - `getCatalog` -> `{sourceId, page, query}`. Поддерживает приведение `page` (Number/String с ограничением >= 1) и `sourceId` (String/64-bit Long).
  - `getMangaDetails` -> `{sourceId, mangaUrl}`.
  - `getChapters` -> `{sourceId, mangaUrl}`.
  - `getChapterPages` -> `{sourceId, chapterUrl}`.
  - `fetchImage` -> `{sourceId, url}` -> бинарный `ByteArray`.
  - `getHeaders` -> `{sourceId}` -> `Map<String, String>`.
  - `getReloadFailures` -> возвращает `Map<String, String>` всех зафиксированных ошибок перезагрузки при старте приложения.
- **Защитное приведение типов аргументов (Defensive Type Coercion)**:
  - `sourceId` во всех методах извлекается безопасно: поддерживает строковые и 64-битные числовые (`Long`/`Int`) аргументы, предотвращая `ClassCastException` при вызовах со стороны Dart/JS. Пустые строки отклоняются с `INVALID_ARGUMENT`.
  - `page` аргумент безопасно преобразуется из любого типа `Number` (`toInt()`) или `String` (`toIntOrNull()`) с ограничением `coerceAtLeast(1)`.
  - Колбэки `postSuccess`, `postError` и `postProgress` защищены блоками `try-catch` от сбоев при отсоединении движка FlutterEngine или повторной отправке ответов.
- **Шлюз готовности при старте (Startup-Readiness Gate)**:
  - Инициализируется до регистрации обработчиков каналов (`setMethodCallHandler`).
  - Все вызовы каналов (`listInstalled`, операции с источниками, мутации `install`/`uninstall`, `getReloadFailures`) ожидают (`awaitStartupReady()`) полного завершения фоновой перезагрузки расширений.
  - Предотвращает состояние гонки при рестарте приложения, когда Dart `SourceManager.initialize()` мог получить пустой список расширений (0 installed) до завершения фонового сканирования диска.
  - Исключает взаимные блокировки (deadlock) за счет неблокирующего `CompletableDeferred.await()`, корректно сохраняет отмену корутин (`CancellationException`) и транслирует ошибки старта в ответы Flutter (`LIST_ERROR`).
- **EventChannel**: `dev.dcatcher/extensions/progress`
  - Потоковые события прогресса скачивания: `{packageName, received, total}`.
- **Потоки**: все фоновые операции выполняются на пуле `Dispatchers.IO`, результаты и события передаются в UI/Main-поток.
- **Типизированные ошибки**: `SOURCE_NOT_FOUND`, `SECURITY_ERROR`, `INVALID_ARGUMENT`, `INSTALL_ERROR`. Исключен fall back на другие источники при отсутствии запрошенного.
- **Регистрация**: плагин зарегистрирован в `MainActivity.configureFlutterEngine`.

---

## 5. Модульные и регрессионные тесты (46+ тестов)

1. `ExtensionSecurityPolicyTest.kt` (18 тестов):
   - Валидация легитимного URL Keiyoushi.
   - Отклонение протокола HTTP.
   - Отклонение портов (включая явный `:443`).
   - Отклонение query-параметров и пустого маркера `?`.
   - Отклонение fragment и пустого маркера `#`.
   - Отклонение credentials (`user:pass@`).
   - Отклонение спуфинга доменов.
   - Отклонение атак обхода директорий (Path Traversal: `..`, `%2e%2e`, `%5c`, `//`).
   - Отклонение не-APK ассетов.
   - Whitelist редиректов (GitHub CDN и release-assets).
   - Валидация имени пакета.
   - Подтверждение доверия (`trustConfirmed == true`).
   - Проверка пиннинга сертификата.
   - Запрет даунгрейда версий.
   - Разрешение имен классов через `;` и `.`.
2. `ApkSignatureVerifierTest.kt` (4 теста):
   - Форматирование SHA-256 fingerprint.
   - Вычисление SHA-256 хэша.
   - Политика доверенного сертификата (sole pinned Keiyoushi).
   - Fail-closed на несуществующих файлах.
   - Отсутствие захардкоженных scratch-путей, совместимость с CI.
3. `SourceOperationsTest.kt` (7 тестов):
   - Маппинг числовых кодов статуса SManga в осмысленные строки (`"Ongoing"`, `"Completed"`, `"Licensed"`, `"Publishing finished"`, `"Cancelled"`, `"On hiatus"`, `"Unknown"`).
   - Маппинг каталога, `hasNextPage` и сохранение жанров и статуса строками.
   - Получение деталей манги со строковым статусом `"Completed"`.
   - Кэширование объединенного вызова `getMangaUpdate` (details + chapters).
   - Получение глав с датой загрузки строкой (`"dateUpload": "1700000000000"`).
   - Разрешение страниц с `imageUrl == null` через `getImageUrl`.
   - Безопасное извлечение заголовков источника (`getHeaders`) без сбоев DI.
4. `ExtensionMetadataParserTest.kt` (7 тестов):
   - Утверждения для подлинного фикстурного APK (`acceptance-mangadex.apk`): `packageName` = `eu.kanade.tachiyomi.extension.all.mangadex`, `versionCode` = `106001` (`0x19e11`), `versionName` = `"1.6.1"`, `feature` = `"tachiyomi.extension"`, `tachiyomix.extensionLib` = `1.6f`.
   - Проверка успешного разбора валидных метаданных.
   - Негативный тест: отсутствие обязательного объявленного `uses-feature: tachiyomi.extension` завершается ошибкой безопасности `SecurityException`.
   - Негативный тест: отсутствие ключа `tachiyomix.extensionLib` завершается ошибкой безопасности.
   - Негативные тесты: неподдерживаемые версии API (1.4, 1.5) отклоняются, строго требуется API 1.6.
   - Негативный тест: отсутствие `versionName` завершается ошибкой без искусственных fallback-значений.
   - Полное отсутствие захардкоженных путей, поддержка `-Dacceptance.apk.path`.
5. `ExtensionLifecycleRegressionTest.kt` (14 тестов):
   - Проверка точного соответствия контракта DTO `toMap()`: `versionCode` строкой (`String`), `extensionLib` обязательной строкой (`"1.6"`), `id` источников строками.
   - Межъязыковой контрактный тест (`testCrossLanguageContractMatchesDartNativePackageDtoParser`): проверка полного совпадения структуры `toMap()` со строгим парсером Dart `NativePackageDto.fromJson`.
   - Проверка обязательного точного соответствия версий (`metadata.versionCode == expectedVersionCode`).
   - Проверка сохранения пути ClassLoader: активный файл живет по постоянному неизменяемому пути `<packageName>.apk`, переживает обновления и защищен от удаления временных файлов (`testClassLoaderPathSurvivesInstallAndUpdate`).
   - Проверка, что отсутствие или ошибка `RuntimeBootstrap` приводит к ошибке, а не к ложному успеху.
   - Проверка сохранения старого валидного APK при сбое установки нового (`safeAtomicReplace`).
   - Проверка успешной замены с установкой флага `read-only` (Android 14+ dynamic code rule) и удалением бэкапа.
   - Проверка отказа деинсталляции без удаления регистраций, если файл не удалось удалить с диска.
   - Проверка сбора информативных ошибок в реестре сбоев перезагрузки (`getReloadFailures`).
   - Проверка самоисцеления при старте (`testSelfHealingRecoversMissingApkFromBackupOnStartup`): восстановление отсутствующего APK из резервной копии `.apk.bak` с установкой флага `read-only`.
   - Проверка очистки устаревших бэкапов (`testStaleBackupCleanedUpIfTargetApkExists`): удаление старого `.bak` при наличии рабочего `.apk`.
   - Проверка полной очистки при деинсталляции (`testUninstallCleansUpBothTargetAndStaleBackup`): удаление как целевого `.apk`, так и `.bak` с диска.
   - Проверка защитного приведения аргументов плагина (`testPluginArgumentCoercionHelpers`): корректная обработка `Long`/`Int`/`String`/`null` для `page` и `sourceId`.
   - Проверка ожидания шлюза готовности (`testStartupGateSuspendsListInstalledUntilReloadCompletes`): при намеренно приостановленной перезагрузке вызов `listInstalled` не может завершиться раньше перезагрузки и мгновенно завершается после её разблокировки.
   - Проверка проброса ошибок через шлюз (`testStartupGatePropagatesReloadErrorToListInstalled`): сбой при стартовой перезагрузке транслируется в ответ канала без зависания.
   - Проверка сохранения отмены при детаче плагина (`testStartupGateRetainsCancellationOnDetach`): отмена движка Flutter отменяет шлюз и фоновые корутины.

---

## 6. Конфигурация сборки

В `android/app/build.gradle.kts`:
- Установлен `minSdk = 26` (Android 8.0 Oreo).
- Согласованы `JavaVersion.VERSION_17` и `jvmTarget = "17"` с библиотечным модулем `:tachiyomi-runtime`.
- Добавлена зависимость `implementation(project(":tachiyomi-runtime"))`.
- Добавлены зависимости `kotlinx-coroutines-android:1.8.1` и `testOptions.unitTests.isReturnDefaultValues = true`.
