package com.aiformvault.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// ---------- design tokens (mirror SCREEN_DESIGN.html exactly) ----------

object Design {
    /** 20px radius used by cards, pill/banner corners and checkboxes. */
    val radius = 20.dp
    /** 26px radius used by hero and digital-ID cards. */
    val radiusBig = 26.dp
    /** Hairline between list rows. */
    val line = Color(0xFFE4E6DE)
    /** Navy gradient stop colours used for the legacy icon plate. */
    val navyTop = Color(0xFF0D2A40)
    val navyBottom = Color(0xFF04182A)
    /** Gradient colours used throughout the UI. */
    val emeraldDeep = Color(0xFF004E3B)
    val emerald = Color(0xFF059669)
    val emeraldBright = Color(0xFF10B981)
    val teal = Color(0xFF14B8A6)
    val tealDeep = Color(0xFF0F766E)
    val mint = Color(0xFF6EE7B7)
    val mintSoft = Color(0xFFD0FAE5)
    val warn = Color(0xFFB45309)
    val warnSoft = Color(0xFFFEF3C7)
    val danger = Color(0xFFB91C1C)
    val dangerSoft = Color(0xFFFEECEC)
    val okBorder = Color(0xFFB9F0D8)
    /** Backgrounds from HTML. */
    val bg = Color(0xFFF8F9F6)
    val surface = Color(0xFFF0F2EC)
    /** Ink from HTML. */
    val ink = Color(0xFF1A1C18)
    val inkMuted = Color(0xFF5C6356)
    val surface2 = Color(0xFFE4E6DE)
    /** Status tonal states. */
    val warnBorder = Color(0xFFF3D9A4)
    val dangerBorder = Color(0xFFF3C6C6)
    val okBorder2 = Color(0xFFB9F0D8)
}

// ---------- tonal states used inside Design composables ----------

/** The three tonal states used by DesignPill. */
enum class PillTone { Ok, Warn, Danger, Neutral }

/** The three tonal states used by DesignBanner. */
enum class BannerTone { Warn, Danger, Ok, Info }

/** The four tonal states used by DesignButton. */
enum class ButtonTone { Primary, Ghost, Soft, Danger }

/** The three tonal states used by DesignCheck. */
enum class CheckTone { Checked, Unchecked }

// ---------- primitives (mirror SCREEN_DESIGN.html 1:1) ----------

// ---------- cards ----------

/** The design's flat (surface-coloured) card, used for secondary blocks. */
@Composable
fun DesignFlatCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Brand.Surface),
        shape = RoundedCornerShape(Design.radius),
        border = androidx.compose.foundation.BorderStroke(1.dp, Design.line),
    ) { Column(Modifier.padding(16.dp), content = content) }
}

// ---------- buttons ----------

/** Buttons: `primary` (emerald gradient), `ghost` (surface), `soft` (mint), `danger`. */
@Composable
fun DesignButton(
    text: String,
    modifier: Modifier = Modifier,
    tone: ButtonTone = ButtonTone.Primary,
    enabled: Boolean = true,
    leading: String? = null,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(14.dp)
    val bg: Color
    val fg: Color
    when (tone) {
        ButtonTone.Primary -> { bg = Brand.Emerald; fg = Color.White }
        ButtonTone.Ghost -> { bg = Brand.Surface; fg = Brand.Ink }
        ButtonTone.Soft -> { bg = Brand.MintSoft; fg = Brand.EmeraldDeep }
        ButtonTone.Danger -> { bg = Brand.DangerSoft; fg = Brand.Danger }
    }
    Row(
        modifier
            .fillMaxWidth()
            .clip(shape)
            .background(if (enabled) bg else Brand.Surface2)
            .clickable(enabled = enabled) { onClick() }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (leading != null) {
            Text(leading, fontSize = 15.sp, color = Brand.Ink)
            Spacer(Modifier.width(8.dp))
        }
        Text(text, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = if (enabled) fg else Brand.InkMuted)
    }
}

/** The design's status pill: `ok`, `warn`, `danger` or neutral. */
@Composable
fun DesignPill(text: String, tone: PillTone = PillTone.Neutral) {
    val (fg, bg) = when (tone) {
        PillTone.Ok -> Brand.EmeraldDeep to Brand.MintSoft
        PillTone.Warn -> Brand.Warn to Brand.WarnSoft
        PillTone.Danger -> Brand.Danger to Brand.DangerSoft
        else -> Brand.Ink to Brand.Surface
    }
    Text(text, fontSize = 10.5.sp, fontWeight = FontWeight.Bold, color = fg,
        modifier = Modifier.clip(RoundedCornerShape(50)).background(bg).padding(horizontal = 9.dp, vertical = 3.dp))
}

/** The design's small outlined chip. */
@Composable
fun DesignChip(text: String, fg: Color = Brand.EmeraldDeep, bg: Color = Brand.MintSoft) =
    Text(text, fontSize = 11.5.sp, fontWeight = FontWeight.SemiBold, color = fg,
        modifier = Modifier.clip(RoundedCornerShape(50)).background(bg).padding(horizontal = 10.dp, vertical = 5.dp))

