package com.aiformvault.ui

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsBottomHeight
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import com.aiformvault.Category
import com.aiformvault.Document
import com.aiformvault.expiry
import java.time.LocalDate
import java.time.temporal.ChronoUnit

// Primitives mirroring SCREEN_DESIGN.html class-for-class. Names in comments are the CSS classes.

// ---------- type ----------
val H1 get() = TextStyle(fontFamily = Disp, fontWeight = FontWeight.Bold, fontSize = 32.sp, lineHeight = 36.sp, letterSpacing = (-0.03).em)
val Ti get() = TextStyle(fontFamily = Body, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, lineHeight = 22.sp)
val Su get() = TextStyle(fontFamily = Body, fontSize = 14.sp, lineHeight = 20.sp)

@Composable fun TiText(text: String, modifier: Modifier = Modifier, color: Color = C.ink, maxLines: Int = Int.MAX_VALUE) =
    Text(text, modifier, style = Ti, color = color, maxLines = maxLines, overflow = TextOverflow.Ellipsis)
@Composable fun SuText(text: String, modifier: Modifier = Modifier, color: Color = C.ink2, maxLines: Int = Int.MAX_VALUE) =
    Text(text, modifier, style = Su, color = color, maxLines = maxLines, overflow = TextOverflow.Ellipsis)
@Composable fun SuText(text: AnnotatedString, modifier: Modifier = Modifier) = Text(text, modifier, style = Su, color = C.ink2)

/** `mark`: highlight [q] inside [text]. */
@Composable
fun marked(text: String, q: String): AnnotatedString {
    val g = C.g; val on = C.on
    return buildAnnotatedString {
        val i = if (q.isBlank()) -1 else text.indexOf(q.trim(), ignoreCase = true)
        if (i < 0) { append(text); return@buildAnnotatedString }
        append(text.substring(0, i))
        withStyle(SpanStyle(background = g, color = on)) { append(text.substring(i, i + q.trim().length)) }
        append(text.substring(i + q.trim().length))
    }
}

private fun Modifier.tap(onClick: (() -> Unit)?, role: Role = Role.Button) = if (onClick == null) this else clickable(role = role, onClick = onClick)

// ---------- screen shell ----------

/** `.screen`: optional `.bar`, a `.scroll` body and an optional `.dock`. [tabs] reserves room for the floating tab bar. */
@Composable
fun Screen(
    title: String? = null,
    onBack: (() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {},
    header: (@Composable () -> Unit)? = null,
    tabs: Boolean = false,
    dock: (@Composable ColumnScope.() -> Unit)? = null,
    overlay: @Composable BoxScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize()) {
            if (header != null) header() else if (title != null) Bar(title, onBack, actions)
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 4.dp)) {
                content()
                Spacer(Modifier.height(if (tabs) 120.dp else 24.dp))
                if (dock == null) Spacer(Modifier.windowInsetsBottomHeight(WindowInsets.navigationBars))
            }
            if (dock != null) Dock(dock)
        }
        overlay()
    }
}

