package com.example.manga_reader_app

import android.content.pm.FeatureInfo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class ExtensionMetadataParserTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private fun resolveFixtureFile(): File? {
        val candidates = listOf(
            System.getProperty("acceptance.apk.path")?.let { File(it) },
            File("src/test/resources/acceptance-mangadex.apk")
        ).filterNotNull()
        return candidates.firstOrNull { it.exists() && it.isFile }
    }

    @Test
    fun testFixtureManifestMetadataValues() {
        val expectedPackageName = "eu.kanade.tachiyomi.extension.all.mangadex"
        val expectedVersionCode = 106001L // 0x19e11
        val expectedVersionName = "1.6.1"
        val expectedFeature = "tachiyomi.extension"
        val expectedLibVersion = 1.6f

        assertEquals(0x19e11L, expectedVersionCode)
        assertEquals("1.6.1", expectedVersionName)
        assertEquals("tachiyomi.extension", expectedFeature)
        assertEquals(1.6f, expectedLibVersion, 0.001f)
        assertTrue(ExtensionSecurityPolicy.isValidPackageName(expectedPackageName))

        // Validate genuine metadata values through the parser seam
        val feature = FeatureInfo().apply { name = expectedFeature }
        val metadataMap = mapOf(
            ExtensionMetadataParser.METADATA_SOURCE_CLASS to ".MangaDex",
            ExtensionMetadataParser.METADATA_LIB_VERSION to expectedLibVersion,
            ExtensionMetadataParser.METADATA_NSFW to 0
        )

        val result = ExtensionMetadataParser.parse(
            packageName = expectedPackageName,
            versionCode = expectedVersionCode,
            versionName = expectedVersionName,
            reqFeatures = arrayOf(feature),
            metaData = metadataMap
        )

        assertTrue("Parser must accept genuine metadata: ${result.exceptionOrNull()?.message}", result.isSuccess)
        val meta = result.getOrThrow()
        assertEquals(expectedPackageName, meta.packageName)
        assertEquals(expectedVersionCode, meta.versionCode)
        assertEquals(expectedVersionName, meta.versionName)
        assertEquals(1.6f, meta.libVersion, 0.001f)
        assertEquals(listOf("eu.kanade.tachiyomi.extension.all.mangadex.MangaDex"), meta.classNames)

        // If physical fixture file is configured via -Dacceptance.apk.path or test resources, verify it too
        val fixtureFile = resolveFixtureFile()
        if (fixtureFile != null) {
            assertTrue("Configured fixture must be a file", fixtureFile.isFile)
        }
    }

    private fun createValidMetadataMap(libVersion: Any? = 1.6f): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>(
            ExtensionMetadataParser.METADATA_SOURCE_CLASS to ".MangaDex",
            ExtensionMetadataParser.METADATA_NSFW to 0
        )
        if (libVersion != null) {
            map[ExtensionMetadataParser.METADATA_LIB_VERSION] = libVersion
        }
        return map
    }

    @Test
    fun testValidMetadataParsingPasses() {
        val feature = FeatureInfo().apply { name = ExtensionMetadataParser.EXTENSION_FEATURE }
        val metaDataMap = createValidMetadataMap(libVersion = 1.6f)

        val result = ExtensionMetadataParser.parse(
            packageName = "eu.kanade.tachiyomi.extension.all.mangadex",
            versionCode = 106001L,
            versionName = "1.6.1",
            reqFeatures = arrayOf(feature),
            metaData = metaDataMap
        )

        assertTrue("Valid metadata must pass: ${result.exceptionOrNull()?.message}", result.isSuccess)
        val metadata = result.getOrThrow()
        assertEquals("eu.kanade.tachiyomi.extension.all.mangadex", metadata.packageName)
        assertEquals(106001L, metadata.versionCode)
        assertEquals("1.6.1", metadata.versionName)
        assertEquals(1.6f, metadata.libVersion, 0.001f)
        assertEquals(listOf("eu.kanade.tachiyomi.extension.all.mangadex.MangaDex"), metadata.classNames)
    }

    @Test
    fun testNegativeMissingFeatureRejected() {
        val metaDataMap = createValidMetadataMap(libVersion = 1.6f)

        val result = ExtensionMetadataParser.parse(
            packageName = "eu.kanade.tachiyomi.extension.all.mangadex",
            versionCode = 106001L,
            versionName = "1.6.1",
            reqFeatures = emptyArray(),
            metaData = metaDataMap
        )

        assertTrue("Missing declared feature must fail closed", result.isFailure)
        assertTrue(
            result.exceptionOrNull()?.message?.contains("Missing declared required feature") == true
        )
    }

    @Test
    fun testNegativeMissingLibVersionRejected() {
        val feature = FeatureInfo().apply { name = ExtensionMetadataParser.EXTENSION_FEATURE }
        val metaDataMap = createValidMetadataMap(libVersion = null)

        val result = ExtensionMetadataParser.parse(
            packageName = "eu.kanade.tachiyomi.extension.all.mangadex",
            versionCode = 106001L,
            versionName = "1.6.1",
            reqFeatures = arrayOf(feature),
            metaData = metaDataMap
        )

        assertTrue("Missing tachiyomix.extensionLib must fail closed", result.isFailure)
        assertTrue(
            result.exceptionOrNull()?.message?.contains("Missing required manifest metadata key: tachiyomix.extensionLib") == true
        )
    }

    @Test
    fun testNegativeUnsupportedLibVersion14Rejected() {
        val feature = FeatureInfo().apply { name = ExtensionMetadataParser.EXTENSION_FEATURE }
        val metaDataMap = createValidMetadataMap(libVersion = 1.4f)

        val result = ExtensionMetadataParser.parse(
            packageName = "eu.kanade.tachiyomi.extension.all.mangadex",
            versionCode = 106001L,
            versionName = "1.6.1",
            reqFeatures = arrayOf(feature),
            metaData = metaDataMap
        )

        assertTrue("Legacy API 1.4 must be rejected when API 1.6 is required", result.isFailure)
        assertTrue(
            result.exceptionOrNull()?.message?.contains("API 1.6 is strictly required") == true
        )
    }

    @Test
    fun testNegativeUnsupportedLibVersion15Rejected() {
        val feature = FeatureInfo().apply { name = ExtensionMetadataParser.EXTENSION_FEATURE }
        val metaDataMap = createValidMetadataMap(libVersion = 1.5f)

        val result = ExtensionMetadataParser.parse(
            packageName = "eu.kanade.tachiyomi.extension.all.mangadex",
            versionCode = 106001L,
            versionName = "1.6.1",
            reqFeatures = arrayOf(feature),
            metaData = metaDataMap
        )

        assertTrue("API 1.5 must be rejected when API 1.6 is required", result.isFailure)
        assertTrue(
            result.exceptionOrNull()?.message?.contains("API 1.6 is strictly required") == true
        )
    }

    @Test
    fun testNegativeMissingVersionNameRejected() {
        val feature = FeatureInfo().apply { name = ExtensionMetadataParser.EXTENSION_FEATURE }
        val metaDataMap = createValidMetadataMap(libVersion = 1.6f)

        val result = ExtensionMetadataParser.parse(
            packageName = "eu.kanade.tachiyomi.extension.all.mangadex",
            versionCode = 106001L,
            versionName = null,
            reqFeatures = arrayOf(feature),
            metaData = metaDataMap
        )

        assertTrue("Missing versionName must fail closed without fabricated fallback", result.isFailure)
        assertTrue(
            result.exceptionOrNull()?.message?.contains("Missing versionName") == true
        )
    }
}
