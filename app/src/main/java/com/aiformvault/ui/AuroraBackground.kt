package com.aiformvault.ui

import android.provider.Settings
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

private class Blob(val color: Color, val x: Float, val y: Float, val radius: Float, val phase: Float)

private val blobs = listOf(
    Blob(Brand.EmeraldBright.copy(alpha = 0.45f), 0.15f, 0.05f, 0.75f, 0f),
    Blob(Brand.Teal.copy(alpha = 0.40f), 0.90f, 0.15f, 0.70f, 2.1f),
    Blob(Brand.Mint.copy(alpha = 0.50f), 0.50f, 0.35f, 0.65f, 4.2f),
)

/** Slow drifting aurora (24s loop, like vardio's hero). Static when system animations are off. */
@Composable
fun AuroraBackground(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    val resolver = LocalContext.current.contentResolver
    val animate = remember {
        Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) > 0f
    }
    val t = if (animate) {
        rememberInfiniteTransition(label = "aurora").animateFloat(
            initialValue = 0f,
            targetValue = (2 * PI).toFloat(),
            animationSpec = infiniteRepeatable(tween(24_000, easing = LinearEasing)),
            label = "t",
        ).value
    } else 0f

    Box(modifier.fillMaxSize()) {
        Canvas(Modifier.fillMaxSize()) {
            drawRect(Brand.Background)
            val span = maxOf(size.width, size.height)
            for (b in blobs) {
                val center = Offset(
                    size.width * (b.x + 0.08f * cos(t + b.phase)),
                    size.height * (b.y + 0.05f * sin(t + b.phase)),
                )
                drawCircle(
                    Brush.radialGradient(listOf(b.color, Color.Transparent), center, b.radius * span),
                    radius = b.radius * span,
                    center = center,
                )
            }
            // Wash toward the background lower down so content stays readable (WCAG AA).
            drawRect(Brush.verticalGradient(0.3f to Color.Transparent, 0.75f to Brand.Background))
        }
        content()
    }
}