/** `.bar` / `.bar.back`: back `.ib`, an h1 title, and right-hand actions. */
@Composable
fun Bar(title: String, onBack: (() -> Unit)? = null, actions: @Composable RowScope.() -> Unit = {}) {
    Row(
        Modifier.fillMaxWidth().padding(start = if (onBack != null) 8.dp else 20.dp, end = 16.dp, top = 8.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        if (onBack != null) { IconBtn(Ic.left, "Back", onBack); Spacer(Modifier.width(6.dp)) }
        Text(title, Modifier.weight(1f), style = H1, color = C.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
        actions()
    }
}

/** `.ib`: 44dp round icon button. */
@Composable
fun IconBtn(icon: ImageVector, label: String, onClick: () -> Unit) {
    Box(
        Modifier.size(44.dp).clip(CircleShape).background(C.card).border(1.dp, C.line, CircleShape)
            .clickable(onClick = onClick).semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) { I(icon, tint = C.ink) }
}

/** `.ib` with a `more` icon that opens a menu. */
@Composable
fun MoreMenu(vararg items: Pair<String, () -> Unit>) {
    var open by remember { mutableStateOf(false) }
    Box {
        IconBtn(Ic.more, "More options") { open = true }
        DropdownMenu(open, { open = false }, containerColor = C.card) {
            items.forEach { (t, f) -> DropdownMenuItem(text = { Text(t, color = C.ink, fontSize = 15.sp) }, onClick = { open = false; f() }) }
        }
    }
}

/** `h2.sec` */
@Composable
fun Sec(text: String, action: String? = null, onAction: () -> Unit = {}) {
    Row(Modifier.fillMaxWidth().padding(start = 6.dp, end = 6.dp, top = 28.dp, bottom = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(text, Modifier.weight(1f), fontFamily = Body, fontWeight = FontWeight(650), fontSize = 15.sp, lineHeight = 20.sp, color = C.ink)
        if (action != null) Text(action, Modifier.clip(RoundedCornerShape(12.dp)).clickable(onClick = onAction).padding(horizontal = 6.dp, vertical = 2.dp),
            color = C.g, fontWeight = FontWeight(650), fontSize = 14.sp)
    }
}

// ---------- groups and rows ----------

/** `.grp`: rounded card; rows inside get hairlines between them. */
@Composable
fun Grp(rows: List<@Composable () -> Unit>) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(C.card).border(1.dp, C.line, RoundedCornerShape(24.dp))) {
        rows.forEachIndexed { i, r ->
            if (i > 0) Box(Modifier.fillMaxWidth().height(1.dp).background(C.line))
            r()
        }
    }
}
@Composable fun Grp(vararg rows: @Composable () -> Unit) = Grp(rows.toList())

/** `.item`: leading icon/avatar, title + subtitle, trailing end. */
@Composable
fun Item(lead: @Composable () -> Unit, title: String, sub: String? = null, end: @Composable () -> Unit = {}, titleColor: Color = C.ink, subText: AnnotatedString? = null, onClick: (() -> Unit)? = null) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 72.dp).tap(onClick).padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        lead()
        Column(Modifier.weight(1f)) {
            TiText(title, color = titleColor)
            if (subText != null) SuText(subText) else if (!sub.isNullOrBlank()) SuText(sub)
        }
        end()
    }
}

/** `.chev` */
@Composable fun Chev() = I(Ic.right, 20.dp, C.ink2)

/** `.dic`: 46dp rounded icon tile. */
@Composable
fun Dic(icon: ImageVector, size: Dp = 46.dp, iconSize: Dp = 22.dp, danger: Boolean = false, bg: Color = if (danger) C.card2 else C.gs, tint: Color = if (danger) C.ink else C.g2, shape: RoundedCornerShape = RoundedCornerShape(14.dp)) {
    Box(Modifier.size(size).clip(shape).background(bg), contentAlignment = Alignment.Center) { I(icon, iconSize, tint) }
}

/** `.av`: initials avatar. */
@Composable
fun Av(name: String, size: Dp = 46.dp, onClick: (() -> Unit)? = null) {
    Box(Modifier.size(size).clip(CircleShape).background(C.g).tap(onClick), contentAlignment = Alignment.Center) {
        Text(initials(name), fontFamily = Disp, fontWeight = FontWeight.Bold, fontSize = 15.sp, color = C.on)
    }
}
fun initials(name: String) = name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.let { p ->
    (p.firstOrNull()?.take(1).orEmpty() + (if (p.size > 1) p.last().take(1) else "")).uppercase().ifEmpty { "?" }
}

