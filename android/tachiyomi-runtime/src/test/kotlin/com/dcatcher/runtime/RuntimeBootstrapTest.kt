package com.dcatcher.runtime

import android.app.Application
import android.content.Context
import android.content.ContextWrapper
import eu.kanade.tachiyomi.network.JavaScriptEngine
import eu.kanade.tachiyomi.network.NetworkHelper
import eu.kanade.tachiyomi.network.NetworkPreferences
import eu.kanade.tachiyomi.network.interceptor.CloudflareInterceptor
import eu.kanade.tachiyomi.network.interceptor.UncaughtExceptionInterceptor
import eu.kanade.tachiyomi.network.interceptor.UserAgentInterceptor
import eu.kanade.tachiyomi.source.CatalogueSource
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.SourceFactory
import eu.kanade.tachiyomi.source.model.Filter
import eu.kanade.tachiyomi.source.model.FilterList
import eu.kanade.tachiyomi.source.model.MangasPage
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import eu.kanade.tachiyomi.source.model.SMangaUpdate
import eu.kanade.tachiyomi.source.online.HttpSource
import eu.kanade.tachiyomi.source.online.ParsedHttpSource
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.protobuf.ProtoBuf
import nl.adaptivity.xmlutil.serialization.XML
import okhttp3.Headers
import okhttp3.Request
import okhttp3.Response
import org.jsoup.nodes.Document
import org.jsoup.nodes.Element
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import tachiyomi.core.common.preference.InMemoryPreferenceStore
import tachiyomi.core.common.preference.PreferenceStore
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.addSingleton
import uy.kohesive.injekt.api.get
import java.io.File
import java.lang.reflect.Field
import java.lang.reflect.Method
import java.lang.reflect.Modifier
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CyclicBarrier
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.zip.ZipFile

class RuntimeBootstrapTest {

    @After
    fun tearDown() {
        RuntimeBootstrap.resetForTesting()
    }

    class TestHttpSource : HttpSource() {
        override val name: String = "Test Source"
        override val baseUrl: String = "https://example.com"
        override val lang: String = "en"
        override val supportsLatest: Boolean = true

        override suspend fun getPopularManga(page: Int): MangasPage = MangasPage(emptyList(), false)
        override suspend fun getSearchManga(page: Int, query: String, filters: FilterList): MangasPage = MangasPage(emptyList(), false)
        override suspend fun getLatestUpdates(page: Int): MangasPage = MangasPage(emptyList(), false)
        override suspend fun getMangaUpdate(
            manga: SManga,
            chapters: List<SChapter>,
            fetchDetails: Boolean,
            fetchChapters: Boolean,
        ): SMangaUpdate = SMangaUpdate(manga, chapters)

        override suspend fun getPageList(chapter: SChapter): List<Page> = emptyList()
        override suspend fun getImageUrl(page: Page): String = "https://example.com/image.jpg"

        override fun popularMangaRequest(page: Int): Request = Request.Builder().url(baseUrl).build()
        override fun popularMangaParse(response: Response): MangasPage = MangasPage(emptyList(), false)
        override fun latestUpdatesRequest(page: Int): Request = Request.Builder().url(baseUrl).build()
        override fun latestUpdatesParse(response: Response): MangasPage = MangasPage(emptyList(), false)
        override fun searchMangaRequest(page: Int, query: String, filters: FilterList): Request = Request.Builder().url(baseUrl).build()
        override fun searchMangaParse(response: Response): MangasPage = MangasPage(emptyList(), false)

        fun testGenerateId(name: String, lang: String, versionId: Int): Long = generateId(name, lang, versionId)
    }

    class TestParsedHttpSource : ParsedHttpSource() {
        override val name: String = "Parsed Source"
        override val baseUrl: String = "https://example.com"
        override val lang: String = "en"
        override val supportsLatest: Boolean = false

