package com.example.manga_reader_app

import android.app.Application
import android.graphics.Color
import android.util.TypedValue
import android.view.ContextThemeWrapper
import androidx.core.graphics.ColorUtils
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class)
class SourceAccessThemeTest {

    private fun resolvePrimaryTextColor(themeResId: Int): Int {
        val app = RuntimeEnvironment.getApplication()
        val themedContext = ContextThemeWrapper(app, themeResId)
        val typedValue = TypedValue()
        val resolved = themedContext.theme.resolveAttribute(android.R.attr.textColorPrimary, typedValue, true)
        assertTrue("android.R.attr.textColorPrimary should resolve in Theme.SourceAccess", resolved)

        return if (typedValue.type >= TypedValue.TYPE_FIRST_COLOR_INT && typedValue.type <= TypedValue.TYPE_LAST_COLOR_INT) {
            typedValue.data
        } else {
            val a = themedContext.obtainStyledAttributes(typedValue.resourceId, intArrayOf(android.R.attr.textColorPrimary))
            val color = a.getColor(0, Color.BLACK)
            a.recycle()
            color
        }
    }

    @Test
    @Config(qualifiers = "notnight")
    fun testTextColorContrastOnWhiteBackground_dayMode() {
        val textColor = resolvePrimaryTextColor(R.style.Theme_SourceAccess)
        val hardcodedBackground = Color.WHITE
        val contrastRatio = ColorUtils.calculateContrast(textColor, hardcodedBackground)

        assertTrue(
            "Primary text color (0x${Integer.toHexString(textColor)}) contrast on hardcoded Color.WHITE ($contrastRatio) must be >= 4.5 in day mode",
            contrastRatio >= 4.5
        )
    }

    @Test
    @Config(qualifiers = "night")
    fun testTextColorContrastOnWhiteBackground_nightMode() {
        val textColor = resolvePrimaryTextColor(R.style.Theme_SourceAccess)
        val hardcodedBackground = Color.WHITE
        val contrastRatio = ColorUtils.calculateContrast(textColor, hardcodedBackground)

        // Under Theme.AppCompat.DayNight, night mode resolves textColorPrimary to white/light text.
        // When combined with a hardcoded Color.WHITE root background, this creates invisible white-on-white text.
        // This test asserts accessible contrast (>= 4.5) against Color.WHITE, which fails (RED) on unadapted DayNight themes.
        assertTrue(
            "Primary text color (0x${Integer.toHexString(textColor)}) contrast on hardcoded Color.WHITE ($contrastRatio) must be >= 4.5 in night mode",
            contrastRatio >= 4.5
        )
    }
}