/** `.kv`: key/value row; value `.off` when unset. */
@Composable
fun Kv(k: String, v: String?, onClick: (() -> Unit)? = null, trailing: @Composable () -> Unit = {}) {
    Row(Modifier.fillMaxWidth().tap(onClick).padding(horizontal = 18.dp, vertical = 15.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(k, Modifier.width(104.dp), fontSize = 14.sp, color = C.ink2)
        if (v.isNullOrBlank()) Text("Not set", Modifier.weight(1f), fontSize = 16.sp, color = C.ink2)
        else Text(v, Modifier.weight(1f), fontSize = 16.sp, fontWeight = FontWeight(550), color = C.ink)
        trailing()
    }
}

/** `.pill.ok` (check) / `.pill.warn` (alert). */
@Composable
fun Pill(text: String, ok: Boolean = true) {
    val bg = if (ok) C.gs else C.g; val fg = if (ok) C.g else C.on
    Row(Modifier.clip(RoundedCornerShape(14.dp)).background(bg).padding(start = 8.dp, end = 11.dp, top = 5.dp, bottom = 5.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        I(if (ok) Ic.check else Ic.alert, 14.dp, fg)
        Text(text, fontSize = 12.sp, fontWeight = FontWeight(650), color = fg, maxLines = 1)
    }
}

// ---------- buttons ----------

enum class BtnKind { Pri, Tonal, Line, Ghost }

/** `.btn` (.pri / .tonal / .line / .ghost, `.sm`). */
@Composable
fun Btn(text: String, kind: BtnKind = BtnKind.Pri, modifier: Modifier = Modifier, small: Boolean = false, icon: ImageVector? = null, enabled: Boolean = true, fill: Boolean = !small, onClick: () -> Unit) {
    val shape = RoundedCornerShape(if (small) 19.dp else 28.dp)
    val (bg, fg) = when (kind) {
        BtnKind.Pri -> C.g to C.on
        BtnKind.Tonal -> C.gs to C.g
        BtnKind.Line -> C.card to C.ink
        BtnKind.Ghost -> Color.Transparent to C.ink
    }
    Row(
        modifier.then(if (fill) Modifier.fillMaxWidth() else Modifier).height(if (small) 38.dp else 56.dp).clip(shape).background(bg)
            .then(if (kind == BtnKind.Line) Modifier.border(1.5.dp, C.line, shape) else Modifier)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick).padding(horizontal = if (small) 18.dp else 24.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically,
    ) {
        val c = if (enabled) fg else fg.copy(alpha = 0.4f)
        if (icon != null) I(icon, 20.dp, c)
        Text(text, fontSize = if (small) 14.sp else 16.sp, fontWeight = FontWeight(650), color = c, maxLines = 1,
            textDecoration = if (kind == BtnKind.Ghost) TextDecoration.Underline else null)
    }
}

/** `.tbtn`: text button in brand green. */
@Composable
fun TBtn(text: String, color: Color = C.g, enabled: Boolean = true, onClick: () -> Unit) =
    Box(Modifier.height(44.dp).clip(RoundedCornerShape(22.dp)).clickable(enabled = enabled, role = Role.Button, onClick = onClick).padding(horizontal = 16.dp),
        contentAlignment = Alignment.Center) {
        Text(text, color = if (enabled) color else color.copy(alpha = 0.4f), fontWeight = FontWeight(650), fontSize = 15.sp)
    }

// ---------- notes, fields, chips ----------

/** `.note.warn` (outlined) / `.note.ok` (filled). */
@Composable
fun Note(warn: Boolean, icon: ImageVector, title: String, text: String, onClick: (() -> Unit)? = null, actions: (@Composable RowScope.() -> Unit)? = null) {
    val shape = RoundedCornerShape(22.dp)
    Row(
        Modifier.fillMaxWidth().padding(bottom = 10.dp).clip(shape)
            .then(if (warn) Modifier.border(1.5.dp, C.g, shape) else Modifier.background(C.gs)).tap(onClick).padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        I(icon, 22.dp, C.g)
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 15.sp, lineHeight = 20.sp, fontWeight = FontWeight(650), color = C.ink)
            Text(text, Modifier.padding(top = 2.dp), fontSize = 14.sp, lineHeight = 20.sp, color = C.ink2)
            if (actions != null) Row(Modifier.padding(top = 14.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically, content = actions)
        }
    }
}

/** `.tf` (`.miss` dashed when [miss]): label over an editable value. Read-only when [onChange] is null. */
@Composable
fun Tf(label: String, value: String, onChange: ((String) -> Unit)? = null, miss: Boolean = false, placeholder: String = "", singleLine: Boolean = true,
       keyboard: KeyboardOptions = KeyboardOptions.Default, trailing: (@Composable () -> Unit)? = null, visual: androidx.compose.ui.text.input.VisualTransformation = androidx.compose.ui.text.input.VisualTransformation.None) {
    val shape = RoundedCornerShape(18.dp)
    val line = C.line; val g = C.g
    Row(
        Modifier.fillMaxWidth().padding(bottom = 10.dp).clip(shape)
            .then(if (miss) Modifier.dashed(g, 18.dp) else Modifier.background(C.card).border(1.dp, line, shape))
            .padding(start = 16.dp, end = if (trailing != null) 6.dp else 16.dp, top = 10.dp, bottom = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(label, fontSize = 12.sp, color = C.ink2)
            val style = TextStyle(fontFamily = Body, fontSize = 17.sp, fontWeight = FontWeight(550), lineHeight = 24.sp, color = C.ink)
            if (onChange == null) Text(value.ifEmpty { placeholder }, style = if (value.isEmpty()) style.copy(color = C.ink2, fontWeight = FontWeight.Normal) else style)
            else BasicTextField(value, onChange, singleLine = singleLine, textStyle = style, cursorBrush = SolidColor(g), keyboardOptions = keyboard, visualTransformation = visual,
                decorationBox = { inner -> Box { if (value.isEmpty()) Text(placeholder, style = style.copy(color = C.ink2, fontWeight = FontWeight.Normal)); inner() } },
                modifier = Modifier.fillMaxWidth())
        }
        trailing?.invoke()
    }
}

private fun Modifier.dashed(color: Color, r: Dp) = drawBehind {
    drawRoundRect(color, cornerRadius = CornerRadius(r.toPx()), style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(6.dp.toPx(), 4.dp.toPx()))))
}

