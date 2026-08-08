package com.dominigo.roostify

import android.os.Bundle
import android.view.View
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
    }
}
