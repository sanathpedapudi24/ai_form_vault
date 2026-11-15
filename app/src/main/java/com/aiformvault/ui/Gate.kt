package com.aiformvault.ui

import androidx.activity.compose.LocalActivity
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK
import androidx.biometric.BiometricPrompt
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

fun biometricAvailable(ctx: android.content.Context) =
    BiometricManager.from(ctx).canAuthenticate(BIOMETRIC_STRONG or BIOMETRIC_WEAK) == BiometricManager.BIOMETRIC_SUCCESS

fun promptBiometric(activity: FragmentActivity, title: String, onSuccess: () -> Unit) {
    BiometricPrompt(activity, ContextCompat.getMainExecutor(activity), object : BiometricPrompt.AuthenticationCallback() {
        override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) = onSuccess()
    }).authenticate(
        BiometricPrompt.PromptInfo.Builder().setTitle(title).setNegativeButtonText("Use PIN")
            .setAllowedAuthenticators(BIOMETRIC_STRONG or BIOMETRIC_WEAK).build()
    )
}

private data class Slide(val title: String, val body: String)

private val slides = listOf(
    Slide("Store once.\nUnderstand forever.\nReuse everywhere.",
        "Scan your Aadhaar, PAN, marksheets and more. The app reads them and builds your profile from the details you confirm."),
    Slide("Private by design.",
        "Everything is read and stored on this phone, encrypted. No account, no cloud, no uploads. Your Aadhaar never leaves your hands."),
    Slide("Fill forms in seconds.",
        "Photograph a paper form and it's filled from your profile. Apps and websites can autofill your details too, when you allow it."),
)

@Composable
fun Onboarding(state: AppState) {
    val pager = rememberPagerState { slides.size }
    val scope = rememberCoroutineScope()
    fun finish() { state.lock.onboarded = true; state.gate = if (state.lock.hasPin) Gate.NONE else Gate.PIN_SETUP }
    Column(Modifier.fillMaxSize().safeDrawingPadding().padding(24.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) { TextButton(onClick = ::finish) { Text("Skip") } }
        HorizontalPager(pager, Modifier.weight(1f)) { i ->
            Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.Center) {
                Text(slides[i].title, style = MaterialTheme.typography.headlineLarge)
                Spacer(Modifier.height(16.dp))
                Text(slides[i].body, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Row(Modifier.fillMaxWidth().padding(vertical = 16.dp), horizontalArrangement = Arrangement.Center) {
            repeat(slides.size) { i ->
                Spacer(Modifier.padding(4.dp).size(8.dp).background(if (i == pager.currentPage) Brand.Emerald else Brand.Surface2, CircleShape))
            }
        }
        Button(
            onClick = { if (pager.currentPage == slides.lastIndex) finish() else scope.launch { pager.animateScrollToPage(pager.currentPage + 1) } },
            Modifier.fillMaxWidth().height(52.dp),
        ) { Text(if (pager.currentPage == slides.lastIndex) "Get started" else "Next") }
    }
}

/** Create a PIN (enter + confirm), then offer fingerprint. Skippable, with a nag on Home. */
@Composable
fun PinSetup(state: AppState, onFinish: () -> Unit = { state.gate = Gate.NONE; state.locked = false }) {
    val ctx = LocalContext.current
    var first by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var askBio by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().safeDrawingPadding()) {
        if (askBio) {
            Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center) {
                Text("Unlock with your fingerprint too?", style = MaterialTheme.typography.headlineMedium)
                Spacer(Modifier.height(12.dp))
                Muted("Your PIN still works, and is needed if fingerprint fails.")
                Spacer(Modifier.height(24.dp))
                Button(onClick = { state.lock.biometric = true; onFinish() }, Modifier.fillMaxWidth().height(52.dp)) { Text("Use fingerprint") }
                TextButton(onClick = onFinish, Modifier.fillMaxWidth()) { Text("PIN only") }
            }
        } else PinPad(
            title = if (first == null) "Create a PIN" else "Confirm your PIN",
            subtitle = "4 digits to unlock your vault",
            error = error,
            onDone = { pin ->
                when {
                    first == null -> { first = pin; error = null }
                    pin == first -> {
                        state.lock.setPin(pin); state.lock.pinSkipped = false
                        if (biometricAvailable(ctx)) askBio = true else onFinish()
                    }
                    else -> { first = null; error = "PINs didn't match. Try again." }
                }
            },
        ) {
            if (state.gate == Gate.PIN_SETUP) TextButton(onClick = { state.lock.pinSkipped = true; onFinish() }) { Text("Skip for now") }
            else TextButton(onClick = onFinish) { Text("Cancel") }
        }
    }
}

@Composable
fun LockScreen(state: AppState) {
    val activity = LocalActivity.current as FragmentActivity
    var error by remember { mutableStateOf<String?>(null) }
    var cooldown by remember { mutableLongStateOf(state.lock.cooldownMs()) }
    var forgot by remember { mutableStateOf(false) }
    val bio = state.lock.biometric && biometricAvailable(activity)
    fun unlock() { state.locked = false }

    LaunchedEffect(Unit) { if (bio) promptBiometric(activity, "Unlock AI Form & Vault", ::unlock) }
    LaunchedEffect(cooldown > 0) {
        while (cooldown > 0) { delay(1000); cooldown = state.lock.cooldownMs() }
    }

    Column(Modifier.fillMaxSize().safeDrawingPadding()) {
        PinPad(
            title = "Enter your PIN",
            subtitle = null,
            error = if (cooldown > 0) "Too many attempts. Try again in ${(cooldown + 999) / 1000}s." else error,
            enabled = cooldown == 0L,
            onDone = { pin ->
                if (state.lock.check(pin)) unlock()
                else { error = "Wrong PIN"; cooldown = state.lock.cooldownMs() }
            },
        ) {
            Row(horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                if (bio) OutlinedButton(onClick = { promptBiometric(activity, "Unlock AI Form & Vault", ::unlock) }) { Text("Use fingerprint") }
                TextButton(onClick = { forgot = true }) { Text("Forgot PIN?") }
            }
        }
    }
    if (forgot) AlertDialog(
        onDismissRequest = { forgot = false },
        title = { Text("Erase the vault?") },
        text = { Text("There's no account to recover your PIN through, so the only way back in is to erase everything in the vault on this phone. If you have an encrypted backup, you can restore it afterwards.") },
        confirmButton = { TextButton(onClick = { forgot = false; state.wipe() }) { Text("Erase everything", color = MaterialTheme.colorScheme.error) } },
        dismissButton = { TextButton(onClick = { forgot = false }) { Text("Cancel") } },
    )
}
