package com.aiformvault.ui

import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.aiformvault.ManualFact
import com.aiformvault.Ocr
import com.aiformvault.bestFacts
import com.aiformvault.whereToFind
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Snap-to-Fill (FR-SNAP): photograph a blank form → find its labels → suggest values from the confirmed profile →
 * the user reviews every field (FR-SNAP-05/06) → values are written onto the image → share it.
 * Corrections go back into the profile so the next form is right first time.
 */
@Composable
fun SnapFillScreen(state: AppState) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var form by remember { mutableStateOf<Bitmap?>(null) }
    val fields = remember { mutableStateListOf<Ocr.FormField>() }
    var result by remember { mutableStateOf<Bitmap?>(null) }
    var zoom by remember { mutableStateOf(false) }

    val scan = rememberScanner(1, { state.message = it }) { pages ->
        busy = true
        scope.launch {
            runCatching { withContext(Dispatchers.Default) { Ocr.detectFields(ctx, pages[0], bestFacts(state.data)) } }
                .onSuccess { (bmp, fs) -> form = bmp; fields.clear(); fields += fs; result = null }
                .onFailure { state.message = "Couldn't read that form: ${it.message}" }
            busy = false
        }
    }

    fun fill() {
        val f = form ?: return
        val best = bestFacts(state.data)
        val corrections = fields.filter { it.key != null && it.value.isNotBlank() && it.value.trim() != best[it.key] }
        val filled = fields.count { it.value.isNotBlank() }
        state.update { d ->
            d.copy(
                manual = d.manual.filter { m -> corrections.none { it.key == m.key } } +
                    corrections.map { ManualFact(it.key!!, it.value.trim(), System.currentTimeMillis()) },
                fieldsFilled = d.fieldsFilled + filled,
            )
        }
        busy = true
        scope.launch {
            result = withContext(Dispatchers.Default) { Ocr.render(f, fields.toList()) }
            busy = false
            if (corrections.isNotEmpty()) state.message = "Saved ${corrections.size} correction${if (corrections.size > 1) "s" else ""} to your profile"
        }
    }

    fun share(bmp: Bitmap) = scope.launch {
        val uri = withContext(Dispatchers.IO) {
            Ocr.cacheFile(ctx, "jpg").also { file -> file.outputStream().use { bmp.compress(Bitmap.CompressFormat.JPEG, 92, it) } }.let { Ocr.shareUri(ctx, it) }
        }
        Session.external = true
        ctx.startActivity(Intent.createChooser(
            Intent(Intent.ACTION_SEND).setType("image/jpeg").putExtra(Intent.EXTRA_STREAM, uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),
            "Share filled form"))
    }

    val done = result
    Screen("SnapFill", onBack = state::back, actions = { if (form != null && !busy) MoreMenu("Use a different photo" to scan) }, dock = when {
        busy -> null
        done != null -> ({
            Btn("Share", icon = Ic.share) { share(done) }
            Btn("Edit fields", BtnKind.Line) { result = null }
        })
        form != null -> ({
            Btn("Fill this form", icon = Ic.form, onClick = ::fill)
            Btn("Use a different photo", BtnKind.Line, onClick = scan)
        })
        else -> ({ Btn("Photograph a form", icon = Ic.scan, onClick = scan) })
    }) {
        when {
            busy -> Column(Modifier.fillMaxWidth().padding(vertical = 64.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Spinner(28.dp); Spacer(Modifier.height(14.dp)); SuText("Working on this phone…")
            }
            done != null -> {
                TiText("Filled form", Modifier.padding(horizontal = 4.dp))
                Para("Check the preview. Tap it to zoom.", top = 4.dp)
                Spacer(Modifier.height(16.dp))
                Image(done.asImageBitmap(), "Filled form, tap to zoom", contentScale = ContentScale.FillWidth,
                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).border(1.dp, C.line, RoundedCornerShape(24.dp)).clickable { zoom = true })
            }
            form != null -> {
                val found = fields.count { it.value.isNotBlank() }
                TiText("$found of ${fields.size} fields filled", Modifier.padding(horizontal = 4.dp))
                Para("Filled from your vault. Review each field before you submit.", top = 4.dp)
                Spacer(Modifier.height(16.dp))
                if (fields.isEmpty()) Note(true, Ic.alert, "No fields found", "Try a flatter, sharper photo of the form.")
                fields.forEachIndexed { i, f ->
                    val where = f.key?.takeIf { f.value.isBlank() }?.let(whereToFind::get)
                    val label = f.key?.label?.takeIf { it != f.label }?.let { "${f.label} (${it.lowercase()})" } ?: f.label
                    if (f.options.isNotEmpty()) {
                        Text(label, Modifier.padding(start = 4.dp, bottom = 6.dp), fontSize = 12.sp, color = C.ink2)
                        Chips(listOf("") + f.options.keys, f.value, { it.ifEmpty { "None" } }) { fields[i] = f.copy(value = it) }
                    } else Tf(label, f.value, { fields[i] = f.copy(value = it) }, miss = f.key != null && f.value.isBlank(),
                        placeholder = where?.let { "Not set. It's on your $it." } ?: "Not set. Type it, or leave it blank.")
                }
            }
            else -> {
                TiText("Photograph any blank form", Modifier.padding(horizontal = 4.dp))
                Para("A scholarship, admission, bank or KYC form on paper. The app finds the fields, fills them from your confirmed details, and you check everything before sharing or printing.", top = 4.dp)
                Spacer(Modifier.height(16.dp))
                Note(false, Ic.info, "Works best when", "The form is flat and well lit, labels are printed (not handwritten), and you've scanned your own ID documents first.")
            }
        }
    }

    if (zoom && done != null) Dialog(onDismissRequest = { zoom = false }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(Modifier.fillMaxSize().background(Color.Black)) {
            ZoomImage(done)
            TextButton(onClick = { zoom = false }, Modifier.align(Alignment.TopEnd).padding(16.dp)) { Text("Close", color = Color.White) }
        }
    }
}
