package com.aiformvault.ui

import android.app.Activity
import android.content.Context
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.LocalActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.aiformvault.Category
import com.aiformvault.DocType
import com.aiformvault.Document
import com.aiformvault.Fact
import com.aiformvault.FactKey
import com.aiformvault.Lock
import com.aiformvault.Ocr
import com.aiformvault.Relation
import com.aiformvault.Store
import com.aiformvault.VaultData
import com.aiformvault.expectedFacts
import com.aiformvault.extract
import com.aiformvault.extractDevanagari
import com.aiformvault.mergeDevanagari
import com.aiformvault.mismatches
import com.aiformvault.profile
import com.aiformvault.search
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalTime

sealed interface Route {
    data object Home : Route
    data object Vault : Route
    data object Search : Route
    data object Profile : Route
    data class Doc(val id: String) : Route
    /** null = the ID tab: shows the user's own ID documents. */
    data class DigitalId(val id: String? = null) : Route
    /** [step]: 0 reading, 1 understanding, 2 organizing. */
    data class Scanning(val step: Int, val pages: Int, val note: String = "") : Route
    data class Review(val pages: List<Uri>, val type: DocType, val facts: List<Fact>, val text: String = "") : Route
    data object Relationships : Route
    data object SnapFill : Route
}

/** `.tabs` from the design: Home, Vault, ID, Profile. */
private val tabs = listOf(Route.Home, Route.Vault, Route.DigitalId(), Route.Profile)

enum class Gate { ONBOARDING, PIN_SETUP, NONE }

/** Set while another app's screen (scanner, share sheet, file picker) is on top, so leaving doesn't re-lock. */
object Session { @Volatile var external = false }

/** App-wide state. Holds only the application context, so it outlives activity recreation. */
class AppState(val ctx: Context) {
    val lock = Lock(ctx)
    var data by mutableStateOf(runCatching { Store.load(ctx) }.getOrElse { VaultData() })
    var locked by mutableStateOf(lock.hasPin)
    var gate by mutableStateOf(if (!lock.onboarded) Gate.ONBOARDING else if (!lock.hasPin && !lock.pinSkipped) Gate.PIN_SETUP else Gate.NONE)
    val stack = mutableStateListOf<Route>(Route.Home)
    var message by mutableStateOf<String?>(null)
    /** Query to pre-fill when Search opens (e.g. from the "Expiring soon" tile). */
    var searchSeed = ""

    /** Applies a change and persists it encrypted. Every write goes through here. */
    fun update(f: (VaultData) -> VaultData) { data = f(data); Store.save(ctx, data) }

    val route get() = stack.last()
    fun go(r: Route) { stack += r }
    fun back() {
        // Leaving the scan screen stops the OCR job, so it can't push a Review on top of wherever the user went.
        if (route is Route.Scanning) { scanJob?.cancel(); scanJob = null }
        // Leaving a queued document abandons the rest of the queue; whatever was already saved stays.
        if (batch.isNotEmpty() && (route is Route.Scanning || route is Route.Review)) quitBatch()
        if (stack.size > 1) stack.removeAt(stack.lastIndex)
    }
    fun replace(r: Route) { stack[stack.lastIndex] = r }
    fun tab(r: Route) { stack.clear(); stack += r }

    fun wipe() {
        Store.wipe(ctx); lock.clearAll()
        data = VaultData(); locked = false; gate = Gate.ONBOARDING; tab(Route.Home)
    }

    /** The running OCR job, cancelled by back() / "Cancel scan". */
    var scanJob: Job? = null
    var scan: () -> Unit = {}
    var importPdf: () -> Unit = {}
    var importImages: () -> Unit = {}

    // ---------- Import queue (issue #9): several documents, one review each ----------

    /** One entry per document still to review; empty when no queue is running. Set only for 2+ items. */
    var batch by mutableStateOf<List<List<Uri>>>(emptyList())
    /** 0-based index of the queued document currently in review. */
    var batchPos by mutableStateOf(0)
    val batchTotal get() = batch.size

