package com.example.manga_reader_app

import android.view.View
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

object SourceAccessInsets {

    /**
     * Data class to track initial padding of a View before insets were applied.
     */
    data class InitialPadding(
        val left: Int,
        val top: Int,
        val right: Int,
        val bottom: Int
    )

    /**
     * Tags used to track initial padding and listener registration.
     */
    private val INITIAL_PADDING_KEY = "SourceAccessInsets_initial_padding".hashCode()

    /**
     * Inset types to apply as padding on edge-to-edge screens.
     * System bars include statusBars() and navigationBars().
     * displayCutout() handles notch/camera cutouts (e.g., Pixel 7).
     * ime() handles software keyboard insets so inputs/buttons stay accessible
     * while bottom system bar insets are deduplicated by taking the max.
     */
    val INSET_MASK = WindowInsetsCompat.Type.systemBars() or
            WindowInsetsCompat.Type.displayCutout() or
            WindowInsetsCompat.Type.ime()

    /**
     * Applies system window insets (status bar, navigation bar, display cutout, and IME)
     * as padding on the given view.
     *
     * Ensures:
     * 1. Initial padding defined in XML or code is preserved.
     * 2. Multiple inset dispatches (e.g. rotation, keyboard show/hide, window focus change)
     *    never accumulate padding.
     * 3. IME insets take precedence over navigation bars for bottom padding without double counting.
     * 4. If the view is already attached, requests apply insets immediately; otherwise requests
     *    insets when attached to window.
     */
    fun applyEdgeToEdgeInsets(view: View): View {
        val initialPadding = (view.getTag(INITIAL_PADDING_KEY) as? InitialPadding) ?: run {
            val record = InitialPadding(
                left = view.paddingLeft,
                top = view.paddingTop,
                right = view.paddingRight,
                bottom = view.paddingBottom
            )
            view.setTag(INITIAL_PADDING_KEY, record)
            record
        }

        ViewCompat.setOnApplyWindowInsetsListener(view) { v, windowInsets ->
            computeAndApplyPadding(v, windowInsets, initialPadding)
            windowInsets
        }

        if (view.isAttachedToWindow) {
            ViewCompat.requestApplyInsets(view)
        } else {
            view.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
                override fun onViewAttachedToWindow(v: View) {
                    v.removeOnAttachStateChangeListener(this)
                    ViewCompat.requestApplyInsets(v)
                }

                override fun onViewDetachedFromWindow(v: View) {
                    // No-op
                }
            })
        }

        return view
    }

    /**
     * Computes the new padding given the initial padding and WindowInsetsCompat,
     * then applies it to the View.
     */
    fun computeAndApplyPadding(
        view: View,
        windowInsets: WindowInsetsCompat,
        initialPadding: InitialPadding
    ) {
        val insets = windowInsets.getInsets(INSET_MASK)
        val newLeft = initialPadding.left + insets.left
        val newTop = initialPadding.top + insets.top
        val newRight = initialPadding.right + insets.right
        val newBottom = initialPadding.bottom + insets.bottom

        view.setPadding(newLeft, newTop, newRight, newBottom)
    }
}
