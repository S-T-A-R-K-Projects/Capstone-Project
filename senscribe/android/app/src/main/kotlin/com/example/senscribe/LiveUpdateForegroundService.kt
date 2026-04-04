package com.example.senscribe

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder

class LiveUpdateForegroundService : Service() {
  companion object {
    const val ACTION_START = "com.example.senscribe.action.START_LIVE_UPDATES"
    const val ACTION_STOP = "com.example.senscribe.action.STOP_LIVE_UPDATES"
    const val ACTION_MUTE = "com.example.senscribe.action.MUTE_LIVE_UPDATES"
  }

  private var isMuted = false

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      ACTION_STOP -> {
        stopForeground(true)
        stopSelf()
        return START_NOT_STICKY
      }
      ACTION_MUTE -> {
        isMuted = !isMuted
        AudioClassificationPlugin.isLiveUpdateMuted = isMuted
        val message = if (isMuted) "Muted live updates" else "Live updates unmuted"
        val notification = AudioClassificationPlugin.buildNotification(this, "SenScribe Live Updates", message)
        startForeground(AudioClassificationPlugin.NOTIFICATION_ID, notification)
        return START_STICKY
      }
      ACTION_START -> {
        val notification = createForegroundNotification()
        startForeground(AudioClassificationPlugin.NOTIFICATION_ID, notification)
        return START_STICKY
      }
      else -> {
        // Keep running if service gets started with no explicit action
        val notification = createForegroundNotification()
        startForeground(AudioClassificationPlugin.NOTIFICATION_ID, notification)
        return START_STICKY
      }
    }
  }

  private fun createForegroundNotification(): Notification {
    return AudioClassificationPlugin.buildNotification(this, "SenScribe Live Updates", "Listening for sounds...")
  }

  override fun onDestroy() {
    stopForeground(true)
    super.onDestroy()
  }
}
