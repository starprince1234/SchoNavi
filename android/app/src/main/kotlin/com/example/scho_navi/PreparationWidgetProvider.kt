package com.example.scho_navi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import java.time.LocalDate
import java.time.temporal.ChronoUnit

class PreparationWidgetProvider : AppWidgetProvider() {
    companion object {
        const val ACTION_REFRESH = "com.example.scho_navi.action.REFRESH_PREPARATION_WIDGET"
        const val ACTION_ROTATE = "com.example.scho_navi.action.ROTATE_PREPARATION_WIDGET"

        fun refreshAll(context: Context) {
            context.sendBroadcast(
                Intent(context, PreparationWidgetProvider::class.java).apply {
                    action = ACTION_REFRESH
                },
            )
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_REFRESH -> {
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(ComponentName(context, PreparationWidgetProvider::class.java))
                ids.forEach { render(context, manager, it, rotate = false) }
            }
            ACTION_ROTATE -> {
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(ComponentName(context, PreparationWidgetProvider::class.java))
                ids.forEach { render(context, manager, it, rotate = true) }
            }
            else -> super.onReceive(context, intent)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { render(context, appWidgetManager, it, rotate = true) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        render(context, appWidgetManager, appWidgetId, rotate = false)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        appWidgetIds.forEach { ReminderStorage.deleteWidgetIndex(context, it) }
    }

    private fun layoutFor(options: Bundle): Int {
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        return when {
            minWidth < 180 || minHeight < 110 -> R.layout.preparation_widget_micro
            minWidth < 250 -> R.layout.preparation_widget_small
            minHeight < 180 -> R.layout.preparation_widget_wide
            else -> R.layout.preparation_widget_hero
        }
    }

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        rotate: Boolean,
    ) {
        val snapshot = ReminderStorage.loadSnapshot(context)
        val options = manager.getAppWidgetOptions(appWidgetId)
        val views = RemoteViews(context.packageName, layoutFor(options))
        if (snapshot.plans.isEmpty()) {
            renderEmpty(context, views, appWidgetId)
            manager.updateAppWidget(appWidgetId, views)
            return
        }

        val previous = ReminderStorage.widgetIndex(context, appWidgetId)
        val index = when {
            previous !in snapshot.plans.indices -> 0
            rotate && snapshot.plans.size > 1 -> (previous + 1) % snapshot.plans.size
            else -> previous
        }
        ReminderStorage.saveWidgetIndex(context, appWidgetId, index)
        val plan = snapshot.plans[index]
        val today = LocalDate.now()
        val target = parseDay(plan.targetDate) ?: today
        val days = ChronoUnit.DAYS.between(today, target).toInt()
        val progress = if (plan.totalTasks == 0) 0 else plan.completedTasks * 100 / plan.totalTasks
        val lastActivity = snapshot.lastActivityDay?.let(::parseDay)
        val preparedToday = lastActivity == today
        val activeStreak = lastActivity != null &&
            ChronoUnit.DAYS.between(lastActivity, today) <= 1
        val streak = if (activeStreak) snapshot.currentStreak else 0

        views.setViewVisibility(R.id.widget_empty_group, View.GONE)
        views.setViewVisibility(R.id.widget_content_group, View.VISIBLE)
        views.setTextViewText(R.id.widget_competition, plan.competitionName)
        views.setTextViewText(
            R.id.widget_position,
            if (snapshot.plans.size > 1) "${index + 1}/${snapshot.plans.size}" else "备赛中",
        )
        views.setTextViewText(
            R.id.widget_countdown,
            when {
                days > 0 -> "D-$days"
                days == 0 -> "今天比赛"
                else -> "已过 ${-days} 天"
            },
        )
        views.setTextViewText(R.id.widget_phase, "当前阶段 · ${plan.currentPhase}")
        views.setTextViewText(
            R.id.widget_streak,
            when {
                preparedToday && streak > 0 -> "连续 $streak 天 · 今天已推进"
                streak > 0 -> "连续 $streak 天 · 完成 1 项续上"
                else -> "从今天开始推进一小步"
            },
        )
        views.setTextViewText(
            R.id.widget_next_task,
            plan.nextTaskTitle?.let { "下一项 · $it" } ?: "当前任务已全部完成",
        )
        views.setTextViewText(
            R.id.widget_due,
            plan.nextTaskDueDate?.let { dueLabel(it, today) } ?: "去计划中查看下一阶段",
        )
        views.setProgressBar(R.id.widget_progress, 100, progress, false)
        views.setTextViewText(
            R.id.widget_progress_text,
            "${plan.completedTasks}/${plan.totalTasks} · $progress%",
        )
        val openPlan = routePendingIntent(context, appWidgetId, "/preparation-plans/${plan.planId}")
        views.setOnClickPendingIntent(R.id.widget_root, openPlan)
        views.setContentDescription(
            R.id.widget_root,
            "${plan.competitionName}，${viewsCountdown(days)}，下一项${plan.nextTaskTitle ?: "任务已完成"}",
        )
        bindPhaseRow(context, views, plan)
        manager.updateAppWidget(appWidgetId, views)
    }

    private fun bindPhaseRow(context: Context, views: RemoteViews, plan: ReminderPlan) {
        val phases = plan.phases
        val phaseViewIds = intArrayOf(
            R.id.widget_phase_0, R.id.widget_phase_1, R.id.widget_phase_2,
            R.id.widget_phase_3, R.id.widget_phase_4,
        )
        val labelViewIds = intArrayOf(
            R.id.widget_phase_label_0, R.id.widget_phase_label_1, R.id.widget_phase_label_2,
            R.id.widget_phase_label_3, R.id.widget_phase_label_4,
        )
        for (i in phaseViewIds.indices) {
            if (i < phases.size) {
                val phase = phases[i]
                views.setViewVisibility(phaseViewIds[i], View.VISIBLE)
                views.setViewVisibility(labelViewIds[i], View.VISIBLE)
                val drawable = when (phase.status) {
                    "completed" -> R.drawable.preparation_widget_phase_done
                    "active" -> R.drawable.preparation_widget_phase_active
                    else -> R.drawable.preparation_widget_phase_upcoming
                }
                views.setInt(phaseViewIds[i], "setBackgroundResource", drawable)
                views.setTextViewText(labelViewIds[i], phase.title)
                views.setTextColor(
                    labelViewIds[i],
                    if (phase.status == "active") {
                        context.getColor(R.color.widget_primary)
                    } else {
                        context.getColor(R.color.widget_text_secondary)
                    },
                )
            } else {
                views.setViewVisibility(phaseViewIds[i], View.INVISIBLE)
                views.setViewVisibility(labelViewIds[i], View.INVISIBLE)
            }
        }
    }

    private fun renderEmpty(context: Context, views: RemoteViews, appWidgetId: Int) {
        views.setViewVisibility(R.id.widget_content_group, View.GONE)
        views.setViewVisibility(R.id.widget_empty_group, View.VISIBLE)
        views.setTextViewText(R.id.widget_empty_title, "还没有进行中的备赛计划")
        views.setTextViewText(R.id.widget_empty_action, "打开 SchoNavi 创建计划")
        views.setOnClickPendingIntent(
            R.id.widget_root,
            routePendingIntent(context, appWidgetId, "/preparation-plans"),
        )
        views.setContentDescription(R.id.widget_root, "还没有进行中的备赛计划，点击打开 SchoNavi")
    }

    private fun routePendingIntent(
        context: Context,
        appWidgetId: Int,
        route: String,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = "com.example.scho_navi.OPEN_${appWidgetId}_${route.hashCode()}"
            putExtra(MainActivity.EXTRA_ROUTE, route)
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context,
            appWidgetId * 31 + route.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun dueLabel(raw: String, today: LocalDate): String {
        val due = parseDay(raw) ?: return "查看截止日期"
        val delta = ChronoUnit.DAYS.between(today, due).toInt()
        return when {
            delta < 0 -> "已逾期 ${-delta} 天"
            delta == 0 -> "今天截止"
            delta == 1 -> "明天截止"
            else -> "${due.monthValue}月${due.dayOfMonth}日截止"
        }
    }

    private fun viewsCountdown(days: Int): String = when {
        days > 0 -> "距离目标还有$days 天"
        days == 0 -> "今天比赛"
        else -> "目标日期已过${-days}天"
    }

    private fun parseDay(value: String): LocalDate? = try {
        LocalDate.parse(value)
    } catch (_: Exception) {
        null
    }
}
