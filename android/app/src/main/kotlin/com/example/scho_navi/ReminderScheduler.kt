package com.example.scho_navi

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import java.time.LocalDate
import java.time.ZonedDateTime

object ReminderScheduler {
    const val ACTION_NOTIFY = "com.example.scho_navi.action.SEND_PREPARATION_REMINDER"

    fun apply(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val pendingIntent = pendingIntent(context)
        alarmManager.cancel(pendingIntent)
        val schedule = ReminderStorage.loadSchedule(context)
        if (!schedule.enabled) return

        val now = ZonedDateTime.now()
        var next = now.toLocalDate().atTime(schedule.hour, schedule.minute).atZone(now.zone)
        if (!next.isAfter(now)) next = next.plusDays(1)
        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            next.toInstant().toEpochMilli(),
            pendingIntent,
        )
    }

    private fun pendingIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        4103,
        Intent(context, ReminderReceiver::class.java).apply { action = ACTION_NOTIFY },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}

class ReminderReceiver : BroadcastReceiver() {
    companion object {
        private const val CHANNEL_ID = "preparation_reminders"
        private const val NOTIFICATION_ID = 4104
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ReminderScheduler.ACTION_NOTIFY) return
        ReminderScheduler.apply(context)
        val schedule = ReminderStorage.loadSchedule(context)
        if (!schedule.enabled || !canNotify(context)) return
        val plan = mostUrgentPlan(ReminderStorage.loadSnapshot(context).plans) ?: return
        val notificationManager = context.getSystemService(NotificationManager::class.java)
        ensureChannel(notificationManager)
        val route = "/preparation-plans/${plan.planId}"
        val openIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.example.scho_navi.OPEN_REMINDER_${plan.planId}"
            putExtra(MainActivity.EXTRA_ROUTE, route)
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            4105,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val due = plan.nextTaskDueDate?.let(::parseDay)
        val overdue = due?.isBefore(LocalDate.now()) == true
        val body = if (overdue) {
            "任务已到期：${plan.nextTaskTitle}"
        } else {
            "下一项：${plan.nextTaskTitle}${due?.let { " · ${it.monthValue}月${it.dayOfMonth}日截止" } ?: ""}"
        }
        val notification = android.app.Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_reminder_notification)
            .setContentTitle("今晚推进「${plan.competitionName}」")
            .setContentText(body)
            .setStyle(android.app.Notification.BigTextStyle().bigText(body))
            .setContentIntent(openPendingIntent)
            .setAutoCancel(true)
            .setCategory(android.app.Notification.CATEGORY_REMINDER)
            .build()
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun mostUrgentPlan(plans: List<ReminderPlan>): ReminderPlan? = plans
        .filter { it.nextTaskTitle != null && it.nextTaskDueDate != null }
        .minWithOrNull(
            compareBy<ReminderPlan> { it.nextTaskDueDate }
                .thenBy { it.targetDate }
                .thenBy { it.planId },
        )

    private fun ensureChannel(manager: NotificationManager) {
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "备赛提醒",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "每天提醒最紧急的备赛任务"
            },
        )
    }

    private fun canNotify(context: Context): Boolean {
        if (!context.getSystemService(NotificationManager::class.java).areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun parseDay(value: String): LocalDate? = try {
        LocalDate.parse(value)
    } catch (_: Exception) {
        null
    }
}

class ReminderRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ReminderScheduler.apply(context)
        PreparationWidgetProvider.refreshAll(context)
    }
}