// ---------- rows ----------

/** A labelled value row: muted key on the left, value on the right, hairline between rows. */
@Composable
fun FieldRow(key: String, value: String, trailing: (@Composable () -> Unit)? = null) {
    Row(Modifier.fillMaxWidth().padding(vertical = 11.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(key, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Brand.InkMuted, modifier = Modifier.width(118.dp))
        Text(value, fontSize = 13.5.sp, fontWeight = FontWeight.Medium, color = Brand.Ink, modifier = Modifier.weight(1f), maxLines = 2, overflow = TextOverflow.Ellipsis)
        if (trailing != null) trailing()
    }
}

@Composable
fun Hairline(modifier: Modifier = Modifier) =
    Box(modifier.fillMaxWidth().height(1.dp).background(Design.line))

// ---------- banners ----------

/** The design's banner: soft tint + border, optional action buttons underneath. */
@Composable
fun DesignBanner(
    title: String,
    subtitle: String? = null,
    tone: BannerTone = BannerTone.Warn,
    icon: String? = null,
    actions: (@Composable RowScope.() -> Unit)? = null,
) {
    val (bg, border) = when (tone) {
        BannerTone.Warn -> Brand.WarnSoft to Design.warnBorder
        BannerTone.Danger -> Brand.DangerSoft to Design.dangerBorder
        BannerTone.Ok -> Brand.MintSoft to Design.okBorder2
        else -> Brand.Surface to Design.line
    }
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(bg).border(1.dp, border, RoundedCornerShape(16.dp)).padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            if (icon != null) {
                Text(icon, fontSize = 15.sp)
                Spacer(Modifier.width(8.dp))
            }
            Column(Modifier.weight(1f)) {
                Text(title, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Brand.Ink)
                if (subtitle != null) Text(subtitle, fontSize = 12.sp, color = Brand.InkMuted)
            }
        }
        if (actions != null) {
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), content = actions)
        }
    }
}

/** The design's 3-up statistic tile. */
@Composable
fun StatTile(value: String, label: String, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Brand.Surface).padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(value, fontSize = 19.sp, fontWeight = FontWeight.Bold, color = Brand.Ink)
        Text(label, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.5.sp, color = Brand.InkMuted)
    }
}

// ---------- document row ----------

/** The design's document row: coloured glyph tile, title, subtitle and a status pill. */
@Composable
fun DesignDocRow(
    glyph: String,
    title: String,
    subtitle: String,
    modifier: Modifier = Modifier,
    pill: String? = null,
    pillTone: PillTone = PillTone.Ok,
    onClick: () -> Unit,
) {
    Row(
        modifier.fillMaxWidth().clickable { onClick() }.padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(42.dp).clip(RoundedCornerShape(14.dp)).background(Brand.MintSoft),
            contentAlignment = Alignment.Center,
        ) { Text(glyph, fontSize = 17.sp) }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Brand.Ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(subtitle, fontSize = 12.sp, color = Brand.InkMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        if (pill != null) {
            Spacer(Modifier.width(8.dp))
            DesignPill(pill, pillTone)
        }
    }
}

// ---------- avatar ----------

/** The design's round avatar with initials. */
@Composable
fun DesignAvatar(initials: String, modifier: Modifier = Modifier, size: Int = 40) {
    Box(
        modifier.size(size.dp).clip(RoundedCornerShape((size * 0.35f).dp))
            .background(Brush.linearGradient(listOf(Brand.EmeraldBright, Brand.TealDeep))),
        contentAlignment = Alignment.Center,
    ) { Text(initials, color = Color.White, fontSize = (size * 0.38f).sp, fontWeight = FontWeight.Bold) }
}

// ---------- segmented control ----------

/** The design's segmented control. */
@Composable
fun Segmented(items: List<String>, selected: Int, modifier: Modifier = Modifier, onSelect: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Brand.Surface).padding(4.dp)) {
        items.forEachIndexed { i, label ->
            val active = i == selected
            Box(
                Modifier.weight(1f).clip(RoundedCornerShape(11.dp))
                    .background(if (active) Color.White else Brand.Surface2)
                    .shadow(if (active) 2.dp else 0.dp, RoundedCornerShape(11.dp), clip = false)
                    .clickable { onSelect(i) }
                    .padding(vertical = if (active) 9.dp else 9.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(label, fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, color = if (active) Brand.Ink else Brand.InkMuted, maxLines = 1)
            }
        }
    }
}

// ---------- search field ----------

