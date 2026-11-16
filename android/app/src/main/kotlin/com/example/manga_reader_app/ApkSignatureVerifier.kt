package com.example.manga_reader_app

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import java.io.File
import java.security.MessageDigest

object ApkSignatureVerifier {

    fun bytesToHex(bytes: ByteArray): String {
        val sb = StringBuilder(bytes.size * 2)
        for (b in bytes) {
            sb.append(String.format("%02x", b.toInt() and 0xff))
        }
        return sb.toString()
    }

    fun sha256Hex(bytes: ByteArray): String {
        val md = MessageDigest.getInstance("SHA-256")
        return bytesToHex(md.digest(bytes))
    }

    /**
     * Verifies that the APK is signed exclusively by the pinned Keiyoushi signer.
     * Uses Android PackageManager.getPackageArchiveInfo to enforce real Android OS verification
     * and strictly fails closed on missing Context, missing PackageInfo, multiple signers, or signature mismatch.
     */
    fun verifyApkSignature(context: Context, apkFile: File): Result<String> {
        if (!apkFile.exists() || !apkFile.isFile) {
            return Result.failure(SecurityException("APK file does not exist: ${apkFile.absolutePath}"))
        }

        val pm = context.packageManager
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES or PackageManager.GET_META_DATA
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES or PackageManager.GET_META_DATA
        }

        val pkgInfo = pm.getPackageArchiveInfo(apkFile.absolutePath, flags)
            ?: return Result.failure(SecurityException("PackageManager failed to parse archive at ${apkFile.absolutePath}"))

        val currentSigners = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = pkgInfo.signingInfo
                ?: return Result.failure(SecurityException("No signing info found in archive"))
            signingInfo.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            pkgInfo.signatures
        }

        if (currentSigners == null || currentSigners.isEmpty()) {
            return Result.failure(SecurityException("No signature certificates present in archive"))
        }

        // Enforce sole signer: APK must not be co-signed with untrusted certificates
        if (currentSigners.size != 1) {
            return Result.failure(SecurityException("Expected sole signer but found ${currentSigners.size} signers"))
        }

        val soleSignerBytes = currentSigners[0].toByteArray()
        val signerFingerprint = sha256Hex(soleSignerBytes).lowercase()

        if (!ExtensionSecurityPolicy.isTrustedSigner(signerFingerprint)) {
            return Result.failure(
                SecurityException(
                    "Signer certificate fingerprint $signerFingerprint does not match pinned Keiyoushi certificate"
                )
            )
        }

        return Result.success(signerFingerprint)
    }
}
