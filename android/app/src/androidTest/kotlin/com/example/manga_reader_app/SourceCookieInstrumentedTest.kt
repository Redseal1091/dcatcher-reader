package com.example.manga_reader_app

import android.webkit.CookieManager
import android.webkit.WebView
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.webkit.WebViewFeature
import eu.kanade.tachiyomi.network.AndroidCookieJar
import kotlinx.coroutines.runBlocking
import okhttp3.Cookie
import okhttp3.HttpUrl.Companion.toHttpUrl
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class SourceCookieInstrumentedTest {

    companion object {
        private const val TEST_SITE = "https://dcatcher-auth-test.invalid"
        private const val TEST_SUBDOMAIN = "https://sub.dcatcher-auth-test.invalid"
        private const val TEST_PATH_URL = "https://dcatcher-auth-test.invalid/account"
        private const val OTHER_SITE = "https://dcatcher-auth-other.invalid"

        private const val ROOT_COOKIE_NAME = "dc_root_token"
        private const val ROOT_COOKIE_VAL = "fixture_root_123"

        private const val SUB_COOKIE_NAME = "dc_sub_token"
        private const val SUB_COOKIE_VAL = "fixture_sub_456"

        private const val PATH_COOKIE_NAME = "dc_path_token"
        private const val PATH_COOKIE_VAL = "fixture_path_789"

        private const val OTHER_COOKIE_NAME = "dc_other_token"
        private const val OTHER_COOKIE_VAL = "fixture_other_abc"

        private const val PERSISTENT_COOKIE_NAME = "dc_persistent_token"
        private const val PERSISTENT_COOKIE_VAL = "fixture_persistent_xyz"

        private const val LATCH_TIMEOUT_SEC = 5L
    }

    private var activeWebView: WebView? = null
    private var preservePersistentFixture: Boolean = false
    private val cookieManager: CookieManager by lazy { CookieManager.getInstance() }
    private val cookieJar: AndroidCookieJar by lazy { AndroidCookieJar() }

    @Before
    fun setUp() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext

        instrumentation.runOnMainSync {
            val webView = WebView(context)
            cookieManager.setAcceptCookie(true)
            cookieManager.setAcceptThirdPartyCookies(webView, true)
            activeWebView = webView
        }
    }

    @After
    fun tearDown() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()

        instrumentation.runOnMainSync {
            try {
                activeWebView?.stopLoading()
                activeWebView?.destroy()
            } catch (_: Exception) {
            } finally {
                activeWebView = null
            }
        }

        cleanupFixtureSites()
    }

    private fun setCookieSync(url: String, cookieValue: String) {
        val latch = CountDownLatch(1)
        var success = false

        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            cookieManager.setCookie(url, cookieValue) { isSuccess ->
                success = isSuccess
                latch.countDown()
            }
        }

        assertTrue("Timed out waiting to set cookie for $url", latch.await(LATCH_TIMEOUT_SEC, TimeUnit.SECONDS))
        assertTrue("CookieManager.setCookie callback reported failure for $url", success)
    }

    private fun flushCookiesSync() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            cookieManager.flush()
        }
    }

    private fun removeCookieSync(url: String, cookieName: String, path: String = "/") {
        val expired = "$cookieName=; Max-Age=0; path=$path; domain=${url.toHttpUrl().host}; Secure; SameSite=Lax"
        setCookieSync(url, expired)
        flushCookiesSync()
    }

    private fun cleanupFixtureSites() {
        try {
            removeCookieSync(TEST_SITE, ROOT_COOKIE_NAME, "/")
            if (!preservePersistentFixture) {
                removeCookieSync(TEST_SITE, PERSISTENT_COOKIE_NAME, "/")
            }
            removeCookieSync(TEST_SUBDOMAIN, SUB_COOKIE_NAME, "/")
            removeCookieSync(TEST_PATH_URL, PATH_COOKIE_NAME, "/account")
            removeCookieSync(OTHER_SITE, OTHER_COOKIE_NAME, "/")
        } catch (_: Exception) {
        }
    }

    private fun cookieNames(cookieHeader: String?): Set<String> {
        if (cookieHeader.isNullOrBlank()) return emptySet()
        return cookieHeader.split(";")
            .map { it.trim().substringBefore("=").trim() }
            .filter { it.isNotEmpty() }
            .toSet()
    }

    @Test
    fun testScopedClearRemovesRootPathSubdomainButPreservesOtherSite() {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.DELETE_BROWSING_DATA)) {
            fail("WebViewFeature.DELETE_BROWSING_DATA is unsupported on this device/WebView provider; cannot perform scoped deleteBrowsingDataForSite")
        }

        setCookieSync(
            TEST_SITE,
            "$ROOT_COOKIE_NAME=$ROOT_COOKIE_VAL; path=/; domain=dcatcher-auth-test.invalid; Secure; SameSite=Lax"
        )
        setCookieSync(
            TEST_SUBDOMAIN,
            "$SUB_COOKIE_NAME=$SUB_COOKIE_VAL; path=/; domain=sub.dcatcher-auth-test.invalid; Secure; SameSite=Lax"
        )
        setCookieSync(
            TEST_PATH_URL,
            "$PATH_COOKIE_NAME=$PATH_COOKIE_VAL; path=/account; domain=dcatcher-auth-test.invalid; Secure; SameSite=Lax"
        )
        setCookieSync(
            OTHER_SITE,
            "$OTHER_COOKIE_NAME=$OTHER_COOKIE_VAL; path=/; domain=dcatcher-auth-other.invalid; Secure; SameSite=Lax"
        )
        flushCookiesSync()

        assertTrue(
            "Root fixture cookie should be present before clear",
            cookieNames(cookieManager.getCookie(TEST_SITE)).contains(ROOT_COOKIE_NAME)
        )
        assertTrue(
            "Subdomain fixture cookie should be present before clear",
            cookieNames(cookieManager.getCookie(TEST_SUBDOMAIN)).contains(SUB_COOKIE_NAME)
        )
        assertTrue(
            "Path fixture cookie should be present before clear",
            cookieNames(cookieManager.getCookie(TEST_PATH_URL)).contains(PATH_COOKIE_NAME)
        )
        assertTrue(
            "Other site fixture cookie should be present before clear",
            cookieNames(cookieManager.getCookie(OTHER_SITE)).contains(OTHER_COOKIE_NAME)
        )

        runBlocking {
            SourceCookieService.clearSourceCookies(TEST_SITE)
        }

        val testSiteCookies = cookieNames(cookieManager.getCookie(TEST_SITE))
        val subSiteCookies = cookieNames(cookieManager.getCookie(TEST_SUBDOMAIN))
        val pathCookies = cookieNames(cookieManager.getCookie(TEST_PATH_URL))
        val otherSiteCookies = cookieNames(cookieManager.getCookie(OTHER_SITE))

        assertFalse(
            "Root cookie for target site must be removed by clearSourceCookies",
            testSiteCookies.contains(ROOT_COOKIE_NAME)
        )
        assertFalse(
            "Subdomain cookie for target site must be removed by clearSourceCookies",
            subSiteCookies.contains(SUB_COOKIE_NAME)
        )
        assertFalse(
            "Path cookie for target site must be removed by clearSourceCookies",
            pathCookies.contains(PATH_COOKIE_NAME)
        )
        assertTrue(
            "Other site cookies must be preserved by clearSourceCookies",
            otherSiteCookies.contains(OTHER_COOKIE_NAME)
        )
    }

    @Test
    fun testNativeCookieJarAndWebViewShareCookies() {
        val rootHttpUrl = TEST_SITE.toHttpUrl()

        // Direction 1: OkHttp AndroidCookieJar.saveFromResponse -> WebView CookieManager
        val nativeCookie = Cookie.Builder()
            .domain("dcatcher-auth-test.invalid")
            .path("/")
            .name(ROOT_COOKIE_NAME)
            .value(ROOT_COOKIE_VAL)
            .secure()
            .build()

        cookieJar.saveFromResponse(rootHttpUrl, listOf(nativeCookie))
        flushCookiesSync()

        val webViewCookies = cookieNames(cookieManager.getCookie(TEST_SITE))
        assertTrue(
            "Cookie saved via AndroidCookieJar.saveFromResponse must be visible in CookieManager",
            webViewCookies.contains(ROOT_COOKIE_NAME)
        )

        // Direction 2: WebView CookieManager.setCookie -> OkHttp AndroidCookieJar.loadForRequest
        setCookieSync(
            OTHER_SITE,
            "$OTHER_COOKIE_NAME=$OTHER_COOKIE_VAL; path=/; domain=dcatcher-auth-other.invalid; Secure; SameSite=Lax"
        )
        flushCookiesSync()

        val otherHttpUrl = OTHER_SITE.toHttpUrl()
        val loadedCookies = cookieJar.loadForRequest(otherHttpUrl)
        val loadedMatch = loadedCookies.firstOrNull { it.name == OTHER_COOKIE_NAME }

        assertNotNull(
            "Cookie set via CookieManager must be loaded by AndroidCookieJar.loadForRequest",
            loadedMatch
        )
        assertEquals(
            "Loaded cookie name must match fixture",
            OTHER_COOKIE_NAME,
            loadedMatch?.name
        )
    }

    @Test
    fun seedPersistentSession() {
        preservePersistentFixture = true
        val oneHourLaterMs = System.currentTimeMillis() + TimeUnit.HOURS.toMillis(1)
        val persistentCookie = Cookie.Builder()
            .domain("dcatcher-auth-test.invalid")
            .path("/")
            .name(PERSISTENT_COOKIE_NAME)
            .value(PERSISTENT_COOKIE_VAL)
            .expiresAt(oneHourLaterMs)
            .secure()
            .build()

        cookieJar.saveFromResponse(TEST_SITE.toHttpUrl(), listOf(persistentCookie))
        flushCookiesSync()
    }

    @Test
    fun verifyPersistentSessionAndCleanup() {
        try {
            val loadedCookies = cookieJar.loadForRequest(TEST_SITE.toHttpUrl())
            val matched = loadedCookies.firstOrNull { it.name == PERSISTENT_COOKIE_NAME }

            assertNotNull(
                "Persistent cookie fixture must survive across process restarts",
                matched
            )
            assertEquals(
                "Persistent cookie name must match fixture",
                PERSISTENT_COOKIE_NAME,
                matched?.name
            )
        } finally {
            removeCookieSync(TEST_SITE, PERSISTENT_COOKIE_NAME, "/")
        }
    }
}
