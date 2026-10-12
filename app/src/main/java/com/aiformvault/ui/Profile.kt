package com.aiformvault.ui

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.autofill.AutofillManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.aiformvault.Entry
import com.aiformvault.FactKey
import com.aiformvault.ManualFact
import com.aiformvault.Mismatch
import com.aiformvault.Person
import com.aiformvault.Relation
import com.aiformvault.Store
import com.aiformvault.bestFacts
import com.aiformvault.mask
import com.aiformvault.mismatches
import com.aiformvault.profile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.util.UUID

@Composable
fun ProfileScreen(state: AppState) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val data = state.data
    val entries = remember(data) { profile(data) }
    val conflicts = remember(entries) { mismatches(entries).associateBy { it.key } }
    val best = remember(data) { bestFacts(data) }
    var editing by remember { mutableStateOf<Pair<FactKey, String>?>(null) }
    var changingPin by remember { mutableStateOf(false) }
    var hasPin by remember { mutableStateOf(state.lock.hasPin) }
    var bio by remember { mutableStateOf(state.lock.biometric) }
    var share by remember { mutableStateOf(state.lock.autofill) }
    var reminders by remember { mutableStateOf(state.lock.reminders) }
    var passFor by remember { mutableStateOf<String?>(null) } // "export" or "import"
    var restoreUri by remember { mutableStateOf<Uri?>(null) }
    var pendingPass by remember { mutableStateOf<CharArray?>(null) }
    var confirmWipe by remember { mutableStateOf(false) }

    val afm = ctx.getSystemService(AutofillManager::class.java)
    var autofillOn by remember { mutableStateOf(afm?.hasEnabledAutofillServices() == true) }
    LaunchedEffect(Unit) { while (true) { autofillOn = afm?.hasEnabledAutofillServices() == true; delay(1000) } }

    val notifPerm = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        reminders = ok; state.lock.reminders = ok
        if (!ok) state.message = "Allow notifications in Android settings to get expiry reminders"
    }
    val exportTo = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")) { uri ->
        val pass = pendingPass; pendingPass = null
        if (uri != null && pass != null) scope.launch {
            state.message = "Encrypting backup…"
            state.message = runCatching { withContext(Dispatchers.IO) { Store.exportBackup(ctx, state.data, pass, uri) } }
                .fold({ "Backup saved. Keep the passphrase safe: it can't be recovered." }, { "Backup failed: ${it.message}" })
        }
    }
    val importFrom = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) { restoreUri = uri; passFor = "import" }
    }

    if (changingPin) { PinSetup(state) { changingPin = false; hasPin = state.lock.hasPin; bio = state.lock.biometric }; return }

    Page(title = "Profile") {
        Text(data.self?.name ?: "Your profile", style = MaterialTheme.typography.headlineMedium)
        val own = data.self?.let { data.docsOf(it.id).size } ?: 0
        Muted(if (own == 0) "Scan one of your own documents to build your profile." else "Built from $own of your documents. Your edits always win.")
        Spacer(Modifier.height(16.dp))
        entries.groupBy { it.key }.toSortedMap().forEach { (key, es) ->
            FactCard(key, es, conflicts[key], best[key].orEmpty(),
                onUse = { v -> state.update { d -> d.copy(manual = d.manual.filter { it.key != key } + ManualFact(key, v, System.currentTimeMillis())) } },
                onEdit = { editing = key to best[key].orEmpty() },
                onUndo = { state.update { d -> d.copy(manual = d.manual.filter { it.key != key }) } })
            Spacer(Modifier.height(8.dp))
        }
        AddFieldMenu(FactKey.entries.filter { it != FactKey.EXPIRY }) { editing = it to best[it].orEmpty() }

        Section("Family", "Manage") { state.go(Route.Relationships) }
        val pending = data.people.count { !it.confirmed }
        val fam = data.people.count { it.confirmed && it.relation != Relation.SELF }
        SoftCard(onClick = { state.go(Route.Relationships) }) {
            Text(if (fam == 0) "No family members yet" else "$fam family member${if (fam > 1) "s" else ""}", style = MaterialTheme.typography.titleSmall)
            Muted(if (pending > 0) "$pending suggestion${if (pending > 1) "s" else ""} waiting for you" else "Their documents stay separate from your profile.")
        }

        Section("App lock")
        SoftCard {
            if (hasPin) {
                Text("PIN lock is on", style = MaterialTheme.typography.titleSmall)
                Muted("The vault locks whenever you leave the app.")
                Row {
                    TextButton(onClick = { changingPin = true }) { Text("Change PIN") }
                    TextButton(onClick = { state.lock.removePin(); hasPin = false; bio = false }) { Text("Turn off") }
                }
                if (biometricAvailable(ctx)) SwitchRow("Unlock with fingerprint", bio) { bio = it; state.lock.biometric = it }
            } else {
                Text("No app lock", style = MaterialTheme.typography.titleSmall)
                Muted("Anyone holding your phone can open your vault.")
                Spacer(Modifier.height(8.dp))
                Button(onClick = { changingPin = true }) { Text("Set up a PIN") }
            }
        }

        Section("Autofill in other apps")
        SoftCard {
            if (autofillOn) {
                Text("AI Form & Vault is your autofill service", style = MaterialTheme.typography.titleSmall)
            } else {
                Text("Fill forms in other apps and websites", style = MaterialTheme.typography.titleSmall)
                Muted("Pick AI Form & Vault as the autofill service in Android settings. You can switch back any time.")
                Spacer(Modifier.height(8.dp))
                Button(onClick = {
                    Session.external = true
                    ctx.startActivity(Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE).setData(Uri.parse("package:${ctx.packageName}")))
                }) { Text("Turn on in Android settings") }
            }
            Spacer(Modifier.height(8.dp))
            SwitchRow("Offer my details to other apps", share) { share = it; state.lock.autofill = it }
            Muted("Offered: ${FactKey.entries.filter { it.shareable }.joinToString { it.label.lowercase() }}. " +
                "Never offered: Aadhaar, passport, voter ID, licence and vehicle numbers. You pick before anything is filled.")
        }

        Section("Reminders")
        SoftCard {
            SwitchRow("Remind me before documents expire", reminders) { on ->
                if (on && Build.VERSION.SDK_INT >= 33) notifPerm.launch(Manifest.permission.POST_NOTIFICATIONS)
                else { reminders = on; state.lock.reminders = on }
            }
            Muted("90, 30 and 7 days before, for passports, licences and anything else with an expiry date.")
        }

        Section("Backup")
        SoftCard {
            Muted("A backup is one file encrypted with a passphrase you choose. Keep it on Drive, email or a USB stick: without the passphrase nobody can open it, including us.")
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { passFor = "export" }, Modifier.weight(1f)) { Text("Back up") }
                OutlinedButton(onClick = { Session.external = true; importFrom.launch(arrayOf("*/*")) }, Modifier.weight(1f)) { Text("Restore") }
            }
        }

        Section("Privacy")
        Muted("Documents are read on this phone and stored encrypted with a key held in Android's secure hardware. Nothing is uploaded: there's no account and no server. Screenshots are blocked inside the app.")
        Spacer(Modifier.height(16.dp))
        TextButton(onClick = { confirmWipe = true }) { Text("Erase everything", color = MaterialTheme.colorScheme.error) }
    }

    editing?.let { (key, initial) ->
        var v by remember(key) { mutableStateOf(initial) }
        AlertDialog(
            onDismissRequest = { editing = null },
            title = { Text(key.label) },
            text = { OutlinedTextField(v, { v = it }, singleLine = key != FactKey.ADDRESS, modifier = Modifier.fillMaxWidth()) },
            confirmButton = {
                TextButton(onClick = {
                    editing = null
                    if (v.isNotBlank()) state.update { d -> d.copy(manual = d.manual.filter { it.key != key } + ManualFact(key, v.trim(), System.currentTimeMillis())) }
                }) { Text("Save") }
            },
            dismissButton = { TextButton(onClick = { editing = null }) { Text("Cancel") } },
        )
    }

    passFor?.let { mode ->
        var p1 by remember(mode) { mutableStateOf("") }
        var p2 by remember(mode) { mutableStateOf("") }
        val export = mode == "export"
        val ok = if (export) p1.length >= 8 && p1 == p2 else p1.isNotEmpty()
        AlertDialog(
            onDismissRequest = { passFor = null },
            title = { Text(if (export) "Choose a backup passphrase" else "Backup passphrase") },
            text = {
                Column {
                    if (export) Muted("At least 8 characters. It can't be recovered if you forget it.")
                    OutlinedTextField(p1, { p1 = it }, label = { Text("Passphrase") }, singleLine = true, visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password), modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
                    if (export) OutlinedTextField(p2, { p2 = it }, label = { Text("Repeat passphrase") }, singleLine = true, visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password), modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
                }
            },
            confirmButton = {
                TextButton(enabled = ok, onClick = {
                    passFor = null
                    if (export) {
                        pendingPass = p1.toCharArray(); Session.external = true
                        exportTo.launch("ai-form-vault-${LocalDate.now()}.aivault")
                    } else restoreUri?.let { uri ->
                        scope.launch {
                            state.message = "Restoring…"
                            runCatching { withContext(Dispatchers.IO) { Store.importBackup(ctx, state.data, p1.toCharArray(), uri) } }
                                .onSuccess { merged -> val added = merged.documents.size - state.data.documents.size; state.update { merged }; state.message = "Restored $added document${if (added == 1) "" else "s"}" }
                                .onFailure { state.message = it.message ?: "Restore failed" }
                        }
                    }
                }) { Text(if (export) "Choose where to save" else "Restore") }
            },
            dismissButton = { TextButton(onClick = { passFor = null }) { Text("Cancel") } },
        )
    }

    if (confirmWipe) AlertDialog(
        onDismissRequest = { confirmWipe = false },
        title = { Text("Erase everything?") },
        text = { Text("All documents, details, family members and settings are permanently removed from this phone. Back up first if you might want them again.") },
        confirmButton = { TextButton(onClick = { confirmWipe = false; state.wipe() }) { Text("Erase", color = MaterialTheme.colorScheme.error) } },
        dismissButton = { TextButton(onClick = { confirmWipe = false }) { Text("Cancel") } },
    )
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        Switch(checked, onChange)
    }
}

