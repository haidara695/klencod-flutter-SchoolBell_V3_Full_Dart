package com.haidara.schoolbell

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import java.util.Calendar

object BellScheduler {
    private const val MAX_ALARMS = 600
    private fun pending(context: Context, id: Int): PendingIntent {
        val intent = Intent(context, BellReceiver::class.java).putExtra("alarmId", id)
        return PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    fun scheduleAll(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (i in 0 until MAX_ALARMS) manager.cancel(pending(context, i))
        val raw = context.getSharedPreferences("school_bell_native", Context.MODE_PRIVATE).getString("schedule", null) ?: return
        val settings = try { JSONObject(raw) } catch (_: Exception) { return }
        if (!settings.optBoolean("enabled", true)) return
        val entries = settings.optJSONArray("bells") ?: return
        val now = System.currentTimeMillis()
        var id = 0
        for (dayOffset in 0..7) {
            val day = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, dayOffset) }
            val weekday = (day.get(Calendar.DAY_OF_WEEK) + 5) % 7 // Monday=0
            for (j in 0 until entries.length()) {
                val bell = entries.optJSONObject(j) ?: continue
                if (!bell.optBoolean("enabled", true)) continue
                val days = bell.optJSONArray("days") ?: continue
                if (!(0 until days.length()).any { days.optInt(it, -1) == weekday }) continue
                val time = (day.clone() as Calendar).apply {
                    set(Calendar.HOUR_OF_DAY, bell.optInt("hour", 8))
                    set(Calendar.MINUTE, bell.optInt("minute", 0))
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }.timeInMillis
                if (time <= now || id >= MAX_ALARMS) continue
                val intent = Intent(context, BellReceiver::class.java)
                    .putExtra("alarmId", id)
                    .putExtra("title", bell.optString("title", "موعد الجرس"))
                    .putExtra("subject", bell.optString("subject", ""))
                    .putExtra("soundPath", bell.optString("soundPath", ""))
                    .putExtra("duration", settings.optInt("duration", 8))
                val pending = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) {
                    manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pending)
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pending)
                } else {
                    manager.setExact(AlarmManager.RTC_WAKEUP, time, pending)
                }
                id++
            }
        }
    }
}
