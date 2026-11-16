package com.example.manga_reader_app

import android.webkit.CookieManager
import android.webkit.WebStorage
import androidx.webkit.WebStorageCompat
import androidx.webkit.WebViewFeature
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import java.net.URI
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArraySet
import kotlin.coroutines.resume

object SourceCookieService {

    private val cookieManager: CookieManager by lazy { CookieManager.getInstance() }

    // Maps homeUrl string -> set of normalized visited URL path/host combinations or URLs
    private val visitedUrlsByHome = ConcurrentHashMap<String, CopyOnWriteArraySet<String>>()

    fun hasCookies(homeUrl: String): Boolean {
        if (!SourceAccessPolicy.isSafeWebUrl(homeUrl)) return false
        val rootCookies = cookieManager.getCookie(homeUrl)
        if (!rootCookies.isNullOrBlank()) return true

        val recorded = visitedUrlsByHome[homeUrl] ?: return false
        for (url in recorded) {
            val cookies = cookieManager.getCookie(url)
            if (!cookies.isNullOrBlank()) {
                return true
            }
        }
        return false
    }

    fun recordVisitedUrl(homeUrl: String, visitedUrl: String) {
        if (!SourceAccessPolicy.isSafeWebUrl(homeUrl) || !SourceAccessPolicy.isSafeWebUrl(visitedUrl)) {
            return
        }

        if (!SourceAccessPolicy.isSourceCookieHost(homeUrl, visitedUrl)) {
            return
        }

        // Strip query and fragment
        val strippedUrl = try {
            val uri = URI(visitedUrl)
            URI(uri.scheme, uri.authority, uri.path, null, null).toString()
        } catch (_: Exception) {
            val httpUrl = visitedUrl.toHttpUrlOrNull() ?: return
            httpUrl.newBuilder().query(null).fragment(null).build().toString()
        }

        val set = visitedUrlsByHome.getOrPut(homeUrl) { CopyOnWriteArraySet() }
        set.add(strippedUrl)
    }

    suspend fun clearSourceCookies(homeUrl: String) {
        if (!SourceAccessPolicy.isSafeWebUrl(homeUrl)) {
            throw IllegalArgumentException("Invalid URL")
        }

        if (!WebViewFeature.isFeatureSupported(WebViewFeature.DELETE_BROWSING_DATA)) {
            throw UnsupportedOperationException(
                "Очистка данных сайта не поддерживается текущей версией Android System WebView. Пожалуйста, обновите Android System WebView через Google Play или выполните выход непосредственно на сайте."
            )
        }

        // Must run on Main.immediate because WebStorage / WebStorageCompat requires UI thread Looper
        withContext(Dispatchers.Main.immediate) {
            suspendCancellableCoroutine<Unit> { cont ->
                val webStorage = WebStorage.getInstance()
                WebStorageCompat.deleteBrowsingDataForSite(webStorage, homeUrl, Runnable {
                    if (cont.isActive) {
                        cont.resume(Unit)
                    }
                })
            }
        }

        visitedUrlsByHome.remove(homeUrl)

        // Flush CookieManager on IO dispatcher
        withContext(Dispatchers.IO) {
            cookieManager.flush()
        }
    }
}
