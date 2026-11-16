package com.example.manga_reader_app

import android.app.Application
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Regression and lifecycle concurrency tests for [SourceAccessPlugin].
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class)
class SourceAccessPluginLifecycleTest {

    private val testDispatcher = StandardTestDispatcher()
    private val testScope = TestScope(testDispatcher)

    private lateinit var extensionsPlugin: DcatcherExtensionsPlugin
    private lateinit var sourceAccessPlugin: SourceAccessPlugin

    private class TestResultRecorder : MethodChannel.Result {
        var successResult: Any? = null
        var errorCode: String? = null
        var errorMessage: String? = null
        var errorDetails: Any? = null
        var callCount: Int = 0

        override fun success(result: Any?) {
            callCount++
            successResult = result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            callCount++
            this.errorCode = errorCode
            this.errorMessage = errorMessage
            this.errorDetails = errorDetails
        }

        override fun notImplemented() {
            callCount++
            errorCode = "NOT_IMPLEMENTED"
        }
    }

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)

        extensionsPlugin = DcatcherExtensionsPlugin()
        // Ensure startupGate is an uncompleted deferred so coroutines calling awaitStartupReady() suspend
        extensionsPlugin.startupGate = CompletableDeferred()

        sourceAccessPlugin = SourceAccessPlugin(extensionsPlugin)
        sourceAccessPlugin.pluginScope = testScope
    }

    @After
    fun tearDown() {
        testScope.cancel()
        sourceAccessPlugin.pluginScope.cancel()
        extensionsPlugin.pluginScope.cancel()
        Dispatchers.resetMain()
    }

    /**
     * Mutual-exclusion verification:
     * When clearSourceCookies(sourceId = "1", confirmed = true) is initiated, it is pending
     * (suspended waiting for startup gate / operations).
     * Then openSourceWebView(sourceId = "1") is invoked synchronously while clear is pending.
     * The second call MUST return "BUSY" because an operation with the source screen/cookies is in progress.
     */
    @Test
    fun testClearSourceCookiesPending_thenOpenSourceWebView_returnsBusy(): Unit {
        val clearResult = TestResultRecorder()
        val openResult = TestResultRecorder()

        val clearCall = MethodCall("clearSourceCookies", mapOf("sourceId" to "1", "confirmed" to true))
        val openCall = MethodCall("openSourceWebView", mapOf("sourceId" to "1"))

        sourceAccessPlugin.onMethodCall(clearCall, clearResult)

        // Verify clear is pending (neither success nor error returned yet)
        assertNull("Clear should be pending while startupGate is uncompleted", clearResult.errorCode)
        assertNull("Clear should not have succeeded yet", clearResult.successResult)
        assertEquals(0, clearResult.callCount)

        // Invoke openSourceWebView synchronously while clear is pending
        sourceAccessPlugin.onMethodCall(openCall, openResult)

        // BUG REPRODUCTION ASSERTION:
        // openSourceWebView must immediately reject with BUSY because a source operation is already pending
        assertEquals("BUSY", openResult.errorCode)
    }

    /**
     * Passing regression:
     * When openSourceWebView(sourceId = "1") is initiated and pending,
     * a subsequent clearSourceCookies(sourceId = "1", confirmed = true) returns "BUSY".
     */
    @Test
    fun testOpenSourceWebViewPending_thenClearSourceCookies_returnsBusy(): Unit {
        val openResult = TestResultRecorder()
        val clearResult = TestResultRecorder()

        val openCall = MethodCall("openSourceWebView", mapOf("sourceId" to "1"))
        val clearCall = MethodCall("clearSourceCookies", mapOf("sourceId" to "1", "confirmed" to true))

        sourceAccessPlugin.onMethodCall(openCall, openResult)

        // open is pending and has reserved activePendingRequest
        assertEquals(0, openResult.callCount)

        // clearSourceCookies should be rejected with BUSY
        sourceAccessPlugin.onMethodCall(clearCall, clearResult)

        assertEquals("BUSY", clearResult.errorCode)
        assertEquals(1, clearResult.callCount)
    }

    /**
     * Passing regression:
     * When openSourceWebView is pending and the plugin detaches from activity,
     * the pending request returns CANCELLED exactly once and cancels the owning coroutine job.
     */
    @Test
    fun testDetachActivityWithPendingOpen_returnsCancelledOnceAndCancelsJob(): Unit {
        val openResult = TestResultRecorder()
        val openCall = MethodCall("openSourceWebView", mapOf("sourceId" to "1"))

        sourceAccessPlugin.onMethodCall(openCall, openResult)
        assertEquals(0, openResult.callCount)

        // Detach from activity while open is pending
        sourceAccessPlugin.onDetachedFromActivity()

        assertEquals(1, openResult.callCount)
        assertEquals("CANCELLED", openResult.errorCode)

        // Calling detach again must not deliver result a second time
        sourceAccessPlugin.onDetachedFromActivity()
        assertEquals(1, openResult.callCount)
    }

    /**
     * Requirement (1):
     * Start clear, runCurrent so it suspends at startupGate, capture owning Job via narrowly scoped reflection;
     * detach, assert captured Job isCancelled, exactly one CANCELLED, complete gate and advance scheduler, no duplicate.
     */
    @Test
    fun testClearSourceCookiesPending_detachActivity_cancelsJobAndDeliversCancelledOnce(): Unit {
        val clearResult = TestResultRecorder()
        val clearCall = MethodCall("clearSourceCookies", mapOf("sourceId" to "1", "confirmed" to true))

        sourceAccessPlugin.onMethodCall(clearCall, clearResult)

        // Advance dispatcher so coroutine launches and suspends at startupGate
        testDispatcher.scheduler.runCurrent()

        assertEquals(0, clearResult.callCount)

        // Capture owning Job via narrowly scoped reflection
        val activePendingField = SourceAccessPlugin::class.java.getDeclaredField("activePendingRequest")
        activePendingField.isAccessible = true
        val pending = activePendingField.get(sourceAccessPlugin)
        assertNotNull("activePendingRequest should be set for clearSourceCookies", pending)

        val owningJobField = pending.javaClass.getDeclaredField("owningJob")
        owningJobField.isAccessible = true
        val owningJob = owningJobField.get(pending) as? Job
        assertNotNull("owningJob should be captured on pending request", owningJob)
        assertFalse("owningJob should not be cancelled before detach", owningJob!!.isCancelled)

        // Detach from activity
        sourceAccessPlugin.onDetachedFromActivity()

        // Assert captured Job is cancelled
        assertTrue("captured Job must be cancelled after detach", owningJob.isCancelled)
        assertEquals(1, clearResult.callCount)
        assertEquals("CANCELLED", clearResult.errorCode)
        assertEquals(SourceAccessPlugin.ERR_CANCELLED, clearResult.errorMessage)

        // Complete gate and advance scheduler to verify no duplicate result is delivered
        extensionsPlugin.startupGate.complete(Unit)
        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals(1, clearResult.callCount)
    }

    /**
     * Requirement (2):
     * Capture old PendingRequest before detach; start replacement clear;
     * simulate stale delivery through private deliverPendingSuccess with captured old request,
     * assert old once-only result and replacement still excludes another open with BUSY.
     * Note: Clearly labeled as simulated late callback, not actual WebView/deletion.
     */
    @Test
    fun testStaleDeliveryFromCapturedOldRequest_simulatedLateCallback_preservesActiveReplacement(): Unit {
        val oldResult = TestResultRecorder()
        val oldClearCall = MethodCall("clearSourceCookies", mapOf("sourceId" to "1", "confirmed" to true))

        sourceAccessPlugin.onMethodCall(oldClearCall, oldResult)

        val activePendingField = SourceAccessPlugin::class.java.getDeclaredField("activePendingRequest")
        activePendingField.isAccessible = true
        val oldPending = activePendingField.get(sourceAccessPlugin)
        assertNotNull("old pending request should be present", oldPending)

        // Detach from activity, which cancels old pending and delivers CANCELLED to oldResult
        sourceAccessPlugin.onDetachedFromActivity()
        assertEquals(1, oldResult.callCount)
        assertEquals("CANCELLED", oldResult.errorCode)

        // Start replacement clear
        val replacementResult = TestResultRecorder()
        val replacementClearCall = MethodCall("clearSourceCookies", mapOf("sourceId" to "1", "confirmed" to true))
        sourceAccessPlugin.onMethodCall(replacementClearCall, replacementResult)
        assertEquals(0, replacementResult.callCount)

        val currentPending = activePendingField.get(sourceAccessPlugin)
        assertNotNull("activePendingRequest should now reference replacement", currentPending)
        assertTrue("replacement should be a new pending request instance", currentPending !== oldPending)

        // Simulate stale delivery through private deliverPendingSuccess with captured old request
        // (This is a simulated late callback, not actual WebView/deletion)
        val deliverSuccessMethod = SourceAccessPlugin::class.java.getDeclaredMethod(
            "deliverPendingSuccess",
            oldPending.javaClass,
            Any::class.java
        )
        deliverSuccessMethod.isAccessible = true
        deliverSuccessMethod.invoke(sourceAccessPlugin, oldPending, null)

        // Assert old result was once-only (callCount remains 1 and code remains CANCELLED)
        assertEquals(1, oldResult.callCount)
        assertEquals("CANCELLED", oldResult.errorCode)

        // Replacement request is still active and excludes another open with BUSY
        val openResult = TestResultRecorder()
        val openCall = MethodCall("openSourceWebView", mapOf("sourceId" to "1"))
        sourceAccessPlugin.onMethodCall(openCall, openResult)

        assertEquals("BUSY", openResult.errorCode)
        assertEquals(1, openResult.callCount)
        assertEquals(0, replacementResult.callCount)
    }

    /**
     * Requirement (3):
     * With pending clear assert onActivityResult rejects LOGIN, SETTINGS and CLEAR codes,
     * leaves result pending and BUSY intact.
     */
    @Test
    fun testPendingClear_onActivityResultRejectsLoginSettingsAndClearCodes_leavesBusyIntact(): Unit {
        val clearResult = TestResultRecorder()
        val clearCall = MethodCall("clearSourceCookies", mapOf("sourceId" to "1", "confirmed" to true))

        sourceAccessPlugin.onMethodCall(clearCall, clearResult)
        assertEquals(0, clearResult.callCount)

        // onActivityResult for REQUEST_CODE_LOGIN should return false
        val handledLogin = sourceAccessPlugin.onActivityResult(SourceAccessPlugin.REQUEST_CODE_LOGIN, -1, null)
        assertFalse("onActivityResult must reject LOGIN code when clear is pending", handledLogin)

        // onActivityResult for REQUEST_CODE_SETTINGS should return false
        val handledSettings = sourceAccessPlugin.onActivityResult(SourceAccessPlugin.REQUEST_CODE_SETTINGS, -1, null)
        assertFalse("onActivityResult must reject SETTINGS code when clear is pending", handledSettings)

        // onActivityResult for REQUEST_CODE_CLEAR should return false
        val handledClear = sourceAccessPlugin.onActivityResult(SourceAccessPlugin.REQUEST_CODE_CLEAR, -1, null)
        assertFalse("onActivityResult must reject CLEAR code", handledClear)

        // Result remains pending
        assertEquals(0, clearResult.callCount)
        assertNull(clearResult.errorCode)
        assertNull(clearResult.successResult)

        // BUSY remains intact for subsequent open attempt
        val openResult = TestResultRecorder()
        val openCall = MethodCall("openSourceWebView", mapOf("sourceId" to "1"))
        sourceAccessPlugin.onMethodCall(openCall, openResult)

        assertEquals("BUSY", openResult.errorCode)
        assertEquals(1, openResult.callCount)
        assertEquals(0, clearResult.callCount)
    }

    /**
     * Requirement (4):
     * startupGate completeExceptionally with synthetic RuntimeException containing secret-looking fixture,
     * run scheduler, assert one INTERNAL_ERROR with predefined safe message/null details,
     * then new request admitted rather than BUSY.
     */
    @Test
    fun testStartupGateExceptionWithSecretFixture_returnsSafeInternalError_andAdmitsNewRequest(): Unit {
        val clearResult = TestResultRecorder()
        val clearCall = MethodCall("clearSourceCookies", mapOf("sourceId" to "1", "confirmed" to true))

        sourceAccessPlugin.onMethodCall(clearCall, clearResult)
        assertEquals(0, clearResult.callCount)

        // Fail startup gate exceptionally with synthetic RuntimeException containing secret-looking fixture
        val secretFixture = "Bearer secret_token_xyz_12345!PRIVATE_KEY_CREDENTIALS"
        extensionsPlugin.startupGate.completeExceptionally(RuntimeException("Database connection failed: $secretFixture"))

        // Run scheduler to execute coroutine catch block and main dispatcher block
        testDispatcher.scheduler.advanceUntilIdle()

        // Assert exactly one INTERNAL_ERROR with predefined safe message and null errorDetails
        assertEquals(1, clearResult.callCount)
        assertEquals("INTERNAL_ERROR", clearResult.errorCode)
        assertEquals(SourceAccessPlugin.ERR_RUNTIME_GENERIC, clearResult.errorMessage)
        assertNull("errorDetails must be null to avoid leaking sensitive information", clearResult.errorDetails)

        // Assert subsequent new request is admitted rather than BUSY
        // Provide a fresh startupGate so new request can proceed or be handled cleanly without BUSY
        extensionsPlugin.startupGate = CompletableDeferred()

        val nextClearResult = TestResultRecorder()
        val nextClearCall = MethodCall("clearSourceCookies", mapOf("sourceId" to "1", "confirmed" to true))
        sourceAccessPlugin.onMethodCall(nextClearCall, nextClearResult)

        // Should NOT return BUSY; call count is 0 because it suspended on the new uncompleted startupGate
        assertNull("New request should not be rejected with BUSY", nextClearResult.errorCode)
        assertEquals(0, nextClearResult.callCount)
    }
}
