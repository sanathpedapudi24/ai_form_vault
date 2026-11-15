package com.aiformvault.ui

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.toArgb
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


    val expected = expectedFacts[type].orEmpty()
    Screen("Review", onBack = state::back, dock = {
        Btn("Save document", enabled = !saving, onClick = ::save)
        Btn("Skip this one", BtnKind.Line, enabled = !saving) { if (state.batchTotal > 1) finishItem() else state.back() }
    }) {
        if (state.batchTotal > 1) {
            Para("Document ${state.batchPos + 1} of ${state.batchTotal}, ${type.label}")
            Spacer(Modifier.height(8.dp))
            Prog((state.batchPos + 1f) / state.batchTotal)
        } else {
            Para("${type.label}. Fix anything misread. Nothing is saved until you tap Save.")
            Spacer(Modifier.height(18.dp))
        }
        dupes.firstOrNull()?.let { hit ->
            Note(true, Ic.alert,
                if (hit.strong) "This ${type.label.lowercase()} is already in your vault" else "You may already have this",
                "${hit.doc.title}, added ${addedOn(hit.doc.createdAt)}.") {
                Btn("Open it", small = true) { state.go(Route.Doc(hit.doc.id)) }
                if (hit.strong) Btn("Update it", BtnKind.Line, small = true, enabled = !saving) { updateExisting(hit.doc) }
                Btn("Save anyway", BtnKind.Ghost, small = true, enabled = !saving, onClick = ::save)
            }
        }

        // Which of the details this document type should carry were actually read.
        val checks = expected.ifEmpty { facts.map { it.key }.distinct() }
        if (checks.isNotEmpty()) {
            Sec("Found on the document")
            Grp(checks.map { k ->
                @Composable {
                    val found = facts.any { it.key == k && it.value.isNotBlank() }
                    Item({ CheckDot(found) }, k.label, if (found) "Read from the scan. Check it below." else "Not found. Add it below if it's printed.")
                }
            })
        }

        Sec("Check and edit")
        if (facts.isEmpty()) Para("Nothing could be read automatically. Add the details you need.", top = 0.dp)
        facts.forEachIndexed { i, f ->
            Tf(f.key.label, f.value, { facts[i] = f.copy(value = it) }, singleLine = f.key != FactKey.ADDRESS,
                trailing = { TBtn("Clear", C.ink2) { facts.removeAt(i) } })
        }
        expected.filter { k -> facts.none { it.key == k } }.forEach { k ->
            Tf(k.label, "", { if (it.isNotBlank()) facts += Fact(k, it) }, miss = true, placeholder = "Not found. Type it if it's printed.")
        }
        AddFieldMenu(FactKey.entries.filter { k -> facts.none { it.key == k } }) { facts += Fact(it, "") }

        Sec("About this document")
        PickerTf("Type", type, DocType.entries, { it.label }) { type = it; category = it.category; title = suggestTitle(it, facts) }
        PickerTf("Category", category, Category.entries, { it.label }) { category = it }
        Tf("Name in your vault", title, { title = it })

        Sec("Whose document is this?")
        val owners = listOf(ME) + family.take(3).map { it.id } + OTHER
        Chips(owners, owner, { o -> when (o) { ME -> "Mine"; OTHER -> "Someone else"; else -> family.first { it.id == o }.name.substringBefore(' ') } }) { owner = it }
        if (owner == OTHER) {
            Tf("Their name", otherName, { otherName = it })
            PickerTf("They are your", otherRelation, Relation.entries.filter { it != Relation.SELF }, { it.label.lowercase() }) { otherRelation = it }
        }
        if (owner != ME) Para("Details from this document stay with them, not in your profile.")
        if (r.text.isNotBlank()) { Spacer(Modifier.height(12.dp)); TBtn("Send scanned text") { sendText = true } }
    }

    if (sendText) AlertDialog(
        onDismissRequest = { sendText = false },
        containerColor = C.card,
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

/** `.dot.ok` (check) for a found detail; a muted alert dot for a missing one. */
@Composable
private fun CheckDot(ok: Boolean) {
    Box(Modifier.size(36.dp).clip(CircleShape).background(if (ok) C.g else C.card2), contentAlignment = Alignment.Center) {
        I(if (ok) Ic.check else Ic.alert, 18.dp, if (ok) C.on else C.ink2)
    }
}

@Composable
fun AddFieldMenu(keys: List<FactKey>, onPick: (FactKey) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        TBtn("+ Add a detail") { open = true }
        DropdownMenu(open, { open = false }, containerColor = C.card) { keys.forEach { k -> DropdownMenuItem(text = { Text(k.label, color = C.ink) }, onClick = { open = false; onPick(k) }) } }
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

    /** Sets one fact on this document (adding it if new) and, for the user's own document, records it as their value so it wins in profile(). */
    fun setFact(key: FactKey, value: String) {
        val mine = doc.ownerId == state.data.self?.id
        state.update { d ->
            d.copy(
                documents = d.documents.map { doc0 ->
                    if (doc0.id != id) doc0
                    else if (doc0.facts.any { it.key == key }) doc0.copy(facts = doc0.facts.map { if (it.key == key) it.copy(value = value) else it })
                    else doc0.copy(facts = doc0.facts + Fact(key, value))
                },
                manual = if (mine) d.manual.filter { it.key != key } + ManualFact(key, value, System.currentTimeMillis()) else d.manual,
            )
        }
        state.message = "${key.label} updated"
    }

    /** Picking a re-read candidate replaces only that fact. */
    fun pick(key: FactKey, value: String) { rereadKey = null; candidates = emptyList(); setFact(key, value) }

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


    var editKey by remember { mutableStateOf<FactKey?>(null) }
    var choose by remember { mutableStateOf<String?>(null) } // "reread" or "edit": pick which detail first
    val owner = state.data.person(doc.ownerId)
    val f = doc.facts.associate { it.key to it.value }
    val number = idNumberKeys.firstNotNullOfOrNull { k -> f[k]?.let { k to it } }

    Screen(doc.title, onBack = state::back, actions = {
        MoreMenu("Share pages" to { share() }, "Digital ID" to { state.go(Route.DigitalId(id)) }, "Delete document" to { confirmDelete = true })
    }) {
        Cred(listOfNotNull(doc.type.label, owner?.takeIf { it.relation != Relation.SELF }?.relation?.label).joinToString(", "),
            f[FactKey.NAME]?.let(::titleCase) ?: owner?.name ?: doc.title,
            number?.let { (k, v) -> if (reveal) v else mask(k, v) }, onNum = { reveal = !reveal })
        daysLeft(doc)?.takeIf { it <= 90 }?.let { left ->
            Spacer(Modifier.height(12.dp))
            Note(true, Ic.alert, if (left < 0) "Expired" else "Expires in $left days", "Renew it before you need it for a form.")
        }

        if (doc.pages > 0) {
            Sec("Pages")
            HorizontalPager(pager, Modifier.fillMaxWidth().height(240.dp).clip(RoundedCornerShape(24.dp)).background(C.card).border(1.dp, C.line, RoundedCornerShape(24.dp))) { p ->
                PageImage(id, p, 1200) { bmp ->
                    Box(Modifier.fillMaxSize().clickable { zoom = p }, contentAlignment = Alignment.Center) {
                        if (bmp == null) Spinner(28.dp)
                        else Image(bmp.asImageBitmap(), "Page ${p + 1}, tap to zoom", contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize())
                    }
                }
            }
            Para(if (doc.pages > 1) "Page ${pager.currentPage + 1} of ${doc.pages}. Swipe, or tap to zoom." else "Tap to zoom.", top = 8.dp)
        }

        Sec("Extracted details", if (doc.facts.any { it.key.sensitive }) (if (reveal) "Hide numbers" else "Show numbers") else null) { reveal = !reveal }
        if (doc.facts.isEmpty()) Para("No details saved for this document.")
        else Grp(doc.facts.map { fact ->
            @Composable {
                Kv(fact.key.label, if (reveal) fact.value else mask(fact.key, fact.value), onClick = { editKey = fact.key }) {
                    if (reading == fact.key) Spinner()
                }
            }
        })

        Sec("Note")
        Tf("Note", note, { note = it }, placeholder = "e.g. Used for NSP scholarship, 2026", singleLine = false)
        if (note != doc.note) Btn("Save note", BtnKind.Tonal, small = true) {
            state.update { d -> d.copy(documents = d.documents.map { if (it.id == id) it.copy(note = note.trim()) else it }) }
        }

        Sec("Manage")
        Grp(
            { Item({ Dic(Ic.redo) }, "Re-read fields", if (reading != null) "Reading ${reading?.label?.lowercase()}…" else "Run text recognition again on saved pages", end = { Chev() }) { if (reading == null) choose = "reread" } },
            { Item({ Dic(Ic.edit) }, "Edit manually", "Override a value on this document", end = { Chev() }) { choose = "edit" } },
            { Item({ Dic(Ic.id) }, "Digital ID", "Show it as a card, share or print it", end = { Chev() }) { state.go(Route.DigitalId(id)) } },
            { Item({ Dic(Ic.trash, danger = true) }, "Delete document", "Removes the scans and extracted details") { confirmDelete = true } },
        )
    }

    choose?.let { mode ->
        val keys = if (mode == "edit") doc.facts.map { it.key } + FactKey.entries.filter { k -> doc.facts.none { it.key == k } } else doc.facts.map { it.key }
        AlertDialog(
            onDismissRequest = { choose = null }, containerColor = C.card,
            title = { Text(if (mode == "edit") "Which detail?" else "Re-read which detail?") },
            text = {
                Column(Modifier.verticalScroll(rememberScrollState())) {
                    keys.forEach { k -> TextButton(onClick = { choose = null; if (mode == "edit") editKey = k else reread(k) }, Modifier.fillMaxWidth()) {
                        Text(k.label, Modifier.fillMaxWidth(), color = C.ink)
                    } }
                }
            },
            confirmButton = { TextButton(onClick = { choose = null }) { Text("Cancel") } },
        )
    }
    editKey?.let { key ->
        var v by remember(key) { mutableStateOf(f[key].orEmpty()) }
        AlertDialog(
            onDismissRequest = { editKey = null }, containerColor = C.card,
            title = { Text(key.label) },
            text = { Tf(key.label, v, { v = it }, singleLine = key != FactKey.ADDRESS) },
            confirmButton = { TextButton(enabled = v.isNotBlank(), onClick = { editKey = null; setFact(key, v.trim()) }) { Text("Save") } },
            dismissButton = { TextButton(onClick = { editKey = null }) { Text("Cancel") } },
        )
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
            onDismissRequest = { rereadKey = null; candidates = emptyList() }, containerColor = C.card,
            title = { Text("Other values for ${key.label.lowercase()}") },
            text = {
                Column {
                    SuText("Read from this document. Pick the one the card actually shows.")
                    Spacer(Modifier.height(8.dp))
                    candidates.forEach { c ->
                        TextButton(onClick = { pick(key, c.value) }, Modifier.fillMaxWidth()) {
                            Column(Modifier.fillMaxWidth()) {
                                Text(if (reveal) c.value else mask(key, c.value), color = C.ink, fontSize = 16.sp)
                                Text("Page ${c.page}", color = C.ink2, fontSize = 12.sp)
                            }
                        }
                    }
                }
            },
            confirmButton = { TextButton(onClick = { rereadKey = null; candidates = emptyList() }) { Text("Cancel") } },
        )
    }
    if (confirmDelete) AlertDialog(
        onDismissRequest = { confirmDelete = false }, containerColor = C.card,
        title = { Text("Delete ${doc.title}?") },
        text = { Text("The scan and its details are removed from this phone for good. Details in your profile that came only from this document go too.") },
        confirmButton = {
            TextButton(onClick = {
                confirmDelete = false
                Store.deleteImages(ctx, id)
                state.update { d -> d.copy(documents = d.documents.filter { it.id != id }) }
                state.back(); state.message = "Document deleted"
            }) { Text("Delete", fontWeight = FontWeight.Bold) }
        },
        dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Cancel") } },
    )
}

