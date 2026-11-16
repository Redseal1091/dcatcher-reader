package com.example.manga_reader_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ExtensionSecurityPolicyTest {

    private val validUrl =
        "https://github.com/keiyoushi/extensions/releases/download/v1.0.0/tachiyomi-en.mangadex-v1.0.0.apk"

    @Test
    fun testValidDownloadUrlAccepted() {
        val result = ExtensionSecurityPolicy.validateDownloadUrl(validUrl)
        assertTrue("Expected valid Keiyoushi release URL to be accepted: ${result.errorMessage}", result.isValid)
    }

    @Test
    fun testInsecureHttpRejected() {
        val httpUrl = "http://github.com/keiyoushi/extensions/releases/download/v1.0.0/test.apk"
        val result = ExtensionSecurityPolicy.validateDownloadUrl(httpUrl)
        assertFalse("HTTP scheme must be rejected", result.isValid)
    }

    @Test
    fun testExplicitPortRejectedEven443() {
        val port443Url = "https://github.com:443/keiyoushi/extensions/releases/download/v1.0.0/test.apk"
        val result443 = ExtensionSecurityPolicy.validateDownloadUrl(port443Url)
        assertFalse("Explicit port 443 must be rejected", result443.isValid)

        val badPortUrl = "https://github.com:8443/keiyoushi/extensions/releases/download/v1.0.0/test.apk"
        val resultBad = ExtensionSecurityPolicy.validateDownloadUrl(badPortUrl)
        assertFalse("Non-443 port must be rejected", resultBad.isValid)
    }

    @Test
    fun testUrlWithQueryRejected() {
        val queryUrl = "$validUrl?key=value"
        assertFalse("URLs with query parameters must be rejected", ExtensionSecurityPolicy.validateDownloadUrl(queryUrl).isValid)

        val emptyQueryMarker = "$validUrl?"
        assertFalse("URLs with empty query marker '?' must be rejected", ExtensionSecurityPolicy.validateDownloadUrl(emptyQueryMarker).isValid)
    }

    @Test
    fun testUrlWithFragmentRejected() {
        val fragmentUrl = "$validUrl#fragment"
        assertFalse("URLs with fragments must be rejected", ExtensionSecurityPolicy.validateDownloadUrl(fragmentUrl).isValid)

        val emptyFragmentMarker = "$validUrl#"
        assertFalse("URLs with empty fragment marker '#' must be rejected", ExtensionSecurityPolicy.validateDownloadUrl(emptyFragmentMarker).isValid)
    }

    @Test
    fun testUrlWithCredentialsRejected() {
        val credsUrl = "https://user:password@github.com/keiyoushi/extensions/releases/download/v1.0.0/test.apk"
        val result = ExtensionSecurityPolicy.validateDownloadUrl(credsUrl)
        assertFalse("URLs with embedded credentials must be rejected", result.isValid)
    }

    @Test
    fun testHostSuffixSpoofingRejected() {
        val spoofUrls = listOf(
            "https://attacker-github.com/keiyoushi/extensions/releases/download/v1.0.0/test.apk",
            "https://github.com.attacker.com/keiyoushi/extensions/releases/download/v1.0.0/test.apk",
            "https://evilgithub.com/keiyoushi/extensions/releases/download/v1.0.0/test.apk",
            "https://api.github.com/keiyoushi/extensions/releases/download/v1.0.0/test.apk"
        )
        for (url in spoofUrls) {
            val result = ExtensionSecurityPolicy.validateDownloadUrl(url)
            assertFalse("Host spoofing must be rejected: $url", result.isValid)
        }
    }

    @Test
    fun testPathTraversalRejected() {
        val traversalUrls = listOf(
            "https://github.com/keiyoushi/extensions/releases/download/v1.0.0/../../malicious.apk",
            "https://github.com/keiyoushi/extensions/releases/download/..%2fmalicious.apk",
            "https://github.com/keiyoushi/extensions/releases/download/%2e%2e/malicious.apk",
            "https://github.com/keiyoushi/extensions/releases/download/v1.0.0/..%5cmalicious.apk",
            "https://github.com/keiyoushi/extensions/releases/download/v1.0.0//double-slash.apk"
        )
        for (url in traversalUrls) {
            val result = ExtensionSecurityPolicy.validateDownloadUrl(url)
            assertFalse("Path traversal must be rejected: $url", result.isValid)
        }
    }

    @Test
    fun testNonApkExtensionRejected() {
        val nonApkUrls = listOf(
            "https://github.com/keiyoushi/extensions/releases/download/v1.0.0/payload.dex",
            "https://github.com/keiyoushi/extensions/releases/download/v1.0.0/payload.jar",
            "https://github.com/keiyoushi/extensions/releases/download/v1.0.0/payload.apk.exe",
            "https://github.com/keiyoushi/extensions/releases/download/v1.0.0/payload"
        )
        for (url in nonApkUrls) {
            val result = ExtensionSecurityPolicy.validateDownloadUrl(url)
            assertFalse("Non-APK asset must be rejected: $url", result.isValid)
        }
    }

    @Test
    fun testUntrustedRepoOwnerOrNameRejected() {
        val badRepoUrls = listOf(
            "https://github.com/attacker/extensions/releases/download/v1.0.0/test.apk",
            "https://github.com/keiyoushi/malicious-repo/releases/download/v1.0.0/test.apk"
        )
        for (url in badRepoUrls) {
            val result = ExtensionSecurityPolicy.validateDownloadUrl(url)
            assertFalse("Untrusted repository owner/repo must be rejected: $url", result.isValid)
        }
    }

    @Test
    fun testRedirectHostValidation() {
        val allowedRedirects = listOf(
            "https://release-assets.githubusercontent.com/some/long/uuid",
            "https://objects.githubusercontent.com/github-production-release-asset-2e65be/some/long/uuid",
            "https://github.com/keiyoushi/extensions/releases/download/v1.0.0/test.apk"
        )
        for (url in allowedRedirects) {
            assertTrue("Expected allowed redirect: $url", ExtensionSecurityPolicy.isAllowedRedirectUrl(url))
        }

        val forbiddenRedirects = listOf(
            "http://release-assets.githubusercontent.com/asset",
            "https://attacker.com/payload.apk",
            "https://evil-release-assets.githubusercontent.com/asset",
            "https://release-assets.githubusercontent.com.evil.com/asset",
            "https://user:pass@release-assets.githubusercontent.com/asset",
            "https://release-assets.githubusercontent.com:8443/asset"
        )
        for (url in forbiddenRedirects) {
            assertFalse("Redirect must be rejected: $url", ExtensionSecurityPolicy.isAllowedRedirectUrl(url))
        }
    }

    @Test
    fun testPackageNameValidation() {
        val validPackages = listOf(
            "eu.kanade.tachiyomi.extension.all.mangadex",
            "eu.kanade.tachiyomi.extension.en.asurascans",
            "eu.kanade.tachiyomi.extension.ru.mangalib"
        )
        for (pkg in validPackages) {
            assertTrue("Valid package should pass: $pkg", ExtensionSecurityPolicy.isValidPackageName(pkg))
        }

        val invalidPackages = listOf(
            "",
            "com.android.settings",
            "org.malicious.app",
            "eu.kanade.tachiyomi.extension",
            "eu.kanade.tachiyomi.extension.",
            "eu.kanade.tachiyomi.extension..test",
            "eu.kanade.tachiyomi.extension.bad/name",
            "eu.kanade.tachiyomi.extension.123abc"
        )
        for (pkg in invalidPackages) {
            assertFalse("Invalid package should fail: $pkg", ExtensionSecurityPolicy.isValidPackageName(pkg))
        }
    }

    @Test
    fun testExplicitTrustConfirmedRequired() {
        assertTrue(ExtensionSecurityPolicy.validateTrustConfirmation(true).isSuccess)

        val unconfirmedResult = ExtensionSecurityPolicy.validateTrustConfirmation(false)
        assertTrue(unconfirmedResult.isFailure)
        assertEquals("TRUST_NOT_CONFIRMED", unconfirmedResult.exceptionOrNull()?.message)
    }

    @Test
    fun testCertificateFingerprintValidation() {
        val trustedFingerprint = "9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2"
        val upperFingerprint = trustedFingerprint.uppercase()
        val untrustedFingerprint = "11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff"

        assertTrue(ExtensionSecurityPolicy.isTrustedSigner(trustedFingerprint))
        assertTrue(ExtensionSecurityPolicy.isTrustedSigner(upperFingerprint))
        assertFalse(ExtensionSecurityPolicy.isTrustedSigner(untrustedFingerprint))
        assertFalse(ExtensionSecurityPolicy.isTrustedSigner(""))
    }

    @Test
    fun testDowngradePrevention() {
        assertTrue(ExtensionSecurityPolicy.isVersionAllowed(newVersionCode = 100, currentVersionCode = null))
        assertTrue(ExtensionSecurityPolicy.isVersionAllowed(newVersionCode = 100, currentVersionCode = 100))
        assertTrue(ExtensionSecurityPolicy.isVersionAllowed(newVersionCode = 101, currentVersionCode = 100))
        assertFalse(ExtensionSecurityPolicy.isVersionAllowed(newVersionCode = 99, currentVersionCode = 100))
    }

    @Test
    fun testClassNamesParsing() {
        val singleRelative = ExtensionSecurityPolicy.resolveClassNames(
            packageName = "eu.kanade.tachiyomi.extension.en.test",
            rawClasses = ".TestExtension"
        )
        assertEquals(listOf("eu.kanade.tachiyomi.extension.en.test.TestExtension"), singleRelative)

        val multipleClasses = ExtensionSecurityPolicy.resolveClassNames(
            packageName = "eu.kanade.tachiyomi.extension.all.mangadex",
            rawClasses = ".MangaDexEn;.MangaDexRu;com.other.Source"
        )
        assertEquals(
            listOf(
                "eu.kanade.tachiyomi.extension.all.mangadex.MangaDexEn",
                "eu.kanade.tachiyomi.extension.all.mangadex.MangaDexRu",
                "com.other.Source"
            ),
            multipleClasses
        )
    }
}
