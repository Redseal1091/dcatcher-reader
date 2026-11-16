package com.example.manga_reader_app

import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.commit
import androidx.preference.PreferenceFragmentCompat
import androidx.preference.PreferenceScreen
import eu.kanade.tachiyomi.source.ConfigurableSource

class SourceSettingsActivity : AppCompatActivity() {

    companion object {
        private const val FRAGMENT_CONTAINER_ID = 0x7f090001
        private const val KEY_SOURCE_ID = "key_source_id"
        private const val KEY_SOURCE_NAME = "key_source_name"
    }

    private var sourceId: String = ""
    private var sourceName: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val sessionToken = intent?.getStringExtra(SourceAccessSessions.EXTRA_SESSION_TOKEN)?.takeIf { it.isNotBlank() }
            ?: run {
                showProcessDeathError()
                return
            }
        val session = SourceAccessSessions.get(sessionToken)

        if (session == null) {
            // Process death or missing session
            showProcessDeathError()
            return
        }

        val source = session.source
        sourceId = source.id.toString()
        sourceName = source.name

        // Check if source implements ConfigurableSource
        val configurableSource = source as? ConfigurableSource
        if (configurableSource == null) {
            showUnsupportedError("Источник не поддерживает настройки", "Источник «$sourceName» не реализует ConfigurableSource.")
            return
        }

        // Validate source preference key
        val prefKey = try {
            SourceAccessPolicy.sourcePreferenceKey(sourceId)
        } catch (e: Exception) {
            showUnsupportedError("Некорректный ID источника", e.message ?: "Ошибка формирования ключа настроек")
            return
        }

        setupUI()
        setupBackNavigation()

        if (savedInstanceState == null) {
            val fragment = SourceSettingsFragment.newInstance(sessionToken, prefKey)
            supportFragmentManager.commit {
                replace(FRAGMENT_CONTAINER_ID, fragment)
            }
        }
    }

    private fun setupBackNavigation() {
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                // Return RESULT_OK so caller reloads preferences
                setResult(RESULT_OK)
                finish()
            }
        })
    }

    private fun setupUI() {
        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.WHITE)
        }

        // Action bar / Toolbar: Title + Done button
        val toolBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dpToPx(16), dpToPx(12), dpToPx(16), dpToPx(12))
            setBackgroundColor(Color.parseColor("#1F2937"))
        }

        val backButton = Button(this).apply {
            text = "◀"
            setTextColor(Color.WHITE)
            textSize = 14f
            setBackgroundColor(Color.TRANSPARENT)
            layoutParams = LinearLayout.LayoutParams(dpToPx(40), dpToPx(40))
            setOnClickListener {
                setResult(RESULT_OK)
                finish()
            }
        }

        val titleView = TextView(this).apply {
            text = "Настройки: $sourceName"
            setTextColor(Color.WHITE)
            textSize = 17f
            setTypeface(null, Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                leftMargin = dpToPx(8)
                rightMargin = dpToPx(8)
            }
        }

        val doneButton = Button(this).apply {
            text = "Готово"
            textSize = 13f
            setTypeface(null, Typeface.BOLD)
            setOnClickListener {
                setResult(RESULT_OK)
                finish()
            }
        }

        toolBar.addView(backButton)
        toolBar.addView(titleView)
        toolBar.addView(doneButton)

        // Fragment Container
        val fragmentContainer = FrameLayout(this).apply {
            id = FRAGMENT_CONTAINER_ID
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }

        rootLayout.addView(toolBar)
        rootLayout.addView(fragmentContainer)
        SourceAccessInsets.applyEdgeToEdgeInsets(rootLayout)
        setContentView(rootLayout)
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
            text = "Пожалуйста, вернитесь в приложение и откройте настройки заново."
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

    private fun showUnsupportedError(title: String, message: String) {
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

    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics
        ).toInt()
    }

    class SourceSettingsFragment : PreferenceFragmentCompat() {

        companion object {
            private const val ARG_SESSION_TOKEN = "arg_session_token"
            private const val ARG_PREF_KEY = "arg_pref_key"

            fun newInstance(sessionToken: String, prefKey: String): SourceSettingsFragment {
                val fragment = SourceSettingsFragment()
                val args = Bundle().apply {
                    putString(ARG_SESSION_TOKEN, sessionToken)
                    putString(ARG_PREF_KEY, prefKey)
                }
                fragment.arguments = args
                return fragment
            }
        }

        override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
            val token = arguments?.getString(ARG_SESSION_TOKEN)
            val prefKey = arguments?.getString(ARG_PREF_KEY)

            val session = if (!token.isNullOrBlank()) SourceAccessSessions.get(token) else null
            if (session == null || prefKey.isNullOrBlank()) {
                return
            }

            val configurableSource = session.source as? ConfigurableSource ?: return

            // Bind preferenceManager.sharedPreferencesName BEFORE creating PreferenceScreen
            preferenceManager.sharedPreferencesName = prefKey
            preferenceManager.sharedPreferencesMode = android.content.Context.MODE_PRIVATE

            val context = preferenceManager.context
            val screen: PreferenceScreen = preferenceManager.createPreferenceScreen(context)

            // Setup preference screen using the actual ConfigurableSource on main thread
            try {
                configurableSource.setupPreferenceScreen(screen)
            } catch (e: Exception) {
                // Handle any error gracefully
            }

            preferenceScreen = screen
        }
    }
}
