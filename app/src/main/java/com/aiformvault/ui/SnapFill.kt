package com.aiformvault.ui

import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
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
    Page(title = "Fill a form", onBack = state::back, bottom = when {
        busy -> null
        done != null -> ({
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedButton(onClick = { result = null }, Modifier.weight(1f).height(52.dp)) { Text("Edit values") }
                Button(onClick = { share(done) }, Modifier.weight(1f).height(52.dp)) { Text("Share") }
            }
        })
        form != null -> ({ Button(onClick = ::fill, Modifier.fillMaxWidth().height(52.dp)) { Text("Fill the form") } })
        else -> ({ Button(onClick = scan, Modifier.fillMaxWidth().height(52.dp)) { Text("Photograph a form") } })
    }) {
        when {
            busy -> Column(Modifier.fillMaxWidth().padding(vertical = 64.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                CircularProgressIndicator(); Spacer(Modifier.height(12.dp)); Muted("Working on this phone…")
            }
            done != null -> {
                Muted("Check the preview. Tap it to zoom.")
                Spacer(Modifier.height(12.dp))
                Image(done.asImageBitmap(), "Filled form", contentScale = ContentScale.FillWidth,
                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).clickable { zoom = true })
            }
            form != null -> {
                val found = fields.count { it.value.isNotBlank() }
                Text("$found of ${fields.size} fields filled from your profile", style = MaterialTheme.typography.titleMedium)
                Muted("Check each one. Empty fields didn't match anything you've confirmed: type them in, or leave them blank.")
                Spacer(Modifier.height(12.dp))
                if (fields.isEmpty()) Muted("No fields found. Try a flatter, sharper photo of the form.")
                fields.forEachIndexed { i, f ->
                    val where = f.key?.takeIf { f.value.isBlank() }?.let(whereToFind::get)
                    val hint: (@Composable () -> Unit)? = where?.let { w -> @Composable { Text("Found on: $w") } }
                    if (f.options.isNotEmpty()) Column(Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                        Text("${f.label} (tick box)", style = MaterialTheme.typography.labelLarge)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            f.options.keys.forEach { o -> FilterChip(f.value == o, { fields[i] = f.copy(value = if (f.value == o) "" else o) }, label = { Text(o) }) }
                        }
                        hint?.invoke()
                    } else OutlinedTextField(
                        f.value, { fields[i] = f.copy(value = it) },
                        label = { Text(f.key?.label?.let { k -> "${f.label}  →  $k" } ?: f.label) },
                        singleLine = true, modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
                        isError = f.key != null && f.value.isBlank(), supportingText = hint,
                    )
                }
                TextButton(onClick = scan) { Text("Use a different photo") }
            }
            else -> {
                Text("Photograph any blank form", style = MaterialTheme.typography.headlineSmall)
                Spacer(Modifier.height(8.dp))
                Muted("A scholarship, admission, bank or KYC form on paper. The app finds the fields, fills them from your confirmed details, and you check everything before sharing or printing.")
                Spacer(Modifier.height(16.dp))
                SoftCard(color = Brand.MintSoft) {
                    Text("Works best when", style = MaterialTheme.typography.titleSmall)
                    Muted("• the form is flat and well lit\n• labels are printed (not handwritten)\n• you've scanned your own ID documents first")
                }
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
