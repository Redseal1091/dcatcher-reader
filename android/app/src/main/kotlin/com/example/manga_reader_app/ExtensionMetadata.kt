package com.example.manga_reader_app

import android.content.Context
import android.content.pm.FeatureInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import java.io.File

data class ExtensionMetadata(
    val packageName: String,
    val versionCode: Long,
    val versionName: String,
    val libVersion: Float,
    val classNames: List<String>,
    val isFactory: Boolean,
    val isNsfw: Boolean
)

object ExtensionMetadataParser {

    const val METADATA_SOURCE_CLASS = "tachiyomi.extension.class"
    const val METADATA_SOURCE_FACTORY = "tachiyomi.extension.factory"
    const val METADATA_LIB_VERSION = "tachiyomix.extensionLib"
    const val METADATA_NSFW = "tachiyomi.extension.nsfw"
    const val EXTENSION_FEATURE = "tachiyomi.extension"

    const val SUPPORTED_API_VERSION_MIN = 1.6f
    const val SUPPORTED_API_VERSION_MAX = 1.7f // exclusive bound for 1.6.x

    fun parse(context: Context, apkFile: File): Result<ExtensionMetadata> {
        if (!apkFile.exists() || !apkFile.isFile) {
            return Result.failure(SecurityException("APK file not found: ${apkFile.absolutePath}"))
        }

        val pm = context.packageManager
        val flags = PackageManager.GET_META_DATA or PackageManager.GET_CONFIGURATIONS
        val pkgInfo = pm.getPackageArchiveInfo(apkFile.absolutePath, flags)
            ?: return Result.failure(SecurityException("PackageManager failed to read package archive info"))

        return parse(pkgInfo, apkFile)
    }

    fun parse(pkgInfo: PackageInfo, apkFile: File): Result<ExtensionMetadata> {
        val appInfo = pkgInfo.applicationInfo
            ?: return Result.failure(SecurityException("Archive does not contain application info"))

        val metaData = appInfo.metaData
            ?: return Result.failure(SecurityException("Archive manifest contains no extension metadata"))

        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            pkgInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            pkgInfo.versionCode.toLong()
        }

        return parse(
            packageName = pkgInfo.packageName,
            versionCode = versionCode,
            versionName = pkgInfo.versionName,
            reqFeatures = pkgInfo.reqFeatures,
            getMetadataString = { key -> metaData.getString(key) },
            getMetadataFloat = { key ->
                if (metaData.containsKey(key)) {
                    val raw = metaData.get(key)
                    when (raw) {
                        is Number -> raw.toFloat()
                        is String -> raw.toFloatOrNull()
                        else -> null
                    }
                } else null
            },
            getMetadataInt = { key, default -> metaData.getInt(key, default) },
            containsMetadataKey = { key -> metaData.containsKey(key) }
        )
    }

    fun parse(
        packageName: String?,
        versionCode: Long,
        versionName: String?,
        reqFeatures: Array<FeatureInfo>?,
        metaData: Map<String, Any?>
    ): Result<ExtensionMetadata> {
        return parse(
            packageName = packageName,
            versionCode = versionCode,
            versionName = versionName,
            reqFeatures = reqFeatures,
            getMetadataString = { metaData[it]?.toString() },
            getMetadataFloat = { key ->
                if (metaData.containsKey(key)) {
                    val raw = metaData[key]
                    when (raw) {
                        is Number -> raw.toFloat()
                        is String -> raw.toFloatOrNull()
                        else -> null
                    }
                } else null
            },
            getMetadataInt = { key, default -> (metaData[key] as? Number)?.toInt() ?: default },
            containsMetadataKey = { metaData.containsKey(it) }
        )
    }

    fun parse(
        packageName: String?,
        versionCode: Long,
        versionName: String?,
        reqFeatures: Array<FeatureInfo>?,
        getMetadataString: (String) -> String?,
        getMetadataFloat: (String) -> Float?,
        getMetadataInt: (String, Int) -> Int,
        containsMetadataKey: (String) -> Boolean
    ): Result<ExtensionMetadata> {
        val pkgName = packageName ?: ""
        if (!ExtensionSecurityPolicy.isValidPackageName(pkgName)) {
            return Result.failure(SecurityException("Invalid extension package name: $pkgName"))
        }

        // Strict declared feature requirement: MUST be present in reqFeatures
        val hasFeature = reqFeatures?.any { it.name == EXTENSION_FEATURE } == true
        if (!hasFeature) {
            return Result.failure(
                SecurityException("Missing declared required feature: $EXTENSION_FEATURE")
            )
        }

        // Strict versionName requirement (no fabricated fallback)
        if (versionName.isNullOrBlank()) {
            return Result.failure(SecurityException("Missing versionName in archive manifest"))
        }

        // Strict tachiyomix.extensionLib requirement enforcing API 1.6
        if (!containsMetadataKey(METADATA_LIB_VERSION)) {
            return Result.failure(
                SecurityException("Missing required manifest metadata key: $METADATA_LIB_VERSION")
            )
        }

        val libVersion = getMetadataFloat(METADATA_LIB_VERSION) ?: 0.0f
        if (libVersion < SUPPORTED_API_VERSION_MIN || libVersion >= SUPPORTED_API_VERSION_MAX) {
            return Result.failure(
                SecurityException("Unsupported extension API lib version: $libVersion. API 1.6 is strictly required")
            )
        }

        val rawClass = getMetadataString(METADATA_SOURCE_CLASS)
        val rawFactory = getMetadataString(METADATA_SOURCE_FACTORY)

        val isFactory = !rawFactory.isNullOrBlank()
        val rawClassNames = if (isFactory) rawFactory else rawClass

        if (rawClassNames.isNullOrBlank()) {
            return Result.failure(SecurityException("Missing source class or factory metadata in manifest"))
        }

        val classNames = ExtensionSecurityPolicy.resolveClassNames(pkgName, rawClassNames)
        if (classNames.isEmpty()) {
            return Result.failure(SecurityException("No valid source classes resolved from manifest metadata"))
        }

        val isNsfw = getMetadataInt(METADATA_NSFW, 0) == 1

        return Result.success(
            ExtensionMetadata(
                packageName = pkgName,
                versionCode = versionCode,
                versionName = versionName,
                libVersion = libVersion,
                classNames = classNames,
                isFactory = isFactory,
                isNsfw = isNsfw
            )
        )
    }
}
