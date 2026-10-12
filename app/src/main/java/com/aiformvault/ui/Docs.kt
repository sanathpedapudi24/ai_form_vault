package com.aiformvault.ui

import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.aiformvault.Category
import com.aiformvault.DocType
import com.aiformvault.Document
import com.aiformvault.Fact
import com.aiformvault.FactKey
import com.aiformvault.Ocr
import com.aiformvault.Person
import com.aiformvault.Relation
import com.aiformvault.Store
import com.aiformvault.expectedFacts
import com.aiformvault.mask
import com.aiformvault.sameName
import com.aiformvault.suggestRelations
import com.aiformvault.suggestTitle
import com.aiformvault.titleCase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

private const val ME = "me"
private const val OTHER = "other"

/** Every extracted value is a suggestion: the user checks, fixes or drops each before anything is saved (FR-OCR-10). */
@Composable
fun ReviewScreen(state: AppState, r: Route.Review) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val data = state.data
    var type by remember(r) { mutableStateOf(r.type) }
    var category by remember(r) { mutableStateOf(r.type.category) }
    val facts = remember(r) { mutableStateListOf(*r.facts.toTypedArray()) }
    var title by remember(r) { mutableStateOf(suggestTitle(r.type, r.facts)) }
    val name = facts.firstOrNull { it.key == FactKey.NAME }?.value
    val family = data.people.filter { it.confirmed && it.relation != Relation.SELF }
    var owner by remember(r) {
        val self = data.self
        mutableStateOf(when {
            self == null || name == null || sameName(self.name, name) -> ME
            else -> family.firstOrNull { sameName(it.name, name) }?.id ?: OTHER
        })
    }
    var otherName by remember(r) { mutableStateOf(name?.let(::titleCase).orEmpty()) }
    var otherRelation by remember(r) { mutableStateOf(Relation.OTHER) }
    var saving by remember { mutableStateOf(false) }
    var sendText by remember { mutableStateOf(false) }

    fun save() {
        saving = true
        scope.launch {
            val id = UUID.randomUUID().toString()
            runCatching { withContext(Dispatchers.IO) { Store.saveImages(ctx, id, r.pages) } }
                .onFailure { saving = false; state.message = "Couldn't save the images: ${it.message}"; return@launch }
            var d = state.data
            val ownerId = when (owner) {
                ME -> d.self?.id ?: Person(UUID.randomUUID().toString(), name?.let(::titleCase) ?: "Me", Relation.SELF, true)
                    .also { d = d.copy(people = d.people + it) }.id
                OTHER -> Person(UUID.randomUUID().toString(), otherName.ifBlank { "Family member" }.trim(), otherRelation, true)
                    .also { d = d.copy(people = d.people + it) }.id
                else -> owner
            }
            val doc = Document(id, type, category, title.ifBlank { type.label }.trim(), ownerId,
                facts.filter { it.value.isNotBlank() }.map { it.copy(value = it.value.trim()) }, r.pages.size, createdAt = System.currentTimeMillis())
            d = d.copy(documents = d.documents + doc)
            d = d.copy(people = d.people + suggestRelations(d, doc))
            state.update { d }
            state.replace(Route.Doc(id))
            state.message = "Saved to your vault"
        }
    }

    Page(title = "Check the details", onBack = state::back, bottom = {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedButton(onClick = state::back, Modifier.weight(1f).height(52.dp), enabled = !saving) { Text("Discard") }
            Button(onClick = ::save, Modifier.weight(1f).height(52.dp), enabled = !saving) {
                if (saving) CircularProgressIndicator(Modifier.height(20.dp).width(20.dp), color = Color.White, strokeWidth = 2.dp) else Text("Save")
            }
        }
    }) {
        Muted("Fix anything misread and clear anything wrong. Nothing is saved until you tap Save.")
        Spacer(Modifier.height(16.dp))
        Picker("Type", type, DocType.entries, { it.label }) { type = it; category = it.category; title = suggestTitle(it, facts) }
        Spacer(Modifier.height(8.dp))
        Picker("Category", category, Category.entries, { it.label }) { category = it }
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(title, { title = it }, label = { Text("Name in your vault") }, singleLine = true, modifier = Modifier.fillMaxWidth())

        Section("Whose document is this?")
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(owner == ME, { owner = ME }, label = { Text("Mine") })
            family.take(3).forEach { p -> FilterChip(owner == p.id, { owner = p.id }, label = { Text(p.name.substringBefore(' ')) }) }
            FilterChip(owner == OTHER, { owner = OTHER }, label = { Text("Someone else") })
        }
        if (owner == OTHER) {
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(otherName, { otherName = it }, label = { Text("Their name") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            Picker("They are your", otherRelation, Relation.entries.filter { it != Relation.SELF }, { it.label.lowercase() }) { otherRelation = it }
        }
        if (owner != ME) Muted("Details from this document stay with them, not in your profile.", Modifier.padding(top = 8.dp))

        Section("Details found")
        if (facts.isEmpty()) Muted("Nothing could be read automatically. Add the details you need below.")
        facts.forEachIndexed { i, f ->
            OutlinedTextField(
                f.value, { facts[i] = f.copy(value = it) }, label = { Text(f.key.label) }, singleLine = f.key != FactKey.ADDRESS,
                modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
                trailingIcon = { TextButton(onClick = { facts.removeAt(i) }) { Text("Clear") } },
            )
        }
        val missing = expectedFacts[type].orEmpty().filter { k -> facts.none { it.key == k && it.value.isNotBlank() } }
        if (missing.isNotEmpty()) Muted("Not found on this scan: ${missing.joinToString { it.label.lowercase() }}. " +
            "Add them if they're printed, or rescan flatter and better lit.", Modifier.padding(vertical = 8.dp))
        AddFieldMenu(FactKey.entries.filter { k -> facts.none { it.key == k } }) { facts += Fact(it, "") }
        if (r.text.isNotBlank()) TextButton(onClick = { sendText = true }) { Text("Send the scanned text (to report a misread)") }
    }

    if (sendText) AlertDialog(
        onDismissRequest = { sendText = false },
        title = { Text("Send the scanned text?") },
        text = { Text("It contains everything read from this document, including ID numbers. Change the numbers before sending, and only send it to someone you trust.") },
        confirmButton = {
            TextButton(onClick = {
                sendText = false
                Session.external = true
                ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain")
                    .putExtra(Intent.EXTRA_TEXT, "Type: ${type.label}\n---\n${r.text}"), "Send scanned text"))
            }) { Text("Continue") }
        },
        dismissButton = { TextButton(onClick = { sendText = false }) { Text("Cancel") } },
    )
}

