package com.aiformvault.ui

import android.app.Activity
import android.content.Context
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.LocalActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.aiformvault.Category
import com.aiformvault.DocType
import com.aiformvault.Fact
import com.aiformvault.FactKey
import com.aiformvault.Lock
import com.aiformvault.Ocr
import com.aiformvault.Relation
import com.aiformvault.Store
import com.aiformvault.VaultData
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

sealed interface Route {
    data object Home : Route
    data object Vault : Route
    data object Search : Route
    data object Profile : Route
    data class Doc(val id: String) : Route
    data class DigitalId(val id: String) : Route
    data class Scanning(val stage: String) : Route
    data class Review(val pages: List<Uri>, val type: DocType, val facts: List<Fact>, val text: String = "") : Route
    data object Relationships : Route
    data object SnapFill : Route
}

private val tabs = listOf(Route.Home, Route.Vault, Route.Search, Route.Profile)

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

    /** Applies a change and persists it encrypted. Every write goes through here. */
    fun update(f: (VaultData) -> VaultData) { data = f(data); Store.save(ctx, data) }

    val route get() = stack.last()
    fun go(r: Route) { stack += r }
    fun back() {
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
    when {
        state.gate == Gate.ONBOARDING -> Onboarding(state)
        state.gate == Gate.PIN_SETUP -> PinSetup(state)
        state.locked -> LockScreen(state)
        else -> Shell(state)
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
        val seq = if (state.batchTotal > 1) "Document ${state.batchPos + 1} of ${state.batchTotal} — " else ""
        state.go(Route.Scanning("${seq}Reading the text…"))
        scope.launch {
            try {
                var text = withContext(Dispatchers.Default) { Ocr.text(ctx, pages) }
                state.replace(Route.Scanning("${seq}Understanding the document…"))
                var (type, facts) = withContext(Dispatchers.Default) { extract(text) }
                // Fallback only: a Hindi-only name line is invisible to the Latin model, so re-read the
                // pages with the Devanagari model when no usable name came back (issue #8).
                val weakName = facts.firstOrNull { it.key == FactKey.NAME }?.value?.let { it.trim().split(' ').size < 2 } != false
                if (weakName) {
                    state.replace(Route.Scanning("${seq}Reading Hindi text…"))
                    val hindi = withContext(Dispatchers.Default) { Ocr.devanagariText(ctx, pages) }
                    val extra = withContext(Dispatchers.Default) { extractDevanagari(hindi) }
                    if (extra.isNotEmpty()) { facts = mergeDevanagari(facts, extra); text = text + "\n" + hindi }
                }
                state.replace(Route.Scanning("${seq}Organizing…"))
                delay(250)
                state.replace(Route.Review(pages, type, facts, text))
            } catch (e: Exception) {
                state.back(); state.message = "Couldn't read that document: ${e.message}"
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
    Scaffold(
        containerColor = Brand.Surface,
        snackbarHost = { SnackbarHost(snack) },
        bottomBar = {
            if (route in tabs) NavigationBar(containerColor = Brand.Surface) {
                listOf(
                    Triple("Home", "⌂", Route.Home),
                    Triple("Vault", "▦", Route.Vault),
                    Triple("Search", "⌕", Route.Search),
                    Triple("Profile", "◉", Route.Profile),
                ).forEach { (label, glyph, key) ->
                    val active = route == key
                    NavigationBarItem(
                        selected = active,
                        onClick = { state.tab(key) },
                        icon = { Text(glyph, fontSize = 17.sp, color = if (active) Brand.Emerald else Brand.InkMuted) },
                        label = { Text(label, fontSize = 10.sp, fontWeight = if (active) FontWeight.Bold else FontWeight.Normal, color = if (active) Brand.Emerald else Brand.InkMuted) }
                    )
                }
            }
        },
    ) { pad ->
        Box(Modifier.fillMaxSize().padding(pad)) {
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
                is Route.Scanning -> Column(Modifier.fillMaxSize(), Arrangement.Center, Alignment.CenterHorizontally) {
                    CircularProgressIndicator()
                    Spacer(Modifier.height(16.dp))
                    Text(route.stage, style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.height(4.dp))
                    Muted("On this phone. Nothing is uploaded.")
                }
            }
        }
    }
}

@Composable
private fun HomeScreen(state: AppState) {
    val data = state.data
    val self = data.self
    val conflicts = remember(data) { mismatches(profile(data)) }
    val pending = data.people.filter { !it.confirmed }
    Page {
        Spacer(Modifier.height(24.dp))
        if (data.documents.isEmpty()) {
            HeroCard(
                eyebrow = "AI Form & Vault",
                title = "Your encrypted identity-document vault",
                subtitle = "Scan your Aadhaar, PAN or marksheet. Details are read privately, on this phone, and reused to fill forms.",
                cta = "＋ Scan a document",
                onCta = { state.scan },
            )
        } else {
            HeroCard(
                eyebrow = "",
                title = "Hi, ${self?.name?.substringBefore(' ') ?: "there"}",
                subtitle = "Your vault, understood.",
            )
        }
        Spacer(Modifier.height(20.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            DesignButton(
                text = "Scan a document",
                tone = ButtonTone.Primary,
                onClick = state.scan,
                leading = "📷",
            )
            DesignButton(
                text = "Fill a form",
                tone = ButtonTone.Ghost,
                onClick = { state.go(Route.SnapFill) },
                leading = "📝",
            )
        }
        Row {
            DesignButton(
                text = "Import a PDF",
                tone = ButtonTone.Ghost,
                onClick = state.importPdf,
                leading = "📄",
            )
            DesignButton(
                text = "Import photos",
                tone = ButtonTone.Ghost,
                onClick = state.importImages,
                leading = "🖼",
            )
        }

        if (!state.lock.hasPin) {
            Spacer(Modifier.height(8.dp))
            SoftCard(onClick = { state.tab(Route.Profile) }) {
                Column {
                    Text("Set up an app lock", style = MaterialTheme.typography.titleSmall, color = Brand.Warn)
                    Muted("Anyone holding your phone can open your vault right now.")
                }
            }
        }
        if (conflicts.isNotEmpty()) {
            Spacer(Modifier.height(8.dp))
            SoftCard(color = Brand.DangerSoft, onClick = { state.tab(Route.Profile) }) {
                Column {
                    Text("${conflicts.size} detail${if (conflicts.size > 1) "s don't" else " doesn't"} match across documents", style = MaterialTheme.typography.titleSmall, color = Brand.Danger)
                    Muted(conflicts.joinToString { it.key.label } + ". Forms can be rejected over this. Tap to review.")
                }
            }
        }
        pending.firstOrNull()?.let { p ->
            Spacer(Modifier.height(8.dp))
            SoftCard(onClick = { state.go(Route.Relationships) }) {
                Column {
                    Text("Is ${p.name} your ${p.relation.label.lowercase()}?", style = MaterialTheme.typography.titleSmall)
                    Muted(p.evidence)
                    Row {
                        TextButton(onClick = { state.update { d -> d.copy(people = d.people.map { if (it.id == p.id) it.copy(confirmed = true) else it }) } }) { Text("Yes, confirm") }
                        TextButton(onClick = { state.update { d -> d.copy(people = d.people.filter { it.id != p.id }) } }) { Text("No") }
                        if (pending.size > 1) TextButton(onClick = { state.go(Route.Relationships) }) { Text("+${pending.size - 1} more") }
                    }
                }
            }
        }

        if (data.documents.isNotEmpty()) {
            Spacer(Modifier.height(16.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatTile(data.documents.size.toString(), "Documents", Modifier.weight(1f))
                StatTile(data.people.count { it.confirmed && it.relation != Relation.SELF }.toString(), "Family", Modifier.weight(1f))
                StatTile(data.fieldsFilled.toString(), "Fields ready", Modifier.weight(1f))
            }
            val expiring = data.documents.mapNotNull { d -> daysLeft(d)?.takeIf { it <= 90 }?.let { d to it } }.sortedBy { it.second }
            if (expiring.isNotEmpty()) {
                Section("Expiring soon")
                expiring.forEach { (d, _) -> DocRow(d, data.person(d.ownerId)?.name) { state.go(Route.Doc(d.id)) } }
            }
            Section("Recent", "See all") { state.tab(Route.Vault) }
            data.documents.sortedByDescending { it.createdAt }.take(5).forEach { d ->
                DocRow(d, data.person(d.ownerId)?.name) { state.go(Route.Doc(d.id)) }
            }
        }
    }
}

@Composable
private fun VaultScreen(state: AppState) {
    val data = state.data
    var filter by remember { mutableStateOf<Category?>(null) }
    val counts = data.documents.groupingBy { it.category }.eachCount()
    Box(Modifier.fillMaxSize()) {
        Page(title = "Vault", actions = {
            DesignButton(
                text = "Photos",
                tone = ButtonTone.Ghost,
                onClick = state.importImages,
                leading = "📷",
            )
            DesignButton(
                text = "PDF",
                tone = ButtonTone.Ghost,
                onClick = state.importPdf,
                leading = "📄",
            )
        }) {
            Column(Modifier.fillMaxWidth()) {
                Segmented(
                    items = listOf("All") + Category.entries.map { it.label },
                    selected = filter?.let { it.ordinal + 1 } ?: 0,
                    onSelect = { filter = if (it == 0) null else Category.entries[it - 1] },
                )
                Spacer(Modifier.height(12.dp))
                val docs = data.documents.filter { filter == null || it.category == filter }.sortedByDescending { it.createdAt }
                if (docs.isEmpty()) {
                    Muted("Nothing here yet. Scan a document to start your vault.", Modifier.padding(vertical = 24.dp))
                } else {
                    docs.forEach { d -> DesignDocRow(
                        glyph = when (d.category) {
                            Category.IDENTITY -> "🪪"
                            Category.EDUCATION -> "🎓"
                            Category.FINANCE -> "🏦"
                            Category.TRAVEL -> "✈️"
                            else -> "📄"
                        },
                        title = d.title,
                        subtitle = "${data.person(d.ownerId)?.name ?: "Unknown"} • ${d.pages} pages",
                        modifier = Modifier.clickable { state.go(Route.Doc(d.id)) },
                        pill = when (d.category) {
                            Category.IDENTITY -> "OK"
                            Category.EDUCATION -> "Warn"
                            Category.FINANCE -> "OK"
                            Category.TRAVEL -> "OK"
                            else -> null
                        },
                        pillTone = when (d.category) {
                            Category.IDENTITY -> PillTone.Ok
                            Category.EDUCATION -> PillTone.Warn
                            else -> PillTone.Ok
                        },
                        onClick = {},
                    ) }
                }
                Spacer(Modifier.height(72.dp))
            }
        }
        ExtendedFloatingActionButton(
            onClick = state.scan, icon = { Icon(Icons.Filled.Add, null) }, text = { Text("Scan") },
            containerColor = Brand.Emerald, contentColor = Color.White,
            modifier = Modifier.align(Alignment.BottomEnd).padding(20.dp),
        )
    }
}

@Composable
private fun SearchScreen(state: AppState) {
    var q by remember { mutableStateOf("") }
    val results = remember(q, state.data) { search(q, state.data) }
    Page(title = "Search") {
        DesignSearchField(value = q, onValueChange = { q = it }, placeholder = "Search documents…", modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(12.dp))
        if (q.isBlank()) {
            Muted("Search by meaning: a person, a document type, a detail, or when something expires.")
            Spacer(Modifier.height(12.dp))
            listOf("my PAN card", "father's documents", "expiring next year", "ID documents", "marksheet").forEach {
                TextButton(onClick = { q = it }) { Text("“$it”") }
            }
        } else if (results.isEmpty()) {
            Muted("No documents match “$q”.", Modifier.padding(vertical = 16.dp))
        } else {
            Muted("${results.size} result${if (results.size > 1) "s" else ""}")
            Spacer(Modifier.height(8.dp))
            results.forEach { d -> DesignDocRow(
                glyph = when (d.category) {
                    Category.IDENTITY -> "🪪"
                    Category.EDUCATION -> "🎓"
                    Category.FINANCE -> "🏦"
                    Category.TRAVEL -> "✈️"
                    else -> "📄"
                },
                title = d.title,
                subtitle = "${state.data.person(d.ownerId)?.name ?: "Unknown"} • ${d.pages} pages",
                onClick = { state.go(Route.Doc(d.id)) },
            ) }
        }
    }
}
