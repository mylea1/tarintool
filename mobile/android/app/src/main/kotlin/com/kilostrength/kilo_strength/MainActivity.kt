package com.kilostrength.kilo_strength

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Thin bridge between Flutter and the workout foreground service.
 *
 * The timer state lives in [WorkoutTimerService], so it remains visible when
 * the Flutter activity is backgrounded or the screen is locked.
 */
class MainActivity : FlutterActivity() {
    private var timerChannel: MethodChannel? = null
    private var skipReceiver: BroadcastReceiver? = null
    private var notificationPermissionRequested = false
    private var pendingWorkoutOpen = false
    private val timerPreferences by lazy { getSharedPreferences("workout_timer", Context.MODE_PRIVATE) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerRestSkippedReceiver()
        pendingWorkoutOpen = intent?.getBooleanExtra(EXTRA_OPEN_WORKOUT, false) == true

        timerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumePendingWorkoutOpen" -> {
                        val pending = pendingWorkoutOpen
                        pendingWorkoutOpen = false
                        result.success(pending)
                    }
                    "consumePendingTimerActions" -> {
                        val completed = timerPreferences.getBoolean(WorkoutTimerService.KEY_PENDING_SET_COMPLETION, false)
                        timerPreferences.edit().putBoolean(WorkoutTimerService.KEY_PENDING_SET_COMPLETION, false).apply()
                        result.success(mapOf(
                            "completedSets" to if (completed) timerPreferences.getInt("completedSets", 0) else null,
                            "paused" to timerPreferences.getBoolean("workoutPaused", false),
                        ))
                    }

                    "startWorkout" -> {
                        val elapsedSeconds = call.argument<Number>("elapsedSeconds")
                            ?.toLong()
                            ?.coerceAtLeast(0L)
                            ?: 0L
                        enqueueServiceCommand(
                            Intent(this, WorkoutTimerService::class.java)
                                .setAction(WorkoutTimerService.ACTION_START_WORKOUT)
                                .putExtra(WorkoutTimerService.EXTRA_ELAPSED_SECONDS, elapsedSeconds)
                                .putExtra(WorkoutTimerService.EXTRA_EXERCISE, call.argument<String>("exercise"))
                                .putExtra(WorkoutTimerService.EXTRA_COMPLETED_SETS, call.argument<Number>("completedSets")?.toInt() ?: 0)
                                .putExtra(WorkoutTimerService.EXTRA_TOTAL_SETS, call.argument<Number>("totalSets")?.toInt() ?: 0),
                        )
                        result.success(null)
                    }

                    "updateWorkoutState" -> {
                        enqueueServiceCommand(
                            Intent(this, WorkoutTimerService::class.java)
                                .setAction(WorkoutTimerService.ACTION_UPDATE_WORKOUT)
                                .putExtra(WorkoutTimerService.EXTRA_EXERCISE, call.argument<String>("exercise"))
                                .putExtra(WorkoutTimerService.EXTRA_COMPLETED_SETS, call.argument<Number>("completedSets")?.toInt() ?: 0)
                                .putExtra(WorkoutTimerService.EXTRA_TOTAL_SETS, call.argument<Number>("totalSets")?.toInt() ?: 0),
                        )
                        result.success(null)
                    }

                    "startTimer" -> {
                        val exercise = call.argument<String>("exercise") ?: "休息"
                        val seconds = call.argument<Number>("seconds")
                            ?.toLong()
                            ?.coerceAtLeast(0L)
                            ?: 0L
                        enqueueServiceCommand(
                            Intent(this, WorkoutTimerService::class.java)
                                .setAction(WorkoutTimerService.ACTION_START_REST)
                                .putExtra(WorkoutTimerService.EXTRA_EXERCISE, exercise)
                                .putExtra(WorkoutTimerService.EXTRA_SECONDS, seconds),
                        )
                        result.success(null)
                    }