@Composable
fun AddFieldMenu(keys: List<FactKey>, onPick: (FactKey) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        TextButton(onClick = { open = true }) { Text("+ Add a detail") }
        DropdownMenu(open, { open = false }) { keys.forEach { k -> DropdownMenuItem(text = { Text(k.label) }, onClick = { open = false; onPick(k) }) } }
    }
}

@Composable
private fun PageImage(docId: String, page: Int, maxPx: Int, content: @Composable (Bitmap?) -> Unit) {
    val ctx = LocalContext.current
    val bmp by produceState<Bitmap?>(null, docId, page) { value = withContext(Dispatchers.IO) { runCatching { Store.image(ctx, docId, page, maxPx) }.getOrNull() } }
    content(bmp)
}

@Composable
fun ZoomImage(bmp: Bitmap) {
    var scale by remember { mutableFloatStateOf(1f) }
    var offset by remember { mutableStateOf(Offset.Zero) }
    val t = rememberTransformableState { zoom, pan, _ -> scale = (scale * zoom).coerceIn(1f, 6f); offset += pan }
    Image(bmp.asImageBitmap(), "Document page, pinch to zoom", contentScale = ContentScale.Fit,
        modifier = Modifier.fillMaxSize().transformable(t).graphicsLayer(scaleX = scale, scaleY = scale, translationX = offset.x, translationY = offset.y))
}

