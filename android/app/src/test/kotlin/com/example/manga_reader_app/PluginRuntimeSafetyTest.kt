package com.example.manga_reader_app

import android.content.ContextWrapper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class PluginRuntimeSafetyTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private fun createDummyContext(): ContextWrapper {
        val baseDir = tempFolder.newFolder("plugin_runtime_test_${System.nanoTime()}")
        return object : ContextWrapper(null) {
            override fun getFilesDir(): File = baseDir
            override fun getCacheDir(): File = File(baseDir, "cache").apply { mkdirs() }
        }
    }

    @Test
    fun testStartupReloadThrowsNoClassDefFoundErrorThenListInstalledReturnsSourceRuntimeError() = runBlocking {
        val dummyContext = createDummyContext()
        val manager = ExtensionManager(dummyContext)
        val plugin = DcatcherExtensionsPlugin()
        plugin.uiThreadRunner = { runnable -> runnable.run() }

        try {
            // Simulated startup reload throws NoClassDefFoundError (a LinkageError)
            plugin.startStartupReload(manager) {
                throw NoClassDefFoundError("Simulated missing class in extension runtime")
            }

            val listInstalledResult = CompletableDeferred<Pair<String, String?>>()
            val mockResult = object : MethodChannel.Result {
                override fun success(result: Any?) {
                    listInstalledResult.completeExceptionally(AssertionError("listInstalled must not succeed on LinkageError"))
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    listInstalledResult.complete(errorCode to errorMessage)
                }

                override fun notImplemented() {
                    listInstalledResult.completeExceptionally(UnsupportedOperationException("notImplemented"))
                }
            }

            plugin.onMethodCall(MethodCall("listInstalled", null), mockResult)

            val (code, message) = withTimeout(5000) {
                listInstalledResult.await()
            }

            assertEquals("SOURCE_RUNTIME_ERROR", code)
            assertTrue("Error message must contain simulated error info", message?.contains("Simulated missing class") == true)
        } finally {
            plugin.detachPlugin()
        }
    }

    @Test
    fun testDetachPluginCancelsOldScopeAndStartStartupReloadCreatesWorkingNewScopeAndGate() = runBlocking {
        val dummyContext = createDummyContext()
        val manager = ExtensionManager(dummyContext)
        val plugin = DcatcherExtensionsPlugin()
        plugin.uiThreadRunner = { runnable -> runnable.run() }

        try {
            val firstReloadStarted = CompletableDeferred<Unit>()
            val firstReloadSuspendGate = CompletableDeferred<Unit>()

            plugin.startStartupReload(manager) {
                firstReloadStarted.complete(Unit)
                firstReloadSuspendGate.await()
            }

            firstReloadStarted.await()
            val oldScope = plugin.pluginScope
            val oldGate = plugin.startupGate

            // Detach cancels old scope and gate
            plugin.detachPlugin()

            assertFalse("Old plugin scope must be cancelled", oldScope.isActive)
            assertTrue("Old startup gate must be cancelled", oldGate.isCancelled)

            // Start startup reload again creates working new scope and gate
            plugin.startStartupReload(manager) {
                // Successful reload
                manager.reloadInstalledExtensions()
            }

            assertTrue("New plugin scope must be active", plugin.pluginScope.isActive)
            assertFalse("New startup gate must not be cancelled", plugin.startupGate.isCancelled)

            val listInstalledResult = CompletableDeferred<Any?>()
            val mockResult = object : MethodChannel.Result {
                override fun success(result: Any?) {
                    listInstalledResult.complete(result)
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    listInstalledResult.completeExceptionally(RuntimeException("$errorCode: $errorMessage"))
                }

                override fun notImplemented() {
                    listInstalledResult.completeExceptionally(UnsupportedOperationException("notImplemented"))
                }
            }

            plugin.onMethodCall(MethodCall("listInstalled", null), mockResult)

            val resultList = withTimeout(5000) {
                listInstalledResult.await()
            }

            assertNotNull("listInstalled must return non-null result", resultList)
            assertTrue("listInstalled must return a List", resultList is List<*>)
        } finally {
            plugin.detachPlugin()
        }
    }

    @Test
    fun testHoldLifecycleLockSuspendedThenGetHeadersCompletesOnlyAfterReleaseWithSourceNotFound() = runBlocking {
        val dummyContext = createDummyContext()
        val manager = ExtensionManager(dummyContext)
        val plugin = DcatcherExtensionsPlugin()
        plugin.uiThreadRunner = { runnable -> runnable.run() }

        try {
            // Initialize startup reload properly
            plugin.startStartupReload(manager) {
                manager.reloadInstalledExtensions()
            }
            withTimeout(5000) {
                plugin.awaitStartupReady()
            }

            val lockAcquired = CompletableDeferred<Unit>()
            val releaseLock = CompletableDeferred<Unit>()
            val lockHolderFinished = CompletableDeferred<Unit>()

            // Hold actual manager.withLifecycleLock suspended
            val holdingJob = launch(Dispatchers.Default) {
                manager.withLifecycleLock {
                    lockAcquired.complete(Unit)
                    releaseLock.await()
                }
                lockHolderFinished.complete(Unit)
            }

            lockAcquired.await()

            val getHeadersResult = CompletableDeferred<Pair<String, String?>>()
            val mockResult = object : MethodChannel.Result {
                override fun success(result: Any?) {
                    getHeadersResult.completeExceptionally(AssertionError("Expected SOURCE_NOT_FOUND error"))
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    getHeadersResult.complete(errorCode to errorMessage)
                }

                override fun notImplemented() {
                    getHeadersResult.completeExceptionally(UnsupportedOperationException("notImplemented"))
                }
            }

            // Invoke getHeaders for missing source ID while lock is held
            plugin.onMethodCall(
                MethodCall("getHeaders", mapOf("sourceId" to "missing_source_999")),
                mockResult
            )

            // Assert result is NOT completed until lock is released
            delay(100)
            assertFalse(
                "getHeaders result must not complete while lifecycleLock is suspended",
                getHeadersResult.isCompleted
            )

            // Release the lifecycle lock
            releaseLock.complete(Unit)
            lockHolderFinished.await()
            holdingJob.join()

            // After lock is released, assert SOURCE_NOT_FOUND error
            val (errorCode, errorMessage) = withTimeout(5000) {
                getHeadersResult.await()
            }

            assertEquals("SOURCE_NOT_FOUND", errorCode)
            assertTrue(
                "Error message should mention missing source ID",
                errorMessage?.contains("missing_source_999") == true
            )
        } finally {
            plugin.detachPlugin()
        }
    }
}
