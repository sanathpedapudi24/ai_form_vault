package com.aiformvault

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Rect
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import androidx.core.content.FileProvider
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.io.File
import java.util.UUID

/** On-device OCR and image helpers. Blocking: call off the main thread. */
object Ocr {
    private val recognizer by lazy { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) }

    private fun recognize(bmp: Bitmap): Text = Tasks.await(recognizer.process(InputImage.fromBitmap(bmp, 0)))

    fun text(ctx: Context, pages: List<Uri>): String =
        pages.joinToString("\n") { uri -> Store.decodeScaled(ctx, uri, 2400)?.let(::bestText).orEmpty() }

    /** Reads the page as-is and with boosted contrast (faint grey print, e.g. passbooks), keeping whichever found more. */
    private fun bestText(bmp: Bitmap): String {
        val plain = recognize(bmp).text
        val boosted = recognize(highContrast(bmp)).text
        return if (boosted.count(Char::isLetterOrDigit) > plain.count(Char::isLetterOrDigit) * 1.1) boosted else plain
    }

    /** Greyscale, then contrast x2 pivoted at 150: grey ink (~120) turns dark, paper (~220) turns white. */
    private fun highContrast(src: Bitmap): Bitmap {
        val out = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        val c = 2f; val t = 128 - c * 150
        val m = ColorMatrix().apply { setSaturation(0f) }
        m.postConcat(ColorMatrix(floatArrayOf(c, 0f, 0f, 0f, t, 0f, c, 0f, 0f, t, 0f, 0f, c, 0f, t, 0f, 0f, 0f, 1f, 0f)))
        Canvas(out).drawBitmap(src, 0f, 0f, Paint().apply { colorFilter = ColorMatrixColorFilter(m) })
        return out
    }

    /** Renders the first [max] PDF pages to cache JPEGs so they flow through the same scan pipeline. */
    fun pdfPages(ctx: Context, pdf: Uri, max: Int = 5): List<Uri> {
        val fd = ctx.contentResolver.openFileDescriptor(pdf, "r") ?: return emptyList()
        return PdfRenderer(fd).use { r ->
            (0 until minOf(max, r.pageCount)).map { i ->
                r.openPage(i).use { page ->
                    val scale = 2000f / maxOf(page.width, page.height)
                    val bmp = Bitmap.createBitmap((page.width * scale).toInt(), (page.height * scale).toInt(), Bitmap.Config.ARGB_8888)
                    bmp.eraseColor(Color.WHITE)
                    page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    Uri.fromFile(cacheFile(ctx, "jpg").also { f -> f.outputStream().use { bmp.compress(Bitmap.CompressFormat.JPEG, 90, it) } })
                }
            }
        }
    }

    // ---------- Snap-to-Fill ----------

    /**
     * A label on a blank form, where its answer goes, and what we'd write.
     * Tick-box questions ("Gender: [] Male [] Female") have [options]: each choice word and where it is; [value] is the chosen one.
     */
    data class FormField(val label: String, val key: FactKey?, val box: Rect, val value: String, val options: Map<String, Rect> = emptyMap())

    private val choiceGroups = mapOf(
        FactKey.GENDER to listOf("male", "female", "transgender", "other"),
        FactKey.NATIONALITY to listOf("indian", "nri", "foreigner", "others"),
    )

    /** Choice words on one line ("Male / Female / Other"), with each word's own box cut out of its OCR element. */
    private fun choices(line: Text.Line): Pair<FactKey, Map<String, Rect>>? {
        for ((key, words) in choiceGroups) {
            val found = linkedMapOf<String, Rect>()
            for (el in line.elements) {
                val b = el.boundingBox ?: continue
                val t = el.text.lowercase()
                for (w in words) Regex("""(?<![a-z])$w(?![a-z])""").find(t)?.let { m ->
                    // "Male/Female" is often one element: slice its box by character position.
                    val per = b.width().toFloat() / t.length
                    found[titleCase(w)] = Rect((b.left + m.range.first * per).toInt(), b.top, (b.left + (m.range.last + 1) * per).toInt(), b.bottom)
                }
            }
            if (found.size >= 2) return key to found
        }
        return null // ponytail: options stacked on separate lines aren't grouped; add if real forms need it
    }

    /** Finds lines on the form that read like field labels or tick-box questions and pre-fills them from the user's best facts. */
    fun detectFields(ctx: Context, form: Uri, facts: Map<FactKey, String>): Pair<Bitmap, List<FormField>> {
        val bmp = Store.decodeScaled(ctx, form, 2400) ?: error("Couldn't open the form image")
        val all = recognize(bmp).textBlocks.flatMap { it.lines }.mapNotNull { line ->
            val label = line.text.trim()
            val box = line.boundingBox ?: return@mapNotNull null
            choices(line)?.let { (key, opts) ->
                val want = facts[key]?.lowercase()
                return@mapNotNull FormField(key.label, key, box, opts.keys.firstOrNull { it.lowercase() == want }.orEmpty(), opts)
            }
            val key = matchLabel(label.substringBefore(':'))
            // Unknown lines only count as fields when they look like "Label: ____" blanks.
            if (key == null && !Regex("""[:_.]{1,}\s*$|_{3,}""").containsMatchIn(label)) return@mapNotNull null
            FormField(label.trimEnd(':', '_', '.', ' '), key, box, key?.let { facts[it] }.orEmpty())
        }
        // "Gender" on its own line plus a "Male / Female" line: tick the box, don't also write the word.
        val ticked = all.filter { it.options.isNotEmpty() }.mapNotNull { it.key }.toSet()
        return bmp to all.filter { it.options.isNotEmpty() || it.key !in ticked }
    }

    /** Writes each value just right of its label (or under it when there's no room), in dark ink. */
    fun render(form: Bitmap, fields: List<FormField>): Bitmap {
        val out = form.copy(Bitmap.Config.ARGB_8888, true)
        val c = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(16, 42, 140) }
        val pen = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = paint.color; style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }
        for (f in fields.filter { it.options.isNotEmpty() }) {
            val r = f.options[f.value] ?: continue
            val h = r.height().toFloat()
            // ponytail: assumes the box sits just left of the word (most Indian forms); the circle keeps it readable when it doesn't.
            pen.strokeWidth = h * 0.14f
            c.drawPath(Path().apply {
                moveTo(r.left - h * 1.0f, r.exactCenterY()); lineTo(r.left - h * 0.65f, r.bottom - h * 0.1f); lineTo(r.left - h * 0.1f, r.top - h * 0.2f)
            }, pen)
            pen.strokeWidth = h * 0.08f
            c.drawOval(RectF(r.left - h * 0.3f, r.top - h * 0.3f, r.right + h * 0.3f, r.bottom + h * 0.3f), pen)
        }
        for (f in fields.filter { it.value.isNotBlank() && it.options.isEmpty() }) {
            paint.textSize = f.box.height() * 0.85f
            val w = paint.measureText(f.value)
            val roomRight = out.width - f.box.right - 24
            val (x, y) = if (w <= roomRight) (f.box.right + 16f) to (f.box.bottom - f.box.height() * 0.15f)
            else f.box.left.toFloat() to (f.box.bottom + f.box.height() * 1.05f)
            c.drawText(f.value, x, y, paint)
        }
        return out
    }

    fun cacheFile(ctx: Context, ext: String) = File(ctx.cacheDir, "share").apply { mkdirs() }.let { File(it, "${UUID.randomUUID()}.$ext") }

    /** A content:// URI another app can read, for the system share sheet. Lives in cache, cleared on app start. */
    fun shareUri(ctx: Context, f: File): Uri = FileProvider.getUriForFile(ctx, "${ctx.packageName}.files", f)
}
