package com.example.manga_reader_app

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

class ExtensionDownloader(
    private val maxFileSize: Long = 50 * 1024 * 1024L, // 50MB
    private val connectTimeoutMs: Int = 15000,
    private val readTimeoutMs: Int = 30000,
    private val maxRedirects: Int = 5
) {

    suspend fun download(
        initialUrl: String,
        destinationFile: File,
        onProgress: ((received: Long, total: Long) -> Unit)? = null
    ): Result<File> = withContext(Dispatchers.IO) {
        val validation = ExtensionSecurityPolicy.validateDownloadUrl(initialUrl)
        if (!validation.isValid) {
            return@withContext Result.failure(SecurityException("Invalid download URL: ${validation.errorMessage}"))
        }

        var currentUrl = initialUrl
        var redirectCount = 0
        var connection: HttpURLConnection? = null

        try {
            while (redirectCount <= maxRedirects) {
                val urlObj = URL(currentUrl)
                connection = (urlObj.openConnection() as HttpURLConnection).apply {
                    instanceFollowRedirects = false
                    connectTimeout = connectTimeoutMs
                    readTimeout = readTimeoutMs
                    setRequestProperty("User-Agent", "DCatcher-ExtensionDownloader/1.0")
                }

                val responseCode = connection.responseCode
                if (responseCode in 300..399) {
                    val location = connection.getHeaderField("Location")
                        ?: return@withContext Result.failure(SecurityException("Redirect response missing Location header"))

                    val resolvedRedirect = URL(urlObj, location).toString()
                    if (!ExtensionSecurityPolicy.isAllowedRedirectUrl(resolvedRedirect)) {
                        return@withContext Result.failure(
                            SecurityException("Redirect to untrusted URL blocked: $resolvedRedirect")
                        )
                    }

                    connection.disconnect()
                    currentUrl = resolvedRedirect
                    redirectCount++
                    continue
                }

                if (responseCode !in 200..299) {
                    return@withContext Result.failure(
                        Exception("HTTP download failed with response code: $responseCode")
                    )
                }

                val contentLength = connection.contentLengthLong
                if (contentLength > maxFileSize) {
                    return@withContext Result.failure(
                        SecurityException("File size $contentLength exceeds maximum allowed $maxFileSize")
                    )
                }

                destinationFile.parentFile?.mkdirs()
                var totalBytesRead = 0L

                connection.inputStream.use { input ->
                    FileOutputStream(destinationFile).use { output ->
                        val buffer = ByteArray(8192)
                        var bytesRead: Int
                        while (input.read(buffer).also { bytesRead = it } != -1) {
                            output.write(buffer, 0, bytesRead)
                            totalBytesRead += bytesRead
                            if (totalBytesRead > maxFileSize) {
                                destinationFile.delete()
                                return@withContext Result.failure(
                                    SecurityException("Downloaded bytes exceeded maximum allowed $maxFileSize")
                                )
                            }
                            onProgress?.invoke(totalBytesRead, contentLength)
                        }
                    }
                }

                return@withContext Result.success(destinationFile)
            }

            return@withContext Result.failure(SecurityException("Too many redirects (max $maxRedirects)"))
        } catch (e: Exception) {
            if (destinationFile.exists()) {
                destinationFile.delete()
            }
            return@withContext Result.failure(e)
        } finally {
            connection?.disconnect()
        }
    }
}
