package com.example.manga_reader_app

import android.content.Context
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.online.HttpSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap

data class InstalledSourceDto(
    val id: String,
    val name: String,
    val language: String,
    val homeUrl: String
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "name" to name,
        "language" to language,
        "homeUrl" to homeUrl
    )
}

data class InstalledPackageDto(
    val packageName: String,
    val versionCode: Long,
    val versionName: String,
    val extensionLib: String = "1.6",
    val sources: List<InstalledSourceDto>
) {
    constructor(
        packageName: String,
        versionCode: Long,
        versionName: String,
        sources: List<InstalledSourceDto>
    ) : this(packageName, versionCode, versionName, "1.6", sources)

    fun toMap(): Map<String, Any?> = mapOf(
        "packageName" to packageName,
        "versionCode" to versionCode.toString(),
        "versionName" to versionName,
        "extensionLib" to extensionLib,
        "sources" to sources.map { it.toMap() }
    )
}

class SourceNotFoundException(val sourceId: String) :
    Exception("Source with ID '$sourceId' is not installed or available")

class ExtensionManager(private val context: Context) {

    private val installedPackages = ConcurrentHashMap<String, InstalledPackageDto>()
    private val activeSources = ConcurrentHashMap<String, Source>()
    private val packageSourceIds = ConcurrentHashMap<String, List<String>>()
    private val reloadFailures = ConcurrentHashMap<String, String>()
    private val lifecycleLock = Mutex()

    internal suspend fun <T> withLifecycleLock(action: suspend () -> T): T {
        return lifecycleLock.withLock { action() }
    }

    val extensionsDir: File
        get() = File(context.filesDir, "extensions").apply { mkdirs() }

    val chapterCacheDir: File
        get() = File(context.filesDir, "chapter_cache").apply { mkdirs() }

    init {
        SourceOperations.setStorageDirectory(chapterCacheDir)
    }

    private val downloader = ExtensionDownloader()

    fun getReloadFailures(): Map<String, String> = HashMap(reloadFailures)

    suspend fun reloadInstalledExtensions(): Map<String, InstalledPackageDto> =
        withLifecycleLock {
            withContext(Dispatchers.IO) {
                reloadInstalledExtensionsInternal()
            }
        }

    private fun reloadInstalledExtensionsInternal(): Map<String, InstalledPackageDto> {
        reloadFailures.clear()
        val dir = extensionsDir

        // Self-healing: recover from interrupted updates or clean up stale backups
        val backupFiles = dir.listFiles { file -> file.isFile && file.name.endsWith(".apk.bak") }
        if (backupFiles != null) {
            for (backup in backupFiles) {
                val originalName = backup.name.removeSuffix(".bak")
                val targetApk = File(dir, originalName)
                if (!targetApk.exists()) {
                    backup.setWritable(true)
                    if (backup.renameTo(targetApk)) {
                        targetApk.setReadOnly()
                    }
                } else {
                    backup.setWritable(true)
                    backup.delete()
                }
            }
        }

        val apkFiles = dir.listFiles { file -> file.isFile && file.name.endsWith(".apk") }
            ?: return emptyMap()

        for (apkFile in apkFiles) {
            try {
                // Check signature via PackageManager
                val sigResult = ApkSignatureVerifier.verifyApkSignature(context, apkFile)
                if (sigResult.isFailure) {
                    val errMsg = "Signature verification failed: ${sigResult.exceptionOrNull()?.message}"
                    reloadFailures[apkFile.name] = errMsg
                    System.err.println("Skipping ${apkFile.name}: $errMsg")
                    continue
                }

                // Parse metadata
                val metaResult = ExtensionMetadataParser.parse(context, apkFile)
                if (metaResult.isFailure) {
                    val errMsg = "Metadata parsing failed: ${metaResult.exceptionOrNull()?.message}"
                    reloadFailures[apkFile.name] = errMsg
                    System.err.println("Skipping ${apkFile.name}: $errMsg")
                    continue
                }
                val metadata = metaResult.getOrThrow()

                // Instantiate sources directly from the immutable permanent path
                val loadResult = ExtensionLoader.loadExtension(context, apkFile, metadata)
                if (loadResult.isFailure) {
                    val errMsg = "Loading sources failed: ${loadResult.exceptionOrNull()?.message}"
                    reloadFailures[metadata.packageName] = errMsg
                    System.err.println("Skipping ${apkFile.name}: $errMsg")
                    continue
                }
                val sources = loadResult.getOrThrow()

                registerExtensionSources(metadata, sources)
            } catch (e: Exception) {
                val errMsg = "Unexpected error reloading ${apkFile.name}: ${e.message}"
                reloadFailures[apkFile.name] = errMsg
                System.err.println(errMsg)
            }
        }
        return listInstalled()
    }