/** `.chips`: horizontally scrolling single-select chips. */
@Composable
fun <T> Chips(options: List<T>, selected: T, label: (T) -> String, onPick: (T) -> Unit) {
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(top = 2.dp, bottom = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        options.forEach { o -> Chip(label(o), o == selected) { onPick(o) } }
    }
}

/** `.chip` / `.chip.on` */
@Composable
fun Chip(text: String, on: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(19.dp)
    Row(
        Modifier.height(38.dp).clip(shape).background(if (on) C.g else C.card).border(1.dp, if (on) C.g else C.line, shape)
            .clickable(role = Role.RadioButton, onClick = onClick).padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (on) I(Ic.check, 16.dp, C.on)
        Text(text, fontSize = 14.sp, fontWeight = FontWeight(if (on) 650 else 550), color = if (on) C.on else C.ink)
    }
}

/** `.fab` */
@Composable
fun Fab(text: String, icon: ImageVector, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Row(
        modifier.height(56.dp).clip(RoundedCornerShape(28.dp)).background(C.g).clickable(role = Role.Button, onClick = onClick).padding(start = 20.dp, end = 24.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) { I(icon, 24.dp, C.on); Text(text, color = C.on, fontWeight = FontWeight.Bold, fontSize = 16.sp) }
}

/** `.dock`: pinned bottom action area. */
@Composable
fun Dock(content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxWidth().background(C.paper)) {
        Box(Modifier.fillMaxWidth().height(1.dp).background(C.line))
        Column(Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.navigationBars).padding(start = 16.dp, end = 16.dp, top = 14.dp, bottom = 18.dp), verticalArrangement = Arrangement.spacedBy(8.dp), content = content)
    }
}

// ---------- cards ----------

