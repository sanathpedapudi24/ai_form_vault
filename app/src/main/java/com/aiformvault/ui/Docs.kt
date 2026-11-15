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
import com.aiformvault.Candidate
import com.aiformvault.Category
import com.aiformvault.DocType
import com.aiformvault.Document
import com.aiformvault.Fact
import com.aiformvault.FactKey
import com.aiformvault.ManualFact
import com.aiformvault.Ocr
import com.aiformvault.Person
import com.aiformvault.Relation
import com.aiformvault.Store
import com.aiformvault.duplicatesOf
import com.aiformvault.expectedFacts
import com.aiformvault.fieldCandidates
import com.aiformvault.mask
import com.aiformvault.nameKeys
import com.aiformvault.normalize
import com.aiformvault.sameName
import com.aiformvault.suggestRelations
import com.aiformvault.suggestTitle
import com.aiformvault.titleCase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID

private const val ME = "me"
private const val OTHER = "other"

private val addedFmt = DateTimeFormatter.ofPattern("d MMM yyyy", Locale.ENGLISH)
private fun addedOn(millis: Long): String =
    Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).toLocalDate().format(addedFmt)

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

    // Duplicate check runs on the draft, before anything is saved, so it can still be cancelled.
    // Advisory only: it never disables Save.
    val dupes = remember(facts.toList(), owner, type, title, category, data.documents) {
        val ownerKey = when (owner) {
            ME -> data.self?.id ?: ME
            OTHER -> OTHER
            else -> owner
        }
        val draft = Document("", type, category, title.trim(), ownerKey,
            facts.filter { it.value.isNotBlank() }, r.pages.size, createdAt = 0)
        duplicatesOf(draft, data.documents)
    }

    /** Advance the queue after a save or a skip; the last one returns to Home with a summary. */
    fun finishItem() {
        val total = state.batchTotal
        if (state.advanceBatch()) { state.tab(Route.Home); state.message = "Finished — $total documents in this batch" }
    }

    fun quitQueue() {
        state.quitBatch(); state.tab(Route.Home)
        state.message = "Queue closed — saved documents are in your vault"
    }

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
            if (state.batchTotal > 1) finishItem() else {
                state.replace(Route.Doc(id))
                state.message = "Saved to your vault"
            }
        }
    }

    /** Explicit user choice: replace the existing document's details and scans, keeping its id, owner and note. */
    fun updateExisting(existing: Document) {
        saving = true
        val title = title.ifBlank { type.label }.trim()
        val clean = facts.filter { it.value.isNotBlank() }.map { it.copy(value = it.value.trim()) }
        scope.launch {
            // Write the new pages first, prune only after they are down: a failure keeps the old ones readable.
            runCatching {
                withContext(Dispatchers.IO) {
                    Store.saveImages(ctx, existing.id, r.pages)
                    Store.pruneImages(ctx, existing.id, r.pages.size)
                }
            }.onFailure { saving = false; state.message = "Couldn't save the images: ${it.message}"; return@launch }
            state.update { d -> d.copy(documents = d.documents.map {
                if (it.id == existing.id) it.copy(type = type, category = category, title = title, facts = clean, pages = r.pages.size) else it
            }) }
            state.replace(Route.Doc(existing.id))
            state.message = "Updated “$title”"
        }
    }

    Page(title = "Review & Confirm", onBack = state::back) {
        DesignFlatCard {
            Column {
                Muted("Facts found in scan")
                facts.forEachIndexed { i, f ->
                    if (i > 0) Spacer(Modifier.height(4.dp))
                    DesignChip(text = "${f.key.label}: ${if (f.value.isNotBlank()) f.value else "(not found)"}", fg = Brand.Ink, bg = Brand.Surface2)
                }
                if (facts.isEmpty()) Muted("No facts could be read automatically.")
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(title, { title = it }, label = { Text("Name in your vault") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.End) {
                    DesignButton(text = "Skip this one", tone = ButtonTone.Danger, modifier = Modifier.weight(1f).height(48.dp), onClick = { if (state.batchTotal > 1) finishItem() else state.back() })
                    DesignButton(text = "Save", tone = ButtonTone.Primary, modifier = Modifier.weight(1f).height(48.dp), onClick = ::save)
                }
            }
        }
        Spacer(Modifier.height(16.dp))
        if (state.batchTotal > 1) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Chip("Document ${state.batchPos + 1} of ${state.batchTotal}")
                Spacer(Modifier.width(10.dp))
                Muted("Saved documents are kept if you quit.")
            }
            Spacer(Modifier.height(10.dp))
            Muted("Fix anything misread and clear anything wrong. Nothing is saved until you tap Save.")
        }
        if (state.batchTotal > 1) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Chip("Document ${state.batchPos + 1} of ${state.batchTotal}")
                Spacer(Modifier.width(10.dp))
                Muted("Saved documents are kept if you quit.")
            }
            Spacer(Modifier.height(10.dp))
        }
        Muted("Fix anything misread and clear anything wrong. Nothing is saved until you tap Save.")
        dupes.firstOrNull()?.let { hit ->
            Spacer(Modifier.height(12.dp))
            SoftCard(color = Brand.WarnSoft) {
                Text(
                    if (hit.strong) "This ${type.label.lowercase()} is already in your vault" else "You may already have a similar document",
                    style = MaterialTheme.typography.titleSmall,
                )
                Muted("“${hit.doc.title}”, added ${addedOn(hit.doc.createdAt)}.")
                Muted(if (hit.strong)
                    "Tap Save to keep both, or update the old one instead. Nothing is overwritten unless you choose it."
                else "Same type, owner and name. Open it to check before saving a second copy.")
                Row {
                    TextButton(onClick = { state.go(Route.Doc(hit.doc.id)) }) { Text("Open it") }
                    if (hit.strong) TextButton(onClick = { updateExisting(hit.doc) }, enabled = !saving) { Text("Update it") }
                }
            }
        }
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
        if (r.text.isNotBlank()) DesignButton(text = "Send scanned text", tone = ButtonTone.Soft, onClick = { sendText = true })
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
    var reading by remember { mutableStateOf<FactKey?>(null) }
    var rereadKey by remember { mutableStateOf<FactKey?>(null) }
    var candidates by remember { mutableStateOf<List<Candidate>>(emptyList()) }
    val pager = rememberPagerState { doc.pages }

    /** Re-OCR the stored pages and collect every candidate for one key. Nothing is saved until the user picks. */
    fun reread(key: FactKey) {
        if (doc.pages == 0) { state.message = "This document has no stored pages to re-read"; return }
        reading = key
        scope.launch {
            // Name fields get a Hindi pass too: a name printed only in Devanagari is otherwise unreachable.
            val texts = withContext(Dispatchers.IO) {
                runCatching { Ocr.textPerPage(ctx, id, doc.pages, withDevanagari = key in nameKeys) }.getOrElse { emptyList() }
            }
            reading = null
            val current = doc.facts.firstOrNull { it.key == key }?.value.orEmpty()
            // A re-read that returns the value we already hold is not a choice; say plainly that nothing new was found.
            val fresh = fieldCandidates(key, texts).filter { normalize(key, it.value) != normalize(key, current) }
            if (fresh.isEmpty()) state.message = "No other value found on pages 1–${doc.pages}"
            else { candidates = fresh; rereadKey = key }
        }
    }

    /** Picking a candidate replaces only that fact, and records it as the user's own value so it wins in profile(). */
    fun pick(key: FactKey, value: String) {
        val mine = doc.ownerId == state.data.self?.id
        state.update { d ->
            d.copy(
                documents = d.documents.map { doc0 ->
                    if (doc0.id != id) doc0
                    else doc0.copy(facts = doc0.facts.map { if (it.key == key) it.copy(value = value) else it })
                },
                manual = if (mine) d.manual.filter { it.key != key } + ManualFact(key, value, System.currentTimeMillis()) else d.manual,
            )
        }
        rereadKey = null; candidates = emptyList()
        state.message = "${key.label} updated"
    }

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
        HeroCard(
            eyebrow = doc.type.label,
            title = doc.title ?: "Document",
            subtitle = "${state.data.person(doc.ownerId)?.name ?: "Unknown"} • ${doc.pages} pages",
        )
        Spacer(Modifier.height(16.dp))
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            DesignChip(text = doc.type.label, fg = Brand.EmeraldDeep, bg = Brand.MintSoft)
            DesignAvatar(initials = (state.data.person(doc.ownerId)?.name?.substringBefore(' ')?.take(2) ?: "U").uppercase(), size = 32)
            daysLeft(doc)?.takeIf { it <= 90 }?.let { DesignPill("$it days left", if (it <= 30) PillTone.Danger else PillTone.Warn) }
        }

        Section("Details", if (doc.facts.any { it.key.sensitive }) "Show numbers" else null) { reveal = !reveal }
        DesignFlatCard {
            Column {
                doc.facts.forEachIndexed { i, f ->
                    if (i > 0) Spacer(Modifier.height(8.dp))
                    FieldRow(key = f.key.label, value = if (reveal) f.value else mask(f.key, f.value))
                }
                if (doc.facts.isEmpty()) Muted("No details saved for this document.")
            }
        }

        Section("Note")
        OutlinedTextField(note, { note = it }, placeholder = { Text("e.g. Used for NSP scholarship, 2026") }, minLines = 2, modifier = Modifier.fillMaxWidth())
        if (note != doc.note) TextButton(onClick = { state.update { d -> d.copy(documents = d.documents.map { if (it.id == id) it.copy(note = note.trim()) else it }) } }) { Text("Save note") }

        Spacer(Modifier.height(20.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            DesignButton(text = "Digital ID", tone = ButtonTone.Ghost, onClick = { state.go(Route.DigitalId(id)) }, leading = "🪪")
            DesignButton(text = "Share", tone = ButtonTone.Ghost, onClick = { share() }, leading = "📤")
        }
        DesignButton(text = "Delete document", modifier = Modifier.fillMaxWidth(), tone = ButtonTone.Danger, onClick = { confirmDelete = true })
    }

    zoom?.let { p ->
        Dialog(onDismissRequest = { zoom = null }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
            Box(Modifier.fillMaxSize().background(Color.Black)) {
                PageImage(id, p, 3000) { bmp -> if (bmp != null) ZoomImage(bmp) }
                TextButton(onClick = { zoom = null }, Modifier.align(Alignment.TopEnd).padding(16.dp)) { Text("Close", color = Color.White) }
            }
        }
    }
    rereadKey?.let { key ->
        AlertDialog(
            onDismissRequest = { rereadKey = null; candidates = emptyList() },
            title = { Text("Other values for ${key.label.lowercase()}") },
            text = {
                Column {
                    Muted("Read from this document. Pick the one the card actually shows.")
                    Spacer(Modifier.height(8.dp))
                    candidates.forEach { c ->
                        TextButton(onClick = { pick(key, c.value) }, Modifier.fillMaxWidth()) {
                            Column(Modifier.fillMaxWidth()) {
                                Text(if (reveal) c.value else mask(key, c.value), style = MaterialTheme.typography.bodyLarge)
                                Text("Page ${c.page}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
            },
            confirmButton = { TextButton(onClick = { rereadKey = null; candidates = emptyList() }) { Text("Cancel") } },
        )
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
        DesignDocCard(
            eyebrow = doc.type.label.uppercase(),
            name = f[FactKey.NAME]?.let(::titleCase) ?: owner?.name.orEmpty(),
            subtitle = "• ${doc.pages} pages • ${when (doc.category) { Category.IDENTITY -> "OK"; Category.EDUCATION -> "Warn"; Category.FINANCE -> "OK"; Category.TRAVEL -> "OK"; else -> "" }}",
            alt = true,
        ) {
            // Quick facts tap area - currently displayed in the gradient card
        }
    }
}
