package com.example.scho_navi

import android.Manifest
import android.app.NotificationManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Build
import android.provider.Settings
import android.view.animation.DecelerateInterpolator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val EXTRA_ROUTE = "route"
        private const val CHANNEL_NAME = "com.example.scho_navi/preparation_reminders"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4106
    }

    private var remindersChannel: MethodChannel? = null
    private var pendingInitialRoute: String? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingInitialRoute = intent?.getStringExtra(EXTRA_ROUTE)
        super.onCreate(savedInstanceState)
        WidgetRotationScheduler.apply(this)

        splashScreen.setOnExitAnimationListener { splashScreenView ->
            splashScreenView.animate()
                .alpha(0f)
                .setDuration(120L)
                .setInterpolator(DecelerateInterpolator())
                .withEndAction { splashScreenView.remove() }
                .start()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        remindersChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        remindersChannel?.setMethodCallHandler(::handleReminderCall)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        remindersChannel?.setMethodCallHandler(null)
        remindersChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val route = intent.getStringExtra(EXTRA_ROUTE) ?: return
        pendingInitialRoute = route
        remindersChannel?.invokeMethod("openRoute", route)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return
        pendingPermissionResult?.success(notificationStatus())
        pendingPermissionResult = null
    }

    private fun handleReminderCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "syncSnapshot" -> {
                    val json = call.arguments as? String ?: "{}"
                    ReminderStorage.saveSnapshot(this, json)
                    PreparationWidgetProvider.refreshAll(this)
                    WidgetRotationScheduler.apply(this)
                    result.success(null)
                }
                "updateSchedule" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
                    ReminderStorage.saveSchedule(
                        this,
                        enabled = args["enabled"] as? Boolean ?: false,
                        hour = (args["hour"] as? Number)?.toInt() ?: 20,
                        minute = (args["minute"] as? Number)?.toInt() ?: 0,
                    )
                    ReminderScheduler.apply(this)
                    result.success(null)
                }
                "getNotificationStatus" -> result.success(notificationStatus())
                "requestNotificationPermission" -> requestNotificationPermission(result)
                "pinWidget" -> result.success(pinWidget())
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(null)
                }
                "takeInitialRoute" -> result.success(takeInitialRoute())
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("preparation_reminders_error", error.message, null)
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(notificationStatus())
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success(notificationStatus())
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_request_in_progress", "Notification permission request is already in progress.", null)
            return
        }
        pendingPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    private fun notificationStatus(): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            return "denied"
        }
        if (!getSystemService(NotificationManager::class.java).areNotificationsEnabled()) {
            return "denied"
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) "granted" else "notRequired"
    }

    private fun pinWidget(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = getSystemService(AppWidgetManager::class.java)
        if (!manager.isRequestPinAppWidgetSupported) return false
        val provider = ComponentName(this, PreparationWidgetProvider::class.java)
        manager.requestPinAppWidget(provider, null, null)
        return true
    }

    private fun openNotificationSettings() {
        startActivity(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
        )
    }

    private fun takeInitialRoute(): String? {
        val route = pendingInitialRoute ?: intent?.getStringExtra(EXTRA_ROUTE)
        pendingInitialRoute = null
        intent?.removeExtra(EXTRA_ROUTE)
        return route
    }
}