    fun listInstalled(): Map<String, InstalledPackageDto> {
        return HashMap(installedPackages)
    }

    fun listInstalledAsDtoList(): List<Map<String, Any?>> {
        return installedPackages.values.map { it.toMap() }
    }

    fun getSource(sourceId: String): Source {
        return activeSources[sourceId] ?: throw SourceNotFoundException(sourceId)
    }

    suspend fun installExtension(
        apkUrl: String,
        expectedPackageName: String,
        expectedVersionCode: Long,
        trustConfirmed: Boolean,
        onProgress: ((received: Long, total: Long) -> Unit)? = null
    ): Result<Boolean> = withLifecycleLock {
        withContext(Dispatchers.IO) {
            installExtensionInternal(apkUrl, expectedPackageName, expectedVersionCode, trustConfirmed, onProgress)
        }
    }

    private suspend fun installExtensionInternal(
        apkUrl: String,
        expectedPackageName: String,
        expectedVersionCode: Long,
        trustConfirmed: Boolean,
        onProgress: ((received: Long, total: Long) -> Unit)? = null
    ): Result<Boolean> {
        val trustResult = ExtensionSecurityPolicy.validateTrustConfirmation(trustConfirmed)
        if (trustResult.isFailure) {
            return Result.failure(trustResult.exceptionOrNull()!!)
        }

        val urlValidation = ExtensionSecurityPolicy.validateDownloadUrl(apkUrl)
        if (!urlValidation.isValid) {
            return Result.failure(SecurityException("Invalid download URL: ${urlValidation.errorMessage}"))
        }

        if (!ExtensionSecurityPolicy.isValidPackageName(expectedPackageName)) {
            return Result.failure(SecurityException("Invalid package name: $expectedPackageName"))
        }

        val currentInstalled = installedPackages[expectedPackageName]
        if (!ExtensionSecurityPolicy.isVersionAllowed(expectedVersionCode, currentInstalled?.versionCode)) {
            return Result.failure(
                SecurityException(
                    "Downgrade not allowed: new version $expectedVersionCode is lower than installed ${currentInstalled?.versionCode}"
                )
            )
        }

        val tmpFile = File(context.cacheDir, "$expectedPackageName-${System.currentTimeMillis()}.tmp")

        try {
            // 1. Download
            val downloadResult = downloader.download(apkUrl, tmpFile, onProgress)
            if (downloadResult.isFailure) {
                return Result.failure(downloadResult.exceptionOrNull()!!)
            }

            // 2. Validate signatures via PackageManager BEFORE classloading
            val sigResult = ApkSignatureVerifier.verifyApkSignature(context, tmpFile)
            if (sigResult.isFailure) {
                return Result.failure(sigResult.exceptionOrNull()!!)
            }

            // 3. Parse and validate metadata
            val metaResult = ExtensionMetadataParser.parse(context, tmpFile)
            if (metaResult.isFailure) {
                return Result.failure(metaResult.exceptionOrNull()!!)
            }
            val metadata = metaResult.getOrThrow()

            if (metadata.packageName != expectedPackageName) {
                return Result.failure(
                    SecurityException("Archive packageName ${metadata.packageName} does not match expected $expectedPackageName")
                )
            }

            // Exact expectedVersionCode match
            if (metadata.versionCode != expectedVersionCode) {
                return Result.failure(
                    SecurityException(
                        "Archive versionCode ${metadata.versionCode} does not match expected versionCode $expectedVersionCode"
                    )
                )
            }

            if (!ExtensionSecurityPolicy.isVersionAllowed(metadata.versionCode, currentInstalled?.versionCode)) {
                return Result.failure(
                    SecurityException("Archive versionCode ${metadata.versionCode} is lower than installed ${currentInstalled?.versionCode}")
                )
            }

            // 4. Safe atomic placement into permanent path BEFORE creating active ClassLoader
            // This guarantees the active ClassLoader points to the final immutable read-only path that survives
            val targetFile = File(extensionsDir, "$expectedPackageName.apk")
            val backupFile = File(extensionsDir, "$expectedPackageName.apk.bak")
            var backedUp = false

            if (targetFile.exists()) {
                targetFile.setWritable(true)
                if (backupFile.exists()) {
                    backupFile.setWritable(true)
                    backupFile.delete()
                }
                if (!targetFile.renameTo(backupFile)) {
                    if (!copyFile(targetFile, backupFile)) {
                        return Result.failure(IOException("Failed to backup prior APK before upgrade"))
                    }
                    targetFile.delete()
                }
                backedUp = true
            }

            // Move new file into permanent targetFile
            val moved = tmpFile.renameTo(targetFile) || (copyFile(tmpFile, targetFile) && tmpFile.delete())
            if (!moved || !targetFile.exists()) {
                if (backedUp) {
                    if (!restoreFromBackup(backupFile, targetFile)) {
                        return Result.failure(
                            IOException("Failed to install APK and failed to rollback backup to ${targetFile.absolutePath}")
                        )
                    }
                }
                return Result.failure(IOException("Failed to install APK to ${targetFile.absolutePath}"))
            }

            // Android 14+ dynamic-code rule: mark read-only BEFORE loading and fail closed
            if (!targetFile.setReadOnly() || targetFile.canWrite()) {
                if (backedUp) {
                    if (!restoreFromBackup(backupFile, targetFile)) {
                        return Result.failure(
                            IOException(
                                "Failed to mark installed APK as read-only and failed to rollback backup at ${targetFile.absolutePath}"
                            )
                        )
                    }
                } else {
                    targetFile.setWritable(true)
                    targetFile.delete()
                }
                return Result.failure(
                    SecurityException("Failed to mark installed APK as read-only at ${targetFile.absolutePath}")
                )
            }

            // 5. Load ACTIVE instances directly from the permanent immutable targetFile
            val loadResult = ExtensionLoader.loadExtension(context, targetFile, metadata)
            if (loadResult.isFailure) {
                // Rollback! Restore prior file and state
                if (backedUp) {
                    if (!restoreFromBackup(backupFile, targetFile)) {
                        return Result.failure(
                            IOException(
                                "Extension loading failed and rollback from backup failed at ${targetFile.absolutePath}",
                                loadResult.exceptionOrNull()
                            )
                        )
                    }
                } else {
                    targetFile.setWritable(true)
                    targetFile.delete()
                }
                return Result.failure(loadResult.exceptionOrNull()!!)
            }
            val sources = loadResult.getOrThrow()

            // 6. On success: remove backup file and register sources
            if (backupFile.exists()) {
                backupFile.setWritable(true)
                backupFile.delete()
            }

            registerExtensionSources(metadata, sources)
            return Result.success(true)
        } catch (e: Exception) {
            return Result.failure(e)
        } finally {
            if (tmpFile.exists()) {
                tmpFile.setWritable(true)
                tmpFile.delete()
            }
        }
    }

