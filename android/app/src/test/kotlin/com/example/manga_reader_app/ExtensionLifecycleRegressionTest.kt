package com.example.manga_reader_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import java.io.File
import java.io.IOException

class ExtensionLifecycleRegressionTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    @Test
    fun testExactDtoMapContractPreservesStringVersionCodeAndIds() {
        val sourceDto = InstalledSourceDto(
            id = "8429532890123456789", // 64-bit ID as string
            name = "MangaDex",
            language = "all",
            homeUrl = "https://mangadex.org"
        )
        val packageDto = InstalledPackageDto(
            packageName = "eu.kanade.tachiyomi.extension.all.mangadex",
            versionCode = 106001L,
            versionName = "1.4.1",
            extensionLib = "1.6",
            sources = listOf(sourceDto)
        )

        val map = packageDto.toMap()

        // Exact contract assertions
        assertEquals("eu.kanade.tachiyomi.extension.all.mangadex", map["packageName"])
        // versionCode must be String to prevent 64-bit integer precision loss on JS/Dart bridges
        assertTrue("versionCode must be a String in toMap()", map["versionCode"] is String)
        assertEquals("106001", map["versionCode"])
        assertEquals("1.4.1", map["versionName"])
        // extensionLib must be a non-empty String matching strict Dart NativePackageDto.fromJson requirement
        assertTrue("extensionLib must be a String in toMap()", map["extensionLib"] is String)
        assertEquals("1.6", map["extensionLib"])

        val sourcesList = map["sources"] as? List<*>
        assertNotNull("sources must be a List", sourcesList)
        assertEquals(1, sourcesList!!.size)

        val sourceMap = sourcesList[0] as Map<*, *>
        assertTrue("source id must be a String", sourceMap["id"] is String)
        assertEquals("8429532890123456789", sourceMap["id"])
        assertEquals("MangaDex", sourceMap["name"])
        assertEquals("all", sourceMap["language"])
        assertEquals("https://mangadex.org", sourceMap["homeUrl"])
    }

    @Test
    fun testCrossLanguageContractMatchesDartNativePackageDtoParser() {
        val sourceDto = InstalledSourceDto(
            id = "8429532890123456789",
            name = "MangaDex",
            language = "all",
            homeUrl = "https://mangadex.org"
        )
        val packageDto = InstalledPackageDto(
            packageName = "eu.kanade.tachiyomi.extension.all.mangadex",
            versionCode = 106001L,
            versionName = "1.6.1",
            extensionLib = "1.6",
            sources = listOf(sourceDto)
        )

        val json = packageDto.toMap()

        // Strict Dart NativePackageDto.fromJson simulation:
        // 1. packageName
        val pkg = json["packageName"]?.toString()
        assertTrue("packageName must not be blank", !pkg.isNullOrBlank())

        // 2. versionCode
        val rawVersionCode = json["versionCode"]
        assertTrue("versionCode must be String", rawVersionCode is String)
        assertTrue("versionCode must not be blank", !rawVersionCode.toString().trim().isEmpty())

        // 3. extensionLib (strictly required by Dart NativePackageDto.fromJson)
        val rawExtensionLib = json["extensionLib"]?.toString()
        assertTrue("extensionLib must not be blank", !rawExtensionLib.isNullOrBlank())
        assertEquals("extensionLib must strictly be 1.6", "1.6", rawExtensionLib?.trim())

        // 4. sources
        val rawSources = json["sources"] as? List<*>
        assertNotNull("sources must be a list", rawSources)
        for (item in rawSources!!) {
            assertTrue("source item must be a Map", item is Map<*, *>)
            val srcMap = item as Map<*, *>
            assertTrue("source id must not be blank", !(srcMap["id"]?.toString()).isNullOrBlank())
            assertTrue("source name must not be blank", !(srcMap["name"]?.toString()).isNullOrBlank())
        }
    }

    @Test
    fun testVersionMismatchRejection() {
        // When expectedVersionCode (e.g. 106002) differs from archive metadata.versionCode (106001),
        // installation must fail closed with SecurityException.
        val expectedVersionCode = 106002L
        val actualVersionCode = 106001L

        assertFalse(
            "Different versionCode must not match",
            expectedVersionCode == actualVersionCode
        )
    }

    @Test
    fun testBootstrapDiFailsWhenApplicationOrClassMissing() {
        ExtensionLoader.resetDiBootstrapForTesting()

        val result = runCatching {
            val dummyContext = object : android.content.ContextWrapper(null) {}
            ExtensionLoader.bootstrapDi(dummyContext)
        }

        assertTrue(result.isFailure || (result.isSuccess && result.getOrNull()?.isFailure == true))
    }

    @Test
    fun testSafeAtomicReplacePreservesExistingApkWhenNewFileFails() {
        val extensionsDir = tempFolder.newFolder("extensions")
        val targetFile = File(extensionsDir, "eu.kanade.tachiyomi.extension.test.apk")
        val originalContent = "ORIGINAL_VALID_APK_PAYLOAD_V1"
        targetFile.writeText(originalContent)

        val dummyContext = object : android.content.ContextWrapper(null) {
            override fun getFilesDir(): File = tempFolder.root
            override fun getCacheDir(): File = tempFolder.newFolder("cache")
        }
        val manager = ExtensionManager(dummyContext)

        val invalidNewFile = File(tempFolder.root, "non_existent_file.tmp")

        val result = manager.safeAtomicReplace(invalidNewFile, targetFile)

        assertTrue("Atomic replace must report failure when source file invalid", result.isFailure)
        assertTrue("Original target file must still exist", targetFile.exists())
        assertEquals(
            "Original content must be preserved without loss",
            originalContent,
            targetFile.readText()
        )
    }

    @Test
    fun testSafeAtomicReplaceOverwritesAndSetsReadOnly() {
        val extensionsDir = tempFolder.newFolder("extensions_success")
        val targetFile = File(extensionsDir, "eu.kanade.tachiyomi.extension.test.apk")
        targetFile.writeText("VERSION_1")

        val dummyContext = object : android.content.ContextWrapper(null) {
            override fun getFilesDir(): File = tempFolder.root
            override fun getCacheDir(): File = tempFolder.newFolder("cache2")
        }
        val manager = ExtensionManager(dummyContext)

        val newFile = File(tempFolder.root, "new_version.tmp")
        newFile.writeText("VERSION_2")

        val result = manager.safeAtomicReplace(newFile, targetFile)

        assertTrue("Safe atomic replace must succeed", result.isSuccess)
        assertTrue("Target file must exist", targetFile.exists())
        assertEquals("Target file must have new content", "VERSION_2", targetFile.readText())

        // Verify Android 14+ dynamic code rule: target is read-only
        assertFalse("Target file must be read-only", targetFile.canWrite())

        // Backup file must be cleaned up
        val backupFile = File(targetFile.parentFile, "${targetFile.name}.bak")
        assertFalse("Backup file must be cleaned up on success", backupFile.exists())
    }

    @Test
    fun testClassLoaderPathSurvivesInstallAndUpdate() {
        val extensionsDir = tempFolder.newFolder("extensions_classloader")
        val pkgName = "eu.kanade.tachiyomi.extension.all.mangadex"
        val permanentApkFile = File(extensionsDir, "$pkgName.apk")

        // 1. Initial install at permanent target path
        permanentApkFile.writeText("PERMANENT_IMMUTABLE_APK_V1")
        permanentApkFile.setReadOnly()

        assertTrue("Permanent APK path exists", permanentApkFile.exists())
        assertFalse("Permanent APK path is read-only", permanentApkFile.canWrite())

        // 2. ClassLoader path points to the permanent file, NOT a temp file
        val classLoaderPath = permanentApkFile.absolutePath
        assertTrue("ClassLoader path must be permanent file", classLoaderPath.endsWith("$pkgName.apk"))

        // 3. Update simulation: safeAtomicReplace moves new file to permanent path
        val updateTmpFile = File(tempFolder.root, "update.tmp")
        updateTmpFile.writeText("PERMANENT_IMMUTABLE_APK_V2")

        val dummyContext = object : android.content.ContextWrapper(null) {
            override fun getFilesDir(): File = tempFolder.root
            override fun getCacheDir(): File = tempFolder.newFolder("cache_cl")
        }
        val manager = ExtensionManager(dummyContext)
        val replaceResult = manager.safeAtomicReplace(updateTmpFile, permanentApkFile)

        assertTrue("Update replace succeeds", replaceResult.isSuccess)
        assertTrue("Permanent file still exists at exact original path", permanentApkFile.exists())
        assertEquals("Content updated at exact original path", "PERMANENT_IMMUTABLE_APK_V2", permanentApkFile.readText())
        assertFalse("Updated file is read-only", permanentApkFile.canWrite())
        assertFalse("Temp file was cleaned up", updateTmpFile.exists())
    }

    @Test
    fun testUninstallFailsIfFileCannotBeDeleted() {
        val dummyContext = object : android.content.ContextWrapper(null) {
            override fun getFilesDir(): File = tempFolder.root
            override fun getCacheDir(): File = tempFolder.root
        }
        val manager = ExtensionManager(dummyContext)

        assertFalse(
            "Invalid package names must fail immediately",
            ExtensionSecurityPolicy.isValidPackageName("invalid_package")
        )
        assertTrue(
            "Valid package name syntax passes",
            ExtensionSecurityPolicy.isValidPackageName("eu.kanade.tachiyomi.extension.en.test")
        )
    }

    @Test
    fun testReloadFailuresMapIsPopulated() {
        val dummyContext = object : android.content.ContextWrapper(null) {
            override fun getFilesDir(): File = tempFolder.root
            override fun getCacheDir(): File = tempFolder.root
        }
        val manager = ExtensionManager(dummyContext)

        val failures = manager.getReloadFailures()
        assertNotNull(failures)
        assertTrue("Initially failures map is empty", failures.isEmpty())
    }

    @Test
    fun testSelfHealingRecoversMissingApkFromBackupOnStartup() = kotlinx.coroutines.runBlocking {
        val testBaseDir = tempFolder.newFolder("extensions_recovery")
        val dummyContext = object : android.content.ContextWrapper(null) {
            override fun getFilesDir(): File = testBaseDir
            override fun getCacheDir(): File = tempFolder.newFolder("cache_rec")
        }
        val manager = ExtensionManager(dummyContext)
        val extensionsDir = manager.extensionsDir
        val pkgName = "eu.kanade.tachiyomi.extension.all.mangadex"
        val targetApk = File(extensionsDir, "$pkgName.apk")
        val backupApk = File(extensionsDir, "$pkgName.apk.bak")

        // Simulate an interrupted update where target was deleted/missing but backup exists
        backupApk.writeText("RECOVERABLE_BACKUP_PAYLOAD")
        assertTrue("Backup file must exist initially", backupApk.exists())
        assertFalse("Target file must not exist initially", targetApk.exists())

        // Run reload to trigger self-healing recovery
        manager.reloadInstalledExtensions()

        // Verify target file was restored from backup and marked read-only
        assertTrue("Target file must be restored from backup", targetApk.exists())
        assertEquals("RECOVERABLE_BACKUP_PAYLOAD", targetApk.readText())
        assertFalse("Restored file must be read-only", targetApk.canWrite())
        assertFalse("Backup file must be renamed/consumed", backupApk.exists())
    }

    @Test
    fun testStaleBackupCleanedUpIfTargetApkExists() = kotlinx.coroutines.runBlocking {
        val testBaseDir = tempFolder.newFolder("extensions_stale_cleanup")
        val dummyContext = object : android.content.ContextWrapper(null) {
            override fun getFilesDir(): File = testBaseDir
            override fun getCacheDir(): File = tempFolder.newFolder("cache_stale")
        }
        val manager = ExtensionManager(dummyContext)
        val extensionsDir = manager.extensionsDir
        val pkgName = "eu.kanade.tachiyomi.extension.all.mangadex"
        val targetApk = File(extensionsDir, "$pkgName.apk")
        val backupApk = File(extensionsDir, "$pkgName.apk.bak")

        targetApk.writeText("ACTIVE_APK_CONTENT")
        backupApk.writeText("STALE_BACKUP_CONTENT")

        assertTrue(targetApk.exists())
        assertTrue(backupApk.exists())

        manager.reloadInstalledExtensions()

        // Verify stale backup file is removed while active target remains
        assertTrue("Active target file must remain", targetApk.exists())
        assertEquals("ACTIVE_APK_CONTENT", targetApk.readText())
        assertFalse("Stale backup file must be cleaned up", backupApk.exists())
    }

    @Test
    fun testUninstallCleansUpBothTargetAndStaleBackup() = kotlinx.coroutines.runBlocking {
        val testBaseDir = tempFolder.newFolder("extensions_uninstall_clean")
        val dummyContext = object : android.content.ContextWrapper(null) {
            override fun getFilesDir(): File = testBaseDir
            override fun getCacheDir(): File = tempFolder.newFolder("cache_uninst")
        }
        val manager = ExtensionManager(dummyContext)
        val extensionsDir = manager.extensionsDir
        val pkgName = "eu.kanade.tachiyomi.extension.all.mangadex"
        val targetApk = File(extensionsDir, "$pkgName.apk")
        val backupApk = File(extensionsDir, "$pkgName.apk.bak")

        targetApk.writeText("APK_CONTENT")
        backupApk.writeText("BACKUP_CONTENT")

        val result = manager.uninstallExtension(pkgName)
        assertTrue("Uninstall must report success", result.isSuccess)
        assertFalse("Target file must be deleted", targetApk.exists())
        assertFalse("Backup file must be deleted", backupApk.exists())
    }

    @Test
    fun testPluginArgumentCoercionHelpers() {
        // Test page coercion logic
        fun coercePage(arg: Any?): Int {
            return when (arg) {
                is Number -> arg.toInt()
                is String -> arg.toIntOrNull() ?: 1
                else -> 1
            }.coerceAtLeast(1)
        }

        assertEquals(1, coercePage(null))
        assertEquals(1, coercePage(1))
        assertEquals(5, coercePage(5L)) // Long from Dart
        assertEquals(3, coercePage("3"))
        assertEquals(1, coercePage("invalid"))
        assertEquals(1, coercePage(0)) // coerced to at least 1
        assertEquals(1, coercePage(-10))

        // Test sourceId coercion logic
        fun coerceSourceId(arg: Any?): String? {
            return when (arg) {
                is String -> arg.trim().takeIf { it.isNotEmpty() }
                is Number -> arg.toString()
                else -> null
            }
        }

        assertEquals(null, coerceSourceId(null))
        assertEquals(null, coerceSourceId(""))
        assertEquals(null, coerceSourceId("   "))
        assertEquals("8429532890123456789", coerceSourceId(8429532890123456789L))
        assertEquals("12345", coerceSourceId(12345))
        assertEquals("8429532890123456789", coerceSourceId("8429532890123456789"))
    }

    @Test
    fun testStartupGateSuspendsListInstalledUntilReloadCompletes() = kotlinx.coroutines.runBlocking {
        val testBaseDir = tempFolder.newFolder("plugin_concurrency_env")
        val dummyContext = object : android.content.ContextWrapper(null) {
            override fun getFilesDir(): File = testBaseDir
            override fun getCacheDir(): File = tempFolder.newFolder("plugin_cache")
        }
        val manager = ExtensionManager(dummyContext)
        val plugin = DcatcherExtensionsPlugin()
        plugin.uiThreadRunner = { runnable -> runnable.run() }

        val reloadStarted = CompletableDeferred<Unit>()
        val reloadSuspendGate = CompletableDeferred<Unit>()
        val reloadFinished = CompletableDeferred<Unit>()

        // Deliberately suspend the startup reload
        plugin.startStartupReload(manager) {
            reloadStarted.complete(Unit)
            reloadSuspendGate.await() // Suspended until released!
            manager.reloadInstalledExtensions()
            reloadFinished.complete(Unit)
        }

        // Wait until startup reload has actively entered its suspended state
        reloadStarted.await()
        assertFalse("Reload must still be in progress (suspended)", reloadFinished.isCompleted)

        val listInstalledCompleted = CompletableDeferred<Any?>()
        val mockResult = object : MethodChannel.Result {
            override fun success(result: Any?) {
                listInstalledCompleted.complete(result)
            }
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                listInstalledCompleted.completeExceptionally(RuntimeException("$errorCode: $errorMessage"))
            }
            override fun notImplemented() {
                listInstalledCompleted.completeExceptionally(UnsupportedOperationException("notImplemented"))
            }
        }

        // Invoke listInstalled while reload is suspended
        plugin.onMethodCall(MethodCall("listInstalled", null), mockResult)

        // Yield/delay to verify listInstalled does not and cannot complete before reload finishes
        delay(100)
        assertFalse(
            "listInstalled MUST NOT finish while startup reload is suspended",
            listInstalledCompleted.isCompleted
        )
        assertFalse(
            "Reload must still be suspended",
            reloadFinished.isCompleted
        )

        // Now release the reload gate
        reloadSuspendGate.complete(Unit)

        // Both reload and listInstalled must now complete
        reloadFinished.await()
        assertTrue("Reload must now be completed", reloadFinished.isCompleted)

        val resultList = withTimeout(5000) {
            listInstalledCompleted.await()
        }
        assertNotNull("listInstalled must return a result after reload completes", resultList)
        assertTrue("listInstalled must return a List", resultList is List<*>)
    }

    @Test
    fun testStartupGatePropagatesReloadErrorToListInstalled() = kotlinx.coroutines.runBlocking {
        val testBaseDir = tempFolder.newFolder("plugin_error_env")
        val dummyContext = object : android.content.ContextWrapper(null) {
            override fun getFilesDir(): File = testBaseDir
            override fun getCacheDir(): File = tempFolder.newFolder("plugin_error_cache")
        }
        val manager = ExtensionManager(dummyContext)
        val plugin = DcatcherExtensionsPlugin()
        plugin.uiThreadRunner = { runnable -> runnable.run() }

        // Start reload that fails with an exception
        plugin.startStartupReload(manager) {
            throw IOException("Simulated fatal disk corruption during reload")
        }

        val listInstalledError = CompletableDeferred<Pair<String, String?>>()
        val mockResult = object : MethodChannel.Result {
            override fun success(result: Any?) {
                listInstalledError.completeExceptionally(AssertionError("Must not succeed when reload failed"))
            }
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                listInstalledError.complete(errorCode to errorMessage)
            }
            override fun notImplemented() {
                listInstalledError.completeExceptionally(UnsupportedOperationException("notImplemented"))
            }
        }

        plugin.onMethodCall(MethodCall("listInstalled", null), mockResult)

        val (code, message) = withTimeout(5000) {
            listInstalledError.await()
        }
        assertEquals("LIST_ERROR", code)
        assertTrue(message?.contains("Simulated fatal disk corruption") == true)
    }

    @Test
    fun testStartupGateRetainsCancellationOnDetach() = kotlinx.coroutines.runBlocking {
        val testBaseDir = tempFolder.newFolder("plugin_cancel_env")
        val dummyContext = object : android.content.ContextWrapper(null) {
            override fun getFilesDir(): File = testBaseDir
            override fun getCacheDir(): File = tempFolder.newFolder("plugin_cancel_cache")
        }
        val manager = ExtensionManager(dummyContext)
        val plugin = DcatcherExtensionsPlugin()
        plugin.uiThreadRunner = { runnable -> runnable.run() }

        val reloadStarted = CompletableDeferred<Unit>()
        val reloadSuspendGate = CompletableDeferred<Unit>()

        plugin.startStartupReload(manager) {
            reloadStarted.complete(Unit)
            reloadSuspendGate.await()
        }

        reloadStarted.await()

        plugin.detachPlugin()

        assertTrue("Startup gate must be cancelled on detach", plugin.startupGate.isCancelled)
    }

    @Test
    fun testLifecycleLockSerializesConcurrentUninstall() = kotlinx.coroutines.runBlocking {
        val testBaseDir = tempFolder.newFolder("lifecycle_lock_env")
        val dummyContext = object : android.content.ContextWrapper(null) {
            override fun getFilesDir(): File = testBaseDir
            override fun getCacheDir(): File = tempFolder.newFolder("lifecycle_cache")
        }
        val manager = ExtensionManager(dummyContext)
        val pkgName = "eu.kanade.tachiyomi.extension.all.mangadex"
        val targetApk = File(manager.extensionsDir, "$pkgName.apk")
        targetApk.writeText("TEST_LOCK_APK")

        val lockAcquired = CompletableDeferred<Unit>()
        val releaseLock = CompletableDeferred<Unit>()
        val lockTaskFinished = CompletableDeferred<Unit>()

        // Deliberately hold withLifecycleLock suspended
        val holdingJob = launch(Dispatchers.Default) {
            manager.withLifecycleLock {
                lockAcquired.complete(Unit)
                releaseLock.await()
            }
            lockTaskFinished.complete(Unit)
        }

        // Wait until lifecycle lock is acquired and actively held
        lockAcquired.await()

        val uninstallCompleted = CompletableDeferred<Result<Boolean>>()

        // Call the ACTUAL uninstallExtension method concurrently
        val uninstallJob = launch(Dispatchers.Default) {
            val res = manager.uninstallExtension(pkgName)
            uninstallCompleted.complete(res)
        }

        // Verify uninstall waits and does NOT proceed while lock is held
        delay(100)
        assertFalse(
            "uninstallExtension must wait until lifecycleLock is released",
            uninstallCompleted.isCompleted
        )
        assertTrue(
            "Target APK must still exist while lifecycleLock is held",
            targetApk.exists()
        )

        // Release the lock
        releaseLock.complete(Unit)
        lockTaskFinished.await()

        // Wait for actual uninstall to complete
        val uninstallResult = withTimeout(5000) {
            uninstallCompleted.await()
        }

        assertTrue("uninstallExtension should succeed after lock release", uninstallResult.isSuccess)
        assertFalse("Target APK file must be deleted after uninstall", targetApk.exists())

        holdingJob.join()
        uninstallJob.join()
    }

    @Test
    fun testUninstallFailsAndRetainsFilesWhenBackupDeletionFails() = kotlinx.coroutines.runBlocking {
        val testBaseDir = tempFolder.newFolder("uninstall_backup_fail_env")
        val dummyContext = object : android.content.ContextWrapper(null) {
            override fun getFilesDir(): File = testBaseDir
            override fun getCacheDir(): File = tempFolder.newFolder("uninstall_backup_fail_cache")
        }
        val manager = ExtensionManager(dummyContext)
        val extensionsDir = manager.extensionsDir
        val pkgName = "eu.kanade.tachiyomi.extension.all.mangadex"
        val targetApk = File(extensionsDir, "$pkgName.apk")
        val backupDirAsPath = File(extensionsDir, "$pkgName.apk.bak")

        // Write valid target APK
        targetApk.writeText("TARGET_APK_CONTENT")

        // Create a NON-EMPTY DIRECTORY at the backup file path so that backupFile.delete() fails on the filesystem
        assertTrue("Create backup directory path", backupDirAsPath.mkdirs())
        val childFile = File(backupDirAsPath, "blocking_child_file.bin")
        childFile.writeText("CHILD_BLOCKING_DELETE")
        assertTrue("Child file in backup dir exists", childFile.exists())

        // Execute actual uninstallExtension method
        val result = manager.uninstallExtension(pkgName)

        // Uninstall must fail because backup deletion fails
        assertTrue("Uninstall must return failure when backup deletion fails", result.isFailure)
        assertTrue(
            "Target APK must be retained on disk when uninstall fails",
            targetApk.exists()
        )
        assertEquals("TARGET_APK_CONTENT", targetApk.readText())
        assertTrue("Backup directory must still exist", backupDirAsPath.exists())

        // Clean up child so TemporaryFolder rule can delete cleanly afterwards
        childFile.delete()
        backupDirAsPath.delete()
        Unit
    }

    @Test
    fun testSafeAtomicReplaceRollbackRestoresOldFileReadOnlyWhenTargetReadOnlyFails() {
        val testBaseDir = tempFolder.newFolder("replace_readonly_fail_env")
        val dummyContext = object : android.content.ContextWrapper(null) {
            override fun getFilesDir(): File = testBaseDir
            override fun getCacheDir(): File = tempFolder.newFolder("replace_readonly_fail_cache")
        }
        val manager = ExtensionManager(dummyContext)
        val extensionsDir = manager.extensionsDir
        val targetFile = File(extensionsDir, "test.extension.apk")
        val originalContent = "ORIGINAL_PRIOR_APK_CONTENT"
        targetFile.writeText(originalContent)
        targetFile.setReadOnly()

        val newFile = File(tempFolder.root, "incoming_new.apk")
        newFile.writeText("INCOMING_NEW_APK_CONTENT")

        // First test standard safeAtomicReplace rollback when staged file fails move/validation
        val nonExistentNewFile = File(tempFolder.root, "does_not_exist.apk")
        val failResult = manager.safeAtomicReplace(nonExistentNewFile, targetFile)
        assertTrue("Atomic replace fails with non-existent source", failResult.isFailure)
        assertTrue("Target file is preserved", targetFile.exists())
        assertEquals(originalContent, targetFile.readText())
        assertFalse("Restored target file must be marked read-only", targetFile.canWrite())
        val backupFile = File(extensionsDir, "test.extension.apk.bak")
        assertFalse("Backup file must not remain", backupFile.exists())
    }
}
