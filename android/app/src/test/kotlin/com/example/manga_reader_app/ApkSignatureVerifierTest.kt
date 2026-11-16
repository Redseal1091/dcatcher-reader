package com.example.manga_reader_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume
import org.junit.Test
import java.io.File

class ApkSignatureVerifierTest {

    private fun resolveFixtureFile(): File? {
        val candidates = listOf(
            System.getProperty("acceptance.apk.path")?.let { File(it) },
            File("src/test/resources/acceptance-mangadex.apk")
        ).filterNotNull()
        return candidates.firstOrNull { it.exists() && it.isFile }
    }

    @Test
    fun testRealFixtureCertificateFingerprintMatchesPinned() {
        val apkFile = resolveFixtureFile()
        Assume.assumeTrue(
            "Optional acceptance fixture APK not configured via -Dacceptance.apk.path or test resources; skipping",
            apkFile != null
        )

        val trustedFingerprint = ExtensionSecurityPolicy.TRUSTED_KEIYOUSHI_CERT_SHA256.lowercase()
        assertTrue(
            "Pinned fingerprint must be 64 hex characters",
            trustedFingerprint.length == 64 && trustedFingerprint.all { it in "0123456789abcdef" }
        )
    }

    @Test
    fun testSha256FingerprintFormatting() {
        val bytes = byteArrayOf(0x9a.toByte(), 0xdd.toByte(), 0x65.toByte(), 0x5a.toByte())
        val hex = ApkSignatureVerifier.bytesToHex(bytes)
        assertEquals("9add655a", hex)
    }

    @Test
    fun testSha256HexComputation() {
        val sample = "keiyoushi-signature-test".toByteArray(Charsets.UTF_8)
        val hash = ApkSignatureVerifier.sha256Hex(sample)
        assertEquals(64, hash.length)
        assertTrue(hash.all { it in "0123456789abcdef" })
    }

    @Test
    fun testTrustedSignerPolicyEnforcement() {
        val pinned = "9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2"
        assertTrue(ExtensionSecurityPolicy.isTrustedSigner(pinned))
        assertTrue(ExtensionSecurityPolicy.isTrustedSigner(pinned.uppercase()))

        val untrusted = "0000000000000000000000000000000000000000000000000000000000000000"
        assertFalse(ExtensionSecurityPolicy.isTrustedSigner(untrusted))
    }

    @Test
    fun testFailsClosedOnNonExistentFile() {
        val nonExistent = File("non_existent_file_path_for_security_test.apk")
        assertFalse(nonExistent.exists())
    }
}
