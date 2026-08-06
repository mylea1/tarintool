package com.kilostrength.kilo_strength

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.Locale
import kotlin.math.ceil

/**
 * Persistent workout timer notification.
 *
 * This is deliberately a foreground service instead of an Activity-owned
 * notification. Samsung One UI may still hide notifications when the user
 * disables lock-screen notifications, but a public foreground notification is
 * the supported Android path for keeping an active workout visible there.
 */
class WorkoutTimerService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var preferences: android.content.SharedPreferences

    private var workoutActive = false
    private var workoutPaused = false
    private var workoutStartedAt = 0L
    private var workoutElapsedAtPause = 0L
    private var restActive = false
    private var restPaused = false
    private var restEndAt = 0L
    private var restRemainingAtPause = 0L
    private var exerciseName = "训练"

    private val tick = object : Runnable {
        override fun run() {
            if (!workoutActive) return
            val now = System.currentTimeMillis()
            if (restActive && !restPaused && restRemainingSeconds(now) <= 0L) {
                clearRestInternal(notify = false)
            }
            persistState()
            postNotification(now)
            handler.postDelayed(this, UPDATE_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        preferences = getSharedPreferences(PREFERENCES_NAME, MODE_PRIVATE)
        restoreState()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // START_STICKY may restart the service with a null intent. Restore the
        // persisted state in that case instead of resetting the elapsed time.
        if (intent == null) {
            if (workoutActive) {
                ensureForeground()
                postNotification(System.currentTimeMillis())
                scheduleTicks()
                return START_STICKY
            }
            stopSelf()
            return START_NOT_STICKY
        }
        val action = intent.action ?: ACTION_START_WORKOUT
        val commandIntent = intent
        if (action == ACTION_SKIP_REST) {
            clearRestInternal(notify = true)
            sendBroadcast(Intent(ACTION_REST_SKIPPED).setPackage(packageName))
            return if (workoutActive) START_STICKY else START_NOT_STICKY
        }

        if (action == ACTION_FINISH) {
            stopTimerService()
            return START_NOT_STICKY
        }

        // startForeground must be called immediately after startForegroundService.
        // The first notification is updated below after applying the command.
        if (!workoutActive) {
            workoutActive = true
            workoutPaused = false
            workoutStartedAt = System.currentTimeMillis()
            workoutElapsedAtPause = 0L
        }
        ensureForeground()

        when (action) {
            ACTION_START_WORKOUT -> startWorkout(commandIntent)
            ACTION_START_REST -> updateRest(commandIntent)
            ACTION_UPDATE_REST -> updateRest(commandIntent)
            ACTION_CLEAR_REST -> clearRestInternal(notify = false)
            ACTION_PAUSE -> pauseWorkoutAndRest()
        }
        persistState()
        postNotification(System.currentTimeMillis())
        scheduleTicks()
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startWorkout(intent: Intent) {
        val elapsed = intent.getLongExtra(EXTRA_ELAPSED_SECONDS, 0L).coerceAtLeast(0L)
        workoutActive = true
        workoutPaused = false
        workoutElapsedAtPause = elapsed
        workoutStartedAt = System.currentTimeMillis() - elapsed * 1000L
        // A resumed workout may have an existing rest; Flutter follows this
        // command with updateTimer when appropriate.
        if (restActive && restPaused) {
            restPaused = false
            restEndAt = System.currentTimeMillis() + restRemainingAtPause * 1000L
        }
    }

    private fun updateRest(intent: Intent) {
        val seconds = intent.getLongExtra(EXTRA_SECONDS, 0L).coerceAtLeast(0L)
        exerciseName = intent.getStringExtra(EXTRA_EXERCISE)?.trim().orEmpty().ifEmpty { "休息" }
        if (seconds <= 0L) {
            clearRestInternal(notify = false)
            return
        }
        workoutActive = true
        if (workoutStartedAt <= 0L && !workoutPaused) {
            workoutStartedAt = System.currentTimeMillis() - workoutElapsedAtPause * 1000L
        }
        restActive = true
        restPaused = false
        restRemainingAtPause = seconds
        restEndAt = System.currentTimeMillis() + seconds * 1000L
    }

    private fun pauseWorkoutAndRest() {
        if (!workoutActive) return
        val now = System.currentTimeMillis()
        if (!workoutPaused) {
            workoutElapsedAtPause = workoutElapsedSeconds(now)
            workoutStartedAt = 0L
            workoutPaused = true
        }
        if (restActive && !restPaused) {
            restRemainingAtPause = restRemainingSeconds(now)
            restEndAt = 0L
            restPaused = true
        }
    }

    private fun clearRestInternal(notify: Boolean) {
        restActive = false
        restPaused = false
        restEndAt = 0L
        restRemainingAtPause = 0L
        if (notify && workoutActive) postNotification(System.currentTimeMillis())
    }

    private fun stopTimerService() {
        workoutActive = false
        workoutPaused = false
        workoutStartedAt = 0L
        workoutElapsedAtPause = 0L
        clearRestInternal(notify = false)
        persistState()
        handler.removeCallbacksAndMessages(null)
        runCatching { NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun scheduleTicks() {
        handler.removeCallbacks(tick)
        handler.post(tick)
    }

    private fun ensureForeground() {
        val notification = buildNotification(System.currentTimeMillis())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                } else {
                    0
                },
            )
        } else {
            @Suppress("DEPRECATION")
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun postNotification(now: Long) {
        runCatching {
            NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, buildNotification(now))
        }
    }

    private fun buildNotification(now: Long): Notification {
        val workoutElapsed = formatDuration(workoutElapsedSeconds(now))
        val restRemaining = if (restActive) restRemainingSeconds(now) else 0L
        val content = when {
            restActive && restPaused -> "休息已暂停 ${formatRest(restRemaining)} · 训练 $workoutElapsed"
            restActive -> "休息 ${formatRest(restRemaining)} · 训练 $workoutElapsed"
            workoutPaused -> "训练已暂停 · $workoutElapsed"
            else -> "训练 $workoutElapsed"
        }

        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            this,
            REQUEST_OPEN,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val skipIntent = Intent(this, WorkoutTimerService::class.java).setAction(ACTION_SKIP_REST)
        val skipPendingIntent = PendingIntent.getService(
            this,
            REQUEST_SKIP,
            skipIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("KILO · $exerciseName")
            .setContentText(content)
            .setSubText(if (restActive) "组间休息" else "训练进行中")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openPendingIntent)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setAutoCancel(false)

        if (restActive && !restPaused && restEndAt > now) {
            // The system chronometer provides an additional continuously
            // updating countdown on lock screens that support it. The body is
            // also rebuilt each second so Samsung's compact notification view
            // receives the numeric value rather than a frozen initial value.
            builder
                .setWhen(restEndAt)
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
                .addAction(NotificationCompat.Action(0, "跳过休息", skipPendingIntent))
        } else {
            builder.setWhen(now).setUsesChronometer(false)
        }
        return builder.build()
    }

    private fun workoutElapsedSeconds(now: Long): Long {
        if (!workoutActive) return 0L
        if (workoutPaused || workoutStartedAt <= 0L) return workoutElapsedAtPause
        return ((now - workoutStartedAt) / 1000L).coerceAtLeast(0L)
    }

    private fun restRemainingSeconds(now: Long): Long {
        if (!restActive) return 0L
        if (restPaused || restEndAt <= 0L) return restRemainingAtPause
        val remainingMillis = restEndAt - now
        if (remainingMillis <= 0L) return 0L
        return ceil(remainingMillis / 1000.0).toLong()
    }

    private fun formatRest(seconds: Long): String {
        val safe = seconds.coerceAtLeast(0L)
        return String.format(Locale.getDefault(), "%02d:%02d", safe / 60L, safe % 60L)
    }

    private fun formatDuration(seconds: Long): String {
        val safe = seconds.coerceAtLeast(0L)
        return String.format(
            Locale.getDefault(),
            "%02d:%02d:%02d",
            safe / 3600L,
            (safe / 60L) % 60L,
            safe % 60L,
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "KILO 训练计时",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "训练总时长和组间休息倒计时"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun restoreState() {
        workoutActive = preferences.getBoolean(KEY_WORKOUT_ACTIVE, false)
        workoutPaused = preferences.getBoolean(KEY_WORKOUT_PAUSED, false)
        workoutStartedAt = preferences.getLong(KEY_WORKOUT_STARTED_AT, 0L)
        workoutElapsedAtPause = preferences.getLong(KEY_WORKOUT_ELAPSED_PAUSED, 0L)
        restActive = preferences.getBoolean(KEY_REST_ACTIVE, false)
        restPaused = preferences.getBoolean(KEY_REST_PAUSED, false)
        restEndAt = preferences.getLong(KEY_REST_END_AT, 0L)
        restRemainingAtPause = preferences.getLong(KEY_REST_REMAINING_PAUSED, 0L)
        exerciseName = preferences.getString(KEY_EXERCISE, "训练") ?: "训练"
        if (workoutActive) {
            if (restActive && !restPaused && restEndAt <= System.currentTimeMillis()) {
                clearRestInternal(notify = false)
            }
            ensureForeground()
            scheduleTicks()
        }
    }

    private fun persistState() {
        preferences.edit()
            .putBoolean(KEY_WORKOUT_ACTIVE, workoutActive)
            .putBoolean(KEY_WORKOUT_PAUSED, workoutPaused)
            .putLong(KEY_WORKOUT_STARTED_AT, workoutStartedAt)
            .putLong(KEY_WORKOUT_ELAPSED_PAUSED, workoutElapsedAtPause)
            .putBoolean(KEY_REST_ACTIVE, restActive)
            .putBoolean(KEY_REST_PAUSED, restPaused)
            .putLong(KEY_REST_END_AT, restEndAt)
            .putLong(KEY_REST_REMAINING_PAUSED, restRemainingAtPause)
            .putString(KEY_EXERCISE, exerciseName)
            .apply()
    }

    companion object {
        const val ACTION_START_WORKOUT = "com.kilostrength.kilo_strength.START_WORKOUT"
        const val ACTION_START_REST = "com.kilostrength.kilo_strength.START_REST"
        const val ACTION_UPDATE_REST = "com.kilostrength.kilo_strength.UPDATE_REST"
        const val ACTION_CLEAR_REST = "com.kilostrength.kilo_strength.CLEAR_REST"
        const val ACTION_PAUSE = "com.kilostrength.kilo_strength.PAUSE_TIMER"
        const val ACTION_FINISH = "com.kilostrength.kilo_strength.FINISH_WORKOUT"
        const val ACTION_SKIP_REST = "com.kilostrength.kilo_strength.SKIP_REST"
        const val ACTION_REST_SKIPPED = "com.kilostrength.kilo_strength.REST_SKIPPED"

        const val EXTRA_EXERCISE = "exercise"
        const val EXTRA_SECONDS = "seconds"
        const val EXTRA_ELAPSED_SECONDS = "elapsedSeconds"

        private const val NOTIFICATION_CHANNEL_ID = "kilo_workout_v3"
        private const val NOTIFICATION_ID = 704
        private const val REQUEST_OPEN = 705
        private const val REQUEST_SKIP = 706
        private const val UPDATE_INTERVAL_MS = 1000L
        private const val PREFERENCES_NAME = "workout_timer"
        private const val KEY_WORKOUT_ACTIVE = "workoutActive"
        private const val KEY_WORKOUT_PAUSED = "workoutPaused"
        private const val KEY_WORKOUT_STARTED_AT = "workoutStartedAt"
        private const val KEY_WORKOUT_ELAPSED_PAUSED = "workoutElapsedAtPause"
        private const val KEY_REST_ACTIVE = "restActive"
        private const val KEY_REST_PAUSED = "restPaused"
        private const val KEY_REST_END_AT = "restEndAt"
        private const val KEY_REST_REMAINING_PAUSED = "restRemainingAtPause"
        private const val KEY_EXERCISE = "exerciseName"
    }
}
