package com.example.manga_reader_app

import android.app.Application
import okhttp3.OkHttp
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * Unit tests for SourceAccessPolicy.
 * Targets:
 * - isSafeWebUrl(String): Boolean
 * - isSourceCookieHost(sourceHomeUrl: String, candidateUrl: String): Boolean
 * - sourcePreferenceKey(sourceId: Long): String
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class)
class SourceAccessPolicyTest {

    @Before
    fun setUp() {
        OkHttp.initialize(RuntimeEnvironment.getApplication())
    }

    @Test
    fun testIsSafeWebUrl_validHttpsDefaultPort() {
        assertTrue(SourceAccessPolicy.isSafeWebUrl("https://example.com/manga/123"))
        assertTrue(SourceAccessPolicy.isSafeWebUrl("https://sub.domain.org:443/read"))
    }

    @Test
    fun testIsSafeWebUrl_rejectsNonHttpsSchemes() {
        assertFalse(SourceAccessPolicy.isSafeWebUrl("http://example.com/"))
        assertFalse(SourceAccessPolicy.isSafeWebUrl("file:///android_asset/index.html"))
        assertFalse(SourceAccessPolicy.isSafeWebUrl("content://media/external/images"))
        assertFalse(SourceAccessPolicy.isSafeWebUrl("javascript:alert(1)"))
        assertFalse(SourceAccessPolicy.isSafeWebUrl("data:text/html,<h1>test</h1>"))
        assertFalse(SourceAccessPolicy.isSafeWebUrl("intent://scan/#Intent;scheme=zxing;end"))
    }

    @Test
    fun testIsSafeWebUrl_rejectsUserInfoNonDefaultPortAndWhitespace() {
        assertFalse(SourceAccessPolicy.isSafeWebUrl("https://user:password@example.com/"))
        assertFalse(SourceAccessPolicy.isSafeWebUrl("https://example.com:8443/"))
        assertFalse(SourceAccessPolicy.isSafeWebUrl("https://example .com/"))
        assertFalse(SourceAccessPolicy.isSafeWebUrl(" https://example.com/"))
        assertFalse(SourceAccessPolicy.isSafeWebUrl("https://example.com/\n"))
    }

    @Test
    fun testIsSourceCookieHost_allowsSameAndSubdomains() {
        val home = "https://manga.example.com"
        assertTrue(SourceAccessPolicy.isSourceCookieHost(home, "https://manga.example.com/api"))
        assertTrue(SourceAccessPolicy.isSourceCookieHost(home, "https://cdn.manga.example.com/images"))
        assertTrue(SourceAccessPolicy.isSourceCookieHost(home, "https://example.com/login"))
    }

    @Test
    fun testIsSourceCookieHost_rejectsAttackerSuffixes() {
        val home = "https://example.com"
        assertFalse(SourceAccessPolicy.isSourceCookieHost(home, "https://attackerexample.com"))
        assertFalse(SourceAccessPolicy.isSourceCookieHost(home, "https://example.com.evil.org"))
    }

    @Test
    fun testIsSourceCookieHost_blocksCrossGithubIoTenants() {
        val sourceUserSite = "https://tenant1.github.io"
        assertTrue(SourceAccessPolicy.isSourceCookieHost(sourceUserSite, "https://tenant1.github.io/manga"))
        assertFalse(SourceAccessPolicy.isSourceCookieHost(sourceUserSite, "https://tenant2.github.io/manga"))
        assertFalse(SourceAccessPolicy.isSourceCookieHost(sourceUserSite, "https://github.io"))
    }

    @Test
    fun testSourcePreferenceKey_preservesExactLargeId() {
        val largeId = 9007199254740993L
        val key = SourceAccessPolicy.sourcePreferenceKey(largeId)
        assertEquals("source_9007199254740993", key)

        val keyFromStr = SourceAccessPolicy.sourcePreferenceKey("9007199254740993")
        assertEquals("source_9007199254740993", keyFromStr)
    }

    @Test(expected = IllegalArgumentException::class)
    fun testSourcePreferenceKey_rejectsNegativeLong() {
        SourceAccessPolicy.sourcePreferenceKey(-1L)
    }

    @Test(expected = IllegalArgumentException::class)
    fun testSourcePreferenceKey_rejectsZeroLong() {
        SourceAccessPolicy.sourcePreferenceKey(0L)
    }

    @Test(expected = IllegalArgumentException::class)
    fun testSourcePreferenceKey_rejectsBlankString() {
        SourceAccessPolicy.sourcePreferenceKey("   ")
    }

    @Test(expected = IllegalArgumentException::class)
    fun testSourcePreferenceKey_rejectsEmptyString() {
        SourceAccessPolicy.sourcePreferenceKey("")
    }

    @Test(expected = IllegalArgumentException::class)
    fun testSourcePreferenceKey_rejectsLeadingZeros() {
        SourceAccessPolicy.sourcePreferenceKey("0123")
    }

    @Test(expected = IllegalArgumentException::class)
    fun testSourcePreferenceKey_rejectsZeroString() {
        SourceAccessPolicy.sourcePreferenceKey("0")
    }

    @Test(expected = IllegalArgumentException::class)
    fun testSourcePreferenceKey_rejectsNonDecimal() {
        SourceAccessPolicy.sourcePreferenceKey("12a34")
    }

    @Test(expected = IllegalArgumentException::class)
    fun testSourcePreferenceKey_rejectsSlashes() {
        SourceAccessPolicy.sourcePreferenceKey("123/456")
    }
}