        override fun popularMangaSelector(): String = "div.manga"
        override fun popularMangaFromElement(element: Element): SManga = SManga.create().apply { title = "Element Manga" }
        override fun popularMangaNextPageSelector(): String? = "a.next"
        override fun popularMangaRequest(page: Int): Request = Request.Builder().url(baseUrl).build()

        override fun latestUpdatesSelector(): String = "div.latest"
        override fun latestUpdatesFromElement(element: Element): SManga = SManga.create()
        override fun latestUpdatesNextPageSelector(): String? = null
        override fun latestUpdatesRequest(page: Int): Request = Request.Builder().url(baseUrl).build()

        override fun searchMangaSelector(): String = "div.search"
        override fun searchMangaFromElement(element: Element): SManga = SManga.create()
        override fun searchMangaNextPageSelector(): String? = null
        override fun searchMangaRequest(page: Int, query: String, filters: FilterList): Request = Request.Builder().url(baseUrl).build()

        override fun mangaDetailsParse(document: Document): SManga = SManga.create()
        override fun chapterListSelector(): String = "div.chapter"
        override fun chapterFromElement(element: Element): SChapter = SChapter.create()
        override fun pageListParse(document: Document): List<Page> = emptyList()
        override fun imageUrlParse(document: Document): String = "https://example.com/img.png"
    }

    class TestTextFilter(name: String, state: String = "") : Filter.Text(name, state)
    class TestSelectFilter(name: String, values: Array<String>, state: Int = 0) : Filter.Select<String>(name, values, state)
    class TestCheckBoxFilter(name: String, state: Boolean = false) : Filter.CheckBox(name, state)
    class TestSortFilter(name: String, values: Array<String>, state: Filter.Sort.Selection? = null) : Filter.Sort(name, values, state)

    class TestHttpSourceWithCustomHeaders : HttpSource() {
        override val name: String = "Custom Header Source"
        override val baseUrl: String = "https://example.com"
        override val lang: String = "en"
        override val supportsLatest: Boolean = false

        override fun headersBuilder(): Headers.Builder = Headers.Builder().apply {
            add("User-Agent", "CustomAgent/1.0")
            add("Referer", baseUrl)
        }

        override suspend fun getPopularManga(page: Int): MangasPage = MangasPage(emptyList(), false)
        override suspend fun getSearchManga(page: Int, query: String, filters: FilterList): MangasPage = MangasPage(emptyList(), false)
        override suspend fun getLatestUpdates(page: Int): MangasPage = MangasPage(emptyList(), false)
        override suspend fun getMangaUpdate(
            manga: SManga,
            chapters: List<SChapter>,
            fetchDetails: Boolean,
            fetchChapters: Boolean,
        ): SMangaUpdate = SMangaUpdate(manga, chapters)
        override suspend fun getPageList(chapter: SChapter): List<Page> = emptyList()
        override suspend fun getImageUrl(page: Page): String = "https://example.com/image.jpg"

        override fun popularMangaRequest(page: Int): Request = Request.Builder().url(baseUrl).build()
        override fun popularMangaParse(response: Response): MangasPage = MangasPage(emptyList(), false)
        override fun latestUpdatesRequest(page: Int): Request = Request.Builder().url(baseUrl).build()
        override fun latestUpdatesParse(response: Response): MangasPage = MangasPage(emptyList(), false)
        override fun searchMangaRequest(page: Int, query: String, filters: FilterList): Request = Request.Builder().url(baseUrl).build()
        override fun searchMangaParse(response: Response): MangasPage = MangasPage(emptyList(), false)
    }

