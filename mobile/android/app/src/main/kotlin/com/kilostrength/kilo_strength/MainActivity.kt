package com.kilostrength.kilo_strength

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Android system-capability bridge. Workout state remains in Flutter's AppController. */
class MainActivity : FlutterActivity() {
    private val channelName = "kilo.platform.timer"
    private val notificationChannelId = "kilo_rest_v2"
    private val notificationId = 704
    private val notificationPermissionRequestCode = 704
    private val skipAction = "com.kilostrength.kilo_strength.SKIP_REST"
    private var currentExercise = "休息计时"
    private var timerEndAt = 0L
    private var timerSeconds = 0
    private var timerPaused = false
    private var pendingNotification = false
    private var notificationPermissionRequested = false
    private var timerChannel: MethodChannel? = null
    private var skipReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()
        registerSkipReceiver()
        timerChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        timerChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startTimer" -> {
                    currentExercise = call.argument<String>("exercise") ?: "休息计时"
                    timerSeconds = call.argument<Number>("seconds")?.toInt()?.coerceAtLeast(0) ?: 0
                    timerEndAt = System.currentTimeMillis() + timerSeconds * 1000L
                    timerPaused = false
                    requestNotificationPermissionIfNeeded()
                    result.success(null)
                }
                "updateTimer" -> {
                    currentExercise = call.argument<String>("exercise") ?: currentExercise
                    timerSeconds = call.argument<Number>("seconds")?.toInt()?.coerceAtLeast(0) ?: timerSeconds
                    timerEndAt = System.currentTimeMillis() + timerSeconds * 1000L
                    postTimerNotificationIfAllowed()
                    result.success(null)
                }
                "pauseTimer" -> {
                    timerSeconds = ((timerEndAt - System.currentTimeMillis()) / 1000L).toInt().coerceAtLeast(0)
                    timerPaused = true
                    postTimerNotificationIfAllowed()
                    result.success(null)
                }
                "finishTimer" -> {
                    finishTimerNotification()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        skipReceiver?.let {
            runCatching { unregisterReceiver(it) }
        }
        skipReceiver = null
        timerChannel = null
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationPermissionRequestCode) {
            val shouldPost = pendingNotification
            pendingNotification = false
            if (shouldPost && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
                postTimerNotification()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(notificationChannelId, "KILO 休息计时", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "训练组间休息倒计时"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun registerSkipReceiver() {
        if (skipReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == skipAction) {
                    timerChannel?.invokeMethod("restSkippedFromNotification", null)
                    finishTimerNotification()
                }
            }
        }
        skipReceiver = receiver
        val filter = IntentFilter(skipAction)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            pendingNotification = true
            if (!notificationPermissionRequested) {
                notificationPermissionRequested = true
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationPermissionRequestCode)
            }
            return
        }
        pendingNotification = false
        postTimerNotification()
    }

    private fun postTimerNotificationIfAllowed() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            pendingNotification = true
            return
        }
        pendingNotification = false
        postTimerNotification()
    }

    private fun postTimerNotification() {
        createNotificationChannel()
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(this, 705, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val skipIntent = Intent(skipAction).setPackage(packageName)
        val skipPendingIntent = PendingIntent.getBroadcast(this, 706, skipIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val endLabel = if (timerPaused) "已暂停 · 剩余 ${timerSeconds}s" else "剩余 ${timerSeconds}s · 结束 ${formatClock(timerEndAt)}"
        val builder = NotificationCompat.Builder(this, notificationChannelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("KILO · $currentExercise")
            .setContentText(endLabel)
            .setSubText("组间休息")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openPendingIntent)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(NotificationCompat.Action(0, "跳过休息", skipPendingIntent))
        if (!timerPaused && timerEndAt > 0) {
            builder.setWhen(timerEndAt).setUsesChronometer(true).setChronometerCountDown(true)
        } else {
            builder.setWhen(System.currentTimeMillis()).setUsesChronometer(false)
        }
        runCatching { NotificationManagerCompat.from(this).notify(notificationId, builder.build()) }
    }

    private fun finishTimerNotification() {
        pendingNotification = false
        timerPaused = false
        timerSeconds = 0
        timerEndAt = 0L
        runCatching { NotificationManagerCompat.from(this).cancel(notificationId) }
    }

    private fun formatClock(timeMillis: Long): String = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(timeMillis))
}