/** `.cred` / `.cred.alt`: dark credential card. [onNum] makes the number tappable (reveal). */
@Composable
fun Cred(label: String, name: String, num: String?, alt: Boolean = false, onNum: (() -> Unit)? = null, extra: (@Composable ColumnScope.() -> Unit)? = null) {
    Column(
        Modifier.fillMaxWidth().heightIn(min = 196.dp).clip(RoundedCornerShape(28.dp)).background(if (alt) Deep.credAlt else Deep.cred).padding(22.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(label, Modifier.weight(1f), fontSize = 14.sp, fontWeight = FontWeight(550), color = Deep.soft)
            I(Ic.shield, 22.dp, Deep.soft)
        }
        Column(Modifier.padding(top = 24.dp)) {
            Text(name, fontFamily = Disp, fontWeight = FontWeight.Bold, fontSize = 30.sp, lineHeight = 34.sp, letterSpacing = (-0.025).em, color = Color.White)
            if (num != null) {
                Box(Modifier.padding(top = 14.dp).fillMaxWidth().height(1.dp).background(Color.White.copy(alpha = 0.2f)))
                Text(num, Modifier.padding(top = 14.dp).tap(onNum), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.08.em, color = Deep.num)
            }
            extra?.invoke(this)
        }
    }
}

/** `.hero`: scan call-to-action card. */
@Composable
fun Hero(title: String, text: String, cta: String, onCta: () -> Unit) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(30.dp)).background(Deep.cred).padding(22.dp)) {
        Box(Modifier.size(52.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.14f)), contentAlignment = Alignment.Center) { I(Ic.scan, 26.dp, Color.White) }
        Text(title, Modifier.padding(top = 30.dp), fontFamily = Disp, fontWeight = FontWeight.Bold, fontSize = 34.sp, lineHeight = 36.sp, letterSpacing = (-0.03).em, color = Color.White)
        Text(text, Modifier.padding(top = 8.dp, bottom = 20.dp).width(270.dp), fontSize = 15.sp, lineHeight = 21.sp, color = Deep.soft)
        Row(
            Modifier.fillMaxWidth().height(56.dp).clip(RoundedCornerShape(28.dp)).background(Color.White).clickable(role = Role.Button, onClick = onCta),
            horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically,
        ) { I(Ic.scan, 20.dp, Deep.cred); Text(cta, color = Deep.cred, fontSize = 16.sp, fontWeight = FontWeight(650)) }
    }
}