    @Test
    fun testKeiSourceCompressionInterceptorsAbi() {
        // KeiSource from Keiyoushi uses OkHttp CompressionInterceptor with Gzip, Brotli, Zstd
        val interceptorClass = Class.forName("okhttp3.CompressionInterceptor")
        val gzipClass = Class.forName("okhttp3.Gzip")
        val brotliClass = Class.forName("okhttp3.brotli.Brotli")
        val zstdClass = Class.forName("okhttp3.zstd.Zstd")

        assertNotNull("CompressionInterceptor class must exist on runtime classpath", interceptorClass)
        assertNotNull("Gzip class must exist", gzipClass)
        assertNotNull("Brotli class must exist", brotliClass)
        assertNotNull("Zstd class must exist", zstdClass)

        // Verify constructor accepts exported okhttp3 codecs (Gzip, Brotli, Zstd)
        val interceptor = okhttp3.CompressionInterceptor(
            okhttp3.Gzip,
            okhttp3.brotli.Brotli,
            okhttp3.zstd.Zstd,
        )
        assertNotNull("CompressionInterceptor instance must be successfully created with codecs", interceptor)
        assertTrue("CompressionInterceptor must implement okhttp3.Interceptor", interceptor is okhttp3.Interceptor)

        // Verify OkHttpClient.Builder integration
        val client = okhttp3.OkHttpClient.Builder()
            .addInterceptor(interceptor)
            .build()
        assertNotNull("OkHttpClient must build successfully with CompressionInterceptor", client)
        assertEquals(1, client.interceptors.size)
        assertTrue("Configured interceptor must be CompressionInterceptor", client.interceptors[0] is okhttp3.CompressionInterceptor)
    }

    @Test
    fun testBootstrapTransactionalFailureDoesNotPoisonAndRetries() {
        val mockContext = object : ContextWrapper(null) {}
        val mockApp = object : Application() {
            override fun getApplicationContext(): Context = mockContext
        }

        // 1. Initial attempt fails due to simulated factory exception in createJson
        val failingFactory = object : RuntimeBootstrap.ComponentFactory {
            override fun createPreferenceStore(context: Context): PreferenceStore =
                InMemoryPreferenceStore()
            override fun createNetworkPreferences(store: PreferenceStore): NetworkPreferences =
                NetworkPreferences(store)
            override fun createNetworkHelper(context: Context, preferences: NetworkPreferences): NetworkHelper =
                NetworkHelper(context, preferences)
            override fun createJavaScriptEngine(context: Context): JavaScriptEngine =
                JavaScriptEngine(context)
            override fun createJson(): Json {
                throw IllegalStateException("Simulated factory failure during DI setup")
            }
            override fun createProtoBuf(): ProtoBuf = ProtoBuf { encodeDefaults = true }
            override fun createXml(): XML = XML {}
        }

        RuntimeBootstrap.resetForTesting(failingFactory)
        var exceptionThrown = false
        try {
            RuntimeBootstrap.initialize(mockApp)
        } catch (e: IllegalStateException) {
            exceptionThrown = true
            assertEquals("Simulated factory failure during DI setup", e.message)
        }

        assertTrue("Exception must be propagated to caller", exceptionThrown)
        assertFalse("RuntimeBootstrap MUST NOT be marked initialized when an exception occurs", RuntimeBootstrap.isInitialized)

        // 2. Retry with healthy factory must succeed without being poisoned
        val succeedingFactory = object : RuntimeBootstrap.ComponentFactory {
            override fun createPreferenceStore(context: Context): PreferenceStore =
                InMemoryPreferenceStore()
            override fun createNetworkPreferences(store: PreferenceStore): NetworkPreferences =
                NetworkPreferences(store)
            override fun createNetworkHelper(context: Context, preferences: NetworkPreferences): NetworkHelper =
                NetworkHelper(context, preferences)
            override fun createJavaScriptEngine(context: Context): JavaScriptEngine =
                JavaScriptEngine(context)
            override fun createJson(): Json = Json {
                ignoreUnknownKeys = true
                explicitNulls = false
            }
            override fun createProtoBuf(): ProtoBuf = ProtoBuf { encodeDefaults = true }
            override fun createXml(): XML = XML {}
        }

        RuntimeBootstrap.componentFactory = succeedingFactory
        RuntimeBootstrap.initialize(mockApp)

        assertTrue("RuntimeBootstrap must succeed and be initialized on retry", RuntimeBootstrap.isInitialized)
        assertNotNull("Injekt must export Application", Injekt.get<Application>())
        assertNotNull("Injekt must export Context", Injekt.get<Context>())
        assertNotNull("Injekt must export PreferenceStore", Injekt.get<PreferenceStore>())
        assertNotNull("Injekt must export NetworkPreferences", Injekt.get<NetworkPreferences>())
        assertNotNull("Injekt must export NetworkHelper", Injekt.get<NetworkHelper>())
        assertNotNull("Injekt must export JavaScriptEngine", Injekt.get<JavaScriptEngine>())
        assertNotNull("Injekt must export Json", Injekt.get<Json>())
        assertNotNull("Injekt must export ProtoBuf", Injekt.get<ProtoBuf>())
        assertNotNull("Injekt must export XML", Injekt.get<XML>())
    }

