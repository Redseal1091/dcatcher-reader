package com.example.manga_reader_app

import eu.kanade.tachiyomi.network.GET
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.model.Filter
import eu.kanade.tachiyomi.source.model.FilterList
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import eu.kanade.tachiyomi.source.model.SMangaUpdate
import eu.kanade.tachiyomi.source.online.HttpSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.io.File
import java.io.IOException
import java.security.MessageDigest
import java.util.LinkedHashMap

object SourceOperations {

    private val mangaUpdateCache = object : LinkedHashMap<String, SMangaUpdate>(50, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, SMangaUpdate>?): Boolean {
            return size > 50
        }
    }

    private val chapterContextCache = object : LinkedHashMap<String, SChapter>(200, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, SChapter>?): Boolean {
            return size > 200
        }
    }

    private val pageContextCache = object : LinkedHashMap<String, Page>(500, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Page>?): Boolean {
            return size > 500
        }
    }

    @Volatile
    private var baseStorageDir: File? = null

    fun setStorageDirectory(dir: File) {
        dir.mkdirs()
        baseStorageDir = dir
    }

    fun getStorageDirectory(): File? = baseStorageDir

    private fun getSourceStorageDir(sourceId: Long): File? {
        val base = baseStorageDir ?: return null
        return File(base, sourceId.toString()).apply { mkdirs() }
    }

    fun clearCache() {
        synchronized(mangaUpdateCache) {
            mangaUpdateCache.clear()
        }
        synchronized(chapterContextCache) {
            chapterContextCache.clear()
        }
        synchronized(pageContextCache) {
            pageContextCache.clear()
        }
        val base = baseStorageDir
        if (base != null && base.exists()) {
            base.deleteRecursively()
            base.mkdirs()
        }
    }

    fun clearMemoryCacheOnly() {
        synchronized(mangaUpdateCache) {
            mangaUpdateCache.clear()
        }
        synchronized(chapterContextCache) {
            chapterContextCache.clear()
        }
        synchronized(pageContextCache) {
            pageContextCache.clear()
        }
    }

    fun invalidateForSource(sourceId: Long) {
        synchronized(mangaUpdateCache) {
            val prefix = "$sourceId:"
            val iterator = mangaUpdateCache.keys.iterator()
            while (iterator.hasNext()) {
                if (iterator.next().startsWith(prefix)) {
                    iterator.remove()
                }
            }
        }
        synchronized(chapterContextCache) {
            val prefix = "$sourceId:"
            val iterator = chapterContextCache.keys.iterator()
            while (iterator.hasNext()) {
                if (iterator.next().startsWith(prefix)) {
                    iterator.remove()
                }
            }
        }
        synchronized(pageContextCache) {
            val prefix = "$sourceId:"
            val iterator = pageContextCache.keys.iterator()
            while (iterator.hasNext()) {
                if (iterator.next().startsWith(prefix)) {
                    iterator.remove()
                }
            }
        }
        getSourceStorageDir(sourceId)?.deleteRecursively()
    }

    fun invalidateForSources(sourceIds: Collection<String>) {
        for (idStr in sourceIds) {
            val idLong = idStr.toLongOrNull() ?: continue
            invalidateForSource(idLong)
        }
    }

    private fun chapterUrlToHash(url: String): String {
        val md = MessageDigest.getInstance("SHA-256")
        val digest = md.digest(url.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }

    private fun chapterToJson(chapter: SChapter): String {
        val obj = buildJsonObject {
            put("url", chapter.url)
            put("name", chapter.name)
            put("chapter_number", chapter.chapter_number)
            put("date_upload", chapter.date_upload)
            chapter.scanlator?.let { put("scanlator", it) }
            put("memo", chapter.memo)
        }
        return obj.toString()
    }

    private fun jsonToChapter(jsonString: String): SChapter? {
        return try {
            val element = Json.parseToJsonElement(jsonString).jsonObject
            val urlPrim = element["url"]?.jsonPrimitive
            val urlStr = if (urlPrim != null && urlPrim !is kotlinx.serialization.json.JsonNull) urlPrim.content else return null
            val namePrim = element["name"]?.jsonPrimitive
            val nameStr = if (namePrim != null && namePrim !is kotlinx.serialization.json.JsonNull) namePrim.content else ""
            val numPrim = element["chapter_number"]?.jsonPrimitive
            val chapterNum = numPrim?.content?.toFloatOrNull() ?: -1f
            val datePrim = element["date_upload"]?.jsonPrimitive
            val dateUpload = datePrim?.content?.toLongOrNull() ?: 0L
            val scanPrim = element["scanlator"]?.jsonPrimitive
            val scanlator = if (scanPrim != null && scanPrim !is kotlinx.serialization.json.JsonNull) scanPrim.content else null
            val memoObj = element["memo"] as? JsonObject ?: JsonObject(emptyMap())

            SChapter.create().apply {
                url = urlStr
                name = nameStr
                chapter_number = chapterNum
                date_upload = dateUpload
                this.scanlator = scanlator
                memo = memoObj
            }
        } catch (_: Exception) {
            null
        }
    }

    fun mapStatusToString(status: Int): String {
        return when (status) {
            SManga.ONGOING -> "Ongoing"
            SManga.COMPLETED -> "Completed"
            SManga.LICENSED -> "Licensed"
            SManga.PUBLISHING_FINISHED -> "Publishing finished"
            SManga.CANCELLED -> "Cancelled"
            SManga.ON_HIATUS -> "On hiatus"
            else -> "Unknown"
        }
    }

    fun applyTypeFilter(filterList: FilterList, type: String?): Boolean {
        if (type.isNullOrBlank()) return false
        val normalizedType = type.trim().lowercase()

        val typeKeywords = when (normalizedType) {
            "manhwa" -> listOf("манхва", "manhwa")
            "manhua" -> listOf("маньхуа", "manhua")
            "manga" -> listOf("манга", "manga")
            else -> emptyList()
        }

        val countryKeywords = when (normalizedType) {
            "manhwa" -> listOf("корея", "korea", "южная корея", "south korea")
            "manhua" -> listOf("китай", "china")
            "manga" -> listOf("япония", "japan")
            else -> emptyList()
        }

        val formatKeywords = when (normalizedType) {
            "manhwa" -> listOf("вебтун", "webtoon")
            else -> emptyList()
        }

        val typeGroupNames = setOf("тип", "type", "publication type", "вид")
        val countryGroupNames = setOf("страна", "country", "страна выпуска", "страна происхождение", "происхождение")
        val formatGroupNames = setOf("формат", "format")

        fun matchesKeyword(text: String, keywords: List<String>): Boolean {
            val clean = text.trim().lowercase()
            if (keywords.any { it == clean }) return true
            val tokens = clean.split(Regex("[^a-zA-Zа-яА-Я0-9]+")).filter { it.isNotEmpty() }
            return keywords.any { kw -> tokens.contains(kw) }
        }

        fun tryApplyToGroup(group: Filter.Group<*>, keywords: List<String>): Boolean {
            val children = (group.state as? List<*>)?.filterIsInstance<Filter<*>>() ?: return false
            var matchedIndex = -1

            // Exact match pass
            for (i in children.indices) {
                val clean = children[i].name.trim().lowercase()
                if (keywords.any { it == clean }) {
                    matchedIndex = i
                    break
                }
            }

            // Token match pass
            if (matchedIndex == -1) {
                for (i in children.indices) {
                    if (matchesKeyword(children[i].name, keywords)) {
                        matchedIndex = i
                        break
                    }
                }
            }

            if (matchedIndex != -1) {
                for (i in children.indices) {
                    val child = children[i]
                    val isTarget = (i == matchedIndex)
                    when (child) {
                        is Filter.TriState -> {
                            child.state = if (isTarget) Filter.TriState.STATE_INCLUDE else Filter.TriState.STATE_IGNORE
                        }
                        is Filter.CheckBox -> {
                            child.state = isTarget
                        }
                        else -> {}
                    }
                }
                return true
            }
            return false
        }

        fun tryApplyToSelect(select: Filter.Select<*>, keywords: List<String>): Boolean {
            val values = select.values
            var matchedIndex = -1

            for (i in values.indices) {
                val clean = values[i].toString().trim().lowercase()
                if (keywords.any { it == clean }) {
                    matchedIndex = i
                    break
                }
            }

            if (matchedIndex == -1) {
                for (i in values.indices) {
                    if (matchesKeyword(values[i].toString(), keywords)) {
                        matchedIndex = i
                        break
                    }
                }
            }

            if (matchedIndex != -1) {
                select.state = matchedIndex
                return true
            }
            return false
        }

        // Priority 1: Groups with Type-related names, matching typeKeywords
        for (filter in filterList) {
            if (filter is Filter.Group<*>) {
                val gName = filter.name.trim().lowercase()
                if (typeGroupNames.any { gName.contains(it) }) {
                    if (typeKeywords.isNotEmpty() && tryApplyToGroup(filter, typeKeywords)) {
                        return true
                    }
                }
            } else if (filter is Filter.Select<*>) {
                val sName = filter.name.trim().lowercase()
                if (typeGroupNames.any { sName.contains(it) }) {
                    if (typeKeywords.isNotEmpty() && tryApplyToSelect(filter, typeKeywords)) {
                        return true
                    }
                }
            }
        }

        // Priority 2: Groups with Country-related names, matching countryKeywords
        for (filter in filterList) {
            if (filter is Filter.Group<*>) {
                val gName = filter.name.trim().lowercase()
                if (countryGroupNames.any { gName.contains(it) }) {
                    if (countryKeywords.isNotEmpty() && tryApplyToGroup(filter, countryKeywords)) {
                        return true
                    }
                }
            } else if (filter is Filter.Select<*>) {
                val sName = filter.name.trim().lowercase()
                if (countryGroupNames.any { sName.contains(it) }) {
                    if (countryKeywords.isNotEmpty() && tryApplyToSelect(filter, countryKeywords)) {
                        return true
                    }
                }
            }
        }

        // Priority 3: Groups with Format-related names, matching formatKeywords
        if (formatKeywords.isNotEmpty()) {
            for (filter in filterList) {
                if (filter is Filter.Group<*>) {
                    val gName = filter.name.trim().lowercase()
                    if (formatGroupNames.any { gName.contains(it) }) {
                        if (tryApplyToGroup(filter, formatKeywords)) {
                            return true
                        }
                    }
                } else if (filter is Filter.Select<*>) {
                    val sName = filter.name.trim().lowercase()
                    if (formatGroupNames.any { sName.contains(it) }) {
                        if (tryApplyToSelect(filter, formatKeywords)) {
                            return true
                        }
                    }
                }
            }
        }

        // Priority 4: Any Group or Select whose children match typeKeywords, then countryKeywords
        for (filter in filterList) {
            if (filter is Filter.Group<*>) {
                if (typeKeywords.isNotEmpty() && tryApplyToGroup(filter, typeKeywords)) return true
            } else if (filter is Filter.Select<*>) {
                if (typeKeywords.isNotEmpty() && tryApplyToSelect(filter, typeKeywords)) return true
            }
        }
        for (filter in filterList) {
            if (filter is Filter.Group<*>) {
                if (countryKeywords.isNotEmpty() && tryApplyToGroup(filter, countryKeywords)) return true
            } else if (filter is Filter.Select<*>) {
                if (countryKeywords.isNotEmpty() && tryApplyToSelect(filter, countryKeywords)) return true
            }
        }

        return false
    }

    fun applyGenreFilter(
        filterList: FilterList,
        includedGenres: List<String>?,
        excludedGenres: List<String>?
    ): Boolean {
        val inc = includedGenres?.filter { it.isNotBlank() }?.map { it.trim().lowercase() } ?: emptyList()
        val exc = excludedGenres?.filter { it.isNotBlank() }?.map { it.trim().lowercase() } ?: emptyList()
        if (inc.isEmpty() && exc.isEmpty()) return false

        val genreGroupNames = setOf(
            "жанры", "жанр", "genres", "genre",
            "теги", "тег", "tags", "tag",
            "категории", "категория", "categories", "category",
            "темы", "тема", "themes", "theme"
        )

        val genreSynonyms = mapOf(
            "action" to listOf("action", "экшен", "боевик"),
            "adventure" to listOf("adventure", "приключения"),
            "comedy" to listOf("comedy", "комедия"),
            "drama" to listOf("drama", "драма"),
            "fantasy" to listOf("fantasy", "фэнтези"),
            "horror" to listOf("horror", "ужасы", "хоррор"),
            "romance" to listOf("romance", "романтика"),
            "martial arts" to listOf("martial arts", "боевые искусства", "уся"),
            "mystery" to listOf("mystery", "мистика", "тайна", "детектив"),
            "psychological" to listOf("psychological", "психология"),
            "sci-fi" to listOf("sci-fi", "scifi", "научная фантастика", "фантастика"),
            "supernatural" to listOf("supernatural", "сверхъестественное"),
            "thriller" to listOf("thriller", "триллер"),
            "harem" to listOf("harem", "гарем"),
            "system" to listOf("system", "система"),
            "cultivation" to listOf("cultivation", "культивация", "сянься"),
            "regression" to listOf("regression", "регрессия"),
            "reincarnation" to listOf("reincarnation", "перерождение", "реинкарнация"),
            "isekai" to listOf("isekai", "исекай", "исэкай")
        )

        fun expandKeywords(keywords: List<String>): List<String> {
            val result = mutableSetOf<String>()
            for (kw in keywords) {
                result.add(kw)
                for ((key, syns) in genreSynonyms) {
                    if (kw == key || syns.contains(kw)) {
                        result.addAll(syns)
                    }
                }
            }
            return result.toList()
        }

        val expandedInc = expandKeywords(inc)
        val expandedExc = expandKeywords(exc)

        fun matchesKeywords(name: String, keywords: List<String>): Boolean {
            val clean = name.trim().lowercase()
            for (kw in keywords) {
                if (clean == kw) return true
                if (clean.length >= 3 && kw.length >= 3) {
                    if (clean.contains(kw) || kw.contains(clean)) return true
                }
            }
            return false
        }

        var anyApplied = false

        for (filter in filterList) {
            if (filter is Filter.Group<*>) {
                val gName = filter.name.trim().lowercase()
                val isGenreGroup = genreGroupNames.any { gName.contains(it) }
                val children = (filter.state as? List<*>)?.filterIsInstance<Filter<*>>() ?: continue

                val hasMatchingChildren = isGenreGroup || children.any { child ->
                    matchesKeywords(child.name, expandedInc) || matchesKeywords(child.name, expandedExc)
                }

                if (hasMatchingChildren) {
                    for (child in children) {
                        when (child) {
                            is Filter.TriState -> {
                                val isInc = matchesKeywords(child.name, expandedInc)
                                val isExc = matchesKeywords(child.name, expandedExc)
                                if (isInc) {
                                    child.state = Filter.TriState.STATE_INCLUDE
                                    anyApplied = true
                                } else if (isExc) {
                                    child.state = Filter.TriState.STATE_EXCLUDE
                                    anyApplied = true
                                }
                            }
                            is Filter.CheckBox -> {
                                val isInc = matchesKeywords(child.name, expandedInc)
                                if (isInc) {
                                    child.state = true
                                    anyApplied = true
                                }
                            }
                            else -> {}
                        }
                    }
                }
            } else if (filter is Filter.TriState) {
                val isInc = matchesKeywords(filter.name, expandedInc)
                val isExc = matchesKeywords(filter.name, expandedExc)
                if (isInc) {
                    filter.state = Filter.TriState.STATE_INCLUDE
                    anyApplied = true
                } else if (isExc) {
                    filter.state = Filter.TriState.STATE_EXCLUDE
                    anyApplied = true
                }
            } else if (filter is Filter.CheckBox) {
                val isInc = matchesKeywords(filter.name, expandedInc)
                if (isInc) {
                    filter.state = true
                    anyApplied = true
                }
            }
        }

        return anyApplied
    }

    private fun findBestOptionIndex(options: List<String>, keywordPasses: List<List<String>>): Int {
        for (keywords in keywordPasses) {
            for (i in options.indices) {
                val clean = options[i].trim().lowercase()
                if (keywords.any { it == clean }) return i
            }
            for (i in options.indices) {
                val clean = options[i].trim().lowercase()
                val tokens = clean.split(Regex("[^a-zA-Zа-яА-ЯёЁ0-9]+")).filter { it.isNotEmpty() }
                if (keywords.any { kw -> tokens.contains(kw) || (kw.length >= 4 && clean.contains(kw)) }) {
                    return i
                }
            }
        }
        return -1
    }

    fun applyStatusFilter(filterList: FilterList, status: String?): Boolean {
        if (status.isNullOrBlank()) return false
        val normalized = status.trim().lowercase()

        val keywordPasses: List<List<String>> = when (normalized) {
            "completed" -> listOf(
                listOf("завершен", "завершён", "закончен", "completed", "complete", "done", "finished"),
                listOf("выпуск завершен", "publishing finished")
            )
            "ongoing" -> listOf(
                listOf("онгоинг", "продолжается", "выходит", "ongoing", "publishing", "в процессе")
            )
            "hiatus" -> listOf(
                listOf("заморожен", "приостановлен", "hiatus", "on hiatus", "frozen", "заброшен")
            )
            else -> emptyList()
        }
        if (keywordPasses.isEmpty()) return false

        val statusGroupNames = setOf("статус", "status", "состояние", "статус тайтла", "статус выпуска")

        fun applyToGroup(group: Filter.Group<*>): Boolean {
            val children = (group.state as? List<*>)?.filterIsInstance<Filter<*>>() ?: return false
            val idx = findBestOptionIndex(children.map { it.name }, keywordPasses)
            if (idx == -1) return false
            for (i in children.indices) {
                val isTarget = i == idx
                when (val child = children[i]) {
                    is Filter.CheckBox -> child.state = isTarget
                    is Filter.TriState -> child.state =
                        if (isTarget) Filter.TriState.STATE_INCLUDE else Filter.TriState.STATE_IGNORE
                    else -> {}
                }
            }
            return true
        }

        fun applyToSelect(select: Filter.Select<*>): Boolean {
            val idx = findBestOptionIndex(select.values.map { it.toString() }, keywordPasses)
            if (idx == -1) return false
            select.state = idx
            return true
        }

        // Priority 1: Explicit title status groups/selects (avoiding "Статус перевода")
        for (filter in filterList) {
            val fName = filter.name.trim().lowercase()
            if (fName.contains("перевод") || fName.contains("translation")) continue
            if (statusGroupNames.any { fName == it || fName.contains(it) }) {
                when (filter) {
                    is Filter.Group<*> -> if (applyToGroup(filter)) return true
                    is Filter.Select<*> -> if (applyToSelect(filter)) return true
                    else -> {}
                }
            }
        }

        // Priority 2: Any non-translation group/select with matching status option
        for (filter in filterList) {
            val fName = filter.name.trim().lowercase()
            if (fName.contains("перевод") || fName.contains("translation") || fName.contains("возраст")) continue
            when (filter) {
                is Filter.Group<*> -> if (applyToGroup(filter)) return true
                is Filter.Select<*> -> if (applyToSelect(filter)) return true
                else -> {}
            }
        }

        return false
    }

    fun applySortFilter(filterList: FilterList, ordering: String?): Boolean {
        if (ordering.isNullOrBlank()) return false
        val normalized = ordering.trim().lowercase()

        val keywordPasses: List<List<String>> = when (normalized) {
            "-id" -> listOf(
                listOf(
                    "по новинкам", "новинки", "новинкам",
                    "дате создания", "по дате создания", "дата создания",
                    "дате добавления", "по дате добавления", "дате публикации",
                    "created", "newest", "new"
                ),
                listOf(
                    "обновленные", "обновлённые", "по дате обновления",
                    "дате последней главы", "последнему обновлению",
                    "latest", "updated", "recent"
                )
            )
            "-count_chapters" -> listOf(
                listOf("по главам", "главам", "количеству глав", "кол-ву глав", "chapters", "chapter count")
            )
            "-total_views" -> listOf(
                listOf("по просмотрам", "просмотрам", "просмотры", "views", "most viewed"),
                listOf("популярные", "популярности", "popular")
            )
            "-rating" -> listOf(
                listOf("популярные", "популярности", "по рейтингу", "рейтингу", "рейтинг", "popular", "rating")
            )
            else -> emptyList()
        }
        if (keywordPasses.isEmpty()) return false

        val sortNames = listOf("сорт", "sort", "порядок", "order", "упорядоч")
        val sortOptionIndicators = listOf(
            "популяр", "рейтинг", "новинк", "обновлен", "просмотр", "дате соз", "главам",
            "popular", "rating", "latest", "views", "chapters", "created"
        )

        for (filter in filterList) {
            if (filter is Filter.Sort) {
                val idx = findBestOptionIndex(filter.values.toList(), keywordPasses)
                if (idx != -1) {
                    filter.state = Filter.Sort.Selection(idx, ascending = false)
                    return true
                }
            }
        }

        for (filter in filterList) {
            if (filter is Filter.Select<*>) {
                val fName = filter.name.trim().lowercase()
                val options = filter.values.map { it.toString() }
                val looksLikeSort = sortNames.any { fName.contains(it) } ||
                    options.any { opt -> sortOptionIndicators.any { ind -> opt.lowercase().contains(ind) } }
                if (!looksLikeSort) continue

                val idx = findBestOptionIndex(options, keywordPasses)
                if (idx != -1) {
                    filter.state = idx
                    return true
                }
            }
        }

        return false
    }

    suspend fun getCatalog(
        source: Source,
        page: Int,
        query: String?,
        type: String? = null,
        includedGenres: List<String>? = null,
        excludedGenres: List<String>? = null,
        ordering: String? = null,
        status: String? = null
    ): Map<String, Any?> = withContext(Dispatchers.IO) {
        val filterList = try {
            source.getFilterList()
        } catch (_: Throwable) {
            FilterList()
        }

        val hasTypeFilter = applyTypeFilter(filterList, type)
        val hasGenreFilter = applyGenreFilter(filterList, includedGenres, excludedGenres)
        val hasStatusFilter = applyStatusFilter(filterList, status)
        val isNonDefaultOrdering = !ordering.isNullOrBlank() && ordering != "-rating"
        val hasSortFilter = if (isNonDefaultOrdering) applySortFilter(filterList, ordering) else false
        val hasQuery = !query.isNullOrBlank()

        val mangasPage = if (hasQuery || hasTypeFilter || hasGenreFilter || hasStatusFilter || hasSortFilter) {
            source.getSearchManga(page, query ?: "", filterList)
        } else if (ordering == "-id") {
            source.getLatestUpdates(page)
        } else {
            source.getPopularManga(page)
        }

        val items = mangasPage.mangas.map { manga ->
            mapOf(
                "url" to manga.url,
                "title" to manga.title,
                "thumbnailUrl" to manga.thumbnail_url,
                "description" to manga.description,
                "genre" to manga.genre,
                "status" to mapStatusToString(manga.status),
                "author" to manga.author,
                "artist" to manga.artist
            )
        }

        mapOf(
            "items" to items,
            "hasNextPage" to mangasPage.hasNextPage
        )
    }

    suspend fun getMangaDetails(
        source: Source,
        mangaUrl: String
    ): Map<String, Any?> = withContext(Dispatchers.IO) {
        val cacheKey = "${source.id}:$mangaUrl"
        val cached = synchronized(mangaUpdateCache) { mangaUpdateCache[cacheKey] }

        val manga = if (cached != null && cached.manga.initialized) {
            cached.manga
        } else {
            val initialManga = SManga.create().apply {
                url = mangaUrl
                title = ""
            }

            // Upstream API 1.6 supports details + chapters in a single getMangaUpdate call
            val update = source.getMangaUpdate(
                manga = initialManga,
                chapters = emptyList(),
                fetchDetails = true,
                fetchChapters = true
            )

            synchronized(mangaUpdateCache) {
                mangaUpdateCache[cacheKey] = update
            }
            update.manga
        }

        mapOf(
            "url" to manga.url,
            "title" to manga.title,
            "thumbnailUrl" to manga.thumbnail_url,
            "description" to manga.description,
            "genre" to manga.genre,
            "status" to mapStatusToString(manga.status),
            "author" to manga.author,
            "artist" to manga.artist
        )
    }

    suspend fun getChapters(
        source: Source,
        mangaUrl: String
    ): List<Map<String, Any?>> = withContext(Dispatchers.IO) {
        val cacheKey = "${source.id}:$mangaUrl"
        val cached = synchronized(mangaUpdateCache) { mangaUpdateCache[cacheKey] }

        val chapters = if (cached != null && cached.chapters.isNotEmpty()) {
            cached.chapters
        } else {
            val initialManga = SManga.create().apply {
                url = mangaUrl
                title = ""
            }

            val update = source.getMangaUpdate(
                manga = initialManga,
                chapters = emptyList(),
                fetchDetails = false,
                fetchChapters = true
            )

            synchronized(mangaUpdateCache) {
                mangaUpdateCache[cacheKey] = update
            }
            update.chapters
        }

        // Cache and persist full chapter context (including SChapter.memo)
        val sourceDir = getSourceStorageDir(source.id)
        for (chapter in chapters) {
            val chapterKey = "${source.id}:${chapter.url}"
            synchronized(chapterContextCache) {
                chapterContextCache[chapterKey] = chapter
            }
            if (sourceDir != null) {
                try {
                    val file = File(sourceDir, "${chapterUrlToHash(chapter.url)}.json")
                    file.writeText(chapterToJson(chapter))
                } catch (e: Exception) {
                    System.err.println("Failed to persist chapter context for ${chapter.url}: ${e.message}")
                }
            }
        }

        chapters.map { chapter ->
            mapOf(
                "url" to chapter.url,
                "name" to chapter.name,
                "chapterNumber" to chapter.chapter_number.toDouble(),
                "dateUpload" to chapter.date_upload.toString(),
                "scanlator" to chapter.scanlator
            )
        }
    }

    suspend fun getChapterPages(
        source: Source,
        chapterUrl: String
    ): List<String> = withContext(Dispatchers.IO) {
        val chapterKey = "${source.id}:$chapterUrl"

        // 1. Check in-memory chapter context cache
        var chapter = synchronized(chapterContextCache) {
            chapterContextCache[chapterKey]
        }

        // 2. Check persistent disk cache if not in memory (e.g. process restart)
        if (chapter == null) {
            val sourceDir = getSourceStorageDir(source.id)
            if (sourceDir != null) {
                val file = File(sourceDir, "${chapterUrlToHash(chapterUrl)}.json")
                if (file.exists() && file.isFile) {
                    try {
                        val loaded = jsonToChapter(file.readText())
                        if (loaded != null) {
                            chapter = loaded
                            synchronized(chapterContextCache) {
                                chapterContextCache[chapterKey] = loaded
                            }
                        }
                    } catch (e: Exception) {
                        System.err.println("Failed to read persisted chapter context: ${e.message}")
                    }
                }
            }
        }

        // 3. Fallback to bare chapter if not found in context
        val finalChapter = chapter ?: SChapter.create().apply {
            url = chapterUrl
            name = ""
        }

        val pages = source.getPageList(finalChapter)
        val httpSource = source as? HttpSource

        pages.map { page ->
            val resolvedUrl = if (page.imageUrl.isNullOrBlank()) {
                if (httpSource != null) {
                    val directUrl = httpSource.getImageUrl(page)
                    if (directUrl.isBlank()) {
                        throw IOException("Resolved image URL is blank for page index ${page.index}")
                    }
                    directUrl
                } else {
                    throw IOException("Source does not support HTTP image URL resolution for page index ${page.index}")
                }
            } else {
                page.imageUrl!!
            }
            if (resolvedUrl.isBlank()) {
                throw IOException("Resolved image URL is blank for page index ${page.index}")
            }
            page.imageUrl = resolvedUrl
            synchronized(pageContextCache) {
                pageContextCache["${source.id}:$resolvedUrl"] = page
            }
            resolvedUrl
        }
    }

    suspend fun fetchImage(
        source: Source,
        url: String
    ): ByteArray = withContext(Dispatchers.IO) {
        val httpSource = source as? HttpSource
            ?: throw IllegalStateException("Source ${source.name} does not support HTTP image fetching")

        val targetPage = synchronized(pageContextCache) {
            pageContextCache["${source.id}:$url"]
        } ?: Page(0, url = url, imageUrl = url)

        val response = httpSource.getImage(targetPage)
        response.use { resp ->
            if (!resp.isSuccessful) {
                throw IOException("Image fetch failed with HTTP code ${resp.code}: ${resp.message}")
            }
            val bytes = resp.body?.bytes()
            if (bytes == null || bytes.isEmpty()) {
                throw IOException("Image fetch returned empty bytes for $url")
            }
            bytes
        }
    }

    fun getHeaders(source: Source): Map<String, String> {
        val httpSource = source as? HttpSource ?: return emptyMap()
        val headers = try {
            httpSource.headers
        } catch (_: Exception) {
            return emptyMap()
        }
        val map = mutableMapOf<String, String>()
        for (i in 0 until headers.size) {
            map[headers.name(i)] = headers.value(i)
        }
        return map
    }
}