/** The design's search field. */
@Composable
fun DesignSearchField(value: String, onValueChange: (String) -> Unit, placeholder: String, modifier: Modifier = Modifier) {
    TextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = true,
        modifier = modifier.fillMaxWidth(),
        placeholder = { Text(placeholder, fontSize = 14.sp, color = Brand.InkMuted) },
        leadingIcon = { Text("🔍", fontSize = 15.sp) },
        shape = RoundedCornerShape(13.dp),
        colors = TextFieldDefaults.colors(
            focusedContainerColor = Color.White,
            unfocusedContainerColor = Color.White,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
            disabledIndicatorColor = Color.Transparent,
        ),
    )
}

// ---------- hero card ----------

/** The design's hero panel with the emerald-teal gradient and a white call to action. */
@Composable
fun HeroCard(
    eyebrow: String,
    title: String,
    subtitle: String,
    modifier: Modifier = Modifier,
    cta: String? = null,
    onCta: () -> Unit = {},
) {
    Column(
        modifier.fillMaxWidth().shadow(10.dp, RoundedCornerShape(Design.radiusBig), clip = false)
            .clip(RoundedCornerShape(Design.radiusBig))
            .background(Brush.linearGradient(listOf(Design.emeraldDeep, Design.emerald, Design.teal)))
            .padding(22.dp),
    ) {
        Text(eyebrow, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp,
            color = Color.White.copy(alpha = 0.9f), modifier = Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.18f)).padding(horizontal = 10.dp, vertical = 5.dp))
        Spacer(Modifier.height(10.dp))
        Text(title, fontSize = 20.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
        Spacer(Modifier.height(4.dp))
        Text(subtitle, fontSize = 12.5.sp, color = Color.White.copy(alpha = 0.82f))
        if (cta != null) {
        Spacer(Modifier.height(16.dp))
        Row(
            Modifier.fillMaxWidth().shadow(8.dp, RoundedCornerShape(16.dp), clip = false)
                .clip(RoundedCornerShape(16.dp)).background(Color.White).clickable { onCta() }.padding(14.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("＋", fontSize = 15.sp, color = Brand.EmeraldDeep)
            Spacer(Modifier.width(10.dp))
            Text(cta, fontSize = 14.5.sp, fontWeight = FontWeight.Bold, color = Brand.EmeraldDeep)
        }
        }
    }
}

// ---------- doc card ----------

/** The design's document card (digital ID): gradient panel with the person's details. */
@Composable
fun DesignDocCard(
    eyebrow: String,
    name: String,
    subtitle: String,
    modifier: Modifier = Modifier,
    alt: Boolean = false,
    extra: (@Composable () -> Unit)? = null,
) {
    Column(
        modifier.fillMaxWidth().shadow(10.dp, RoundedCornerShape(22.dp), clip = false)
            .clip(RoundedCornerShape(22.dp))
            .background(Brush.linearGradient(if (alt) listOf(Brand.TealDeep, Brand.Emerald, Brand.Mint) else listOf(Design.emeraldDeep, Design.emerald, Design.teal)))
            .padding(20.dp),
    ) {
        Text(eyebrow, fontSize = 12.sp, letterSpacing = 1.2.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.8f))
        Spacer(Modifier.height(6.dp))
        Text(name, fontSize = 21.sp, fontWeight = FontWeight.SemiBold, color = Color.White, maxLines = 2, overflow = TextOverflow.Ellipsis)
        Text(subtitle, fontSize = 12.sp, color = Color.White.copy(alpha = 0.85f), maxLines = 2, overflow = TextOverflow.Ellipsis)
        if (extra != null) {
            Spacer(Modifier.height(14.dp))
            extra()
        }
    }
}

// ---------- checkbox ----------

/** The design's checkbox, used by the review screen's "expected vs found" list. */
@Composable
fun DesignCheck(checked: Boolean, modifier: Modifier = Modifier) {
    val radius = 11.dp // half of 22px design size
    Box(
        modifier.size(22.dp).clip(RoundedCornerShape(radius))
            .background(if (checked) Brand.Emerald else Brand.Surface2),
        contentAlignment = Alignment.Center,
    ) { if (checked) Text("✓", fontSize = 13.sp, color = Color.White, fontWeight = FontWeight.Bold) }
}

// ---------- bottom tab bar ----------

// ---------- material icon button ----------

// ---------- text button ----------

/** The design's "text button" pair inside a banner or an action row. */
@Composable
fun DesignTextButton(text: String, modifier: Modifier = Modifier, tone: ButtonTone = ButtonTone.Soft, onClick: () -> Unit) {
    val (bg, fg) = when (tone) {
        ButtonTone.Primary -> Brand.Emerald to Color.White
        ButtonTone.Ghost -> Brand.Surface to Brand.Ink
        ButtonTone.Soft -> Brand.MintSoft to Brand.EmeraldDeep
        ButtonTone.Danger -> Brand.DangerSoft to Brand.Danger
    }
    Text(text, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = fg,
        modifier = modifier.clip(RoundedCornerShape(12.dp)).background(bg).clickable { onClick() }.padding(horizontal = 14.dp, vertical = 9.dp))
}

// ---------- divider ----------
