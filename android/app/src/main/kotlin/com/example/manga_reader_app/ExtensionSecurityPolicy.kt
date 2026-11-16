package com.example.manga_reader_app

import java.net.URI

data class ValidationResult(
    val isValid: Boolean,
    val errorMessage: String? = null
) {
    companion object {
        fun success() = ValidationResult(isValid = true)
        fun failure(message: String) = ValidationResult(isValid = false, errorMessage = message)
    }
}

object ExtensionSecurityPolicy {

    const val TRUSTED_KEIYOUSHI_CERT_SHA256 =
        "9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2"

    private val ALLOWED_REDIRECT_HOSTS = setOf(
        "release-assets.githubusercontent.com",
        "objects.githubusercontent.com",
        "github.com"
    )

    private val PACKAGE_NAME_REGEX =
        Regex("""^eu\.kanade\.tachiyomi\.extension\.[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$""")

    private val RELEASE_PATH_REGEX =
        Regex("""^/keiyoushi/extensions/releases/download/[^/]+/[^/]+\.apk$""")

    fun validateDownloadUrl(urlString: String): ValidationResult {
        if (urlString.isBlank()) {
            return ValidationResult.failure("URL is empty")
        }

        // Strict rejection: empty or present '?' or '#' markers
        if (urlString.contains("?") || urlString.contains("#")) {
            return ValidationResult.failure("Query or fragment markers ('?' or '#') strictly forbidden")
        }

        val rawLower = urlString.lowercase()
        // Check for path traversal and dangerous encoded patterns
        if (rawLower.contains("..") ||
            rawLower.contains("%2e%2e") ||
            rawLower.contains("\\") ||
            rawLower.contains("%5c") ||
            rawLower.contains("%2f")
        ) {
            return ValidationResult.failure("Path traversal or illegal encoded characters detected")
        }

        // Check for double slashes in path (after scheme)
        val schemeEnd = urlString.indexOf("://")
        if (schemeEnd == -1) {
            return ValidationResult.failure("Missing scheme delimiter")
        }
        val afterScheme = urlString.substring(schemeEnd + 3)
        if (afterScheme.contains("//")) {
            return ValidationResult.failure("URL contains empty path segments")
        }

        val uri = try {
            URI(urlString)
        } catch (e: Exception) {
            return ValidationResult.failure("Malformed URL: ${e.message}")
        }

        if (uri.scheme != "https") {
            return ValidationResult.failure("Insecure scheme: ${uri.scheme}. Strictly HTTPS is required")
        }

        val host = uri.host?.lowercase()
        if (host != "github.com") {
            return ValidationResult.failure("Untrusted host: $host. Strictly github.com is required")
        }

        // Strict no-port: even explicit :443 is forbidden
        if (uri.port != -1) {
            return ValidationResult.failure("Explicit port forbidden: ${uri.port}")
        }

        if (uri.userInfo != null) {
            return ValidationResult.failure("Credentials in URL rejected")
        }

        if (uri.rawQuery != null) {
            return ValidationResult.failure("Query parameters in URL rejected")
        }

        if (uri.rawFragment != null) {
            return ValidationResult.failure("Fragment in URL rejected")
        }

        val path = uri.path ?: ""
        if (!RELEASE_PATH_REGEX.matches(path)) {
            return ValidationResult.failure("Path must match /keiyoushi/extensions/releases/download/<tag>/<file>.apk")
        }

        if (!path.endsWith(".apk", ignoreCase = true)) {
            return ValidationResult.failure("File asset must end with .apk")
        }

        return ValidationResult.success()
    }

    fun isAllowedRedirectUrl(urlString: String): Boolean {
        if (urlString.isBlank()) return false

        val rawLower = urlString.lowercase()
        if (rawLower.contains("..") ||
            rawLower.contains("%2e%2e") ||
            rawLower.contains("\\") ||
            rawLower.contains("%5c")
        ) {
            return false
        }

        val uri = try {
            URI(urlString)
        } catch (e: Exception) {
            return false
        }

        if (uri.scheme != "https") return false
        if (uri.port != -1 && uri.port != 443) return false
        if (uri.userInfo != null) return false

        val host = uri.host?.lowercase() ?: return false
        return ALLOWED_REDIRECT_HOSTS.contains(host)
    }

    fun isValidPackageName(packageName: String): Boolean {
        if (packageName.isBlank()) return false
        return PACKAGE_NAME_REGEX.matches(packageName)
    }

    fun validateTrustConfirmation(trustConfirmed: Boolean): Result<Unit> {
        return if (trustConfirmed) {
            Result.success(Unit)
        } else {
            Result.failure(SecurityException("TRUST_NOT_CONFIRMED"))
        }
    }

    fun isTrustedSigner(fingerprintHex: String): Boolean {
        if (fingerprintHex.isBlank()) return false
        return fingerprintHex.equals(TRUSTED_KEIYOUSHI_CERT_SHA256, ignoreCase = true)
    }

    fun isVersionAllowed(newVersionCode: Long, currentVersionCode: Long?): Boolean {
        if (currentVersionCode == null) return true
        return newVersionCode >= currentVersionCode
    }

    fun resolveClassNames(packageName: String, rawClasses: String?): List<String> {
        if (rawClasses.isNullOrBlank()) return emptyList()
        return rawClasses.split(";")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .map { className ->
                if (className.startsWith(".")) {
                    "$packageName$className"
                } else {
                    className
                }
            }
    }
}
