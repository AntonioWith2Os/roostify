package com.dominigo.roostify

import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Some OEM Autofill services (observed on this build's vivo/BBK skin)
        // trigger a suggestion popup based on a field's hint/label text even
        // when Flutter reports autofillHints: const [] for that field. That
        // popup competing for window focus with the IME closes the soft
        // keyboard the moment a character is typed into an empty field.
        // Excluding the whole view tree from Autofill (rather than relying
        // on per-field opt-outs the OEM service ignores) stops the popup
        // from ever appearing.
        window.decorView.importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS

        // Without this, API 28+ reserves a hard safe-zone window around any
        // camera cutout whenever the device is in landscape (as the CCTV
        // fullscreen player forces it to be), at the native window level —
        // before Flutter's own layout ever runs. That left a black gap the
        // fullscreen video/control overlay couldn't draw into no matter what
        // Flutter-side padding was removed. Letting content lay out under
        // the cutout's short edges is the standard fix for edge-to-edge
        // fullscreen media content.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }
}
