package com.example.manga_reader_app

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.webkit.CookieManager
import eu.kanade.tachiyomi.source.ConfigurableSource
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.online.HttpSource
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.net.URI
import kotlin.coroutines.resume

class SourceAccessPlugin(
    private val extensionsPlugin: DcatcherExtensionsPlugin
) : FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    companion object {
        const val METHOD_CHANNEL_NAME = "dev.dcatcher/source_access"
        const val REQUEST_CODE_LOGIN = 10101
        const val REQUEST_CODE_SETTINGS = 10102
        const val REQUEST_CODE_CLEAR = 10103

        const val LOGIN_ACTIVITY_CLASS_NAME = "com.example.manga_reader_app.SourceLoginActivity"
        const val SETTINGS_ACTIVITY_CLASS_NAME = "com.example.manga_reader_app.SourceSettingsActivity"

        // Safe predefined Russian error messages (NEVER export e.message or raw URLs)
        const val ERR_INVALID_SOURCE_ID = "Некорректный идентификатор источника"
        const val ERR_SOURCE_NOT_FOUND = "Источник не найден среди установленных расширений"
        const val ERR_CONFIRMATION_REQUIRED = "Требуется явное подтверждение операции"
        const val ERR_OPERATION_IN_PROGRESS = "Предыдущая операция с экраном источника еще выполняется"
        const val ERR_ACTIVITY_UNAVAILABLE = "Экран приложения недоступен для запуска операции"
        const val ERR_LAUNCH_FAILED = "Не удалось открыть экран источника"
        const val ERR_UNSUPPORTED_SETTINGS = "Данный источник не поддерживает настройки"
        const val ERR_UNSAFE_URL = "Адрес источника не является безопасным HTTPS URL"
        const val ERR_SOURCE_NOT_HTTP = "Источник не является веб-источником"
        const val ERR_CANCELLED = "Операция отменена"
        const val ERR_RUNTIME_GENERIC = "Произошла системная ошибка при обработке источника"
    }

    private class PendingRequest(
        val requestCode: Int,
        val sourceId: String,
        val result: MethodChannel.Result
    ) {
        var owningJob: Job? = null
        var sessionToken: String? = null
        var isResultDelivered: Boolean = false
    }

    private var methodChannel: MethodChannel? = null
    private var applicationContext: Context? = null
    private var currentActivity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    internal var pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    // All mutations and reads of activePendingRequest happen on Dispatchers.Main
    private var activePendingRequest: PendingRequest? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel?.setMethodCallHandler(this)
        if (!pluginScope.isActive) {
            pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        applicationContext = null
        cancelPendingOnDetach()
        pluginScope.cancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        setActivityBinding(binding)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        setActivityBinding(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        cleanActivityBinding()
    }

    override fun onDetachedFromActivity() {
        cleanActivityBinding()
        cancelPendingOnDetach()
    }

    private fun setActivityBinding(binding: ActivityPluginBinding) {
        activityBinding = binding
        currentActivity = binding.activity
        binding.addActivityResultListener(this)
    }

    private fun cleanActivityBinding() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        currentActivity = null
    }

    private fun cancelPendingOnDetach() {
        val req = activePendingRequest ?: return
        activePendingRequest = null

        val token = req.sessionToken
        if (token != null) {
            SourceAccessSessions.remove(token)
        }

        req.owningJob?.cancel()

        if (!req.isResultDelivered) {
            req.isResultDelivered = true
            try {
                req.result.error("CANCELLED", ERR_CANCELLED, null)
            } catch (_: Throwable) {}
        }
    }

    private fun parseCanonicalSourceId(arg: Any?): String? {
        val str = arg as? String ?: return null
        return try {
            SourceAccessPolicy.sourcePreferenceKey(str)
            str
        } catch (_: Throwable) {
            null
        }
    }

    private fun rethrowFatalThrowable(t: Throwable) {
        if (t is VirtualMachineError || t is ThreadDeath) {
            throw t
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getSourceAccessInfo" -> handleGetSourceAccessInfo(call, result)
            "openSourceWebView" -> handleOpenSourceActivity(call, result, REQUEST_CODE_LOGIN, LOGIN_ACTIVITY_CLASS_NAME)
            "openSourceSettings" -> handleOpenSourceActivity(call, result, REQUEST_CODE_SETTINGS, SETTINGS_ACTIVITY_CLASS_NAME)
            "clearSourceCookies" -> handleClearSourceCookies(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleGetSourceAccessInfo(call: MethodCall, result: MethodChannel.Result) {
        val canonicalSourceId = parseCanonicalSourceId(call.argument<Any>("sourceId"))
        if (canonicalSourceId == null) {
            result.error("INVALID_ARGUMENT", ERR_INVALID_SOURCE_ID, null)
            return
        }

        pluginScope.launch {
            try {
                extensionsPlugin.awaitStartupReady()

                val info = extensionsPlugin.extensionManager.withLifecycleLock {
                    val source = resolveInstalledExactSource(canonicalSourceId)
                        ?: throw SourceNotFoundException(canonicalSourceId)

                    val fullHomeUrl = if (source is HttpSource) {
                        val rawHomeUrl = source.getHomeUrl()
                        if (SourceAccessPolicy.isSafeWebUrl(rawHomeUrl)) rawHomeUrl else ""
                    } else {
                        ""
                    }

                    val originHomeUrl = if (fullHomeUrl.isNotEmpty()) {
                        try {
                            val uri = URI(fullHomeUrl)
                            val scheme = uri.scheme
                            val authority = uri.rawAuthority
                            if (!scheme.isNullOrEmpty() && !authority.isNullOrEmpty()) {
                                "$scheme://$authority"
                            } else {
                                ""
                            }
                        } catch (_: Throwable) {
                            ""
                        }
                    } else {
                        ""
                    }

                    val hasCookies = if (fullHomeUrl.isNotEmpty()) {
                        SourceCookieService.hasCookies(fullHomeUrl)
                    } else {
                        false
                    }

                    mapOf(
                        "sourceId" to source.id.toString(),
                        "name" to source.name,
                        "homeUrl" to originHomeUrl,
                        "supportsSettings" to (source is ConfigurableSource),
                        "hasCookies" to hasCookies,
                        "loginVerified" to false
                    )
                }

                withContext(Dispatchers.Main) {
                    result.success(info)
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: SourceNotFoundException) {
                withContext(Dispatchers.Main) {
                    result.error("SOURCE_NOT_FOUND", ERR_SOURCE_NOT_FOUND, null)
                }
            } catch (t: Throwable) {
                rethrowFatalThrowable(t)
                withContext(Dispatchers.Main) {
                    result.error("INTERNAL_ERROR", ERR_RUNTIME_GENERIC, null)
                }
            }
        }
    }

    private fun handleOpenSourceActivity(
        call: MethodCall,
        result: MethodChannel.Result,
        requestCode: Int,
        targetClassName: String
    ) {
        val canonicalSourceId = parseCanonicalSourceId(call.argument<Any>("sourceId"))
        if (canonicalSourceId == null) {
            result.error("INVALID_ARGUMENT", ERR_INVALID_SOURCE_ID, null)
            return
        }

        // Must be checked and assigned on Main
        if (activePendingRequest != null) {
            result.error("BUSY", ERR_OPERATION_IN_PROGRESS, null)
            return
        }

        val pending = PendingRequest(requestCode, canonicalSourceId, result)
        activePendingRequest = pending

        val job = pluginScope.launch {
            try {
                extensionsPlugin.awaitStartupReady()

                // Resolve source under lifecycle lock, release lock BEFORE user interaction
                val (source, rawFullHomeUrl) = extensionsPlugin.extensionManager.withLifecycleLock {
                    val resolvedSource = resolveInstalledExactSource(canonicalSourceId)
                        ?: throw SourceNotFoundException(canonicalSourceId)

                    val resolvedHomeUrl = if (resolvedSource is HttpSource) {
                        resolvedSource.getHomeUrl()
                    } else {
                        ""
                    }

                    if (requestCode == REQUEST_CODE_SETTINGS) {
                        if (resolvedSource !is ConfigurableSource) {
                            throw UnsupportedOperationException("Settings not supported")
                        }
                    } else if (requestCode == REQUEST_CODE_LOGIN) {
                        if (resolvedSource !is HttpSource) {
                            throw IllegalArgumentException("Not HttpSource")
                        }
                        if (!SourceAccessPolicy.isSafeWebUrl(resolvedHomeUrl)) {
                            throw IllegalArgumentException("Unsafe homeUrl for WebView")
                        }
                    }

                    Pair(resolvedSource, resolvedHomeUrl)
                }

                withContext(Dispatchers.Main) {
                    // Check ownership before creating token / launching
                    if (activePendingRequest !== pending) {
                        return@withContext
                    }

                    val activity = currentActivity
                    if (activity == null) {
                        deliverPendingError(pending, "ACTIVITY_UNAVAILABLE", ERR_ACTIVITY_UNAVAILABLE)
                        return@withContext
                    }

                    // Native session retains full source URL
                    val token = SourceAccessSessions.create(source, rawFullHomeUrl)
                    pending.sessionToken = token

                    try {
                        val intent = Intent().apply {
                            component = ComponentName(activity, targetClassName)
                            putExtra(SourceAccessSessions.EXTRA_SESSION_TOKEN, token)
                        }
                        activity.startActivityForResult(intent, requestCode)
                    } catch (t: Throwable) {
                        rethrowFatalThrowable(t)
                        deliverPendingError(pending, "LAUNCH_ERROR", ERR_LAUNCH_FAILED)
                    }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: SourceNotFoundException) {
                withContext(Dispatchers.Main) {
                    deliverPendingError(pending, "SOURCE_NOT_FOUND", ERR_SOURCE_NOT_FOUND)
                }
            } catch (e: UnsupportedOperationException) {
                withContext(Dispatchers.Main) {
                    deliverPendingError(pending, "UNSUPPORTED", ERR_UNSUPPORTED_SETTINGS)
                }
            } catch (e: IllegalArgumentException) {
                withContext(Dispatchers.Main) {
                    deliverPendingError(pending, "INVALID_URL", ERR_UNSAFE_URL)
                }
            } catch (t: Throwable) {
                rethrowFatalThrowable(t)
                withContext(Dispatchers.Main) {
                    deliverPendingError(pending, "INTERNAL_ERROR", ERR_RUNTIME_GENERIC)
                }
            }
        }

        pending.owningJob = job
    }

    private fun handleClearSourceCookies(call: MethodCall, result: MethodChannel.Result) {
        val canonicalSourceId = parseCanonicalSourceId(call.argument<Any>("sourceId"))
        val confirmedArg = call.argument<Any>("confirmed")
        val confirmed = (confirmedArg as? Boolean) == true

        if (canonicalSourceId == null) {
            result.error("INVALID_ARGUMENT", ERR_INVALID_SOURCE_ID, null)
            return
        }

        if (!confirmed) {
            result.error("CONFIRMATION_REQUIRED", ERR_CONFIRMATION_REQUIRED, null)
            return
        }

        // Avoid page overwriting cookies during deletion: require no open UI
        if (activePendingRequest != null) {
            result.error("BUSY", ERR_OPERATION_IN_PROGRESS, null)
            return
        }

        val pending = PendingRequest(REQUEST_CODE_CLEAR, canonicalSourceId, result)
        activePendingRequest = pending

        val job = pluginScope.launch {
            try {
                extensionsPlugin.awaitStartupReady()

                val homeUrl = extensionsPlugin.extensionManager.withLifecycleLock {
                    val source = resolveInstalledExactSource(canonicalSourceId)
                        ?: throw SourceNotFoundException(canonicalSourceId)

                    if (source is HttpSource) {
                        val rawUrl = source.getHomeUrl()
                        if (SourceAccessPolicy.isSafeWebUrl(rawUrl)) {
                            rawUrl
                        } else {
                            throw IllegalArgumentException("Source homeUrl is not safe")
                        }
                    } else {
                        throw UnsupportedOperationException("Source is not an HttpSource")
                    }
                }

                // Clear cookies for only this selected site
                SourceCookieService.clearSourceCookies(homeUrl)

                // Invalidate source operations cache and reload installed extensions
                val sourceIdLong = canonicalSourceId.toLongOrNull()
                if (sourceIdLong != null) {
                    SourceOperations.invalidateForSource(sourceIdLong)
                }
                extensionsPlugin.extensionManager.reloadInstalledExtensions()

                withContext(Dispatchers.Main) {
                    deliverPendingSuccess(pending, null)
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: SourceNotFoundException) {
                withContext(Dispatchers.Main) {
                    deliverPendingError(pending, "SOURCE_NOT_FOUND", ERR_SOURCE_NOT_FOUND)
                }
            } catch (e: UnsupportedOperationException) {
                withContext(Dispatchers.Main) {
                    deliverPendingError(pending, "UNSUPPORTED", ERR_SOURCE_NOT_HTTP)
                }
            } catch (e: IllegalArgumentException) {
                withContext(Dispatchers.Main) {
                    deliverPendingError(pending, "INVALID_ARGUMENT", ERR_UNSAFE_URL)
                }
            } catch (t: Throwable) {
                rethrowFatalThrowable(t)
                withContext(Dispatchers.Main) {
                    deliverPendingError(pending, "INTERNAL_ERROR", ERR_RUNTIME_GENERIC)
                }
            }
        }

        pending.owningJob = job
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_LOGIN && requestCode != REQUEST_CODE_SETTINGS) {
            return false
        }

        val req = activePendingRequest ?: return false
        if (req.requestCode != requestCode) {
            return false
        }

        // Keep activePendingRequest non-null (BUSY) until flush/reload completed
        val token = req.sessionToken
        if (token != null) {
            SourceAccessSessions.remove(token)
            req.sessionToken = null
        }

        val sourceId = req.sourceId

        val job = pluginScope.launch {
            try {
                // 1. Flush cookies on IO thread
                withContext(Dispatchers.IO) {
                    suspendCancellableCoroutine<Unit> { cont ->
                        CookieManager.getInstance().flush()
                        if (cont.isActive) {
                            cont.resume(Unit)
                        }
                    }
                }

                // 2. Invalidate source operations and reload installed extensions
                val idLong = sourceId.toLongOrNull()
                if (idLong != null) {
                    SourceOperations.invalidateForSource(idLong)
                }
                extensionsPlugin.extensionManager.reloadInstalledExtensions()

                // 3. Verify source still installed under lifecycle lock
                val stillInstalled = extensionsPlugin.extensionManager.withLifecycleLock {
                    resolveInstalledExactSource(sourceId) != null
                }

                val completed = (resultCode == Activity.RESULT_OK) && stillInstalled
                withContext(Dispatchers.Main) {
                    deliverPendingSuccess(req, completed)
                }
            } catch (e: CancellationException) {
                throw e
            } catch (t: Throwable) {
                rethrowFatalThrowable(t)
                withContext(Dispatchers.Main) {
                    deliverPendingError(req, "ACTIVITY_RESULT_ERROR", ERR_RUNTIME_GENERIC)
                }
            }
        }

        req.owningJob = job
        return true
    }

    private fun deliverPendingSuccess(req: PendingRequest, result: Any?) {
        if (activePendingRequest === req) {
            activePendingRequest = null
        }
        val token = req.sessionToken
        if (token != null) {
            SourceAccessSessions.remove(token)
            req.sessionToken = null
        }
        if (!req.isResultDelivered) {
            req.isResultDelivered = true
            try {
                req.result.success(result)
            } catch (_: Throwable) {}
        }
    }

    private fun deliverPendingError(req: PendingRequest, errorCode: String, errorMessage: String) {
        if (activePendingRequest === req) {
            activePendingRequest = null
        }
        val token = req.sessionToken
        if (token != null) {
            SourceAccessSessions.remove(token)
            req.sessionToken = null
        }
        if (!req.isResultDelivered) {
            req.isResultDelivered = true
            try {
                req.result.error(errorCode, errorMessage, null)
            } catch (_: Throwable) {}
        }
    }

    private fun resolveInstalledExactSource(sourceId: String): Source? {
        val manager = extensionsPlugin.extensionManager
        val installedMap = manager.listInstalled()
        val exists = installedMap.values.any { pkg ->
            pkg.sources.any { it.id == sourceId }
        }
        if (!exists) {
            return null
        }

        return try {
            manager.getSource(sourceId)
        } catch (_: SourceNotFoundException) {
            null
        }
    }
}