private val idNumberKeys = listOf(FactKey.AADHAAR, FactKey.PAN, FactKey.PASSPORT, FactKey.VOTER_ID, FactKey.DL_NUMBER, FactKey.VEHICLE_REG, FactKey.ROLL)

/**
 * Wallet-style card for showing details without handing over the phone. [id] null = the ID tab:
 * the user's own ID documents first, with chips to switch between them.
 */
@Composable
fun DigitalIdScreen(state: AppState, id: String?) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val data = state.data
    val selfId = data.self?.id
    val ids = remember(data) {
        data.documents.filter { d -> d.facts.any { it.key in idNumberKeys } }
            .sortedWith(compareByDescending<Document> { it.ownerId == selfId }.thenBy { it.category != Category.IDENTITY }.thenByDescending { it.createdAt })
    }
    var picked by remember { mutableStateOf<String?>(null) }
    val doc = data.documents.firstOrNull { it.id == (id ?: picked) } ?: if (id == null) ids.firstOrNull() else null
    var reveal by remember { mutableStateOf(false) }
    var masked by remember { mutableStateOf(state.lock.maskShare) }
    val tab = id == null

    Screen("Digital ID", onBack = if (tab) null else state::back, tabs = tab) {
        if (doc == null) {
            Note(false, Ic.id, "No ID documents yet", "Scan an Aadhaar, PAN, passport or licence and it shows here as a card you can show, share or print.") {
                Btn("Start scan", small = true, icon = Ic.scan, onClick = state.scan)
            }
            return@Screen
        }
        val owner = data.person(doc.ownerId)
        val f = doc.facts.associate { it.key to it.value }
        val number = idNumberKeys.firstNotNullOfOrNull { k -> f[k]?.let { k to it } }
        val name = f[FactKey.NAME]?.let(::titleCase) ?: owner?.name.orEmpty()
        if (tab && ids.size > 1) Chips(ids, doc, { d ->
            d.type.label + (data.person(d.ownerId)?.takeIf { it.id != selfId }?.let { ", " + it.name.substringBefore(' ') } ?: "")
        }) { picked = it.id }

        Cred("${doc.type.label}, from your scan", name, number?.let { (k, v) -> "${k.label} ${if (reveal) v else mask(k, v)}" }, alt = true, onNum = { reveal = !reveal }) {
            val extra = listOf(FactKey.DOB, FactKey.GENDER, FactKey.EXPIRY).mapNotNull { k -> f[k]?.let { k to it } }
            if (extra.isNotEmpty()) Row(Modifier.padding(top = 14.dp), horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                extra.forEach { (k, v) -> Column { Text(k.label, color = Deep.soft, fontSize = 12.sp); Text(v, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Medium) } }
            }
        }
        Para("Tap the number to show or hide it.", top = 10.dp)

        fun lines(): List<Pair<String, String>> = buildList {
            add("Name" to name)
            number?.let { (k, v) -> add(k.label to if (masked) mask(k, v) else v) }
            listOf(FactKey.DOB, FactKey.GENDER, FactKey.EXPIRY).forEach { k -> f[k]?.let { add(k.label to it) } }
        }
        Sec("Share this ID")
        Grp(
            { Item({ Dic(Ic.share) }, "Share", "Use the Android share sheet. Your vault stays here.", end = { Chev() }) {
                Session.external = true
                val text = doc.type.label + "\n" + lines().joinToString("\n") { "${it.first}: ${it.second}" }
                ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text), "Share ${doc.type.label}"))
            } },
            { Item({ Dic(Ic.print) }, "Print card", "Save as PDF or print", end = { Chev() }) {
                scope.launch {
                    val file = withContext(Dispatchers.IO) { cardPdf(ctx, doc.type.label, lines()) }
                    Session.external = true
                    ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("application/pdf")
                        .putExtra(Intent.EXTRA_STREAM, Ocr.shareUri(ctx, file)).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION), "Save or print"))
                }
            } },
        )
        Sec("Privacy")
        Grp({ Item({ Dic(Ic.lock) }, "Mask number when sharing", "Only the last 4 digits are shown", end = {
            Sw(masked, "Mask number when sharing") { masked = it; state.lock.maskShare = it }
        }) })
        Para("A quick reference from your own scan, not an official ID. Offices may still ask for the original.", top = 16.dp)
    }
}

