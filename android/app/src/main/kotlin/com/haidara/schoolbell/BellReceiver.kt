package com.haidara.schoolbell

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.io.File

class BellReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        val wake = (context.getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "schoolbell:ring")
        try { wake.acquire(35000L) } catch (_: Exception) {}
        try {
            val title = intent.getStringExtra("title") ?: "الجرس المدرسي"
            val subject = intent.getStringExtra("subject") ?: ""
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(NotificationChannel("bell_v3", "الجرس المدرسي", NotificationManager.IMPORTANCE_HIGH))
            }
            val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val notification = NotificationCompat.Builder(context, "bell_v3")
                .setSmallIcon(R.drawable.ic_notification).setContentTitle("🔔 $title")
                .setContentText(subject).setContentIntent(open).setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH).build()
            try { manager.notify(intent.getIntExtra("alarmId", 0), notification) } catch (_: SecurityException) {}
            val player = MediaPlayer()
            try {
                val file = File(intent.getStringExtra("soundPath") ?: "")
                if (file.isFile) player.setDataSource(file.absolutePath)
                else player.setDataSource(context, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
                player.isLooping = true
                player.prepare()
                player.start()
                val duration = intent.getIntExtra("duration", 8).coerceIn(3, 30)
                Handler(Looper.getMainLooper()).postDelayed({
                    try { player.stop(); player.release() } catch (_: Exception) {}
                    try { if (wake.isHeld) wake.release() } catch (_: Exception) {}
                    pending.finish()
                }, duration * 1000L)
            } catch (_: Exception) {
                try { player.release() } catch (_: Exception) {}
                try { if (wake.isHeld) wake.release() } catch (_: Exception) {}
                pending.finish()
            }
        } catch (_: Exception) {
            try { if (wake.isHeld) wake.release() } catch (_: Exception) {}
            pending.finish()
        }
        // Refresh the rolling week of alarms after one fires.
        try { BellScheduler.scheduleAll(context) } catch (_: Exception) {}
    }
}
