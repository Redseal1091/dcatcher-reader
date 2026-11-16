package com.example.manga_reader_app

import android.app.Application
import eu.kanade.tachiyomi.network.NetworkHelper
import eu.kanade.tachiyomi.network.NetworkPreferences
import okhttp3.logging.HttpLoggingInterceptor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import tachiyomi.core.common.preference.InMemoryPreferenceStore

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class)
class SourceLoggingRedactionTest {

    @Suppress("UNCHECKED_CAST")
    private fun getRedactedHeaders(interceptor: HttpLoggingInterceptor): Set<String> {
        val field = HttpLoggingInterceptor::class.java.getDeclaredField("headersToRedact")
        field.isAccessible = true
        val headers = field.get(interceptor) as? Set<*> ?: emptySet<Any>()
        return headers.mapNotNull { it?.toString()?.lowercase() }.toSet()
    }

    @Test
    fun defaultVerboseLoggingFalse_assertNoHttpLoggingInterceptor() {
        val context = RuntimeEnvironment.getApplication()
        val store = InMemoryPreferenceStore()
        val prefs = NetworkPreferences(store)

        val helper = NetworkHelper(context, prefs)
        val interceptors = helper.client.networkInterceptors.filterIsInstance<HttpLoggingInterceptor>()

        assertTrue(
            "Expected no HttpLoggingInterceptor when verboseLogging is false by default",
            interceptors.isEmpty(),
        )
    }

    @Test
    fun verboseLoggingTrue_redactSensitiveHeadersTrue_redactsCookieAndSetCookie() {
        val context = RuntimeEnvironment.getApplication()
        val store = InMemoryPreferenceStore()
        val prefs = NetworkPreferences(store)
        prefs.verboseLogging.set(true)
        prefs.redactSensitiveHeaders.set(true)

        val helper = NetworkHelper(context, prefs)
        val interceptor = helper.client.networkInterceptors.filterIsInstance<HttpLoggingInterceptor>().single()

        val redactedHeaders = getRedactedHeaders(interceptor)

        assertTrue(
            "Expected 'cookie' to be redacted when redactSensitiveHeaders is true, but got: $redactedHeaders",
            redactedHeaders.contains("cookie"),
        )
        assertTrue(
            "Expected 'set-cookie' to be redacted when redactSensitiveHeaders is true, but got: $redactedHeaders",
            redactedHeaders.contains("set-cookie"),
        )
    }

    @Test
    fun verboseLoggingTrue_redactSensitiveHeadersFalse_redactsCookieAndSetCookie() {
        val context = RuntimeEnvironment.getApplication()
        val store = InMemoryPreferenceStore()
        val prefs = NetworkPreferences(store)
        prefs.verboseLogging.set(true)
        prefs.redactSensitiveHeaders.set(false)

        val helper = NetworkHelper(context, prefs)
        val interceptor = helper.client.networkInterceptors.filterIsInstance<HttpLoggingInterceptor>().single()

        val redactedHeaders = getRedactedHeaders(interceptor)

        assertTrue(
            "Expected 'cookie' to be redacted even when redactSensitiveHeaders is false, but got: $redactedHeaders",
            redactedHeaders.contains("cookie"),
        )
        assertTrue(
            "Expected 'set-cookie' to be redacted even when redactSensitiveHeaders is false, but got: $redactedHeaders",
            redactedHeaders.contains("set-cookie"),
        )
    }
}