    /** Wired by the shell: OCR → extract → Review for one document's pages. */
    var processPages: (List<Uri>) -> Unit = {}

    fun startBatch(items: List<List<Uri>>) {
        val clean = items.filter { it.isNotEmpty() }
        if (clean.isEmpty()) { message = "No readable images in that selection"; return }
        tab(Route.Home)
        if (clean.size == 1) { batch = emptyList(); batchPos = 0; processPages(clean[0]); return }
        batch = clean; batchPos = 0; processPages(clean[0])
    }

    /** Drops the current item and moves on. Returns true when that was the last one (queue cleared). */
    fun advanceBatch(): Boolean {
        if (batch.isEmpty()) return true
        val next = batchPos + 1
        if (next >= batch.size) { batch = emptyList(); batchPos = 0; return true }
        batchPos = next
        tab(Route.Home) // drops the finished document's routes so the stack doesn't grow with the queue
        processPages(batch[next])
        return false
    }

    fun quitBatch() { batch = emptyList(); batchPos = 0 }
}

/** Launches Google's on-device document scanner (edge detection, cropping, gallery import). */
@Composable
fun rememberScanner(pageLimit: Int, onError: (String) -> Unit, onPages: (List<Uri>) -> Unit): () -> Unit {
    val activity = LocalActivity.current as Activity
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { r ->
        if (r.resultCode == Activity.RESULT_OK) GmsDocumentScanningResult.fromActivityResultIntent(r.data)?.pages
            ?.map { it.imageUri }?.takeIf { it.isNotEmpty() }?.let(onPages)
    }
    return {
        Session.external = true
        GmsDocumentScanning.getClient(
            GmsDocumentScannerOptions.Builder()
                .setGalleryImportAllowed(true)
                .setPageLimit(pageLimit)
                .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
                .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
                .build()
        ).getStartScanIntent(activity)
            .addOnSuccessListener { launcher.launch(IntentSenderRequest.Builder(it).build()) }
            .addOnFailureListener { Session.external = false; onError("Scanner unavailable: ${it.message}") }
    }
}

@Composable
fun App(state: AppState) {
    Box(Modifier.fillMaxSize().background(C.paper).windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Top + WindowInsetsSides.Horizontal)).imePadding()) {
        when {
            state.gate == Gate.ONBOARDING -> Onboarding(state)
            state.gate == Gate.PIN_SETUP -> PinSetup(state)
            state.locked -> LockScreen(state)
            else -> Shell(state)
        }
    }
}

