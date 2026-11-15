package com.aiformvault.ui

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.autofill.AutofillManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
    var choosing by remember { mutableStateOf<Mismatch?>(null) }
    var reveal by remember { mutableStateOf(false) }
    val self = data.self
    val own = self?.let { data.docsOf(it.id).size } ?: 0
    val keys = entries.map { it.key }.distinct().sorted()

    Screen("Profile", tabs = true, actions = {
        MoreMenu(*listOfNotNull(
            (if (reveal) "Hide numbers" else "Show numbers") to { reveal = !reveal },
            if (hasPin) "Change PIN" to { changingPin = true } else null,
            "Erase everything" to { confirmWipe = true },
        ).toTypedArray())
    }) {
        Cred(if (own == 0) "Scan one of your own documents" else "Built from $own of your document${if (own == 1) "" else "s"}",
            self?.name ?: "Your profile", if (self != null) "Self" else null)

        Sec("Your details")
        if (keys.isEmpty()) Para("Nothing yet. Details from your own documents show up here, and you can add any yourself.")
        else Grp(keys.map { key ->
            @Composable {
                val v = best[key].orEmpty()
                Kv(key.label, if (reveal || !key.sensitive) v else mask(key, v), onClick = { editing = key to v }) {
                    if (entries.any { it.key == key && it.manual }) Text("You", fontSize = 12.sp, color = C.ink2)
                }
            }
        })
        Para("Tap a detail to correct it. Your edits always win over what was read.", top = 8.dp)
        AddFieldMenu(FactKey.entries.filter { it != FactKey.EXPIRY && it !in keys }) { editing = it to "" }

        if (conflicts.isNotEmpty()) {
            Sec("Needs your attention")
            conflicts.values.forEach { m ->
                Note(true, Ic.alert, "${m.key.label} differs",
                    m.values.entries.joinToString(" ") { (v, src) -> "${src.joinToString(", ")} has ${if (reveal) v else mask(m.key, v)}." }) {
                    Btn("Choose one", BtnKind.Tonal, small = true) { choosing = m }
                }
            }
        }

        val pending = data.people.count { !it.confirmed }
        val fam = data.people.count { it.confirmed && it.relation != Relation.SELF }
        Sec("Family")
        Grp({ Item({ Dic(Ic.users) }, "Relationships", "$fam confirmed, $pending to review", end = { Chev() }) { state.go(Route.Relationships) } })

        Sec("App lock")
        Grp(listOfNotNull<@Composable () -> Unit>(
            if (hasPin) { { Item({ Dic(Ic.lock) }, "PIN lock", "The vault locks whenever you leave the app", end = {
                Sw(true, "PIN lock") { state.lock.removePin(); hasPin = false; bio = false; state.message = "App lock turned off" }
            }) } } else { { Item({ Dic(Ic.lock) }, "Set up a PIN", "Anyone holding your phone can open your vault", end = { Chev() }) { changingPin = true } } },
            if (hasPin) { { Item({ Dic(Ic.key) }, "Change PIN", end = { Chev() }) { changingPin = true } } } else null,
            if (hasPin && biometricAvailable(ctx)) { { Item({ Dic(Ic.finger) }, "Unlock with fingerprint", "Your PIN still works", end = {
                Sw(bio, "Unlock with fingerprint") { bio = it; state.lock.biometric = it }
            }) } } else null,
        ))

        Sec("Autofill in other apps")
        Grp(
            { Item({ Dic(Ic.form) }, if (autofillOn) "Autofill service is on" else "Fill forms in other apps",
                if (autofillOn) "AI Form & Vault fills forms in other apps and websites" else "Pick AI Form & Vault in Android settings",
                end = { if (!autofillOn) Chev() }, onClick = if (autofillOn) null else ({
                    Session.external = true
                    ctx.startActivity(Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE).setData(Uri.parse("package:${ctx.packageName}")))
                })) },
            { Item({ Dic(Ic.user) }, "Offer my details", "Never offered: Aadhaar, passport, voter ID, licence and vehicle numbers", end = {
                Sw(share, "Offer my details to other apps") { share = it; state.lock.autofill = it }
            }) },
        )

        Sec("Reminders")
        Grp({ Item({ Dic(Ic.bell) }, "Expiry reminders", "90, 30 and 7 days before a document expires", end = {
            Sw(reminders, "Expiry reminders") { on ->
                if (on && Build.VERSION.SDK_INT >= 33) notifPerm.launch(Manifest.permission.POST_NOTIFICATIONS)
                else { reminders = on; state.lock.reminders = on }
            }
        }) })

        Sec("Backup and reset")
        Grp(
            { Item({ Dic(Ic.down) }, "Export backup", "Encrypted .aivault file", end = { Chev() }) { passFor = "export" } },
            { Item({ Dic(Ic.redo) }, "Restore backup", "Merge a .aivault file into this vault", end = { Chev() }) { Session.external = true; importFrom.launch(arrayOf("*/*")) } },
            { Item({ Dic(Ic.trash, danger = true) }, "Wipe vault", "Deletes database, scans and keys", end = { Chev() }) { confirmWipe = true } },
        )
        Para("Documents are read on this phone and stored encrypted with a key held in Android's secure hardware. Nothing is uploaded: there's no account and no server. Screenshots are blocked inside the app.", top = 16.dp)
    }

    choosing?.let { m ->
        AlertDialog(
            onDismissRequest = { choosing = null }, containerColor = C.card,
            title = { Text("Which ${m.key.label.lowercase()} is right?") },
            text = {
                Column {
                    SuText("Forms can be rejected over a mismatch. Get the wrong document corrected at the issuing office.")
                    m.values.forEach { (v, src) ->
                        TextButton(onClick = {
                            choosing = null
                            state.update { d -> d.copy(manual = d.manual.filter { it.key != m.key } + ManualFact(m.key, v, System.currentTimeMillis())) }
                        }, Modifier.fillMaxWidth()) {
                            Column(Modifier.fillMaxWidth()) {
                                Text(if (reveal) v else mask(m.key, v), color = C.ink, fontSize = 16.sp)
                                Text(src.joinToString(", "), color = C.ink2, fontSize = 12.sp)
                            }
                        }
                    }
                }
            },
            confirmButton = { TextButton(onClick = { choosing = null }) { Text("Cancel") } },
        )
    }

    editing?.let { (key, initial) ->
        var v by remember(key) { mutableStateOf(initial) }
        AlertDialog(
            onDismissRequest = { editing = null }, containerColor = C.card,
            title = { Text(key.label) },
            text = { Tf(key.label, v, { v = it }, singleLine = key != FactKey.ADDRESS) },
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
            onDismissRequest = { passFor = null }, containerColor = C.card,
            title = { Text(if (export) "Choose a backup passphrase" else "Backup passphrase") },
            text = {
                Column {
                    if (export) SuText("At least 8 characters. It can't be recovered if you forget it.")
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
        onDismissRequest = { confirmWipe = false }, containerColor = C.card,
        title = { Text("Erase everything?") },
        text = { Text("All documents, details, family members and settings are permanently removed from this phone. Back up first if you might want them again.") },
        confirmButton = { TextButton(onClick = { confirmWipe = false; state.wipe() }) { Text("Erase", fontWeight = FontWeight.Bold) } },
        dismissButton = { TextButton(onClick = { confirmWipe = false }) { Text("Cancel") } },
    )
}


@Composable
fun RelationshipsScreen(state: AppState) {
    val data = state.data
    var adding by remember { mutableStateOf(false) }
    var open by remember { mutableStateOf<Person?>(null) }
    val pending = data.people.filter { !it.confirmed }
    val fam = data.people.filter { it.confirmed && it.relation != Relation.SELF }
    fun confirm(p: Person, rel: Relation = p.relation) = state.update { d -> d.copy(people = d.people.map { if (it.id == p.id) it.copy(confirmed = true, relation = rel) else it }) }
    fun remove(p: Person) = state.update { d -> d.copy(people = d.people.filter { it.id != p.id }) }

    Screen("Relationships", onBack = state::back, actions = { IconBtn(Ic.plus, "Add person") { adding = true } }) {
        if (pending.isNotEmpty()) Note(false, Ic.info, "${pending.size} suggestion${if (pending.size > 1) "s" else ""} to review", "Built only from your own documents.")
        else Note(false, Ic.info, "Your family", "People are linked only when you confirm them. Their details never go into your profile.")
        if (pending.isEmpty() && fam.isEmpty()) { Para("No one yet. Scan a family member's document and choose “Someone else”, or add them with +."); return@Screen }
        Grp((pending + fam).map { p ->
            @Composable {
                val docs = data.docsOf(p.id).size
                Item({ Av(p.name) }, p.name,
                    if (p.confirmed) "${p.relation.label}, $docs document${if (docs == 1) "" else "s"}" else "${p.relation.label}? ${p.evidence}".trim(),
                    end = { if (p.confirmed) Pill("Confirmed") else Btn("Confirm", BtnKind.Tonal, small = true) { confirm(p) } }) { open = p }
            }
        })
    }

    open?.let { p ->
        var rel by remember(p.id) { mutableStateOf(p.relation) }
        val docs = data.docsOf(p.id)
        AlertDialog(
            onDismissRequest = { open = null }, containerColor = C.card,
            title = { Text(p.name) },
            text = {
                Column {
                    if (!p.confirmed && p.evidence.isNotBlank()) SuText(p.evidence, Modifier.padding(bottom = 10.dp))
                    PickerTf("They are your", rel, Relation.entries.filter { it != Relation.SELF }, { it.label.lowercase() }) { rel = it }
                    docs.forEach { d -> TextButton(onClick = { open = null; state.go(Route.Doc(d.id)) }) { Text(d.title, color = C.g) } }
                }
            },
            confirmButton = { TextButton(onClick = { open = null; confirm(p, rel) }) { Text(if (p.confirmed) "Save" else "Confirm") } },
            dismissButton = {
                if (!p.confirmed || docs.isEmpty()) TextButton(onClick = { open = null; remove(p) }) { Text(if (p.confirmed) "Remove" else "Not related") }
                else TextButton(onClick = { open = null }) { Text("Cancel") }
            },
        )
    }
    if (adding) {
        var name by remember { mutableStateOf("") }
        var rel by remember { mutableStateOf(Relation.OTHER) }
        AlertDialog(
            onDismissRequest = { adding = false }, containerColor = C.card,
            title = { Text("Add person") },
            text = {
                Column {
                    Tf("Name", name, { name = it })
                    PickerTf("They are your", rel, Relation.entries.filter { it != Relation.SELF }, { it.label.lowercase() }) { rel = it }
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
