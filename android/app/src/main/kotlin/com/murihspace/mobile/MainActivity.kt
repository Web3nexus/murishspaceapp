package com.murihspace.mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PictureInPictureParams
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Rational
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val pipChannel = "com.murihspace.mobile/pip"
    private var isCallActive = false
    private var isCallVideo = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "murihspace_chat",
                "Chat Messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for incoming chat messages and alerts"
                enableVibration(true)
                enableLights(true)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateCallState" -> {
                    isCallActive = call.argument<Boolean>("isActive") ?: false
                    isCallVideo = call.argument<Boolean>("isVideo") ?: false

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val builder = PictureInPictureParams.Builder()
                                .setAutoEnterEnabled(isCallActive)
                            if (isCallVideo) {
                                builder.setAspectRatio(Rational(9, 16))
                            } else {
                                builder.setAspectRatio(Rational(16, 9))
                            }
                            setPictureInPictureParams(builder.build())
                        } catch (_: Exception) {}
                    }
                    result.success(true)
                }
                "enterPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val builder = PictureInPictureParams.Builder()
                            if (isCallVideo) {
                                builder.setAspectRatio(Rational(9, 16))
                            } else {
                                builder.setAspectRatio(Rational(16, 9))
                            }
                            enterPictureInPictureMode(builder.build())
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("PIP_FAILED", e.message, null)
                        }
                    } else {
                        result.error("UNSUPPORTED", "PiP requires Android 8.0+", null)
                    }
                }
                "isPipSupported" -> {
                    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                    result.success(supported)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * When the user presses the home button or swipes to exit while a call is active,
     * immediately transition to native Android OS Picture-in-Picture mode.
     */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isCallActive && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val builder = PictureInPictureParams.Builder()
                if (isCallVideo) {
                    builder.setAspectRatio(Rational(9, 16))
                } else {
                    builder.setAspectRatio(Rational(16, 9))
                }
                enterPictureInPictureMode(builder.build())
            } catch (_: Exception) {}
        }
    }

    /**
     * Forwards warm-start deep links to the Flutter engine.
     *
     * The activity is `singleTop`, so tapping a MurihSpace link while the app
     * is already running delivers it here instead of creating a new activity.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        flutterEngine?.activityControlSurface?.onNewIntent(intent)
    }
}