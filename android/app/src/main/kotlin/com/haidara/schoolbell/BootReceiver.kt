package com.haidara.schoolbell
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try { BellScheduler.scheduleAll(context) } catch (_: Exception) {}
    }
}
