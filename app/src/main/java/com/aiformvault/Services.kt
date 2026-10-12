package com.aiformvault

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.assist.AssistStructure.ViewNode
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.text.InputType
import android.view.View
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.concurrent.TimeUnit

/**
 * System-wide autofill (FR-AUTO). Offers only shareable facts (never Aadhaar, passport, voter ID, DL, vehicle numbers),
 * only for fields it can confidently match, and only as a suggestion the user taps (FR-AUTO-04/05).
 * Everything stays on the device: autofill is a local OS mechanism, not a network call.
 */
class VaultAutofillService : AutofillService() {
    override fun onFillRequest(request: FillRequest, signal: CancellationSignal, callback: FillCallback) {
        val structure = request.fillContexts.last().structure
        if (!Lock(this).autofill || structure.activityComponent.packageName == packageName) return callback.onSuccess(null)
        val facts = runCatching { bestFacts(Store.load(this)) }.getOrDefault(emptyMap()).filterKeys { it.shareable }
        if (facts.isEmpty()) return callback.onSuccess(null)

        val matches = linkedMapOf<AutofillId, AutofillValue>()
        fun walk(n: ViewNode) {
            val id = n.autofillId
            val password = n.inputType and InputType.TYPE_MASK_VARIATION == InputType.TYPE_TEXT_VARIATION_PASSWORD
            if (id != null && n.autofillType in setOf(View.AUTOFILL_TYPE_TEXT, View.AUTOFILL_TYPE_LIST) && !password) {
                val key = n.autofillHints?.firstNotNullOfOrNull(::matchHint)
                    ?: listOfNotNull(n.hint, n.idEntry, n.contentDescription?.toString()).firstNotNullOfOrNull(::matchLabel)
                    ?: n.htmlInfo?.attributes?.filter { it.first in setOf("name", "id", "label", "placeholder", "autocomplete") }
                        ?.firstNotNullOfOrNull { matchHint(it.second) }
                val v = key?.let { facts[it] }
                if (v != null) when (n.autofillType) {
                    View.AUTOFILL_TYPE_TEXT -> matches[id] = AutofillValue.forText(v)
                    // Dropdowns: pick the option that reads the same ("Male"), else one that's just its initial ("M").
                    else -> n.autofillOptions?.map { it.toString().trim().lowercase() }?.let { opts ->
                        val i = opts.indexOf(v.lowercase()).takeIf { it >= 0 } ?: opts.indexOf(v.take(1).lowercase())
                        if (i >= 0) matches[id] = AutofillValue.forList(i)
                    }
                }
            }
            for (i in 0 until n.childCount) walk(n.getChildAt(i))
        }
        for (i in 0 until structure.windowNodeCount) walk(structure.getWindowNodeAt(i).rootViewNode)
        if (matches.isEmpty()) return callback.onSuccess(null)

        val label = RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
            setTextViewText(android.R.id.text1, "Fill ${matches.size} field${if (matches.size > 1) "s" else ""} from AI Form & Vault")
        }
        @Suppress("DEPRECATION") // Presentations builder needs API 33; minSdk is 26.
        val ds = Dataset.Builder(label).apply { matches.forEach { (id, v) -> setValue(id, v) } }.build()
        callback.onSuccess(FillResponse.Builder().addDataset(ds).build())
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) = callback.onSuccess()
}

/** Daily check: one local notification as each document crosses 90, 30, 7 and 0 days before expiry. */
class ExpiryWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        val ctx = applicationContext
        if (!Lock(ctx).reminders) return Result.success()
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED &&
            android.os.Build.VERSION.SDK_INT >= 33) return Result.success()
        val sent = ctx.getSharedPreferences("reminded", Context.MODE_PRIVATE)
        val nm = ctx.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel("expiry", "Document expiry", NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(ctx, 0, Intent(ctx, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val today = LocalDate.now()
        for (d in Store.load(ctx).documents) {
            val left = d.expiry()?.let { ChronoUnit.DAYS.between(today, it) } ?: continue
            val threshold = listOf(0L, 7L, 30L, 90L).firstOrNull { left <= it } ?: continue
            val tag = "${d.id}_$threshold"
            if (sent.getBoolean(tag, false)) continue
            val text = if (left < 0) "Expired ${-left} days ago" else if (left == 0L) "Expires today" else "Expires in $left days"
            nm.notify(tag.hashCode(), NotificationCompat.Builder(ctx, "expiry")
                .setSmallIcon(R.drawable.ic_stat).setContentTitle(d.title).setContentText("$text. Time to renew.")
                .setContentIntent(open).setAutoCancel(true).build())
            sent.edit().putBoolean(tag, true).apply()
        }
        return Result.success()
    }

    companion object {
        fun schedule(ctx: Context) = WorkManager.getInstance(ctx).enqueueUniquePeriodicWork(
            "expiry", ExistingPeriodicWorkPolicy.KEEP, PeriodicWorkRequestBuilder<ExpiryWorker>(1, TimeUnit.DAYS).build()
        )
    }
}