/** `.quick button`: round icon over a label. */
@Composable
fun RowScope.Quick(icon: ImageVector, label: String, onClick: () -> Unit) {
    Column(Modifier.weight(1f).clip(RoundedCornerShape(16.dp)).clickable(role = Role.Button, onClick = onClick).padding(vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(Modifier.size(60.dp).clip(CircleShape).background(C.card).border(1.dp, C.line, CircleShape), contentAlignment = Alignment.Center) { I(icon, 24.dp, C.ink) }
        Text(label, fontSize = 13.sp, fontWeight = FontWeight(550), color = C.ink, maxLines = 1)
    }
}

/** `.bc` bento cell (`.warn` inverts). */
@Composable
fun Bc(modifier: Modifier, warn: Boolean = false, onClick: (() -> Unit)? = null, content: @Composable ColumnScope.() -> Unit) {
    val shape = RoundedCornerShape(24.dp)
    CompositionLocalProvider(LocalContentColor provides if (warn) C.on else C.ink) {
        Column(modifier.heightIn(min = 100.dp).clip(shape).background(if (warn) C.g else C.card).border(1.dp, if (warn) C.g else C.line, shape).tap(onClick).padding(16.dp),
            verticalArrangement = Arrangement.SpaceBetween, content = content)
    }
}
@Composable fun BcNum(n: Int, label: String, big: Boolean = false, warn: Boolean = false) = Column {
    Text("$n", fontFamily = Disp, fontWeight = FontWeight.Bold, fontSize = if (big) 64.sp else 40.sp, lineHeight = if (big) 64.sp else 40.sp, letterSpacing = (-0.03).em, color = LocalContentColor.current)
    Text(label, fontSize = 13.sp, color = if (warn) C.on.copy(alpha = 0.8f) else C.ink2)
}

/** `.seg`: three-part proportion bar (largest categories). */
@Composable
fun Seg(parts: List<Int>) {
    val shown = parts.filter { it > 0 }.take(3).ifEmpty { listOf(1) }
    Row(Modifier.fillMaxWidth().height(12.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        shown.forEachIndexed { i, n -> Box(Modifier.weight(n.toFloat()).fillMaxHeight().clip(RoundedCornerShape(6.dp)).background(C.g.copy(alpha = listOf(1f, .5f, .22f)[i]))) }
    }
}

/** `.dc`: document grid card. */
@Composable
fun Dc(icon: ImageVector, title: String, sub: String, modifier: Modifier = Modifier, pill: @Composable () -> Unit, onClick: () -> Unit) {
    val shape = RoundedCornerShape(24.dp)
    Column(modifier.heightIn(min = 176.dp).clip(shape).background(C.card).border(1.dp, C.line, shape).clickable(role = Role.Button, onClick = onClick).padding(16.dp),
        verticalArrangement = Arrangement.SpaceBetween) {
        Dic(icon)
        Column(Modifier.padding(top = 16.dp)) {
            TiText(title, maxLines = 2)
            SuText(sub, Modifier.padding(top = 2.dp, bottom = 10.dp), maxLines = 1)
            pill()
        }
    }
}

/** `.field`: pill-shaped search input. */
@Composable
fun Field(value: String, onChange: (String) -> Unit, placeholder: String, modifier: Modifier = Modifier) {
    Row(Modifier.fillMaxWidth().padding(bottom = 6.dp).height(58.dp).clip(RoundedCornerShape(29.dp)).background(C.card).border(1.dp, C.line, RoundedCornerShape(29.dp)).padding(horizontal = 20.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        I(Ic.search, 22.dp, C.ink2)
        val style = TextStyle(fontFamily = Body, fontSize = 17.sp, color = C.ink)
        BasicTextField(value, onChange, modifier.weight(1f), singleLine = true, textStyle = style, cursorBrush = SolidColor(C.g),
            decorationBox = { inner -> Box { if (value.isEmpty()) Text(placeholder, style = style.copy(color = C.ink2)); inner() } })
    }
}

// ---------- lock ----------

/** `.mark`: app mark tile. */
@Composable
fun Mark() = Box(Modifier.padding(bottom = 18.dp).size(76.dp).clip(RoundedCornerShape(24.dp)).background(C.g), contentAlignment = Alignment.Center) { I(Ic.shield, 34.dp, C.on) }

/** `.lockv`: mark, title, dots and keypad. [left] is the bottom-left key (fingerprint) or null. */
@Composable
fun LockView(title: String, subtitle: String, error: String?, enabled: Boolean = true, left: (() -> Unit)? = null, onDone: (String) -> Unit, extra: @Composable () -> Unit = {}) {
    var pin by remember { mutableStateOf("") }
    // Box centres the column; the column scrolls only when the screen is too short for it.
    Box(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.navigationBars), contentAlignment = Alignment.Center) {
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, bottom = 36.dp),
        horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.height(24.dp))
        Mark()
        Text(title, style = H1, color = C.ink)
        SuText(subtitle, Modifier.padding(top = 6.dp))
        Row(Modifier.padding(top = 28.dp, bottom = 8.dp).semantics { contentDescription = "${pin.length} of 4 digits entered" }, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            repeat(4) { i ->
                val on = i < pin.length
                Box(Modifier.size(14.dp).clip(CircleShape).then(if (on) Modifier.background(C.g) else Modifier.border(2.dp, C.ink2, CircleShape)))
            }
        }
        Text(error.orEmpty(), Modifier.padding(bottom = 12.dp).height(20.dp), fontSize = 14.sp, color = C.ink, fontWeight = FontWeight.SemiBold)
        val keys = listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "bio", "0", "del")
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            keys.chunked(3).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                    row.forEach { k ->
                        val visible = k != "bio" || left != null
                        val m = Modifier.size(76.dp, 68.dp)
                        if (!visible) Spacer(m) else Box(
                            m.clip(CircleShape).background(C.card).border(1.dp, C.line, CircleShape)
                                .clickable(enabled = enabled, role = Role.Button) {
                                    when (k) {
                                        "bio" -> left?.invoke()
                                        "del" -> pin = pin.dropLast(1)
                                        else -> if (pin.length < 4) { pin += k; if (pin.length == 4) { val p = pin; pin = ""; onDone(p) } }
                                    }
                                }.semantics { contentDescription = when (k) { "bio" -> "Unlock with fingerprint"; "del" -> "Delete digit"; else -> k } },
                            contentAlignment = Alignment.Center,
                        ) {
                            val c = if (enabled) C.ink else C.ink2
                            when (k) {
                                "bio" -> I(Ic.finger, 28.dp, c)
                                "del" -> I(Ic.bksp, 26.dp, c)
                                else -> Text(k, fontFamily = Disp, fontWeight = FontWeight.SemiBold, fontSize = 28.sp, color = c)
                            }
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(10.dp))
        extra()
    }
    }
}