                    "updateTimer" -> {
                        val exercise = call.argument<String>("exercise") ?: "休息"
                        val seconds = call.argument<Number>("seconds")
                            ?.toLong()
                            ?.coerceAtLeast(0L)
                            ?: 0L
                        enqueueServiceCommand(
                            Intent(this, WorkoutTimerService::class.java)
                                .setAction(WorkoutTimerService.ACTION_UPDATE_REST)
                                .putExtra(WorkoutTimerService.EXTRA_EXERCISE, exercise)
                                .putExtra(WorkoutTimerService.EXTRA_SECONDS, seconds),
                        )
                        result.success(null)
                    }

                    "clearRest" -> {
                        enqueueServiceCommand(
                            Intent(this, WorkoutTimerService::class.java)
                                .setAction(WorkoutTimerService.ACTION_CLEAR_REST),
                        )
                        result.success(null)
                    }

                    "pauseTimer" -> {
                        enqueueServiceCommand(
                            Intent(this, WorkoutTimerService::class.java)
                                .setAction(WorkoutTimerService.ACTION_PAUSE),
                        )
                        result.success(null)
                    }

                    "finishTimer" -> {
                        enqueueServiceCommand(
                            Intent(this, WorkoutTimerService::class.java)
                                .setAction(WorkoutTimerService.ACTION_FINISH),
                        )
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (!intent.getBooleanExtra(EXTRA_OPEN_WORKOUT, false)) return
        val channel = timerChannel
        if (channel == null) {
            pendingWorkoutOpen = true
        } else {
            pendingWorkoutOpen = false
            channel.invokeMethod("openWorkoutFromSystem", null)
        }
    }

    override fun onDestroy() {
        skipReceiver?.let { receiver ->
            runCatching { unregisterReceiver(receiver) }
        }
        skipReceiver = null
        timerChannel = null
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) return
        notificationPermissionRequested = false
    }

    private fun enqueueServiceCommand(intent: Intent) {
        if (needsNotificationPermission()) {
            // Android allows a foreground service to start without the
            // POST_NOTIFICATIONS runtime grant. Starting immediately keeps the
            // timer alive (and visible in Samsung's task manager) while the
            // permission dialog is shown; a granted permission then enables
            // the public lock-screen notification.
            startWorkoutService(intent)
            if (!notificationPermissionRequested) {
                notificationPermissionRequested = true
                requestPermissions(
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST_CODE,
                )
            }
            return
        }
        startWorkoutService(intent)
    }

    private fun startWorkoutService(intent: Intent) {
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(this, intent)
            } else {
                startService(intent)
            }
        }
    }

    private fun needsNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED

    private fun registerRestSkippedReceiver() {
        if (skipReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    WorkoutTimerService.ACTION_REST_SKIPPED -> timerChannel?.invokeMethod("restSkippedFromNotification", null)
                    WorkoutTimerService.ACTION_SET_COMPLETED -> {
                        timerPreferences.edit().putBoolean(WorkoutTimerService.KEY_PENDING_SET_COMPLETION, false).apply()
                        timerChannel?.invokeMethod(
                            "completeSetFromNotification",
                            mapOf("completedSets" to intent.getIntExtra(WorkoutTimerService.EXTRA_COMPLETED_SETS, 0)),
                        )
                    }
                    WorkoutTimerService.ACTION_PAUSE_CHANGED -> timerChannel?.invokeMethod("pauseChangedFromNotification", intent.getBooleanExtra(WorkoutTimerService.EXTRA_PAUSED, false))
                }
            }
        }
        skipReceiver = receiver
        val filter = IntentFilter().apply {
            addAction(WorkoutTimerService.ACTION_REST_SKIPPED)
            addAction(WorkoutTimerService.ACTION_SET_COMPLETED)
            addAction(WorkoutTimerService.ACTION_PAUSE_CHANGED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
    }

    companion object {
        const val EXTRA_OPEN_WORKOUT = "kilo.extra.OPEN_WORKOUT"
        private const val CHANNEL_NAME = "kilo.platform.timer"
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 704
    }
}
