package com.aiformvault.ui

import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** SCREEN_DESIGN.html icon set: 24px grid, 1.75 stroke, Lucide paths (rects/circles rewritten as paths). */
private fun rect(x: Float, y: Float, w: Float, h: Float, r: Float) =
    "M${x + r} $y h${w - 2 * r} a$r $r 0 0 1 $r $r v${h - 2 * r} a$r $r 0 0 1 -$r $r h-${w - 2 * r} a$r $r 0 0 1 -$r -$r v-${h - 2 * r} a$r $r 0 0 1 $r -$r z"
private fun circle(cx: Float, cy: Float, r: Float) = "M${cx - r} $cy a$r $r 0 1 0 ${2 * r} 0 a$r $r 0 1 0 -${2 * r} 0"

private fun icon(name: String, vararg d: String): ImageVector {
    val b = ImageVector.Builder(name, 24.dp, 24.dp, 24f, 24f)
    d.forEach {
        b.addPath(PathParser().parsePathString(it).toNodes(), fill = null, stroke = SolidColor(Color.Black),
            strokeLineWidth = 1.75f, strokeLineCap = StrokeCap.Round, strokeLineJoin = StrokeJoin.Round)
    }
    return b.build()
}

object Ic {
    val lock = icon("lock", rect(3f, 11f, 18f, 11f, 2f), "M7 11V7a5 5 0 0 1 10 0v4")
    val shield = icon("shield", "M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z", "m9 12 2 2 4-4")
    val finger = icon("finger", "M12 10a2 2 0 0 0-2 2c0 1.02-.1 2.51-.26 4", "M14 13.12c0 2.38 0 6.38-1 8.88", "M17.29 21.02c.12-.6.43-2.3.5-3.02", "M2 12a10 10 0 0 1 18-6", "M5 19.5C5.5 18 6 15 6 12a6 6 0 0 1 .34-2", "M8.65 22c.21-.66.45-1.32.57-2", "M9 6.8a6 6 0 0 1 9 5.2v2")
    val scan = icon("scan", "M3 7V5a2 2 0 0 1 2-2h2", "M17 3h2a2 2 0 0 1 2 2v2", "M21 17v2a2 2 0 0 1-2 2h-2", "M7 21H5a2 2 0 0 1-2-2v-2", "M7 12h10")
    val image = icon("image", rect(3f, 3f, 18f, 18f, 2f), circle(9f, 9f, 2f), "m21 15-3.09-3.09a2 2 0 0 0-2.82 0L6 21")
    val file = icon("file", "M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z", "M14 2v4a2 2 0 0 0 2 2h4", "M10 9H8", "M16 13H8", "M16 17H8")
    val id = icon("id", "M16 10h2", "M16 14h2", "M6.17 15a3 3 0 0 1 5.66 0", circle(9f, 11f, 2f), rect(2f, 5f, 20f, 14f, 2f))
    val redo = icon("redo", "M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8", "M21 3v5h-5", "M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16", "M8 16H3v5")
    val search = icon("search", circle(11f, 11f, 8f), "m21 21-4.3-4.3")
    val plus = icon("plus", "M5 12h14", "M12 5v14")
    val left = icon("left", "m15 18-6-6 6-6")
    val right = icon("right", "m9 18 6-6-6-6")
    val more = icon("more", circle(12f, 12f, 1f), circle(12f, 5f, 1f), circle(12f, 19f, 1f))
    val home = icon("home", "M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8", "M3 10a2 2 0 0 1 .71-1.53l7-6a2 2 0 0 1 2.58 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z")
    val vault = icon("vault", rect(3f, 3f, 18f, 18f, 2f), circle(12f, 12f, 3f), "M12 5v2", "M12 17v2", "M5 12h2", "M17 12h2")
    val user = icon("user", "M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2", circle(12f, 7f, 4f))
    val users = icon("users", "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2", circle(9f, 7f, 4f), "M22 21v-2a4 4 0 0 0-3-3.87", "M16 3.13a4 4 0 0 1 0 7.75")
    val check = icon("check", "M20 6 9 17l-5-5")
    val alert = icon("alert", "m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3", "M12 9v4", "M12 17h.01")
    val info = icon("info", circle(12f, 12f, 10f), "M12 16v-4", "M12 8h.01")
    val share = icon("share", "M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8", "m16 6-4-4-4 4", "M12 2v13")
    val print = icon("print", "M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2", "M6 9V3a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v6", rect(6f, 14f, 12f, 8f, 1f))
    val down = icon("down", "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4", "m7 10 5 5 5-5", "M12 15V3")
    val trash = icon("trash", "M3 6h18", "M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6", "M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2")
    val edit = icon("edit", "M21.17 6.81a1 1 0 0 0-3.99-3.99L3.84 16.17a2 2 0 0 0-.5.83l-1.32 4.35a.5.5 0 0 0 .62.62l4.35-1.32a2 2 0 0 0 .83-.5z", "m15 5 4 4")
    val cap = icon("cap", "M21.42 10.92a1 1 0 0 0-.02-1.84L12.83 5.18a2 2 0 0 0-1.66 0L2.6 9.08a1 1 0 0 0 0 1.83l8.57 3.91a2 2 0 0 0 1.66 0z", "M22 10v6", "M6 12.5V16a6 3 0 0 0 12 0v-3.5")
    val bank = icon("bank", "M3 22h18", "M6 18v-7", "M10 18v-7", "M14 18v-7", "M18 18v-7", "m12 2 8 5H4z")
    val form = icon("form", "M5 4h1a3 3 0 0 1 3 3 3 3 0 0 1 3-3h1", "M13 20h-1a3 3 0 0 1-3-3 3 3 0 0 1-3 3H5", "M5 16H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2h1", "M13 8h7a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2h-7", "M9 7v10")
    val bksp = icon("bksp", "M10 5a2 2 0 0 0-1.34.52l-6.33 5.74a1 1 0 0 0 0 1.48l6.33 5.74A2 2 0 0 0 10 19h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2z", "m12 9 6 6", "m18 9-6 6")
    val key = icon("key", "m21 2-9.6 9.6", circle(7.5f, 15.5f, 5.5f), "m15.5 7.5 3 3L22 7l-3-3")
    val list = icon("list", "M3 6h18", "M3 12h18", "M3 18h12")
    val bell = icon("bell", "M10.27 21a2 2 0 0 0 3.46 0", "M3.26 15.33A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.67C19.41 13.96 18 12.5 18 8A6 6 0 0 0 6 8c0 4.5-1.41 5.96-2.74 7.33")
}

/** Inline SVG equivalent: `I(name, size)` from the design, tinted with the current content colour. */
@Composable
fun I(v: ImageVector, size: Dp = 22.dp, tint: Color = LocalContentColor.current, modifier: Modifier = Modifier) =
    Icon(v, null, modifier.size(size), tint = tint)
