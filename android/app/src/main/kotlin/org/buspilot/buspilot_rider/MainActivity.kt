package org.buspilot.buspilot_rider

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.buspilot.rider/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // The channels the engine sends to (arrival_alerts,
                    // trip_changes), named in the app's language. Creating an
                    // existing channel again only updates its name, so the
                    // user's own channel settings stay.
                    "createChannels" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val names = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                            val manager = getSystemService(NotificationManager::class.java)
                            for ((id, name) in names) {
                                if (id !is String || name !is String) continue
                                manager.createNotificationChannel(
                                    NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH)
                                )
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