/** One-page PDF of the ID card (credit-card proportions on A4), for "Save as PDF or print". */
private fun cardPdf(ctx: android.content.Context, title: String, lines: List<Pair<String, String>>): java.io.File {
    val pdf = PdfDocument()
    val page = pdf.startPage(PdfDocument.PageInfo.Builder(595, 842, 1).create())
    val c = page.canvas
    val card = RectF(40f, 40f, 40f + 400f, 40f + 252f)
    c.drawRoundRect(card, 22f, 22f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Deep.credAlt.toArgb() })
    val soft = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Deep.soft.toArgb(); textSize = 12f }
    val white = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.WHITE; textSize = 22f; typeface = Typeface.DEFAULT_BOLD }
    val body = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Deep.num.toArgb(); textSize = 13f }
    c.drawText("$title, from AI Form & Vault", card.left + 20, card.top + 30, soft)
    var y = card.top + 76
    lines.forEachIndexed { i, (k, v) ->
        if (i == 0) { c.drawText(v, card.left + 20, y, white); y += 36 }
        else { c.drawText("$k: $v", card.left + 20, y, body); y += 22 }
    }
    c.drawText("Reference copy from the owner's own scan. Not an official ID.", card.left + 20, card.bottom - 18, soft)
    pdf.finishPage(page)
    return Ocr.cacheFile(ctx, "pdf").also { f -> f.outputStream().use { pdf.writeTo(it) }; pdf.close() }
}