/** One profile detail, with where it came from. A mismatch shows every value and lets the user pick the right one. */
@Composable
private fun FactCard(key: FactKey, entries: List<Entry>, conflict: Mismatch?, best: String, onUse: (String) -> Unit, onEdit: () -> Unit, onUndo: () -> Unit) {
    var reveal by remember { mutableStateOf(false) }
    val manual = entries.any { it.manual }
    SoftCard(color = if (conflict != null) Brand.DangerSoft else androidx.compose.ui.graphics.Color.White) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(key.label, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
            if (key.sensitive) TextButton(onClick = { reveal = !reveal }) { Text(if (reveal) "Hide" else "Show") }
            TextButton(onClick = onEdit) { Text("Edit") }
        }
        if (conflict == null) {
            Text(if (reveal) best else mask(key, best), style = MaterialTheme.typography.titleMedium)
            Muted(if (manual) "Set by you" else "From " + entries.map { it.source }.distinct().joinToString(", "))
            if (manual && entries.any { !it.manual }) TextButton(onClick = onUndo, contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)) { Text("Use the documents' value") }
        } else {
            Text("Doesn't match across documents", style = MaterialTheme.typography.titleSmall, color = Brand.Danger)
            Spacer(Modifier.height(4.dp))
            conflict.values.forEach { (value, sources) ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(if (reveal) value else mask(key, value), style = MaterialTheme.typography.bodyLarge)
                        Muted(sources.joinToString(", "))
                    }
                    TextButton(onClick = { onUse(value) }) { Text("This is right") }
                }
            }
            Muted("Forms can be rejected over a mismatch. Get the wrong document corrected at the issuing office.")
        }
    }
}

