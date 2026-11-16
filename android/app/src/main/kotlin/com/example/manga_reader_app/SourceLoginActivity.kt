package com.example.manga_reader_app

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Typeface
import android.net.http.SslError
import android.os.Build
import android.os.Bundle
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.SslErrorHandler
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import eu.kanade.tachiyomi.network.NetworkHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.get
import java.io.ByteArrayInputStream
import java.net.URI
import java.nio.charset.StandardCharsets

class SourceLoginActivity : AppCompatActivity() {

    private val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var currentHomeUrl: String = ""
    private var currentSourceName: String = ""

    private var rootLayout: LinearLayout? = null
    private var webView: WebView? = null
    private var progressBar: ProgressBar? = null
    private var originTextView: TextView? = null
    private var errorBanner: TextView? = null
    private var backButton: Button? = null
    private var refreshButton: Button? = null
    private var doneButton: Button? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Session lookup from memory store
        val sessionToken = intent?.getStringExtra(SourceAccessSessions.EXTRA_SESSION_TOKEN)
        val session = if (!sessionToken.isNullOrBlank()) SourceAccessSessions.get(sessionToken) else null

        if (session == null) {
            showProcessDeathError()
            return
        }

        val source = session.source
        currentSourceName = source.name
        currentHomeUrl = session.homeUrl

        if (!SourceAccessPolicy.isSafeWebUrl(currentHomeUrl)) {
            showError("Недопустимый URL источника", "URL источника не соответствует политике безопасности.")
            return
        }