@Composable
private fun Shell(state: AppState) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val snack = remember { SnackbarHostState() }
    LaunchedEffect(state.message) { state.message?.let { snack.showSnackbar(it); state.message = null } }
    BackHandler(state.stack.size > 1) { state.back() }

    fun process(pages: List<Uri>) {
        state.go(Route.Scanning(0, pages.size))
        state.scanJob = scope.launch {
            try {
                var text = withContext(Dispatchers.Default) { Ocr.text(ctx, pages) }
                state.replace(Route.Scanning(1, pages.size))
                var (type, facts) = withContext(Dispatchers.Default) { extract(text) }
                // Fallback only: a Hindi-only name line is invisible to the Latin model, so re-read the
                // pages with the Devanagari model when no usable name came back (issue #8).
                val weakName = facts.firstOrNull { it.key == FactKey.NAME }?.value?.let { it.trim().split(' ').size < 2 } != false
                if (weakName) {
                    state.replace(Route.Scanning(1, pages.size, "Reading Hindi text too"))
                    val hindi = withContext(Dispatchers.Default) { Ocr.devanagariText(ctx, pages) }
                    val extra = withContext(Dispatchers.Default) { extractDevanagari(hindi) }
                    if (extra.isNotEmpty()) { facts = mergeDevanagari(facts, extra); text = text + "\n" + hindi }
                }
                state.replace(Route.Scanning(2, pages.size, "${type.label} layout found"))
                delay(400)
                state.replace(Route.Review(pages, type, facts, text))
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) {
                state.back(); state.message = "Couldn't read that document: ${e.message}"
            } finally {
                state.scanJob = null
            }
        }
    }
    state.processPages = ::process
    state.scan = rememberScanner(10, { state.message = it }, ::process)
    val pdf = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) scope.launch {
            // Silent truncation was the bug: report how much of the PDF was read, and say when it is locked.
            val res = withContext(Dispatchers.IO) { runCatching { Ocr.pdfPages(ctx, uri) } }
                .getOrElse { Ocr.PdfPages(emptyList(), 0, "Couldn't open that PDF: ${it.message}") }
            when {
                res.error != null -> state.message = res.error
                res.pages.isEmpty() -> state.message = "Couldn't read any page from that PDF"
                else -> {
                    if (res.pages.size < res.total) state.message = "Read the first ${res.pages.size} of ${res.total} pages."
                    process(res.pages)
                }
            }
        }
    }
    state.importPdf = { Session.external = true; pdf.launch(arrayOf("application/pdf")) }
    // One image = one document. The picker gives no way to group pages, so guessing would mis-file them.
    val images = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        if (!uris.isNullOrEmpty()) state.startBatch(uris.map { listOf(it) })
    }
    state.importImages = { Session.external = true; images.launch(arrayOf("image/*")) }

    val route = state.route
    Box(Modifier.fillMaxSize()) {
        when (route) {
            Route.Home -> HomeScreen(state)
            Route.Vault -> VaultScreen(state)
            Route.Search -> SearchScreen(state)
            Route.Profile -> ProfileScreen(state)
            Route.Relationships -> RelationshipsScreen(state)
            Route.SnapFill -> SnapFillScreen(state)
            is Route.Doc -> DocScreen(state, route.id)
            is Route.DigitalId -> DigitalIdScreen(state, route.id)
            is Route.Review -> ReviewScreen(state, route)
            is Route.Scanning -> ScanningScreen(state, route)
        }
        val onTab = route in tabs
        if (onTab) Tabs(
            listOf(Triple("Home", Ic.home, route == Route.Home), Triple("Vault", Ic.vault, route == Route.Vault),
                Triple("ID", Ic.id, route == Route.DigitalId()), Triple("Profile", Ic.user, route == Route.Profile)),
            onPick = { state.tab(tabs[it]) },
            modifier = Modifier.align(Alignment.BottomCenter),
        )
        SnackbarHost(snack, Modifier.align(Alignment.BottomCenter).windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Bottom))
            .padding(bottom = if (onTab) 92.dp else 8.dp))
    }
}

/** The status pill on a document row: never claims more than the user confirmed at review. */
fun docStatus(d: Document): Pair<String, Boolean> {
    val left = daysLeft(d)
    val missing = expectedFacts[d.type].orEmpty().firstOrNull { k -> d.facts.none { it.key == k && it.value.isNotBlank() } }
    return when {
        left != null && left < 0 -> "Expired" to false
        left != null && left <= 90 -> "$left days left" to false
        missing != null -> "Add ${missing.label.lowercase()}" to false
        else -> "Confirmed" to true
    }
}

