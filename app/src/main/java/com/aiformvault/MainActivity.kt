package com.aiformvault

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.fragment.app.FragmentActivity
import com.aiformvault.ui.App
import com.aiformvault.ui.AppState
import com.aiformvault.ui.AppTheme
import com.aiformvault.ui.AuroraBackground
import com.aiformvault.ui.Session
import java.io.File

// FragmentActivity because BiometricPrompt needs one.
class MainActivity : FragmentActivity() {
    private lateinit var state: AppState

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Identity documents on screen: keep them out of screenshots, screen recordings and the recents preview.
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        enableEdgeToEdge()
        if (savedInstanceState == null) File(cacheDir, "share").deleteRecursively() // decrypted copies from past shares
        state = held ?: AppState(applicationContext).also { held = it }
        ExpiryWorker.schedule(this)
        setContent { AppTheme { AuroraBackground { App(state) } } }
    }

    override fun onResume() {
        super.onResume()
        Session.external = false
    }

    override fun onStop() {
        super.onStop()
        // Re-lock whenever the user leaves, but not for rotation or our own scanner/share/picker screens.
        if (!isChangingConfigurations && !Session.external && state.lock.hasPin) state.locked = true
    }

    companion object {
        /** Survives activity recreation (rotation); process death simply re-locks. */
        private var held: AppState? = null
    }
}
