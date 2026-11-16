package com.example.manga_reader_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class DcatcherExtensionsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL_NAME = "dev.dcatcher/extensions"
        const val EVENT_CHANNEL_NAME = "dev.dcatcher/extensions/progress"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    internal lateinit var extensionManager: ExtensionManager
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }
    internal var pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    // Startup-readiness gate: ensures callers wait until startup reload finishes
    @Volatile
    internal var startupGate: CompletableDeferred<Unit> = CompletableDeferred()

    internal var uiThreadRunner: (Runnable) -> Unit = { runnable ->
        mainHandler.post(runnable)
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attachPlugin(binding.applicationContext, binding.binaryMessenger)
    }

    internal fun attachPlugin(context: Context, messenger: BinaryMessenger) {
        startStartupReload(ExtensionManager(context))

        methodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(messenger, EVENT_CHANNEL_NAME)
        eventChannel.setStreamHandler(this)
    }

    internal fun startStartupReload(
        manager: ExtensionManager,
        reloadBlock: (suspend () -> Unit)? = null
    ) {
        this.extensionManager = manager
        if (!pluginScope.isActive) {
            pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        }
        val gate = CompletableDeferred<Unit>()
        this.startupGate = gate

        pluginScope.launch {
            try {
                if (reloadBlock != null) {
                    reloadBlock()
                } else {
                    manager.reloadInstalledExtensions()
                }
                gate.complete(Unit)
            } catch (e: CancellationException) {
                gate.cancel(e)
                throw e
            } catch (e: Exception) {
                System.err.println("Startup extension reload error: ${e.message}")
                gate.completeExceptionally(e)
            } catch (e: LinkageError) {
                System.err.println("Startup extension reload linkage error: ${e.message}")
                gate.completeExceptionally(e)
            }
        }
    }

    internal suspend fun awaitStartupReady() {
        startupGate.await()
    }

    fun detachPlugin() {
        if (::methodChannel.isInitialized) {
            methodChannel.setMethodCallHandler(null)
        }
        if (::eventChannel.isInitialized) {
            eventChannel.setStreamHandler(null)
        }
        eventSink = null
        startupGate.cancel()
        pluginScope.cancel()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detachPlugin()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listInstalled" -> {
                pluginScope.launch {
                    try {
                        awaitStartupReady()
                        val installed = extensionManager.listInstalledAsDtoList()
                        postSuccess(result, installed)
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: LinkageError) {
                        postError(result, "SOURCE_RUNTIME_ERROR", e.message)
                    } catch (e: Exception) {
                        postError(result, "LIST_ERROR", e.message)
                    }
                }
            }

            "install" -> {
                val packageName = call.argument<String>("packageName")
                val apkUrl = call.argument<String>("apkUrl")
                val versionCodeRaw = call.argument<Any>("versionCode")
                val trustConfirmed = call.argument<Boolean>("trustConfirmed") ?: false

                if (packageName.isNullOrBlank() || apkUrl.isNullOrBlank() || versionCodeRaw == null) {
                    result.error("INVALID_ARGUMENT", "Missing required install arguments", null)
                    return
                }

                val versionCode = when (versionCodeRaw) {
                    is Number -> versionCodeRaw.toLong()
                    is String -> versionCodeRaw.toLongOrNull() ?: 0L
                    else -> 0L
                }

                pluginScope.launch {
                    try {
                        awaitStartupReady()
                        val installResult = extensionManager.installExtension(
                            apkUrl = apkUrl,
                            expectedPackageName = packageName,
                            expectedVersionCode = versionCode,
                            trustConfirmed = trustConfirmed,
                            onProgress = { received, total ->
                                postProgress(packageName, received, total)
                            }
                        )

                        if (installResult.isSuccess) {
                            postSuccess(result, true)
                        } else {
                            val err = installResult.exceptionOrNull()
                            val code = when (err) {
                                is SecurityException -> "SECURITY_ERROR"
                                is LinkageError -> "INSTALL_ERROR"
                                else -> "INSTALL_ERROR"
                            }
                            postError(result, code, err?.message ?: "Installation failed")
                        }
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: SecurityException) {
                        postError(result, "SECURITY_ERROR", e.message)
                    } catch (e: LinkageError) {
                        postError(result, "INSTALL_ERROR", e.message)
                    } catch (e: Exception) {
                        postError(result, "INSTALL_ERROR", e.message)
                    }
                }
            }

            "uninstall" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "Missing packageName", null)
                    return
                }

                pluginScope.launch {
                    try {
                        awaitStartupReady()
                        val uninstallResult = extensionManager.uninstallExtension(packageName)
                        if (uninstallResult.isSuccess) {
                            postSuccess(result, true)
                        } else {
                            val err = uninstallResult.exceptionOrNull()
                            postError(result, "UNINSTALL_ERROR", err?.message ?: "Uninstall failed")
                        }
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: LinkageError) {
                        postError(result, "UNINSTALL_ERROR", e.message)
                    } catch (e: Exception) {
                        postError(result, "UNINSTALL_ERROR", e.message)
                    }
                }
            }

            "getCatalog" -> {
                val sourceId = getSourceId(call)
                val page = when (val p = call.argument<Any>("page")) {
                    is Number -> p.toInt()
                    is String -> p.toIntOrNull() ?: 1
                    else -> 1
                }.coerceAtLeast(1)
                val query = call.argument<String>("query")
                val type = call.argument<String>("type")
                val includedGenres = call.argument<List<String>>("includedGenres")
                val excludedGenres = call.argument<List<String>>("excludedGenres")

                if (sourceId == null) {
                    result.error("INVALID_ARGUMENT", "Missing sourceId", null)
                    return
                }

                pluginScope.launch {
                    try {
                        awaitStartupReady()
                        val catalog = extensionManager.withLifecycleLock {
                            val source = extensionManager.getSource(sourceId)
                            SourceOperations.getCatalog(source, page, query, type, includedGenres, excludedGenres)
                        }
                        postSuccess(result, catalog)
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: SourceNotFoundException) {
                        postError(result, "SOURCE_NOT_FOUND", e.message)
                    } catch (e: LinkageError) {
                        postError(result, "SOURCE_RUNTIME_ERROR", e.message)
                    } catch (e: Exception) {
                        postError(result, "CATALOG_ERROR", e.message)
                    }
                }
            }

            "getMangaDetails" -> {
                val sourceId = getSourceId(call)
                val mangaUrl = call.argument<String>("mangaUrl")?.trim()?.takeIf { it.isNotEmpty() }

                if (sourceId == null || mangaUrl == null) {
                    result.error("INVALID_ARGUMENT", "Missing sourceId or mangaUrl", null)
                    return
                }

                pluginScope.launch {
                    try {
                        awaitStartupReady()
                        val details = extensionManager.withLifecycleLock {
                            val source = extensionManager.getSource(sourceId)
                            SourceOperations.getMangaDetails(source, mangaUrl)
                        }
                        postSuccess(result, details)
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: SourceNotFoundException) {
                        postError(result, "SOURCE_NOT_FOUND", e.message)
                    } catch (e: LinkageError) {
                        postError(result, "SOURCE_RUNTIME_ERROR", e.message)
                    } catch (e: Exception) {
                        postError(result, "DETAILS_ERROR", e.message)
                    }
                }
            }

            "getChapters" -> {
                val sourceId = getSourceId(call)
                val mangaUrl = call.argument<String>("mangaUrl")?.trim()?.takeIf { it.isNotEmpty() }

                if (sourceId == null || mangaUrl == null) {
                    result.error("INVALID_ARGUMENT", "Missing sourceId or mangaUrl", null)
                    return
                }

                pluginScope.launch {
                    try {
                        awaitStartupReady()
                        val chapters = extensionManager.withLifecycleLock {
                            val source = extensionManager.getSource(sourceId)
                            SourceOperations.getChapters(source, mangaUrl)
                        }
                        postSuccess(result, chapters)
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: SourceNotFoundException) {
                        postError(result, "SOURCE_NOT_FOUND", e.message)
                    } catch (e: LinkageError) {
                        postError(result, "SOURCE_RUNTIME_ERROR", e.message)
                    } catch (e: Exception) {
                        postError(result, "CHAPTERS_ERROR", e.message)
                    }
                }
            }

            "getChapterPages" -> {
                val sourceId = getSourceId(call)
                val chapterUrl = call.argument<String>("chapterUrl")?.trim()?.takeIf { it.isNotEmpty() }

                if (sourceId == null || chapterUrl == null) {
                    result.error("INVALID_ARGUMENT", "Missing sourceId or chapterUrl", null)
                    return
                }

                pluginScope.launch {
                    try {
                        awaitStartupReady()
                        val pages = extensionManager.withLifecycleLock {
                            val source = extensionManager.getSource(sourceId)
                            SourceOperations.getChapterPages(source, chapterUrl)
                        }
                        postSuccess(result, pages)
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: SourceNotFoundException) {
                        postError(result, "SOURCE_NOT_FOUND", e.message)
                    } catch (e: LinkageError) {
                        postError(result, "SOURCE_RUNTIME_ERROR", e.message)
                    } catch (e: Exception) {
                        postError(result, "PAGES_ERROR", e.message)
                    }
                }
            }

            "fetchImage" -> {
                val sourceId = getSourceId(call)
                val url = call.argument<String>("url")?.trim()?.takeIf { it.isNotEmpty() }

                if (sourceId == null || url == null) {
                    result.error("INVALID_ARGUMENT", "Missing sourceId or url", null)
                    return
                }

                pluginScope.launch {
                    try {
                        awaitStartupReady()
                        val imageBytes = extensionManager.withLifecycleLock {
                            val source = extensionManager.getSource(sourceId)
                            SourceOperations.fetchImage(source, url)
                        }
                        postSuccess(result, imageBytes)
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: SourceNotFoundException) {
                        postError(result, "SOURCE_NOT_FOUND", e.message)
                    } catch (e: LinkageError) {
                        postError(result, "SOURCE_RUNTIME_ERROR", e.message)
                    } catch (e: Exception) {
                        postError(result, "FETCH_IMAGE_ERROR", e.message)
                    }
                }
            }

            "getHeaders" -> {
                val sourceId = getSourceId(call)
                if (sourceId == null) {
                    result.error("INVALID_ARGUMENT", "Missing sourceId", null)
                    return
                }

                pluginScope.launch {
                    try {
                        awaitStartupReady()
                        val headers = extensionManager.withLifecycleLock {
                            val source = extensionManager.getSource(sourceId)
                            SourceOperations.getHeaders(source)
                        }
                        postSuccess(result, headers)
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: SourceNotFoundException) {
                        postError(result, "SOURCE_NOT_FOUND", e.message)
                    } catch (e: LinkageError) {
                        postError(result, "SOURCE_RUNTIME_ERROR", e.message)
                    } catch (e: Exception) {
                        postError(result, "HEADERS_ERROR", e.message)
                    }
                }
            }

            "getReloadFailures" -> {
                pluginScope.launch {
                    try {
                        awaitStartupReady()
                        val failures = extensionManager.getReloadFailures()
                        postSuccess(result, failures)
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: LinkageError) {
                        postError(result, "FAILURES_ERROR", e.message)
                    } catch (e: Exception) {
                        postError(result, "FAILURES_ERROR", e.message)
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun getSourceId(call: MethodCall): String? {
        return when (val raw = call.argument<Any>("sourceId")) {
            is String -> raw.trim().takeIf { it.isNotEmpty() }
            is Number -> raw.toString()
            else -> null
        }
    }

    private fun postSuccess(result: MethodChannel.Result, data: Any?) {
        uiThreadRunner {
            try {
                result.success(data)
            } catch (e: Exception) {
                // Ignore if engine detached or channel already answered
            }
        }
    }

    private fun postError(result: MethodChannel.Result, code: String, message: String?) {
        uiThreadRunner {
            try {
                result.error(code, message, null)
            } catch (e: Exception) {
                // Ignore if engine detached or channel already answered
            }
        }
    }

    private fun postProgress(packageName: String, received: Long, total: Long) {
        val sink = eventSink ?: return
        uiThreadRunner {
            try {
                sink.success(
                    mapOf(
                        "packageName" to packageName,
                        "received" to received,
                        "total" to total
                    )
                )
            } catch (e: Exception) {
                // Ignore if event sink cancelled
            }
        }
    }
}