        setupUI()
        setupBackNavigation()
        loadInitialPage()
    }

    private fun setupBackNavigation() {
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                val wv = webView
                if (wv != null && wv.canGoBack()) {
                    wv.goBack()
                } else {
                    handleDoneAndFinish()
                }
            }
        })
    }

    private fun showProcessDeathError() {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.WHITE)
            setPadding(dpToPx(24), dpToPx(24), dpToPx(24), dpToPx(24))
        }

        val titleView = TextView(this).apply {
            text = "Сессия устарела или процесс был перезапущен"
            textSize = 18f
            setTextColor(Color.DKGRAY)
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
        }

        val messageView = TextView(this).apply {
            text = "Пожалуйста, вернитесь в приложение и откройте веб-страницу источника заново."
            textSize = 14f
            setTextColor(Color.GRAY)
            gravity = Gravity.CENTER
            setPadding(0, dpToPx(12), 0, dpToPx(24))
        }

        val closeButton = Button(this).apply {
            text = "Закрыть"
            setOnClickListener {
                setResult(RESULT_CANCELED)
                finish()
            }
        }

        layout.addView(titleView)
        layout.addView(messageView)
        layout.addView(closeButton)
        SourceAccessInsets.applyEdgeToEdgeInsets(layout)
        setContentView(layout)
    }

    private fun showError(title: String, message: String) {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.WHITE)
            setPadding(dpToPx(24), dpToPx(24), dpToPx(24), dpToPx(24))
        }

        val titleView = TextView(this).apply {
            text = title
            textSize = 18f
            setTextColor(Color.RED)
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
        }

        val messageView = TextView(this).apply {
            text = message
            textSize = 14f
            setTextColor(Color.DKGRAY)
            gravity = Gravity.CENTER
            setPadding(0, dpToPx(12), 0, dpToPx(24))
        }

        val closeButton = Button(this).apply {
            text = "Закрыть"
            setOnClickListener {
                setResult(RESULT_CANCELED)
                finish()
            }
        }

        layout.addView(titleView)
        layout.addView(messageView)
        layout.addView(closeButton)
        SourceAccessInsets.applyEdgeToEdgeInsets(layout)
        setContentView(layout)
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun setupUI() {
        rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.WHITE)
        }

        // Top Header bar with source name
        val headerBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dpToPx(12), dpToPx(8), dpToPx(12), dpToPx(8))
            setBackgroundColor(Color.parseColor("#1F2937"))
        }

        val sourceTitle = TextView(this).apply {
            text = currentSourceName
            setTextColor(Color.WHITE)
            textSize = 16f
            setTypeface(null, Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }
        headerBar.addView(sourceTitle)

        // Navigation toolbar: Back, Refresh, Origin bar, Готово
        val toolBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dpToPx(8), dpToPx(4), dpToPx(8), dpToPx(4))
            setBackgroundColor(Color.parseColor("#F3F4F6"))
        }

        backButton = Button(this).apply {
            text = "◀"
            textSize = 14f
            layoutParams = LinearLayout.LayoutParams(dpToPx(44), dpToPx(38))
            setOnClickListener {
                val wv = webView
                if (wv != null && wv.canGoBack()) {
                    wv.goBack()
                } else {
                    handleDoneAndFinish()
                }
            }
        }

        refreshButton = Button(this).apply {
            text = "↻"
            textSize = 14f
            layoutParams = LinearLayout.LayoutParams(dpToPx(44), dpToPx(38)).apply {
                leftMargin = dpToPx(4)
            }
            setOnClickListener {
                hideErrorBanner()
                webView?.reload()
            }
        }

        originTextView = TextView(this).apply {
            text = formatOriginDisplay(currentHomeUrl)
            textSize = 13f
            setTextColor(Color.parseColor("#111827"))
            setBackgroundColor(Color.parseColor("#E5E7EB"))
            setPadding(dpToPx(8), dpToPx(6), dpToPx(8), dpToPx(6))
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                leftMargin = dpToPx(6)
                rightMargin = dpToPx(6)
            }
        }

        doneButton = Button(this).apply {
            text = "Готово"
            textSize = 13f
            setTypeface(null, Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dpToPx(38))
            setOnClickListener {
                handleDoneAndFinish()
            }
        }

        toolBar.addView(backButton)
        toolBar.addView(refreshButton)
        toolBar.addView(originTextView)
        toolBar.addView(doneButton)

        // Progress bar
        progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dpToPx(3)
            )
            max = 100
            visibility = View.GONE
        }

        // Actionable Error Banner
        errorBanner = TextView(this).apply {
            visibility = View.GONE
            setBackgroundColor(Color.parseColor("#FEE2E2"))
            setTextColor(Color.parseColor("#991B1B"))
            textSize = 12f
            setPadding(dpToPx(12), dpToPx(8), dpToPx(12), dpToPx(8))
            setOnClickListener {
                visibility = View.GONE
            }
        }

        // Content Frame for WebView
        val contentFrame = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }

        // WebView configuration
        val wv = WebView(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        configureWebViewSecurity(wv)

        wv.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                if (newProgress < 100) {
                    progressBar?.visibility = View.VISIBLE
                    progressBar?.progress = newProgress
                } else {
                    progressBar?.visibility = View.GONE
                }
            }
        }

        wv.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val url = request?.url?.toString() ?: return true
                return handleNavigationCheck(view, url)
            }

            @Deprecated("Deprecated in Java")
            override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                if (url == null) return true
                return handleNavigationCheck(view, url)
            }

            // Note: shouldInterceptRequest only intercepts the initial resource request and does NOT
            // intercept internal redirect chains (e.g. 307 HTTPS->HTTP redirects), nor does
            // shouldOverrideUrlLoading capture POST redirects. The platform manifest setting
            // (android:usesCleartextTraffic="false") actually blocks plaintext redirects.
            // Request guards and origin commit checks remain in place for initial requests and UI updates.
            override fun shouldInterceptRequest(
                view: WebView?,
                request: WebResourceRequest?
            ): WebResourceResponse? {
                val url = request?.url?.toString()
                if (url == null || !SourceAccessPolicy.isSafeWebUrl(url)) {
                    val emptyStream = ByteArrayInputStream(ByteArray(0))
                    return WebResourceResponse(
                        "text/plain",
                        StandardCharsets.UTF_8.name(),
                        403,
                        "Forbidden",
                        mapOf("Cache-Control" to "no-store"),
                        emptyStream
                    )
                }
                return super.shouldInterceptRequest(view, request)
            }

            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                if (url != null) {
                    if (!SourceAccessPolicy.isSafeWebUrl(url)) {
                        view?.stopLoading()
                        showActionableError("Заблокирован небезопасный переход")
                        return
                    }
                    recordVisitedIfSameSite(url)
                }
            }

            override fun onPageCommitVisible(view: WebView?, url: String?) {
                super.onPageCommitVisible(view, url)
                if (url != null && SourceAccessPolicy.isSafeWebUrl(url)) {
                    updateOriginDisplay(url)
                }
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                if (url != null && SourceAccessPolicy.isSafeWebUrl(url)) {
                    recordVisitedIfSameSite(url)
                }
            }

            override fun onReceivedSslError(view: WebView?, handler: SslErrorHandler?, error: SslError?) {
                // SSL errors ALWAYS cancelled, never ignored
                handler?.cancel()

                val failingUrl = error?.url
                val mainHost = try {
                    val current = view?.url ?: currentHomeUrl
                    URI(current).host
                } catch (_: Exception) {
                    null
                }
                val failingHost = try {
                    if (failingUrl != null) URI(failingUrl).host else null
                } catch (_: Exception) {
                    null
                }

                val isSubresource = failingHost != null && mainHost != null && !failingHost.equals(mainHost, ignoreCase = true)
                if (isSubresource) {
                    showActionableError("Заблокирован небезопасный сторонний ресурс ($failingHost). Нажмите, чтобы скрыть.")
                } else {
                    showActionableError("Ошибка сертификата SSL: соединение небезопасно и было отменено.")
                }
            }

            override fun onReceivedHttpError(
                view: WebView?,
                request: WebResourceRequest?,
                errorResponse: WebResourceResponse?
            ) {
                super.onReceivedHttpError(view, request, errorResponse)
                if (request?.isForMainFrame == true) {
                    val code = errorResponse?.statusCode ?: 0
                    if (code >= 400) {
                        showActionableError("Ошибка загрузки страницы: HTTP $code")
                    }
                }
            }
        }

        this.webView = wv
        contentFrame.addView(wv)

        rootLayout?.addView(headerBar)
        rootLayout?.addView(toolBar)
        rootLayout?.addView(progressBar)
        rootLayout?.addView(errorBanner)
        rootLayout?.addView(contentFrame)

        rootLayout?.let { SourceAccessInsets.applyEdgeToEdgeInsets(it) }
        setContentView(rootLayout)
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun configureWebViewSecurity(wv: WebView) {
        val settings = wv.settings

        // JS + DOM required for modern logins
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true

        // File access hardening
        settings.allowFileAccess = false
        settings.allowContentAccess = false
        settings.allowFileAccessFromFileURLs = false
        settings.allowUniversalAccessFromFileURLs = false

        // Mixed content completely blocked
        settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW

        // Safe browsing enabled
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            settings.safeBrowsingEnabled = true
        }

        // Disable geolocation, downloads and media autofill
        settings.setGeolocationEnabled(false)

        // Matching user agent from NetworkHelper if available
        try {
            val networkHelper = Injekt.get<NetworkHelper>()
            val ua = networkHelper.defaultUserAgentProvider()
            if (ua.isNotBlank()) {
                settings.userAgentString = ua
            }
        } catch (_: Exception) {
            // Keep default WebSettings user agent if Injekt binding unavailable
        }

        // SharedCookieManager singleton: SAME as AndroidCookieJar
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
        cookieManager.setAcceptThirdPartyCookies(wv, true)

        // No JavaScriptInterface, no download listener, no WebChromeClient file chooser override
        wv.setDownloadListener(null)
    }

    private fun handleNavigationCheck(view: WebView?, url: String): Boolean {
        // Only HTTPS URLs allowed (no userinfo, port -1 or 443)
        // Block file:, content:, javascript:, data:, intent:, http:
        if (!SourceAccessPolicy.isSafeWebUrl(url)) {
            showActionableError("Заблокирован небезопасный переход")
            return true
        }

        // Check if destination is source cookie host OR a valid HTTPS OAuth redirect
        val isSameOriginSite = SourceAccessPolicy.isSourceCookieHost(currentHomeUrl, url)
        if (isSameOriginSite) {
            hideErrorBanner()
            return false // Let WebView load
        }

        // OAuth / external login flow: allow valid HTTPS URLs
        hideErrorBanner()
        return false // Allow navigation within safe HTTPS
    }

    private fun recordVisitedIfSameSite(url: String) {
        if (SourceAccessPolicy.isSourceCookieHost(currentHomeUrl, url)) {
            SourceCookieService.recordVisitedUrl(currentHomeUrl, url)
        }
    }

    private fun updateOriginDisplay(url: String) {
        val formattedOrigin = formatOriginDisplay(url)
        originTextView?.text = formattedOrigin
    }

    private fun formatOriginDisplay(url: String): String {
        return try {
            val uri = URI(url)
            val scheme = uri.scheme ?: "https"
            val host = uri.host ?: ""
            "$scheme://$host"
        } catch (_: Exception) {
            val httpUrl = url.toHttpUrlOrNull()
            if (httpUrl != null) {
                "${httpUrl.scheme}://${httpUrl.host}"
            } else {
                url.substringBefore('?').substringBefore('#')
            }
        }
    }

    private fun showActionableError(message: String) {
        errorBanner?.apply {
            text = message
            visibility = View.VISIBLE
        }
    }

    private fun hideErrorBanner() {
        errorBanner?.visibility = View.GONE
    }

    private fun loadInitialPage() {
        val wv = webView ?: return
        // Safe HTTPS home URL; no Authorization headers passed
        wv.loadUrl(currentHomeUrl)
    }

    private fun handleDoneAndFinish() {
        // Flush cookies off main thread, then finish with RESULT_OK
        activityScope.launch {
            withContext(Dispatchers.IO) {
                try {
                    CookieManager.getInstance().flush()
                } catch (_: Exception) {}
            }
            // Screen completion OK (no false verified login status)
            setResult(RESULT_OK)
            finish()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        activityScope.cancel()

        // Clean up WebView
        webView?.let { wv ->
            try {
                wv.stopLoading()
                wv.webChromeClient = null
                wv.webViewClient = WebViewClient()
                (wv.parent as? ViewGroup)?.removeView(wv)
                wv.destroy()
            } catch (_: Exception) {}
        }
        webView = null
        rootLayout = null
    }

    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}