    suspend fun uninstallExtension(packageName: String): Result<Boolean> = withLifecycleLock {
        withContext(Dispatchers.IO) {
            uninstallExtensionInternal(packageName)
        }
    }

    private fun uninstallExtensionInternal(packageName: String): Result<Boolean> {
        if (!ExtensionSecurityPolicy.isValidPackageName(packageName)) {
            return Result.failure(SecurityException("Invalid package name: $packageName"))
        }

        val targetFile = File(extensionsDir, "$packageName.apk")
        val backupFile = File(extensionsDir, "$packageName.apk.bak")

        // Delete/check backup before deleting target to ensure no resurrectable backup remains
        if (backupFile.exists()) {
            backupFile.setWritable(true)
            val backupDeleted = backupFile.delete()
            if (!backupDeleted && backupFile.exists()) {
                return Result.failure(
                    IOException("Failed to delete stale backup file before uninstall for $packageName")
                )
            }
        }

        // First attempt disk deletion. Do NOT remove in-memory registrations if deletion fails!
        if (targetFile.exists()) {
            targetFile.setWritable(true)
            val deleted = targetFile.delete()
            if (!deleted && targetFile.exists()) {
                return Result.failure(
                    IOException("Failed to delete extension file on disk for $packageName")
                )
            }
        }

        // Only after physical deletion succeeded do we unregister sources
        val sourceIds = packageSourceIds.remove(packageName)
        if (sourceIds != null) {
            SourceOperations.invalidateForSources(sourceIds)
            for (id in sourceIds) {
                activeSources.remove(id)
            }
        }
        installedPackages.remove(packageName)

        return Result.success(true)
    }

