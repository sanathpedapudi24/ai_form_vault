package com.aiformvault.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import com.aiformvault.R

/** Tokens from SCREEN_DESIGN.html (:root and [data-theme=dark]), same names. */
@Immutable
data class Palette(
    val paper: Color, val card: Color, val card2: Color, val line: Color,
    val ink: Color, val ink2: Color, val g: Color, val g2: Color, val on: Color, val gs: Color,
)

val LightPalette = Palette(
    paper = Color(0xFFEDF3EE), card = Color.White, card2 = Color(0xFFDDEADF), line = Color(0xFFCBDACF),
    ink = Color(0xFF0B1A14), ink2 = Color(0xFF4B6055), g = Color(0xFF0A3B2C), g2 = Color(0xFF1B7456),
    on = Color.White, gs = Color(0xFFD9EADF),
)
val DarkPalette = Palette(
    paper = Color(0xFF08130E), card = Color(0xFF101D17), card2 = Color(0xFF19291F), line = Color(0xFF233529),
    ink = Color(0xFFE8F2EC), ink2 = Color(0xFF8AA295), g = Color(0xFFBFE8D2), g2 = Color(0xFF7FCFA6),
    on = Color(0xFF08130E), gs = Color(0xFF19291F),
)

/** Fixed colours of the dark-green credential/hero cards (same in both themes). */
object Deep {
    val cred = Color(0xFF0B3D2E)
    val credAlt = Color(0xFF0E1F18)
    val soft = Color(0xFFB7D4C6)
    val num = Color(0xFFDCEBE3)
}

val LocalPalette = staticCompositionLocalOf { LightPalette }
val C: Palette @Composable get() = LocalPalette.current

@OptIn(ExperimentalTextApi::class)
private fun variable(res: Int, vararg weights: Int) = FontFamily(weights.map {
    Font(res, FontWeight(it), variationSettings = FontVariation.Settings(FontVariation.weight(it)))
})

/** --disp: Bricolage Grotesque. --body: Figtree. Bundled because the app has no network access. */
val Disp = variable(R.font.bricolage, 500, 600, 700, 800)
val Body = variable(R.font.figtree, 400, 500, 550, 600, 650, 700)

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    val p = if (isSystemInDarkTheme()) DarkPalette else LightPalette
    val dark = p == DarkPalette
    val scheme = (if (dark) darkColorScheme() else lightColorScheme()).copy(
        primary = p.g, onPrimary = p.on, primaryContainer = p.gs, onPrimaryContainer = p.g,
        secondary = p.g2, onSecondary = p.on, secondaryContainer = p.gs, onSecondaryContainer = p.g,
        background = p.paper, onBackground = p.ink, surface = p.card, onSurface = p.ink,
        surfaceVariant = p.card2, onSurfaceVariant = p.ink2, surfaceContainer = p.card,
        surfaceContainerLow = p.card, surfaceContainerHigh = p.card, surfaceContainerHighest = p.card2,
        outline = p.line, outlineVariant = p.line, error = p.ink, errorContainer = p.card2,
        inverseSurface = p.ink, inverseOnSurface = p.paper, inversePrimary = p.gs,
    )
    val t = Typography()
    fun TextStyle.b() = copy(fontFamily = Body)
    val type = Typography(
        displayLarge = t.displayLarge.copy(fontFamily = Disp), displayMedium = t.displayMedium.copy(fontFamily = Disp),
        displaySmall = t.displaySmall.copy(fontFamily = Disp), headlineLarge = t.headlineLarge.copy(fontFamily = Disp, fontWeight = FontWeight.Bold),
        headlineMedium = t.headlineMedium.copy(fontFamily = Disp, fontWeight = FontWeight.Bold), headlineSmall = t.headlineSmall.copy(fontFamily = Disp, fontWeight = FontWeight.Bold),
        titleLarge = t.titleLarge.copy(fontFamily = Disp, fontWeight = FontWeight.Bold), titleMedium = t.titleMedium.b(), titleSmall = t.titleSmall.b(),
        bodyLarge = t.bodyLarge.b(), bodyMedium = t.bodyMedium.b(), bodySmall = t.bodySmall.b(),
        labelLarge = t.labelLarge.b(), labelMedium = t.labelMedium.b(), labelSmall = t.labelSmall.b(),
    )
    CompositionLocalProvider(LocalPalette provides p) {
        MaterialTheme(colorScheme = scheme, typography = type, content = content)
    }
}