@Composable
private fun HomeScreen(state: AppState) {
    val data = state.data
    val self = data.self
    val conflicts = remember(data) { mismatches(profile(data)) }
    val pending = data.people.filter { !it.confirmed }
    // Same 180-day window search() uses for "expiring soon", so the tile and the list it opens agree.
    val expiring = data.documents.count { (daysLeft(it) ?: Long.MAX_VALUE) <= 180 }
    val greeting = when (LocalTime.now().hour) { in 5..11 -> "Good morning"; in 12..16 -> "Good afternoon"; else -> "Good evening" }
    Screen(tabs = true, header = {
        Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 16.dp, top = 8.dp, bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                SuText(greeting)
                Text(self?.name ?: "Your vault", style = H1, color = C.ink, maxLines = 1)
            }
            if (self != null) Av(self.name) { state.tab(Route.Profile) }
            else IconBtn(Ic.search, "Search") { state.go(Route.Search) }
        }
    }) {
        Hero("Scan a document", "Text is read on your phone. You check every detail before it is saved.", "Start scan", state.scan)
        Row(Modifier.fillMaxWidth().padding(top = 20.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Quick(Ic.image, "Photos", state.importImages)
            Quick(Ic.file, "PDF", state.importPdf)
            Quick(Ic.id, "Digital ID") { state.tab(Route.DigitalId()) }
            Quick(Ic.form, "Fill form") { state.go(Route.SnapFill) }
        }

        // .bento: 1.2fr / 1fr, the tall cell spans two rows, the wide cell spans both columns.
        Column(Modifier.padding(top = 22.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(Modifier.fillMaxWidth().height(androidx.compose.foundation.layout.IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Bc(Modifier.weight(1.2f).fillMaxSize(), onClick = { state.tab(Route.Vault) }) {
                    Seg(data.documents.groupingBy { it.category }.eachCount().values.sortedDescending())
                    BcNum(data.documents.size, "Documents saved", big = true)
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Bc(Modifier.fillMaxWidth(), warn = expiring > 0, onClick = { state.searchSeed = "expiring soon"; state.go(Route.Search) }) {
                        I(Ic.alert); BcNum(expiring, "Expiring soon", warn = expiring > 0)
                    }
                    Bc(Modifier.fillMaxWidth(), warn = conflicts.isNotEmpty(), onClick = { state.tab(Route.Profile) }) {
                        I(if (conflicts.isEmpty()) Ic.check else Ic.alert); BcNum(conflicts.size, "Mismatches", warn = conflicts.isNotEmpty())
                    }
                }
            }
            val locked = state.lock.hasPin
            Bc(Modifier.fillMaxWidth(), onClick = { state.tab(Route.Profile) }) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    Dic(Ic.lock)
                    Column(Modifier.weight(1f)) {
                        TiText(if (locked) "Encrypted on this phone" else "Set up an app lock")
                        SuText(if (locked) "AES-256 with SQLCipher" else "Encrypted, but anyone holding your phone can open it")
                    }
                    if (!locked) Chev()
                }
            }
        }

        pending.firstOrNull()?.let { p ->
            Spacer(Modifier.height(20.dp))
            Note(false, Ic.users, "Is ${p.name} your ${p.relation.label.lowercase()}?", p.evidence.ifBlank { "Found on your documents." }) {
                Btn("Confirm", BtnKind.Pri, small = true) { state.update { d -> d.copy(people = d.people.map { if (it.id == p.id) it.copy(confirmed = true) else it }) } }
                Btn("Not related", BtnKind.Ghost, small = true) { state.update { d -> d.copy(people = d.people.filter { it.id != p.id }) } }
                if (pending.size > 1) Btn("+${pending.size - 1} more", BtnKind.Ghost, small = true) { state.go(Route.Relationships) }
            }
        }

        if (data.documents.isNotEmpty()) {
            Sec("Recent", "See all") { state.tab(Route.Vault) }
            Grp(data.documents.sortedByDescending { it.createdAt }.take(3).map { d ->
                @Composable { DocItem(state, d) }
            })
        }
    }
}

/** `.item` for a document: category tile, title, owner, status pill. */
@Composable
fun DocItem(state: AppState, d: Document, sub: androidx.compose.ui.text.AnnotatedString? = null) {
    val (label, ok) = docStatus(d)
    Item({ Dic(categoryIcon(d.category)) }, d.title, state.data.person(d.ownerId)?.name, end = { Pill(label, ok) }, subText = sub) { state.go(Route.Doc(d.id)) }
}

