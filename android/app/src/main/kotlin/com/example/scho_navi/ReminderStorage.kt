package com.example.scho_navi

import android.content.Context
import org.json.JSONObject

data class ReminderPlan(
    val planId: String,
    val competitionName: String,
    val targetDate: String,
    val currentPhase: String,
    val completedTasks: Int,
    val totalTasks: Int,
    val nextTaskTitle: String?,
    val nextTaskDueDate: String?,
)

data class ReminderSnapshot(
    val currentStreak: Int,
    val lastActivityDay: String?,
    val plans: List<ReminderPlan>,
)

data class ReminderSchedule(val enabled: Boolean, val hour: Int, val minute: Int)

object ReminderStorage {
    private const val PREFS = "scho_navi_preparation_reminders"
    private const val SNAPSHOT = "snapshot_json"
    private const val ENABLED = "notification_enabled"
    private const val HOUR = "notification_hour"
    private const val MINUTE = "notification_minute"

    fun saveSnapshot(context: Context, json: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(SNAPSHOT, json)
            .apply()
    }

    fun loadSnapshot(context: Context): ReminderSnapshot {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(SNAPSHOT, null) ?: return ReminderSnapshot(0, null, emptyList())
        return try {
            val root = JSONObject(raw)
            if (root.optInt("schemaVersion", 0) != 1) return ReminderSnapshot(0, null, emptyList())
            val plansJson = root.optJSONArray("plans")
            val plans = buildList {
                if (plansJson != null) {
                    for (index in 0 until plansJson.length()) {
                        val item = plansJson.optJSONObject(index) ?: continue
                        add(
                            ReminderPlan(
                                planId = item.optString("planId"),
                                competitionName = item.optString("competitionName"),
                                targetDate = item.optString("targetDate"),
                                currentPhase = item.optString("currentPhase"),
                                completedTasks = item.optInt("completedTasks"),
                                totalTasks = item.optInt("totalTasks"),
                                nextTaskTitle = item.optString("nextTaskTitle").ifBlank { null },
                                nextTaskDueDate = item.optString("nextTaskDueDate").ifBlank { null },
                            ),
                        )
                    }
                }
            }
            ReminderSnapshot(
                currentStreak = root.optInt("currentStreak"),
                lastActivityDay = root.optString("lastActivityDay").ifBlank { null },
                plans = plans,
            )
        } catch (_: Exception) {
            ReminderSnapshot(0, null, emptyList())
        }
    }

    fun saveSchedule(context: Context, enabled: Boolean, hour: Int, minute: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(ENABLED, enabled)
            .putInt(HOUR, hour.coerceIn(0, 23))
            .putInt(MINUTE, minute.coerceIn(0, 59))
            .apply()
    }

    fun loadSchedule(context: Context): ReminderSchedule {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return ReminderSchedule(
            enabled = prefs.getBoolean(ENABLED, false),
            hour = prefs.getInt(HOUR, 20),
            minute = prefs.getInt(MINUTE, 0),
        )
    }

    fun widgetIndex(context: Context, appWidgetId: Int): Int =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getInt("widget_index_$appWidgetId", -1)

    fun saveWidgetIndex(context: Context, appWidgetId: Int, index: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putInt("widget_index_$appWidgetId", index)
            .apply()
    }

    fun deleteWidgetIndex(context: Context, appWidgetId: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove("widget_index_$appWidgetId")
            .apply()
    }
}
