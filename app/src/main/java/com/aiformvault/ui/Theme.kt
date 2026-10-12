package com.aiformvault.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight

// Light-only palette, taken from vardio.in's light theme tokens.
object Brand {
    val Emerald = Color(0xFF059669)
    val EmeraldBright = Color(0xFF10B981)
    val EmeraldDeep = Color(0xFF004E3B)
    val Teal = Color(0xFF14B8A6)
    val TealDeep = Color(0xFF0F766E)
    val Mint = Color(0xFF6EE7B7)
    val MintSoft = Color(0xFFD0FAE5)
    val Background = Color(0xFFF8F9F6)
    val Surface = Color(0xFFF0F2EC)
    val Surface2 = Color(0xFFE4E6DE)
    val Ink = Color(0xFF1A1C18)
    val InkMuted = Color(0xFF5C6356)
    val Danger = Color(0xFFB91C1C)
    val DangerSoft = Color(0xFFFEECEC)
    val Warn = Color(0xFFB45309)
    val WarnSoft = Color(0xFFFEF3C7)
}

private val colors = lightColorScheme(
    primary = Brand.Emerald,
    onPrimary = Color.White,
    primaryContainer = Brand.MintSoft,
    onPrimaryContainer = Brand.EmeraldDeep,
    secondary = Brand.Teal,
    onSecondary = Color.White,
    secondaryContainer = Brand.MintSoft,
    onSecondaryContainer = Brand.EmeraldDeep,
    background = Brand.Background,
    onBackground = Brand.Ink,
    surface = Color.White,
    onSurface = Brand.Ink,
    surfaceVariant = Brand.Surface,
    onSurfaceVariant = Brand.InkMuted,
    surfaceContainer = Brand.Surface,
    surfaceContainerLow = Color.White,
    surfaceContainerHigh = Brand.Surface2,
    surfaceContainerHighest = Brand.Surface2,
    outline = Color(0x33000000),
    outlineVariant = Color(0x14000000),
    error = Brand.Danger,
    errorContainer = Brand.DangerSoft,
)

private val base = Typography()
private val type = base.copy(
    headlineLarge = base.headlineLarge.copy(fontWeight = FontWeight.SemiBold),
    headlineMedium = base.headlineMedium.copy(fontWeight = FontWeight.SemiBold),
    headlineSmall = base.headlineSmall.copy(fontWeight = FontWeight.SemiBold),
    titleLarge = base.titleLarge.copy(fontWeight = FontWeight.SemiBold),
    titleMedium = base.titleMedium.copy(fontWeight = FontWeight.SemiBold),
)

@Composable
fun AppTheme(content: @Composable () -> Unit) = MaterialTheme(colorScheme = colors, typography = type, content = content)
