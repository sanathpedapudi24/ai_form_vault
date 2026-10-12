package com.aiformvault.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.aiformvault.Category
import com.aiformvault.Document
import com.aiformvault.expiry
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/** Standard screen: optional back arrow + title, scrolling content, optional pinned bottom bar. */
@Composable
fun Page(
    title: String? = null,
    onBack: (() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {},
    bottom: (@Composable ColumnScope.() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(Modifier.fillMaxSize()) {
        if (title != null || onBack != null) {
            Row(Modifier.fillMaxWidth().padding(start = 4.dp, end = 8.dp, top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                if (onBack != null) IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") }
                else Spacer(Modifier.width(16.dp))
                Text(title.orEmpty(), style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                actions()
            }
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
            Spacer(Modifier.height(8.dp))
            content()
            Spacer(Modifier.height(24.dp))
        }
        if (bottom != null) Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp), content = bottom)
    }
}

@Composable
fun Section(text: String, action: String? = null, onAction: () -> Unit = {}) {
    Row(Modifier.fillMaxWidth().padding(top = 20.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(text, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
        if (action != null) TextButton(onClick = onAction) { Text(action) }
    }
}

@Composable
fun Muted(text: String, modifier: Modifier = Modifier) =
    Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = modifier)

@Composable
fun SoftCard(modifier: Modifier = Modifier, color: Color = Color.White, onClick: (() -> Unit)? = null, content: @Composable ColumnScope.() -> Unit) {
    val colors = CardDefaults.cardColors(containerColor = color)
    val border = CardDefaults.outlinedCardBorder().copy(width = 1.dp)
    val m = modifier.fillMaxWidth()
    if (onClick != null) Card(onClick = onClick, modifier = m, colors = colors, border = border, shape = RoundedCornerShape(16.dp)) { Column(Modifier.padding(16.dp), content = content) }
    else Card(modifier = m, colors = colors, border = border, shape = RoundedCornerShape(16.dp)) { Column(Modifier.padding(16.dp), content = content) }
}

fun categoryColor(c: Category) = when (c) {
    Category.IDENTITY -> Brand.Emerald
    Category.EDUCATION -> Color(0xFF2563EB)
    Category.VEHICLE -> Color(0xFF7C2D12)
    Category.TRAVEL -> Brand.Teal
    Category.FINANCE -> Color(0xFF15803D)
    Category.MEDICAL -> Color(0xFFDC2626)
    Category.OTHER -> Brand.InkMuted
}

fun daysLeft(d: Document, today: LocalDate = LocalDate.now()) = d.expiry()?.let { ChronoUnit.DAYS.between(today, it) }

@Composable
fun ExpiryBadge(left: Long) {
    val (text, fg, bg) = when {
        left < 0 -> Triple("Expired", Brand.Danger, Brand.DangerSoft)
        left <= 30 -> Triple("$left days left", Brand.Danger, Brand.DangerSoft)
        else -> Triple("$left days left", Brand.Warn, Brand.WarnSoft)
    }
    Text(text, color = fg, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
        modifier = Modifier.background(bg, RoundedCornerShape(50)).padding(horizontal = 10.dp, vertical = 4.dp))
}

@Composable
fun DocRow(doc: Document, owner: String?, onClick: () -> Unit) {
    SoftCard(onClick = onClick, modifier = Modifier.padding(bottom = 8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(44.dp).background(categoryColor(doc.category).copy(alpha = 0.12f), RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
                Text(doc.type.label.take(1), color = categoryColor(doc.category), fontWeight = FontWeight.Bold, fontSize = 18.sp)
            }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(doc.title, style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Muted(listOfNotNull(owner, doc.category.label).joinToString("  ·  "))
            }
            daysLeft(doc)?.takeIf { it <= 90 }?.let { Spacer(Modifier.width(8.dp)); ExpiryBadge(it) }
        }
    }
}

@Composable
fun Stat(value: String, label: String, modifier: Modifier = Modifier) {
    SoftCard(modifier) {
        Text(value, style = MaterialTheme.typography.headlineSmall, color = Brand.EmeraldDeep)
        Muted(label)
    }
}

@Composable
fun Chip(text: String, fg: Color = Brand.EmeraldDeep, bg: Color = Brand.MintSoft) =
    Text(text, color = fg, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
        modifier = Modifier.background(bg, RoundedCornerShape(50)).padding(horizontal = 12.dp, vertical = 6.dp))

/** Outlined button that opens a menu of options. */
@Composable
fun <T> Picker(label: String, value: T, options: List<T>, text: (T) -> String, modifier: Modifier = Modifier, onPick: (T) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box(modifier) {
        OutlinedButton(onClick = { open = true }, Modifier.fillMaxWidth()) {
            Text("$label: ${text(value)}", maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            options.forEach { o -> DropdownMenuItem(text = { Text(text(o)) }, onClick = { open = false; onPick(o) }) }
        }
    }
}

/** 4-dot PIN entry with a 3×4 keypad. Calls [onDone] once 4 digits are in, then clears. */
@Composable
fun PinPad(title: String, subtitle: String?, error: String?, enabled: Boolean = true, onDone: (String) -> Unit, extra: @Composable () -> Unit = {}) {
    var pin by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Text(title, style = MaterialTheme.typography.headlineMedium)
        if (subtitle != null) { Spacer(Modifier.height(8.dp)); Muted(subtitle) }
        Spacer(Modifier.height(28.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.semantics { contentDescription = "${pin.length} of 4 digits entered" }) {
            repeat(4) { i ->
                Box(Modifier.size(16.dp).background(if (i < pin.length) Brand.Emerald else Brand.Surface2, CircleShape))
            }
        }
        Spacer(Modifier.height(16.dp))
        Text(error.orEmpty(), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium)
        Spacer(Modifier.height(16.dp))
        val keys = listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫")
        keys.chunked(3).forEach { row ->
            Row {
                row.forEach { k ->
                    Box(
                        Modifier.size(84.dp, 72.dp).then(
                            if (k.isEmpty() || !enabled) Modifier else Modifier.clickable {
                                if (k == "⌫") pin = pin.dropLast(1)
                                else if (pin.length < 4) {
                                    pin += k
                                    if (pin.length == 4) { val p = pin; pin = ""; onDone(p) }
                                }
                            }.semantics { contentDescription = if (k == "⌫") "Delete digit" else k }
                        ),
                        contentAlignment = Alignment.Center,
                    ) { Text(k, fontSize = 28.sp, color = if (enabled) Brand.Ink else Brand.Surface2) }
                }
            }
        }
        Spacer(Modifier.height(12.dp))
        extra()
    }
}
