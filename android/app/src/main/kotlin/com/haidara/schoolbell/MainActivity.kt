package com.haidara.schoolbell

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.haidara.schoolbell/alarms")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        val json = org.json.JSONObject()
                        json.put("enabled", call.argument<Boolean>("enabled") ?: true)
                        json.put("duration", call.argument<Int>("duration") ?: 8)
                        val items = call.argument<List<Map<String, Any?>>>("bells") ?: emptyList()
                        json.put("bells", org.json.JSONArray(items))
                        getSharedPreferences("school_bell_native", MODE_PRIVATE).edit().putString("schedule", json.toString()).apply()
                        BellScheduler.scheduleAll(this)
                        result.success(true)
                    }
                    "requestExactAlarm" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM))
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