@Composable
private fun VaultScreen(state: AppState) {
    val data = state.data
    var filter by remember { mutableStateOf<Category?>(null) }
    val present = Category.entries.filter { c -> data.documents.any { it.category == c } }
    Screen("Vault", actions = { IconBtn(Ic.search, "Search") { state.go(Route.Search) } }, tabs = true, overlay = {
        Fab("Add", Ic.plus, Modifier.align(Alignment.BottomEnd).windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Bottom)).padding(end = 16.dp, bottom = 100.dp), state.scan)
    }) {
        if (data.documents.isEmpty()) {
            Note(false, Ic.info, "Nothing here yet", "Scan a document, or import photos or a PDF, to start your vault.") {
                Btn("Photos", BtnKind.Pri, small = true, icon = Ic.image, onClick = state.importImages)
                Btn("PDF", BtnKind.Line, small = true, icon = Ic.file, onClick = state.importPdf)
            }
            return@Screen
        }
        Chips(listOf<Category?>(null) + present, filter, { it?.label ?: "All" }) { filter = it }
        val docs = data.documents.filter { filter == null || it.category == filter }.sortedByDescending { it.createdAt }
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            docs.chunked(2).forEach { pair ->
                Row(Modifier.fillMaxWidth().height(androidx.compose.foundation.layout.IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    pair.forEach { d ->
                        val (label, ok) = docStatus(d)
                        Dc(categoryIcon(d.category), d.title, data.person(d.ownerId)?.name?.substringBefore(' ').orEmpty(),
                            Modifier.weight(1f).fillMaxSize(), pill = { Pill(label, ok) }) { state.go(Route.Doc(d.id)) }
                    }
                    if (pair.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun SearchScreen(state: AppState) {
    var q by remember { mutableStateOf(state.searchSeed.also { state.searchSeed = "" }) }
    val data = state.data
    val results = remember(q, data) { search(q, data) }
    val people = remember(q, data) { if (q.isBlank()) emptyList() else data.people.filter { it.confirmed && it.name.contains(q.trim(), ignoreCase = true) } }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    Screen("Search", onBack = state::back) {
        Field(q, { q = it }, "Name, number, document or “expiring”", Modifier.focusRequester(focus))
        if (q.isBlank()) {
            Sec("Try")
            Grp(listOf("my PAN card", "father's documents", "expiring next year", "ID documents", "marksheet").map { s ->
                @Composable { Item({ Dic(Ic.search) }, s, end = { Chev() }) { q = s } }
            })
            return@Screen
        }
        Sec("Matches")
        if (results.isEmpty()) Para("No documents match “$q”.")
        else Grp(results.map { d ->
            @Composable {
                // Show where it matched: the fact value containing the query, else the owner.
                val hit = d.facts.firstOrNull { it.value.contains(q.trim(), ignoreCase = true) }
                val sub = hit?.let { "${it.key.label} ${it.value}" } ?: data.person(d.ownerId)?.name.orEmpty()
                DocItem(state, d, marked(sub, q))
            }
        })
        if (people.isNotEmpty()) {
            Sec("People")
            Grp(people.map { p ->
                @Composable {
                    val docs = data.docsOf(p.id)
                    val rel = if (p.relation == Relation.SELF) "You" else p.relation.label
                    Item({ Av(p.name) }, p.name, "$rel, ${docs.size} document${if (docs.size == 1) "" else "s"}", end = { Chev() }) {
                        if (p.relation == Relation.SELF) state.tab(Route.Profile) else state.go(Route.Relationships)
                    }
                }
            })
        }
    }
}

@Composable
private fun ScanningScreen(state: AppState, r: Route.Scanning) {
    val seq = if (state.batchTotal > 1) "Document ${state.batchPos + 1} of ${state.batchTotal}. " else ""
    Screen("Scanning", onBack = state::back, dock = { Btn("Cancel scan", BtnKind.Line) { state.back() } }) {
        Viewfinder()
        val pages = "${r.pages} page${if (r.pages == 1) "" else "s"}"
        val steps = listOf(
            Triple("Reading the text", if (r.step > 0) "$pages done" else "${seq}Reading $pages on this phone", 0),
            Triple("Understanding the document", if (r.step > 1) r.note.ifBlank { "Document type found" } else r.note.ifBlank { "Working out what this is" }, 1),
            Triple("Organizing the details", "Matching them to what we expect", 2),
        )
        steps.forEach { (t, s, i) ->
            Step(i + 1, when { i < r.step -> StepState.Done; i == r.step -> StepState.Now; else -> StepState.Todo }, t, s, last = i == steps.lastIndex)
        }
        Para("Nothing is uploaded.")
    }
}