// ---------- scanning ----------

/** `.vf`: viewfinder with corner brackets and a sweeping scan line. */
@Composable
fun Viewfinder() {
    val t by rememberInfiniteTransition(label = "scan").animateFloat(0.2f, 0.78f, infiniteRepeatable(tween(1100, easing = LinearEasing), RepeatMode.Reverse), label = "y")
    Canvas(Modifier.fillMaxWidth().padding(bottom = 28.dp).height(230.dp).clip(RoundedCornerShape(28.dp)).background(Deep.cred)) {
        val s = 36.dp.toPx(); val m = 20.dp.toPx(); val w = 4.dp.toPx(); val r = 14.dp.toPx()
        val st = Stroke(w)
        // each corner = a quarter of a rounded square, drawn as an arc plus two short legs
        listOf(Offset(m, m) to 180f, Offset(size.width - m - s, m) to 270f, Offset(m, size.height - m - s) to 90f, Offset(size.width - m - s, size.height - m - s) to 0f).forEach { (o, a) ->
            val box = Size(2 * r, 2 * r)
            val tl = when (a) { 180f -> o; 270f -> Offset(o.x + s - 2 * r, o.y); 90f -> Offset(o.x, o.y + s - 2 * r); else -> Offset(o.x + s - 2 * r, o.y + s - 2 * r) }
            drawArc(Color.White, a, 90f, false, tl, box, style = st)
            val (h1, h2, v1, v2) = when (a) {
                180f -> listOf(Offset(o.x + r, o.y), Offset(o.x + s, o.y), Offset(o.x, o.y + r), Offset(o.x, o.y + s))
                270f -> listOf(Offset(o.x, o.y), Offset(o.x + s - r, o.y), Offset(o.x + s, o.y + r), Offset(o.x + s, o.y + s))
                90f -> listOf(Offset(o.x + r, o.y + s), Offset(o.x + s, o.y + s), Offset(o.x, o.y), Offset(o.x, o.y + s - r))
                else -> listOf(Offset(o.x, o.y + s), Offset(o.x + s - r, o.y + s), Offset(o.x + s, o.y), Offset(o.x + s, o.y + s - r))
            }
            drawLine(Color.White, h1, h2, w); drawLine(Color.White, v1, v2, w)
        }
        val y = size.height * t
        drawRoundRect(Color.White, Offset(size.width * 0.14f, y), Size(size.width * 0.72f, 3.dp.toPx()), CornerRadius(2.dp.toPx()))
    }
}

enum class StepState { Done, Now, Todo }

/** `.s` step with a connector line to the next one. */
@Composable
fun Step(n: Int, state: StepState, title: String, sub: String, last: Boolean) {
    val g = C.g; val line = C.line
    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            val (bg, fg) = when (state) { StepState.Done -> C.g to C.on; StepState.Now -> C.gs to C.g; StepState.Todo -> C.card2 to C.ink2 }
            Box(Modifier.size(36.dp).clip(CircleShape).background(bg), contentAlignment = Alignment.Center) {
                when (state) {
                    StepState.Done -> I(Ic.check, 18.dp, fg)
                    StepState.Now -> Spinner()
                    StepState.Todo -> Text("$n", fontSize = 14.sp, fontWeight = FontWeight(650), color = fg)
                }
            }
            if (!last) Box(Modifier.padding(vertical = 2.dp).width(2.dp).weight(1f).background(if (state == StepState.Done) g else line))
        }
        Column(Modifier.padding(bottom = 28.dp)) { TiText(title); SuText(sub) }
    }
}