    @Test
    fun testBootstrapConcurrentInitialization() {
        val mockContext = object : ContextWrapper(null) {}
        val mockApp = object : Application() {
            override fun getApplicationContext(): Context = mockContext
        }
        val factory = object : RuntimeBootstrap.ComponentFactory {
            override fun createPreferenceStore(context: Context): PreferenceStore =
                InMemoryPreferenceStore()
            override fun createNetworkPreferences(store: PreferenceStore): NetworkPreferences =
                NetworkPreferences(store)
            override fun createNetworkHelper(context: Context, preferences: NetworkPreferences): NetworkHelper =
                NetworkHelper(context, preferences)
            override fun createJavaScriptEngine(context: Context): JavaScriptEngine =
                JavaScriptEngine(context)
            override fun createJson(): Json = Json {
                ignoreUnknownKeys = true
                explicitNulls = false
            }
            override fun createProtoBuf(): ProtoBuf = ProtoBuf { encodeDefaults = true }
            override fun createXml(): XML = XML {}
        }
        RuntimeBootstrap.resetForTesting(factory)

        val threadCount = 8
        val executor = Executors.newFixedThreadPool(threadCount)
        val barrier = CyclicBarrier(threadCount)
        val errors = CopyOnWriteArrayList<Throwable>()
        val observedInstances = CopyOnWriteArrayList<NetworkHelper>()

        for (i in 0 until threadCount) {
            executor.submit {
                try {
                    barrier.await()
                    RuntimeBootstrap.initialize(mockApp)
                    assertTrue("Caller must see initialized state", RuntimeBootstrap.isInitialized)
                    val helper = Injekt.get<NetworkHelper>()
                    assertNotNull("Injekt must export NetworkHelper", helper)
                    assertNotNull("Injekt must export Context", Injekt.get<Context>())
                    observedInstances.add(helper)
                } catch (t: Throwable) {
                    errors.add(t)
                }
            }
        }

        executor.shutdown()
        assertTrue("Executor must finish within 10 seconds", executor.awaitTermination(10, TimeUnit.SECONDS))
        assertTrue("No concurrent initialization errors expected, but got: $errors", errors.isEmpty())
        assertTrue("Bootstrap must be initialized", RuntimeBootstrap.isInitialized)
        assertEquals("All threads must have executed successfully", threadCount, observedInstances.size)
        val firstInstance = observedInstances[0]
        assertTrue("All concurrent callers must observe identical singleton instance", observedInstances.all { it === firstInstance })
    }

    @Test
    fun testHttpSourceHeadersDelegateReflection() {
        // KeiSource from Keiyoushi explicitly reflects on headers$delegate
        val source = TestHttpSource()
        val field: Field? = HttpSource::class.java.declaredFields.firstOrNull { it.name == "headers\$delegate" }
        assertNotNull("HttpSource MUST contain headers\$delegate field for KeiSource reflection", field)
        field?.isAccessible = true
        val delegate = field?.get(source)
        assertNotNull("headers\$delegate instance must not be null", delegate)
        assertTrue("headers\$delegate must be a Lazy delegate", delegate is Lazy<*>)
    }