    private fun registerExtensionSources(
        metadata: ExtensionMetadata,
        sources: List<Source>
    ) {
        val oldIds = packageSourceIds[metadata.packageName]
        if (oldIds != null) {
            SourceOperations.invalidateForSources(oldIds)
            for (oldId in oldIds) {
                activeSources.remove(oldId)
            }
        }

        val dtoList = mutableListOf<InstalledSourceDto>()
        val idsList = mutableListOf<String>()

        for (source in sources) {
            val idStr = source.id.toString()
            val homeUrl = if (source is HttpSource) source.getHomeUrl() else ""
            val dto = InstalledSourceDto(
                id = idStr,
                name = source.name,
                language = source.lang,
                homeUrl = homeUrl
            )
            dtoList.add(dto)
            idsList.add(idStr)
            activeSources[idStr] = source
        }

        packageSourceIds[metadata.packageName] = idsList
        val libStr = if (metadata.libVersion % 1.0f == 0.0f) {
            metadata.libVersion.toInt().toString()
        } else {
            metadata.libVersion.toString()
        }
        installedPackages[metadata.packageName] = InstalledPackageDto(
            packageName = metadata.packageName,
            versionCode = metadata.versionCode,
            versionName = metadata.versionName,
            extensionLib = libStr,
            sources = dtoList
        )
    }

    /**
     * Safely and atomically replaces targetFile with newFile.
     * Preserves the existing valid targetFile in backup until replacement is verified;
     * rolls back to the existing file if replacement fails.
     */
    fun safeAtomicReplace(newFile: File, targetFile: File): Result<Unit> {
        val backupFile = File(targetFile.parentFile, "${targetFile.name}.bak")
        var backedUp = false

        try {
            if (targetFile.exists()) {
                targetFile.setWritable(true)
                if (backupFile.exists()) {
                    backupFile.setWritable(true)
                    backupFile.delete()
                }
                if (!targetFile.renameTo(backupFile)) {
                    if (!copyFile(targetFile, backupFile)) {
                        return Result.failure(IOException("Failed to create backup of existing APK before replacement"))
                    }
                    targetFile.delete()
                }
                backedUp = true
            }

            // Copy/move new file to target
            targetFile.parentFile?.mkdirs()
            val moved = newFile.renameTo(targetFile) || (copyFile(newFile, targetFile) && newFile.delete())

            if (!moved || !targetFile.exists()) {
                // Rollback from backup!
                if (backedUp) {
                    if (!restoreFromBackup(backupFile, targetFile)) {
                        return Result.failure(
                            IOException("Failed to safely install new APK and rollback failed to ${targetFile.absolutePath}")
                        )
                    }
                }
                return Result.failure(IOException("Failed to safely install new APK to ${targetFile.absolutePath}"))
            }

            // Android 14+ dynamic code security rule: fail closed if read-only flag cannot be set
            if (!targetFile.setReadOnly() || targetFile.canWrite()) {
                if (backedUp) {
                    if (!restoreFromBackup(backupFile, targetFile)) {
                        return Result.failure(
                            IOException(
                                "Failed to mark installed APK as read-only and failed to rollback backup at ${targetFile.absolutePath}"
                            )
                        )
                    }
                } else {
                    targetFile.setWritable(true)
                    targetFile.delete()
                }
                return Result.failure(
                    SecurityException("Failed to mark installed APK as read-only at ${targetFile.absolutePath}")
                )
            }

            // Success: remove backup
            if (backupFile.exists()) {
                backupFile.setWritable(true)
                backupFile.delete()
            }

            return Result.success(Unit)
        } catch (e: Exception) {
            if (backedUp) {
                restoreFromBackup(backupFile, targetFile)
            }
            return Result.failure(e)
        }
    }

    private fun restoreFromBackup(backupFile: File, targetFile: File): Boolean {
        return try {
            if (targetFile.exists()) {
                targetFile.setWritable(true)
                targetFile.delete()
            }
            if (!backupFile.exists()) {
                return false
            }
            backupFile.setWritable(true)
            val restored = backupFile.renameTo(targetFile) || (copyFile(backupFile, targetFile) && backupFile.delete())
            if (restored && targetFile.exists()) {
                targetFile.setReadOnly()
                true
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun copyFile(src: File, dst: File): Boolean {
        return try {
            if (dst.exists()) {
                dst.setWritable(true)
                dst.delete()
            }
            FileInputStream(src).use { input ->
                FileOutputStream(dst).use { output ->
                    input.copyTo(output)
                }
            }
            true
        } catch (_: Exception) {
            false
        }
    }
}