/** `.spin` */
@Composable
fun Spinner(size: Dp = 18.dp, color: Color = C.g) {
    val a by rememberInfiniteTransition(label = "spin").animateFloat(0f, 360f, infiniteRepeatable(tween(800, easing = LinearEasing)), label = "a")
    val track = C.line
    Canvas(Modifier.size(size).rotate(a)) {
        val st = Stroke(2.5.dp.toPx())
        drawCircle(track, style = st)
        drawArc(color, -90f, 90f, false, style = st)
    }
}

/** `.prog`: thin progress bar. */
@Composable
fun Prog(fraction: Float) {
    Box(Modifier.fillMaxWidth().padding(start = 4.dp, end = 4.dp, bottom = 18.dp).height(6.dp).clip(RoundedCornerShape(3.dp)).background(C.card2)) {
        Box(Modifier.fillMaxWidth(fraction.coerceIn(0f, 1f)).fillMaxHeight().clip(RoundedCornerShape(3.dp)).background(C.g))
    }
}

/** `.sw` / `.sw.on`: the design's switch. */
@Composable
fun Sw(on: Boolean, label: String, onChange: (Boolean) -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Box(
        Modifier.size(52.dp, 32.dp).clip(shape).background(if (on) C.g else C.card2).border(2.dp, if (on) C.g else C.ink2, shape)
            .clickable(role = Role.Switch) { onChange(!on) }.semantics { contentDescription = label },
        contentAlignment = if (on) Alignment.CenterEnd else Alignment.CenterStart,
    ) {
        Box(Modifier.padding(horizontal = if (on) 2.dp else 4.dp).size(if (on) 24.dp else 18.dp).clip(CircleShape).background(if (on) C.on else C.ink2))
    }
}

/** `.tabs`: floating pill tab bar; the active tab grows and shows its label. */
@Composable
fun Tabs(items: List<Triple<String, ImageVector, Boolean>>, onPick: (Int) -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier.windowInsetsPadding(WindowInsets.navigationBars).padding(16.dp).fillMaxWidth().height(68.dp)
            .clip(RoundedCornerShape(34.dp)).background(C.card).border(1.dp, C.line, RoundedCornerShape(34.dp)).padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        items.forEachIndexed { i, (label, icon, on) ->
            Row(
                Modifier.weight(if (on) 2.1f else 1f).height(52.dp).clip(RoundedCornerShape(26.dp)).background(if (on) C.g else Color.Transparent)
                    .clickable(role = Role.Tab) { onPick(i) }.semantics { contentDescription = label },
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically,
            ) {
                I(icon, 22.dp, if (on) C.on else C.ink2)
                if (on) Text(label, color = C.on, fontWeight = FontWeight.Bold, fontSize = 14.sp, maxLines = 1)
            }
        }
    }
}

// ---------- shared helpers ----------

fun daysLeft(d: Document, today: LocalDate = LocalDate.now()) = d.expiry()?.let { ChronoUnit.DAYS.between(today, it) }

fun categoryIcon(c: Category) = when (c) {
    Category.IDENTITY -> Ic.id
    Category.EDUCATION -> Ic.cap
    Category.FINANCE -> Ic.bank
    else -> Ic.file
}

/** Single-select menu styled as a `.tf`: tap to pick from [options]. */
@Composable
fun <T> PickerTf(label: String, value: T, options: List<T>, text: (T) -> String, onPick: (T) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        Box(Modifier.clickable(role = Role.DropdownList) { open = true }) {
            Tf(label, text(value), trailing = { I(Ic.right, 20.dp, C.ink2, Modifier.rotate(90f)) })
        }
        DropdownMenu(open, { open = false }, containerColor = C.card) {
            options.forEach { o -> DropdownMenuItem(text = { Text(text(o), color = C.ink) }, onClick = { open = false; onPick(o) }) }
        }
    }
}

/** Plain `.su` paragraph with the design's side inset. */
@Composable fun Para(text: String, top: Dp = 0.dp) = SuText(text, Modifier.padding(start = 4.dp, end = 4.dp, top = top))
