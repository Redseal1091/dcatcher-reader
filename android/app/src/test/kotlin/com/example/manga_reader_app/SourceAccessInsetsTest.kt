package com.example.manga_reader_app

import android.app.Application
import android.graphics.Insets
import android.view.View
import android.view.WindowInsets
import androidx.core.graphics.Insets as CoreInsets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class)
class SourceAccessInsetsTest {

    @Test
    fun testInitialPaddingPreservedAndInsetsApplied() {
        val context = RuntimeEnvironment.getApplication()
        val view = View(context)
        view.setPadding(10, 20, 30, 40)

        SourceAccessInsets.applyEdgeToEdgeInsets(view)

        val insets = WindowInsetsCompat.Builder()
            .setInsets(
                WindowInsetsCompat.Type.systemBars(),
                CoreInsets.of(0, 75, 0, 50)
            )
            .build()

        ViewCompat.dispatchApplyWindowInsets(view, insets)

        assertEquals(10, view.paddingLeft)
        assertEquals(20 + 75, view.paddingTop)
        assertEquals(30, view.paddingRight)
        assertEquals(40 + 50, view.paddingBottom)
    }

    @Test
    fun testRepeatedDispatchDoesNotAccumulatePadding() {
        val context = RuntimeEnvironment.getApplication()
        val view = View(context)
        view.setPadding(15, 25, 35, 45)

        SourceAccessInsets.applyEdgeToEdgeInsets(view)

        val insets1 = WindowInsetsCompat.Builder()
            .setInsets(
                WindowInsetsCompat.Type.systemBars(),
                CoreInsets.of(0, 80, 0, 60)
            )
            .build()

        // First dispatch
        ViewCompat.dispatchApplyWindowInsets(view, insets1)
        assertEquals(15, view.paddingLeft)
        assertEquals(25 + 80, view.paddingTop)
        assertEquals(35, view.paddingRight)
        assertEquals(45 + 60, view.paddingBottom)

        // Second identical dispatch - should not double insets
        ViewCompat.dispatchApplyWindowInsets(view, insets1)
        assertEquals(15, view.paddingLeft)
        assertEquals(25 + 80, view.paddingTop)
        assertEquals(35, view.paddingRight)
        assertEquals(45 + 60, view.paddingBottom)

        // Third dispatch with changed insets
        val insets2 = WindowInsetsCompat.Builder()
            .setInsets(
                WindowInsetsCompat.Type.systemBars(),
                CoreInsets.of(5, 90, 5, 70)
            )
            .build()

        ViewCompat.dispatchApplyWindowInsets(view, insets2)
        assertEquals(15 + 5, view.paddingLeft)
        assertEquals(25 + 90, view.paddingTop)
        assertEquals(35 + 5, view.paddingRight)
        assertEquals(45 + 70, view.paddingBottom)
    }

    @Test
    @Config(sdk = [30])
    fun testCutoutAndImeHandlingWithoutDoublePadding() {
        val context = RuntimeEnvironment.getApplication()
        val view = View(context)
        view.setPadding(0, 0, 0, 0)

        SourceAccessInsets.applyEdgeToEdgeInsets(view)

        // System bars (nav bar 48, status bar 60) + IME (keyboard 300) + display cutout
        val insets = WindowInsetsCompat.Builder()
            .setInsets(
                WindowInsetsCompat.Type.statusBars(),
                CoreInsets.of(0, 60, 0, 0)
            )
            .setInsets(
                WindowInsetsCompat.Type.navigationBars(),
                CoreInsets.of(0, 0, 0, 48)
            )
            .setInsets(
                WindowInsetsCompat.Type.ime(),
                CoreInsets.of(0, 0, 0, 300)
            )
            .setInsets(
                WindowInsetsCompat.Type.displayCutout(),
                CoreInsets.of(0, 70, 0, 0) // Pixel 7 cutout at 70
            )
            .build()

        ViewCompat.dispatchApplyWindowInsets(view, insets)

        // getInsets with INSET_MASK unions statusBars, displayCutout, navigationBars, and ime
        val combined = insets.getInsets(SourceAccessInsets.INSET_MASK)
        assertEquals(combined.top, view.paddingTop)
        assertEquals(combined.bottom, view.paddingBottom)
        assertEquals(combined.left, view.paddingLeft)
        assertEquals(combined.right, view.paddingRight)

        // Top inset should be max/union (at least 70 for cutout)
        org.junit.Assert.assertTrue(view.paddingTop >= 70)
        // Bottom inset should be 300 (IME), not 348
        assertEquals(300, view.paddingBottom)
    }

    @Test
    fun testZeroInitialPaddingRemainsZeroWhenZeroInsets() {
        val context = RuntimeEnvironment.getApplication()
        val view = View(context)

        SourceAccessInsets.applyEdgeToEdgeInsets(view)

        val insets = WindowInsetsCompat.Builder()
            .setInsets(
                WindowInsetsCompat.Type.systemBars(),
                CoreInsets.of(0, 0, 0, 0)
            )
            .build()

        ViewCompat.dispatchApplyWindowInsets(view, insets)

        assertEquals(0, view.paddingLeft)
        assertEquals(0, view.paddingTop)
        assertEquals(0, view.paddingRight)
        assertEquals(0, view.paddingBottom)
    }
}