    @Test
    fun testHttpSourceHeadersEvaluation() {
        val source = TestHttpSourceWithCustomHeaders()
        val headers = source.headers
        assertNotNull("Headers must be lazily initialized", headers)
        assertEquals("CustomAgent/1.0", headers["User-Agent"])
        assertEquals("https://example.com", headers["Referer"])
    }

    @Test
    fun testSourceIdGenerationDeterministicAndPositive() {
        val source = TestHttpSource()
        val id1 = source.testGenerateId("MangaDex", "en", 1)
        val id2 = source.testGenerateId("MangaDex", "en", 1)
        assertEquals("Source IDs must be deterministic", id1, id2)
        assertTrue("Source ID must have positive sign bit", id1 > 0)
    }

    @Test
    fun testSerializationInstancesAvailable() {
        val json = Json {
            ignoreUnknownKeys = true
            explicitNulls = false
        }
        val protoBuf = ProtoBuf {
            encodeDefaults = true
        }
        val xml = XML {}

        assertNotNull(json)
        assertNotNull(protoBuf)
        assertNotNull(xml)

        Injekt.addSingleton<Json>(json)
        Injekt.addSingleton<ProtoBuf>(protoBuf)
        Injekt.addSingleton<XML>(xml)

        assertEquals(json, Injekt.get<Json>())
        assertEquals(protoBuf, Injekt.get<ProtoBuf>())
        assertEquals(xml, Injekt.get<XML>())
    }

    @Test
    fun testKeiSourceRequiredInterceptorsMatchSimpleNames() {
        // KeiSource.kt strictly verifies presence of these interceptors by name/class
        val uncaught = UncaughtExceptionInterceptor()
        val userAgent = UserAgentInterceptor { "TestAgent/1.0" }

        assertEquals("UncaughtExceptionInterceptor", uncaught::class.java.simpleName)
        assertEquals("UserAgentInterceptor", userAgent::class.java.simpleName)
        assertEquals("CloudflareInterceptor", CloudflareInterceptor::class.java.simpleName)
    }

    @Test
    fun testSourceModelContract() {
        val manga = SManga.create().apply {
            url = "/manga/123"
            title = "Sample Manga"
            artist = "Sample Artist"
            author = "Sample Author"
            description = "Sample Description"
            genre = "Action, Adventure"
            status = SManga.ONGOING
            thumbnail_url = "https://example.com/cover.jpg"
            initialized = true
        }

        assertEquals("/manga/123", manga.url)
        assertEquals("Sample Manga", manga.title)
        assertTrue(manga.initialized)

        val chapter = SChapter.create().apply {
            url = "/chapter/1"
            name = "Chapter 1"
            chapter_number = 1.0f
            date_upload = 1700000000000L
            scanlator = "Scan Group"
        }

        assertEquals("/chapter/1", chapter.url)
        assertEquals("Chapter 1", chapter.name)
        assertEquals(1.0f, chapter.chapter_number)
    }

    @Test
    fun testSourceFactoryContract() {
        val factory = object : SourceFactory {
            override fun createSources(): List<Source> = listOf(TestHttpSource(), TestParsedHttpSource())
        }
        val sources = factory.createSources()
        assertEquals(2, sources.size)
        assertTrue(sources[0] is CatalogueSource)
        assertTrue(sources[1] is ParsedHttpSource)
    }