@Composable
fun RelationshipsScreen(state: AppState) {
    val data = state.data
    var adding by remember { mutableStateOf(false) }
    Page(title = "Family", onBack = state::back, actions = { TextButton(onClick = { adding = true }) { Text("+ Add") } }) {
        Muted("People are only linked when you confirm them. Their documents and details stay with them, never in your profile.")
        val pending = data.people.filter { !it.confirmed }
        if (pending.isNotEmpty()) Section("Suggestions")
        pending.forEach { p ->
            var rel by remember(p.id) { mutableStateOf(p.relation) }
            SoftCard(Modifier.padding(bottom = 8.dp)) {
                Text(p.name, style = MaterialTheme.typography.titleMedium)
                Muted(p.evidence)
                Spacer(Modifier.height(8.dp))
                Picker("They are your", rel, Relation.entries.filter { it != Relation.SELF }, { it.label.lowercase() }) { rel = it }
                Row {
                    TextButton(onClick = { state.update { d -> d.copy(people = d.people.map { if (it.id == p.id) it.copy(confirmed = true, relation = rel) else it }) } }) { Text("Confirm") }
                    TextButton(onClick = { state.update { d -> d.copy(people = d.people.filter { it.id != p.id }) } }) { Text("Not related") }
                }
            }
        }
        Section("Your family")
        val fam = data.people.filter { it.confirmed && it.relation != Relation.SELF }
        if (fam.isEmpty()) Muted("No one yet. Scan a family member's document and choose “Someone else”, or add them here.")
        fam.forEach { p ->
            val docs = data.docsOf(p.id)
            SoftCard(Modifier.padding(bottom = 8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(p.name, style = MaterialTheme.typography.titleMedium)
                        Muted("${p.relation.label}  ·  ${docs.size} document${if (docs.size == 1) "" else "s"}")
                    }
                    if (docs.isEmpty()) TextButton(onClick = { state.update { d -> d.copy(people = d.people.filter { it.id != p.id }) } }) { Text("Remove") }
                }
                docs.forEach { d -> TextButton(onClick = { state.go(Route.Doc(d.id)) }) { Text(d.title) } }
            }
        }
    }
    if (adding) {
        var name by remember { mutableStateOf("") }
        var rel by remember { mutableStateOf(Relation.OTHER) }
        AlertDialog(
            onDismissRequest = { adding = false },
            title = { Text("Add family member") },
            text = {
                Column {
                    OutlinedTextField(name, { name = it }, label = { Text("Name") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                    Spacer(Modifier.height(8.dp))
                    Picker("They are your", rel, Relation.entries.filter { it != Relation.SELF }, { it.label.lowercase() }) { rel = it }
                }
            },
            confirmButton = {
                TextButton(enabled = name.isNotBlank(), onClick = {
                    adding = false
                    state.update { d -> d.copy(people = d.people + Person(UUID.randomUUID().toString(), name.trim(), rel, true)) }
                }) { Text("Add") }
            },
            dismissButton = { TextButton(onClick = { adding = false }) { Text("Cancel") } },
        )
    }
}
