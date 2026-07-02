package com.example.scho_navi

import android.content.Context

object NotificationActionCoordinator {
    fun complete(
        context: Context,
        planId: String,
        taskId: String,
        onSuccess: () -> Unit,
        onFailure: () -> Unit,
    ) {
        // Task 11 will implement: try UI engine action channel, else headless engine, single-flight, 8s timeout.
        // For now, call onFailure so the notification is preserved (safe default).
        onFailure()
    }

    fun registerUiChannel(engine: io.flutter.embedding.engine.FlutterEngine) {
        // Task 11 will register the MethodChannel.
    }

    fun unregisterUiChannel() {
        // Task 11 will unregister.
    }
}
