package com.example.manga_reader_app

import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import java.net.URI

object SourceAccessPolicy {

    fun isSafeWebUrl(url: String?): Boolean {
        if (url == null || url.isEmpty()) return false

        // Reject whitespace anywhere (leading, trailing, or internal)
        if (url.any { it.isWhitespace() }) return false

        // Parse with java.net.URI for strict raw validation
        val uri = try {
            URI(url)
        } catch (_: Exception) {
            return false
        }

        if (!uri.isAbsolute) return false
        val scheme = uri.scheme ?: return false
        if (!scheme.equals("https", ignoreCase = true)) return false

        // Reject userinfo
        if (uri.rawUserInfo != null) return false

        // Check host presence
        val uriHost = uri.host ?: return false
        if (uriHost.isEmpty()) return false

        // Check port: must be -1 or 443
        val port = uri.port
        if (port != -1 && port != 443) return false

        // Parse with OkHttp HttpUrl
        val httpUrl = url.toHttpUrlOrNull() ?: return false
        if (httpUrl.scheme != "https") return false
        if (httpUrl.username.isNotEmpty() || httpUrl.password.isNotEmpty()) return false
        if (httpUrl.port != 443) return false

        return true
    }

    fun isSourceCookieHost(sourceHomeUrl: String?, candidateUrl: String?): Boolean {
        if (!isSafeWebUrl(sourceHomeUrl) || !isSafeWebUrl(candidateUrl)) return false

        val homeHttpUrl = sourceHomeUrl!!.toHttpUrlOrNull() ?: return false
        val candHttpUrl = candidateUrl!!.toHttpUrlOrNull() ?: return false

        val homeHost = homeHttpUrl.host.lowercase()
        val candHost = candHttpUrl.host.lowercase()

        // Exact match
        if (homeHost == candHost) return true

        // Check topPrivateDomain safely to prevent cross-tenant cookie sharing on public suffixes (e.g. github.io)
        val homeDomain = homeHttpUrl.topPrivateDomain()
        val candDomain = candHttpUrl.topPrivateDomain()

        if (homeDomain != null && candDomain != null && homeDomain == candDomain) {
            // Both share the same registrable domain (e.g. manga.example.com and example.com,
            // or sub.tenant1.github.io and tenant1.github.io)
            if (candHost == homeDomain || candHost.endsWith(".$homeDomain")) {
                return true
            }
        }

        return false
    }

    fun sourcePreferenceKey(sourceId: Long): String {
        require(sourceId > 0) { "Source ID must be a positive Long" }
        return "source_$sourceId"
    }

    fun sourcePreferenceKey(sourceIdStr: String): String {
        require(sourceIdStr.isNotEmpty() && sourceIdStr.all { it.isDigit() }) {
            "Source ID must be a non-empty decimal digit string"
        }
        // Reject leading zeros (prevent silent ID repair / normalization like "0123" -> 123 or "0")
        if (sourceIdStr.length > 1 && sourceIdStr.startsWith('0')) {
            throw IllegalArgumentException("Source ID must not contain leading zeros")
        }
        if (sourceIdStr == "0") {
            throw IllegalArgumentException("Source ID must be positive")
        }
        val id = sourceIdStr.toLongOrNull()
        require(id != null && id > 0) { "Source ID must be a valid positive Long" }
        return "source_$id"
    }
}
