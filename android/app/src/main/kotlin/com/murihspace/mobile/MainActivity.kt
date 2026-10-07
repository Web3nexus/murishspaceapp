package com.murihspace.mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
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

    /**
     * Forwards warm-start deep links to the Flutter engine.
     *
     * The activity is `singleTop`, so tapping a MurihSpace link while the app
     * is already running delivers it here instead of creating a new activity.
     * [FlutterActivity] forwards that intent itself, but this activity extends
     * [FlutterFragmentActivity], whose `onNewIntent` only notifies the
     * fragment manager — so without this override the link is dropped and the
     * user stays on whatever screen they were already looking at.
     *
     * This is what makes a shared live stream, meeting, event, product, chat or
     * profile link open the right screen when the app is already open.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Replace the activity's intent so getIntent() and any later relaunch
        // observe the new destination rather than the original one.
        setIntent(intent)
        flutterEngine?.activityControlSurface?.onNewIntent(intent)
    }
}