@Composable
fun DocScreen(state: AppState, id: String) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val doc = state.data.documents.firstOrNull { it.id == id }
    if (doc == null) { LaunchedEffect(Unit) { state.back() }; return }
    var reveal by remember { mutableStateOf(false) }
    var zoom by remember { mutableStateOf<Int?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }
    var note by remember(doc.id) { mutableStateOf(doc.note) }
    val pager = rememberPagerState { doc.pages }

    fun share() = scope.launch {
        val uris = withContext(Dispatchers.IO) {
            (0 until doc.pages).mapNotNull { p -> Store.imageBytes(ctx, id, p)?.let { b -> Ocr.cacheFile(ctx, "jpg").also { it.writeBytes(b) }.let { Ocr.shareUri(ctx, it) } } }
        }
        if (uris.isEmpty()) return@launch
        val send = if (uris.size == 1) Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_STREAM, uris[0])
        else Intent(Intent.ACTION_SEND_MULTIPLE).putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
        send.setType("image/jpeg").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        Session.external = true
        ctx.startActivity(Intent.createChooser(send, "Share ${doc.title}"))
    }

    Page(title = doc.title, onBack = state::back) {
        if (doc.pages > 0) {
            HorizontalPager(pager, Modifier.fillMaxWidth().height(240.dp).clip(RoundedCornerShape(16.dp)).background(Brand.Surface)) { p ->
                PageImage(id, p, 1200) { bmp ->
                    Box(Modifier.fillMaxSize().clickable { zoom = p }, contentAlignment = Alignment.Center) {
                        if (bmp == null) CircularProgressIndicator()
                        else Image(bmp.asImageBitmap(), "Page ${p + 1}", contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize())
                    }
                }
            }
            Muted(if (doc.pages > 1) "Page ${pager.currentPage + 1} of ${doc.pages}  ·  swipe, tap to zoom" else "Tap to zoom", Modifier.padding(top = 6.dp))
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Chip(doc.type.label)
            state.data.person(doc.ownerId)?.let { Chip(it.name, Brand.InkMuted, Brand.Surface) }
            daysLeft(doc)?.takeIf { it <= 90 }?.let { ExpiryBadge(it) }
        }

        Section("Details", if (doc.facts.any { it.key.sensitive }) (if (reveal) "Hide numbers" else "Show numbers") else null) { reveal = !reveal }
        SoftCard {
            if (doc.facts.isEmpty()) Muted("No details saved for this document.")
            doc.facts.forEachIndexed { i, f ->
                if (i > 0) Spacer(Modifier.height(12.dp))
                Text(f.key.label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(if (reveal) f.value else mask(f.key, f.value), style = MaterialTheme.typography.bodyLarge)
            }
        }

        Section("Note")
        OutlinedTextField(note, { note = it }, placeholder = { Text("e.g. Used for NSP scholarship, 2026") }, minLines = 2, modifier = Modifier.fillMaxWidth())
        if (note != doc.note) TextButton(onClick = { state.update { d -> d.copy(documents = d.documents.map { if (it.id == id) it.copy(note = note.trim()) else it }) } }) { Text("Save note") }

        Spacer(Modifier.height(20.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Button(onClick = { state.go(Route.DigitalId(id)) }, Modifier.weight(1f).height(48.dp)) { Text("Digital ID") }
            OutlinedButton(onClick = { share() }, Modifier.weight(1f).height(48.dp)) { Text("Share") }
        }
        TextButton(onClick = { confirmDelete = true }, Modifier.fillMaxWidth()) { Text("Delete document", color = MaterialTheme.colorScheme.error) }
    }

    zoom?.let { p ->
        Dialog(onDismissRequest = { zoom = null }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
            Box(Modifier.fillMaxSize().background(Color.Black)) {
                PageImage(id, p, 3000) { bmp -> if (bmp != null) ZoomImage(bmp) }
                TextButton(onClick = { zoom = null }, Modifier.align(Alignment.TopEnd).padding(16.dp)) { Text("Close", color = Color.White) }
            }
        }
    }
    if (confirmDelete) AlertDialog(
        onDismissRequest = { confirmDelete = false },
        title = { Text("Delete ${doc.title}?") },
        text = { Text("The scan and its details are removed from this phone for good. Details in your profile that came only from this document go too.") },
        confirmButton = {
            TextButton(onClick = {
                confirmDelete = false
                Store.deleteImages(ctx, id)
                state.update { d -> d.copy(documents = d.documents.filter { it.id != id }) }
                state.back(); state.message = "Document deleted"
            }) { Text("Delete", color = MaterialTheme.colorScheme.error) }
        },
        dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Cancel") } },
    )
}

private val idNumberKeys = listOf(FactKey.AADHAAR, FactKey.PAN, FactKey.PASSPORT, FactKey.VOTER_ID, FactKey.DL_NUMBER, FactKey.VEHICLE_REG, FactKey.ROLL)

/** Wallet-style card for showing details on screen without handing over the phone's gallery or the original. */
@Composable
fun DigitalIdScreen(state: AppState, id: String) {
    val doc = state.data.documents.firstOrNull { it.id == id } ?: return
    val owner = state.data.person(doc.ownerId)
    var reveal by remember { mutableStateOf(false) }
    val f = doc.facts.associate { it.key to it.value }
    val number = idNumberKeys.firstNotNullOfOrNull { k -> f[k]?.let { k to it } }
    Page(title = "Digital ID", onBack = state::back) {
        Spacer(Modifier.height(12.dp))
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp))
                .background(Brush.linearGradient(listOf(Color(0xFF064E3B), Brand.TealDeep, Color(0xFF115E59))))
                .padding(24.dp)
        ) {
            Row {
                Text(doc.type.label.uppercase(), color = Brand.Mint, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.5.sp, modifier = Modifier.weight(1f))
                Text("AI Form & Vault", color = Color.White.copy(alpha = 0.6f), fontSize = 12.sp)
            }
            Spacer(Modifier.height(28.dp))
            Text(f[FactKey.NAME]?.let(::titleCase) ?: owner?.name.orEmpty(), color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.SemiBold)
            number?.let { (k, v) ->
                Spacer(Modifier.height(14.dp))
                Text(k.label, color = Color.White.copy(alpha = 0.6f), fontSize = 12.sp)
                Text(if (reveal) v else mask(k, v), color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Medium, letterSpacing = 2.sp,
                    modifier = Modifier.clickable { reveal = !reveal })
            }
            Spacer(Modifier.height(20.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                listOf(FactKey.DOB, FactKey.GENDER, FactKey.EXPIRY).forEach { k ->
                    f[k]?.let { v ->
                        Column {
                            Text(k.label, color = Color.White.copy(alpha = 0.6f), fontSize = 12.sp)
                            Text(v, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Medium)
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(16.dp))
        Muted("Tap the number to reveal it. This card is a quick reference from your own scan, not an official ID; offices may still ask for the original.")
    }
}
