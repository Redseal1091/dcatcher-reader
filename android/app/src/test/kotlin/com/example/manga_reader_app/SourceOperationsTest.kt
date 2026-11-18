package com.example.manga_reader_app

import eu.kanade.tachiyomi.network.GET
import eu.kanade.tachiyomi.network.HttpException
import eu.kanade.tachiyomi.source.CatalogueSource
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.model.Filter
import eu.kanade.tachiyomi.source.model.FilterList
import eu.kanade.tachiyomi.source.model.MangasPage
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import eu.kanade.tachiyomi.source.model.SMangaUpdate
import eu.kanade.tachiyomi.source.online.HttpSource
import kotlinx.coroutines.runBlocking
import okhttp3.Headers
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.io.File
import java.io.IOException
import java.util.concurrent.atomic.AtomicInteger

class SourceOperationsTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    @Before
    fun setUp() {
        SourceOperations.clearCache()
    }

    private open class MockHttpSource(
        override val id: Long = 1234567890123456789L,
        override val name: String = "Test Mock Source",
        override val lang: String = "en",
        override val baseUrl: String = "https://example.com"
    ) : HttpSource() {
        override val supportsLatest: Boolean = true
        val updateCallCount = AtomicInteger(0)

        override fun headersBuilder(): Headers.Builder = Headers.Builder().apply {
            add("User-Agent", "Mozilla/5.0 DCatcher-Test")
            add("Referer", baseUrl)
        }

        override suspend fun getPopularManga(page: Int): MangasPage {
            val manga = SManga.create().apply {
                url = "/manga/1"
                title = "Mock Title"
                thumbnail_url = "https://example.com/cover.jpg"
                genre = "Action, Adventure, Fantasy"
                status = SManga.ONGOING
                author = "Author A"
                artist = "Artist B"
                description = "Description 1"
            }
            return MangasPage(listOf(manga), hasNextPage = true)
        }

        override suspend fun getLatestUpdates(page: Int): MangasPage = getPopularManga(page)

        override suspend fun getSearchManga(page: Int, query: String, filters: FilterList): MangasPage =
            getPopularManga(page)

        override suspend fun getMangaUpdate(
            manga: SManga,
            chapters: List<SChapter>,
            fetchDetails: Boolean,
            fetchChapters: Boolean
        ): SMangaUpdate {
            updateCallCount.incrementAndGet()
            val updatedManga = manga.copy().apply {
                title = "Updated Mock Title"
                genre = "Action, Romance"
                status = SManga.COMPLETED
                description = "Detailed Description"
                thumbnail_url = "https://example.com/new_cover.jpg"
                initialized = true
            }

            val chapterList = if (fetchChapters) {
                val ch1 = SChapter.create().apply {
                    url = "/chapter/1"
                    name = "Chapter 1"
                    chapter_number = 1.5f
                    date_upload = 1700000000000L
                    scanlator = "ScanGroup"
                }
                listOf(ch1)
            } else {
                chapters
            }

            return SMangaUpdate(updatedManga, chapterList)
        }

        override suspend fun getPageList(chapter: SChapter): List<Page> {
            return listOf(
                Page(index = 0, url = "https://example.com/page0.html", imageUrl = "https://example.com/img0.png"),
                Page(index = 1, url = "https://example.com/page1.html", imageUrl = null) // will require getImageUrl
            )
        }

        override suspend fun getImageUrl(page: Page): String {
            return "https://example.com/resolved_${page.index}.jpg"
        }
    }

    @Test
    fun testStatusMapping() {
        assertEquals("Ongoing", SourceOperations.mapStatusToString(SManga.ONGOING))
        assertEquals("Completed", SourceOperations.mapStatusToString(SManga.COMPLETED))
        assertEquals("Licensed", SourceOperations.mapStatusToString(SManga.LICENSED))
        assertEquals("Publishing finished", SourceOperations.mapStatusToString(SManga.PUBLISHING_FINISHED))
        assertEquals("Cancelled", SourceOperations.mapStatusToString(SManga.CANCELLED))
        assertEquals("On hiatus", SourceOperations.mapStatusToString(SManga.ON_HIATUS))
        assertEquals("Unknown", SourceOperations.mapStatusToString(SManga.UNKNOWN))
        assertEquals("Unknown", SourceOperations.mapStatusToString(-99))
    }

    @Test
    fun testGetCatalogMappingPreservesGenreStatusStringAndHasNextPage() = runBlocking {
        val source = MockHttpSource()
        val result = SourceOperations.getCatalog(source, page = 1, query = null)

        assertTrue(result["hasNextPage"] as Boolean)
        @Suppress("UNCHECKED_CAST")
        val items = result["items"] as List<Map<String, Any?>>
        assertEquals(1, items.size)

        val first = items[0]
        assertEquals("/manga/1", first["url"])
        assertEquals("Mock Title", first["title"])
        assertEquals("Action, Adventure, Fantasy", first["genre"])
        assertEquals("Ongoing", first["status"])
    }

    private class TestTriState(name: String, state: Int = Filter.TriState.STATE_IGNORE) : Filter.TriState(name, state)
    private class TestCheckBox(name: String, state: Boolean = false) : Filter.CheckBox(name, state)
    private class TestGroup(name: String, state: List<Filter<*>>) : Filter.Group<Filter<*>>(name, state)
    private class TestSelect(name: String, values: Array<String>, state: Int = 0) : Filter.Select<String>(name, values, state)

    @Test
    fun testApplyTypeFilterMangaBuffStyleGroupTriState() {
        // MangaBuff structure: Group("Тип") containing TriState filters
        val mangaFilter = TestTriState("Манга")
        val oelFilter = TestTriState("OEL-манга")
        val manhwaFilter = TestTriState("Манхва")
        val manhuaFilter = TestTriState("Маньхуа")
        val typeGroup = TestGroup("Тип", listOf(mangaFilter, oelFilter, manhwaFilter, manhuaFilter))
        val filterList = FilterList(typeGroup)

        // Test manhwa selection
        val manhwaApplied = SourceOperations.applyTypeFilter(filterList, "manhwa")
        assertTrue(manhwaApplied)
        assertEquals(Filter.TriState.STATE_INCLUDE, manhwaFilter.state)
        assertEquals(Filter.TriState.STATE_IGNORE, mangaFilter.state)
        assertEquals(Filter.TriState.STATE_IGNORE, manhuaFilter.state)
        assertEquals(Filter.TriState.STATE_IGNORE, oelFilter.state)

        // Test manhua selection
        val manhuaApplied = SourceOperations.applyTypeFilter(filterList, "manhua")
        assertTrue(manhuaApplied)
        assertEquals(Filter.TriState.STATE_INCLUDE, manhuaFilter.state)
        assertEquals(Filter.TriState.STATE_IGNORE, manhwaFilter.state)
        assertEquals(Filter.TriState.STATE_IGNORE, mangaFilter.state)

        // Test manga selection (should exact-match "Манга", NOT "OEL-манга")
        val mangaApplied = SourceOperations.applyTypeFilter(filterList, "manga")
        assertTrue(mangaApplied)
        assertEquals(Filter.TriState.STATE_INCLUDE, mangaFilter.state)
        assertEquals(Filter.TriState.STATE_IGNORE, oelFilter.state)
        assertEquals(Filter.TriState.STATE_IGNORE, manhwaFilter.state)
        assertEquals(Filter.TriState.STATE_IGNORE, manhuaFilter.state)
    }

    @Test
    fun testApplyTypeFilterInkStoryStyleGroupCheckBox() {
        // Ink Story structure: Group("Страна") containing CheckBox filters
        val japanBox = TestCheckBox("Япония")
        val chinaBox = TestCheckBox("Китай")
        val koreaBox = TestCheckBox("Корея")
        val russiaBox = TestCheckBox("Россия")
        val countryGroup = TestGroup("Страна", listOf(japanBox, chinaBox, koreaBox, russiaBox))
        val filterList = FilterList(countryGroup)

        // Test manhwa selection -> maps to "Корея"
        val manhwaApplied = SourceOperations.applyTypeFilter(filterList, "manhwa")
        assertTrue(manhwaApplied)
        assertTrue(koreaBox.state)
        assertFalse(japanBox.state)
        assertFalse(chinaBox.state)
        assertFalse(russiaBox.state)

        // Test manhua selection -> maps to "Китай"
        val manhuaApplied = SourceOperations.applyTypeFilter(filterList, "manhua")
        assertTrue(manhuaApplied)
        assertTrue(chinaBox.state)
        assertFalse(koreaBox.state)
        assertFalse(japanBox.state)

        // Test manga selection -> maps to "Япония"
        val mangaApplied = SourceOperations.applyTypeFilter(filterList, "manga")
        assertTrue(mangaApplied)
        assertTrue(japanBox.state)
        assertFalse(chinaBox.state)
        assertFalse(koreaBox.state)
    }

    @Test
    fun testApplyTypeFilterSelect() {
        val select = TestSelect("Тип", arrayOf("Все", "Манга", "Манхва", "Маньхуа"), state = 0)
        val filterList = FilterList(select)

        assertTrue(SourceOperations.applyTypeFilter(filterList, "manhwa"))
        assertEquals(2, select.state)

        assertTrue(SourceOperations.applyTypeFilter(filterList, "manhua"))
        assertEquals(3, select.state)

        assertTrue(SourceOperations.applyTypeFilter(filterList, "manga"))
        assertEquals(1, select.state)
    }

    @Test
    fun testGetCatalogWithTypeInvokesSearchManga() = runBlocking {
        var searchMangaCalled = false
        var popularMangaCalled = false
        var passedFilters: FilterList? = null

        val source = object : MockHttpSource() {
            override fun getFilterList(): FilterList {
                return FilterList(TestGroup("Тип", listOf(TestTriState("Манга"), TestTriState("Манхва"))))
            }

            override suspend fun getPopularManga(page: Int): MangasPage {
                popularMangaCalled = true
                return super.getPopularManga(page)
            }

            override suspend fun getSearchManga(page: Int, query: String, filters: FilterList): MangasPage {
                searchMangaCalled = true
                passedFilters = filters
                val manga = SManga.create().apply {
                    url = "/manga/search1"
                    title = "Search Title"
                }
                return MangasPage(listOf(manga), hasNextPage = false)
            }
        }

        // Without type, popular manga is called
        SourceOperations.getCatalog(source, page = 1, query = null, type = null)
        assertTrue(popularMangaCalled)
        assertFalse(searchMangaCalled)

        // With type="manhwa", search manga is called with applied filter
        popularMangaCalled = false
        searchMangaCalled = false
        val result = SourceOperations.getCatalog(source, page = 1, query = null, type = "manhwa")
        assertTrue(searchMangaCalled)
        assertFalse(popularMangaCalled)
        assertNotNull(passedFilters)
        val group = passedFilters!![0] as Filter.Group<*>
        val items = (group.state as List<*>).filterIsInstance<Filter.TriState>()
        assertEquals(Filter.TriState.STATE_INCLUDE, items.first { it.name == "Манхва" }.state)
        assertEquals(Filter.TriState.STATE_IGNORE, items.first { it.name == "Манга" }.state)
        assertEquals(1, (result["items"] as List<*>).size)
    }

    @Test
    fun testApplyGenreFilterTriStateIncludeAndExclude() {
        val action = TestTriState("Экшен")
        val fantasy = TestTriState("Фэнтези")
        val harem = TestTriState("Гарем")
        val romance = TestTriState("Романтика")
        val genreGroup = TestGroup("Жанры", listOf(action, fantasy, harem, romance))
        val filterList = FilterList(genreGroup)

        val applied = SourceOperations.applyGenreFilter(
            filterList = filterList,
            includedGenres = listOf("Фэнтези", "Action"),
            excludedGenres = listOf("Гарем")
        )

        assertTrue(applied)
        assertEquals(Filter.TriState.STATE_INCLUDE, fantasy.state)
        assertEquals(Filter.TriState.STATE_INCLUDE, action.state)
        assertEquals(Filter.TriState.STATE_EXCLUDE, harem.state)
        assertEquals(Filter.TriState.STATE_IGNORE, romance.state)
    }

    @Test
    fun testApplyGenreFilterCheckBox() {
        val martialArts = TestCheckBox("Боевые искусства")
        val comedy = TestCheckBox("Комедия")
        val drama = TestCheckBox("Драма")
        val genreGroup = TestGroup("Теги", listOf(martialArts, comedy, drama))
        val filterList = FilterList(genreGroup)

        val applied = SourceOperations.applyGenreFilter(
            filterList = filterList,
            includedGenres = listOf("Боевые искусства", "Комедия"),
            excludedGenres = null
        )

        assertTrue(applied)
        assertTrue(martialArts.state)
        assertTrue(comedy.state)
        assertFalse(drama.state)
    }

    @Test
    fun testGetCatalogWithGenreInvokesSearchManga() = runBlocking {
        var searchMangaCalled = false
        var popularMangaCalled = false
        var passedFilters: FilterList? = null

        val source = object : MockHttpSource() {
            override fun getFilterList(): FilterList {
                return FilterList(TestGroup("Жанры", listOf(TestTriState("Фэнтези"), TestTriState("Гарем"))))
            }

            override suspend fun getPopularManga(page: Int): MangasPage {
                popularMangaCalled = true
                return super.getPopularManga(page)
            }

            override suspend fun getSearchManga(page: Int, query: String, filters: FilterList): MangasPage {
                searchMangaCalled = true
                passedFilters = filters
                val manga = SManga.create().apply {
                    url = "/manga/search_genre"
                    title = "Genre Search Result"
                }
                return MangasPage(listOf(manga), hasNextPage = false)
            }
        }

        // With includedGenres, search manga is invoked
        val result = SourceOperations.getCatalog(
            source = source,
            page = 1,
            query = null,
            type = null,
            includedGenres = listOf("Фэнтези"),
            excludedGenres = listOf("Гарем")
        )

        assertTrue(searchMangaCalled)
        assertFalse(popularMangaCalled)
        assertNotNull(passedFilters)
        val group = passedFilters!![0] as Filter.Group<*>
        val items = (group.state as List<*>).filterIsInstance<Filter.TriState>()
        assertEquals(Filter.TriState.STATE_INCLUDE, items.first { it.name == "Фэнтези" }.state)
        assertEquals(Filter.TriState.STATE_EXCLUDE, items.first { it.name == "Гарем" }.state)
        assertEquals(1, (result["items"] as List<*>).size)
    }

    @Test
    fun testGetMangaDetailsReturnsMappedDtoWithMeaningfulStatus() = runBlocking {
        val source = MockHttpSource()
        val details = SourceOperations.getMangaDetails(source, "/manga/1")

        assertEquals("/manga/1", details["url"])
        assertEquals("Updated Mock Title", details["title"])
        assertEquals("Action, Romance", details["genre"])
        assertEquals("Detailed Description", details["description"])
        assertEquals("Completed", details["status"])
    }

    @Test
    fun testGetMangaUpdateDetailsAndChaptersCaching() = runBlocking {
        val source = MockHttpSource()
        // First call: getMangaDetails fetches both details + chapters and caches
        val details = SourceOperations.getMangaDetails(source, "/manga/1")
        assertEquals("Updated Mock Title", details["title"])
        assertEquals(1, source.updateCallCount.get())

        // Second call: getChapters reuses the cached update without a new remote network call
        val chapters = SourceOperations.getChapters(source, "/manga/1")
        assertEquals(1, chapters.size)
        assertEquals("Chapter 1", chapters[0]["name"])
        assertEquals(1, source.updateCallCount.get())
    }

    @Test
    fun testGetChaptersReturnsChapterListWithDateUploadString() = runBlocking {
        val source = MockHttpSource()
        val chapters = SourceOperations.getChapters(source, "/manga/1")

        assertEquals(1, chapters.size)
        val ch = chapters[0]
        assertEquals("/chapter/1", ch["url"])
        assertEquals("Chapter 1", ch["name"])
        assertEquals(1.5, ch["chapterNumber"] as Double, 0.001)
        assertEquals("1700000000000", ch["dateUpload"])
        assertEquals("ScanGroup", ch["scanlator"])
    }

    @Test
    fun testGetChapterPagesResolvesNullImageUrl() = runBlocking {
        val source = MockHttpSource()
        val pages = SourceOperations.getChapterPages(source, "/chapter/1")

        assertEquals(2, pages.size)
        assertEquals("https://example.com/img0.png", pages[0])
        // Null imageUrl in page 1 resolved via source.getImageUrl
        assertEquals("https://example.com/resolved_1.jpg", pages[1])
    }

    @Test
    fun testGetHeaders() {
        val source = MockHttpSource()
        val headers = SourceOperations.getHeaders(source)
        assertNotNull(headers)
        assertEquals("Mozilla/5.0 DCatcher-Test", headers["User-Agent"])
        assertEquals("https://example.com", headers["Referer"])
    }

    private class AsuraLikeSource(
        override val id: Long = 987654321098765432L,
        override val name: String = "Asura Scans",
        override val lang: String = "en",
        override val baseUrl: String = "https://asura.gg"
    ) : HttpSource() {
        override val supportsLatest: Boolean = true

        override suspend fun getPopularManga(page: Int): MangasPage =
            MangasPage(emptyList(), false)

        override suspend fun getLatestUpdates(page: Int): MangasPage =
            MangasPage(emptyList(), false)

        override suspend fun getSearchManga(page: Int, query: String, filters: FilterList): MangasPage =
            MangasPage(emptyList(), false)

        override suspend fun getMangaUpdate(
            manga: SManga,
            chapters: List<SChapter>,
            fetchDetails: Boolean,
            fetchChapters: Boolean
        ): SMangaUpdate {
            val ch = SChapter.create().apply {
                url = "/series/solo-leveling/chapter-1"
                name = "Chapter 1"
                chapter_number = 1.0f
                date_upload = 1700000000000L
                // Real Asura requires mangaSlug in chapter.memo
                memo = buildJsonObject {
                    put("mangaSlug", "solo-leveling")
                }
            }
            return SMangaUpdate(manga, listOf(ch))
        }

        override suspend fun getPageList(chapter: SChapter): List<Page> {
            val slugPrim = chapter.memo["mangaSlug"]?.jsonPrimitive
            val slug = slugPrim?.content
            if (slug.isNullOrBlank()) {
                throw IllegalStateException("Chapter memo missing mangaSlug required by Asura!")
            }
            return listOf(
                Page(index = 0, url = "https://asura.gg/series/$slug/chapter-1/page-1", imageUrl = "https://asura.gg/img1.jpg")
            )
        }

        override suspend fun getImageUrl(page: Page): String = page.imageUrl ?: ""
    }

    @Test
    fun testDirectGetPageListFailsWithoutMemo() = runBlocking {
        val asuraSource = AsuraLikeSource()
        val bareChapter = SChapter.create().apply {
            url = "/series/solo-leveling/chapter-1"
            name = "Chapter 1"
        }

        try {
            asuraSource.getPageList(bareChapter)
            fail("Direct getPageList must fail when chapter memo lacks required mangaSlug")
        } catch (e: IllegalStateException) {
            assertTrue("Expected memo failure message", e.message?.contains("mangaSlug") == true)
        }
    }

    @Test
    fun testPreserveSChapterMemoThroughGetChaptersToGetPagesAndRestartPersistence() = runBlocking {
        val testStorageDir = tempFolder.newFolder("asura_chapter_storage")
        SourceOperations.setStorageDirectory(testStorageDir)

        val asuraSource = AsuraLikeSource()
        val chapterUrl = "/series/solo-leveling/chapter-1"

        // 1. Production flow: getChapters populates both in-memory and persistent disk cache with chapter memo
        val chapters = SourceOperations.getChapters(asuraSource, "/series/solo-leveling")
        assertEquals(1, chapters.size)
        assertEquals(chapterUrl, chapters[0]["url"])

        // 2. Production flow: getChapterPages retrieves chapter with preserved memo and succeeds
        val pages1 = SourceOperations.getChapterPages(asuraSource, chapterUrl)
        assertEquals(1, pages1.size)
        assertEquals("https://asura.gg/img1.jpg", pages1[0])

        // 3. Simulate native process restart: clear in-memory caches completely
        SourceOperations.clearMemoryCacheOnly()

        // 4. Production flow after restart: getChapterPages restores full chapter + memo from persistent disk storage
        val pages2 = SourceOperations.getChapterPages(asuraSource, chapterUrl)
        assertEquals(1, pages2.size)
        assertEquals("https://asura.gg/img1.jpg", pages2[0])

        // 5. Invalidation on uninstall/update: invalidates both memory and persistent disk cache
        SourceOperations.invalidateForSource(asuraSource.id)

        // 6. After invalidation, chapter is missing from cache; fallback bare chapter is passed, so source throws
        try {
            SourceOperations.getChapterPages(asuraSource, chapterUrl)
            fail("After invalidation, getChapterPages must fail closed because memo was purged")
        } catch (e: IllegalStateException) {
            assertTrue("Expected memo missing failure", e.message?.contains("mangaSlug") == true)
        }
    }

    @Test
    fun testGetChapterPagesPropagatesExceptionWhenGetImageUrlThrows() = runBlocking {
        val source = object : MockHttpSource() {
            override suspend fun getPageList(chapter: SChapter): List<Page> {
                return listOf(Page(0, url = "https://example.com/page0.html", imageUrl = null))
            }

            override suspend fun getImageUrl(page: Page): String {
                throw IOException("Network error resolving image URL")
            }
        }

        try {
            SourceOperations.getChapterPages(source, "/chapter/1")
            fail("Expected IOException when getImageUrl throws")
        } catch (e: IOException) {
            assertEquals("Network error resolving image URL", e.message)
        }
    }

    @Test
    fun testGetChapterPagesFailsWhenResolvedImageUrlIsBlank() = runBlocking {
        val source = object : MockHttpSource() {
            override suspend fun getPageList(chapter: SChapter): List<Page> {
                return listOf(Page(0, url = "https://example.com/page0.html", imageUrl = "   "))
            }

            override suspend fun getImageUrl(page: Page): String {
                return ""
            }
        }

        try {
            SourceOperations.getChapterPages(source, "/chapter/1")
            fail("Expected exception when resolved imageUrl is blank")
        } catch (e: Exception) {
            assertTrue("Expected empty or invalid image URL error", e.message?.contains("Image URL is blank") == true || e is IOException || e is IllegalStateException)
        }
    }

    @Test
    fun testFetchImageInvokesOverriddenImageRequest() = runBlocking {
        val testBytes = byteArrayOf(1, 2, 3, 4, 5)
        val source = object : MockHttpSource() {
            override val client = OkHttpClient.Builder()
                .addInterceptor(Interceptor { chain ->
                    val request = chain.request()
                    val customHeader = request.header("X-Custom-Image-Header")
                    if (customHeader == "CustomValue") {
                        Response.Builder()
                            .request(request)
                            .protocol(Protocol.HTTP_1_1)
                            .code(200)
                            .message("OK")
                            .body(testBytes.toResponseBody("image/jpeg".toMediaType()))
                            .build()
                    } else {
                        Response.Builder()
                            .request(request)
                            .protocol(Protocol.HTTP_1_1)
                            .code(400)
                            .message("Missing Header")
                            .body(ByteArray(0).toResponseBody("text/plain".toMediaType()))
                            .build()
                    }
                })
                .build()

            override fun imageRequest(page: Page): Request {
                return GET(page.imageUrl!!, headers.newBuilder().add("X-Custom-Image-Header", "CustomValue").build())
            }
        }

        val resultBytes = SourceOperations.fetchImage(source, "https://example.com/image.jpg")
        assertArrayEquals(testBytes, resultBytes)
    }

    @Test
    fun testFetchImageRejectsEmptyBytes() = runBlocking {
        val source = object : MockHttpSource() {
            override val client = OkHttpClient.Builder()
                .addInterceptor(Interceptor { chain ->
                    val request = chain.request()
                    Response.Builder()
                        .request(request)
                        .protocol(Protocol.HTTP_1_1)
                        .code(200)
                        .message("OK")
                        .body(ByteArray(0).toResponseBody("image/jpeg".toMediaType()))
                        .build()
                })
                .build()
        }

        try {
            SourceOperations.fetchImage(source, "https://example.com/empty.jpg")
            fail("Expected exception when response bytes are empty")
        } catch (e: IOException) {
            assertTrue(e.message?.contains("empty") == true || e.message?.contains("Empty") == true)
        }
    }

    @Test
    fun testFetchImageReusesOriginalPageContextFromGetChapterPages() = runBlocking {
        val testBytes = byteArrayOf(9, 8, 7)
        val expectedReferer = "https://example.com/reader/chapter-1/page-5.html"
        val expectedImageUrl = "https://cdn.example.com/images/ch1_p5.jpg"
        val expectedIndex = 5

        val source = object : MockHttpSource() {
            override val client = OkHttpClient.Builder()
                .addInterceptor(Interceptor { chain ->
                    val request = chain.request()
                    val reqReferer = request.header("Referer")
                    val reqIndexHeader = request.header("X-Page-Index")

                    if (reqReferer == expectedReferer && reqIndexHeader == expectedIndex.toString()) {
                        Response.Builder()
                            .request(request)
                            .protocol(Protocol.HTTP_1_1)
                            .code(200)
                            .message("OK")
                            .body(testBytes.toResponseBody("image/jpeg".toMediaType()))
                            .build()
                    } else {
                        Response.Builder()
                            .request(request)
                            .protocol(Protocol.HTTP_1_1)
                            .code(400)
                            .message("Missing or mismatched page context headers: referer=$reqReferer index=$reqIndexHeader")
                            .body(ByteArray(0).toResponseBody("text/plain".toMediaType()))
                            .build()
                    }
                })
                .build()

            override suspend fun getPageList(chapter: SChapter): List<Page> {
                return listOf(
                    Page(
                        index = expectedIndex,
                        url = expectedReferer,
                        imageUrl = expectedImageUrl
                    )
                )
            }

            override fun imageRequest(page: Page): Request {
                return GET(
                    page.imageUrl!!,
                    headers.newBuilder()
                        .set("Referer", page.url)
                        .add("X-Page-Index", page.index.toString())
                        .build()
                )
            }
        }

        // 1. Resolve pages via getChapterPages
        val resolvedPages = SourceOperations.getChapterPages(source, "/chapter/1")
        assertEquals(1, resolvedPages.size)
        assertEquals(expectedImageUrl, resolvedPages[0])

        // 2. Fetch image using resolved image URL; should reuse original Page with index=5 and page.url HTML referer
        val bytes = SourceOperations.fetchImage(source, expectedImageUrl)
        assertArrayEquals(testBytes, bytes)

        // 3. Cover / uncached fallback remains functional with Page(0, url=url, imageUrl=url)
        val fallbackSource = object : MockHttpSource() {
            override val client = OkHttpClient.Builder()
                .addInterceptor(Interceptor { chain ->
                    Response.Builder()
                        .request(chain.request())
                        .protocol(Protocol.HTTP_1_1)
                        .code(200)
                        .message("OK")
                        .body(testBytes.toResponseBody("image/jpeg".toMediaType()))
                        .build()
                })
                .build()

            override fun imageRequest(page: Page): Request {
                assertEquals(0, page.index)
                assertEquals("https://example.com/cover.jpg", page.url)
                assertEquals("https://example.com/cover.jpg", page.imageUrl)
                return super.imageRequest(page)
            }
        }
        val coverBytes = SourceOperations.fetchImage(fallbackSource, "https://example.com/cover.jpg")
        assertArrayEquals(testBytes, coverBytes)

        // 4. Invalidation clears page context cache
        SourceOperations.invalidateForSource(source.id)
        try {
            SourceOperations.fetchImage(source, expectedImageUrl)
            fail("Expected fetchImage to fail after cache invalidation because Page(0) lacks original page.url and index context")
        } catch (e: HttpException) {
            assertEquals(400, e.code)
            assertTrue(e.message?.contains("400") == true)
        }
    }

    private class TestSort(
        name: String,
        values: Array<String>,
        state: Selection? = Selection(0, false)
    ) : Filter.Sort(name, values, state)

    @Test
    fun testApplyStatusFilterMangaBuffAndInkStoryStyle() {
        val translationStatus = TestGroup(
            "Статус перевода",
            listOf(TestCheckBox("Завершен"), TestCheckBox("Продолжается"))
        )
        val titleStatus = TestGroup(
            "Статус",
            listOf(
                TestCheckBox("Анонс"),
                TestCheckBox("Онгоинг"),
                TestCheckBox("Завершен"),
                TestCheckBox("Заморожен")
            )
        )
        val filterList = FilterList(translationStatus, titleStatus)

        assertTrue(SourceOperations.applyStatusFilter(filterList, "completed"))
        val boxes = titleStatus.state.filterIsInstance<Filter.CheckBox>()
        assertFalse(boxes[0].state)
        assertFalse(boxes[1].state)
        assertTrue(boxes[2].state) // Завершен
        assertFalse(boxes[3].state)
        // Must NOT touch "Статус перевода"
        assertFalse((translationStatus.state[0] as Filter.CheckBox).state)

        assertTrue(SourceOperations.applyStatusFilter(filterList, "ongoing"))
        assertTrue(boxes[1].state) // Онгоинг
        assertFalse(boxes[2].state)
    }

    @Test
    fun testApplySortFilterInkStorySortAndMangaBuffSelect() {
        // InkStory style Filter.Sort
        val inkSort = TestSort(
            "Сортировать по",
            arrayOf("Просмотрам", "Лайкам", "Главам", "Рейтингу", "Дате создания")
        )
        val inkFilters = FilterList(inkSort)

        assertTrue(SourceOperations.applySortFilter(inkFilters, "-id"))
        assertEquals(Filter.Sort.Selection(4, false), inkSort.state) // Дате создания

        assertTrue(SourceOperations.applySortFilter(inkFilters, "-count_chapters"))
        assertEquals(Filter.Sort.Selection(2, false), inkSort.state) // Главам

        assertTrue(SourceOperations.applySortFilter(inkFilters, "-total_views"))
        assertEquals(Filter.Sort.Selection(0, false), inkSort.state) // Просмотрам

        // MangaBuff style Filter.Select
        val mbSort = TestSelect(
            "Сортировать по",
            arrayOf("Популярные", "Обновленные", "По рейтингу", "По новинкам")
        )
        val mbFilters = FilterList(mbSort)

        assertTrue(SourceOperations.applySortFilter(mbFilters, "-id"))
        assertEquals(3, mbSort.state) // По новинкам

        assertTrue(SourceOperations.applySortFilter(mbFilters, "-total_views"))
        assertEquals(0, mbSort.state) // Популярные (real_views)
    }

    @Test
    fun testGetCatalogStatusAndOrderingRouting() = runBlocking {
        var searchCalled = false
        var latestCalled = false

        val sourceWithoutSort = object : MockHttpSource() {
            override fun getFilterList(): FilterList = FilterList(
                TestGroup("Статус", listOf(TestCheckBox("Завершен"), TestCheckBox("Продолжается")))
            )

            override suspend fun getLatestUpdates(page: Int): MangasPage {
                latestCalled = true
                return super.getLatestUpdates(page)
            }

            override suspend fun getSearchManga(page: Int, query: String, filters: FilterList): MangasPage {
                searchCalled = true
                return super.getSearchManga(page, query, filters)
            }
        }

        // Ordering "-id" without SortFilter falls back to getLatestUpdates
        SourceOperations.getCatalog(sourceWithoutSort, page = 1, query = null, ordering = "-id")
        assertTrue(latestCalled)
        assertFalse(searchCalled)

        // Status "completed" triggers getSearchManga with StatusFilter applied
        SourceOperations.getCatalog(sourceWithoutSort, page = 1, query = null, status = "completed")
        assertTrue(searchCalled)
    }
}