    @Test
    fun testPageModelAndStateContract() {
        val page = Page(index = 0, url = "https://example.com/page1", imageUrl = "https://example.com/img1.jpg")
        assertEquals(0, page.index)
        assertEquals("https://example.com/page1", page.url)
        assertEquals("https://example.com/img1.jpg", page.imageUrl)
        assertEquals(Page.State.Queue, page.status)

        page.status = Page.State.DownloadImage
        assertEquals(Page.State.DownloadImage, page.status)

        page.status = Page.State.Ready
        assertEquals(Page.State.Ready, page.status)

        assertTrue("Page must be @Serializable", Page::class.java.isAnnotationPresent(Serializable::class.java))
    }

    @Test
    fun testFiltersHierarchyAndContract() {
        val textFilter = TestTextFilter("Author", "Oda")
        val selectFilter = TestSelectFilter("Genre", arrayOf("All", "Action", "Romance"), 1)
        val checkFilter = TestCheckBoxFilter("Completed", true)
        val sortFilter = TestSortFilter("Sort By", arrayOf("Popularity", "Latest"), Filter.Sort.Selection(0, false))

        val filterList = FilterList(listOf(textFilter, selectFilter, checkFilter, sortFilter))
        assertEquals(4, filterList.size)
        assertEquals("Oda", (filterList[0] as Filter.Text).state)
        assertEquals(1, (filterList[1] as Filter.Select<*>).state)
        assertTrue((filterList[2] as Filter.CheckBox).state)
    }

    @Test
    fun testMangaDexAcceptanceApkIntegrityIfPresent() {
        val apkFile = File("C:/Users/an474/AppData/Local/hermes/cache/scratch/dcatcher-toolchain/acceptance-mangadex.apk")
        if (!apkFile.exists()) {
            return
        }

        assertTrue("MangaDex acceptance APK must be a readable file", apkFile.isFile && apkFile.canRead())
        ZipFile(apkFile).use { zip ->
            val manifestEntry = zip.getEntry("AndroidManifest.xml")
            val dexEntry = zip.getEntry("classes.dex")
            assertNotNull("MangaDex APK must contain AndroidManifest.xml", manifestEntry)
            assertNotNull("MangaDex APK must contain compiled classes.dex bytecode", dexEntry)
            assertTrue("classes.dex must not be empty", dexEntry.size > 0)
        }
    }

    @Test
    fun testGeneratedSerializerTypeParametersSerializersRuntimeAbiCompatibility() {
        val iface = Class.forName("kotlinx.serialization.internal.GeneratedSerializer")
        assertTrue("GeneratedSerializer must be an interface", iface.isInterface)

        val method: Method = iface.getMethod("typeParametersSerializers")
        assertNotNull("GeneratedSerializer must declare or inherit typeParametersSerializers", method)
        assertTrue("typeParametersSerializers return type must be an array", method.returnType.isArray)
        assertEquals(
            "typeParametersSerializers component type must be KSerializer",
            kotlinx.serialization.KSerializer::class.java,
            method.returnType.componentType,
        )
        assertEquals("typeParametersSerializers must take 0 parameters", 0, method.parameterTypes.size)

        // Runtime compatibility with newer generated extension serializers:
        // typeParametersSerializers() provides a default implementation (isDefault or concrete implementation)
        // or non-abstract resolution so calling it on implementations doesn't throw abstract method error.
        val isDefaultMethod = method.isDefault
        val isNotAbstract = !Modifier.isAbstract(method.modifiers)
        assertTrue(
            "GeneratedSerializer.typeParametersSerializers() must have a default or concrete implementation for binary compatibility",
            isDefaultMethod || isNotAbstract,
        )

        // Verify invocation on a real @Serializable class generated serializer
        @Serializable
        data class DummyPayload(val title: String)

        val serializer = DummyPayload.serializer()
        assertTrue("Generated serializer must implement GeneratedSerializer", iface.isInstance(serializer))
        val result = method.invoke(serializer)
        assertNotNull("Invocation of typeParametersSerializers on generated serializer must return an array", result)
        assertTrue("Result must be Array<KSerializer>", result is Array<*>)
    }
}
