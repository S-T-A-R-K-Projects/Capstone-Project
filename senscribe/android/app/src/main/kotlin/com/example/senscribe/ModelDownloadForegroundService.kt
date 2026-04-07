package com.example.senscribe

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class ModelDownloadForegroundService : Service(),
  ManagedModelDownloadManager.Listener {

  companion object {
    const val ACTION_START_DOWNLOAD = "com.example.senscribe.action.START_MODEL_DOWNLOAD"
    const val ACTION_CANCEL_DOWNLOAD = "com.example.senscribe.action.CANCEL_MODEL_DOWNLOAD"

    const val EXTRA_MODEL_ID = "model_id"
    const val EXTRA_MODEL_SLUG = "model_slug"
    const val EXTRA_QUANTIZATION_SLUG = "quantization_slug"
    const val EXTRA_DISPLAY_NAME = "display_name"
    const val EXTRA_ESTIMATED_SIZE_MB = "estimated_size_mb"

    private const val CHANNEL_ID = "senscribe_model_downloads"
    private const val CHANNEL_NAME = "Model Downloads"
    private const val NOTIFICATION_ID = 0xAC12
  }

  private val notificationManager by lazy { NotificationManagerCompat.from(this) }
  private var lastNotificationAtMs: Long = 0L
  private var lastNotificationProgress: Double = 0.0

  override fun onCreate() {
    super.onCreate()
    ManagedModelDownloadManager.initialize(applicationContext)
    ManagedModelDownloadManager.addListener(this)
    createNotificationChannel()
  }

  override fun onDestroy() {
    ManagedModelDownloadManager.removeListener(this)
    stopForeground(true)
    super.onDestroy()
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      ACTION_CANCEL_DOWNLOAD -> {
        ManagedModelDownloadManager.cancelDownload()
        stopForeground(true)
        stopSelf()
        return START_NOT_STICKY
      }
      ACTION_START_DOWNLOAD -> {
        val modelId = intent.getStringExtra(EXTRA_MODEL_ID)
        val modelSlug = intent.getStringExtra(EXTRA_MODEL_SLUG)
        val quantizationSlug = intent.getStringExtra(EXTRA_QUANTIZATION_SLUG)
        val displayName = intent.getStringExtra(EXTRA_DISPLAY_NAME) ?: "AI model"
        val estimatedSizeMB = intent.getIntExtra(EXTRA_ESTIMATED_SIZE_MB, 0)

        if (modelId.isNullOrBlank() || modelSlug.isNullOrBlank() || quantizationSlug.isNullOrBlank()) {
          stopSelf()
          return START_NOT_STICKY
        }

        startForeground(
          NOTIFICATION_ID,
          createNotification(
            title = "Downloading $displayName",
            content = if (estimatedSizeMB > 0) {
              "Model size ~${estimatedSizeMB} MB"
            } else {
              "Preparing download..."
            },
          ),
        )

        ManagedModelDownloadManager.startDownload(
          context = applicationContext,
          modelId = modelId,
          modelSlug = modelSlug,
          quantizationSlug = quantizationSlug,
        )
        return START_STICKY
      }
      else -> return START_STICKY
    }
  }

  override fun onSnapshotChanged(snapshot: ManagedModelDownloadSnapshot) {
    val nowMs = System.currentTimeMillis()
    if (snapshot.isRunning &&
      nowMs - lastNotificationAtMs < 500 &&
      (snapshot.progress - lastNotificationProgress) < 0.01
    ) {
      return
    }
    lastNotificationAtMs = nowMs
    lastNotificationProgress = snapshot.progress

    val title = if (snapshot.isRunning) {
      "Downloading ${snapshot.modelId}"
    } else if (snapshot.lastError != null) {
      "Model download failed"
    } else {
      "Model download complete"
    }

    notificationManager.notify(
      NOTIFICATION_ID,
      createNotification(
        title = title,
        content = snapshot.statusMessage.ifBlank { "Preparing download..." },
        progress = if (snapshot.isRunning) snapshot.progress else null,
      ),
    )

    if (!snapshot.isRunning) {
      stopForeground(true)
      stopSelf()
    }
  }

  private fun createNotification(
    title: String,
    content: String,
    progress: Double? = null,
  ): Notification {
    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
    val pendingIntent = PendingIntent.getActivity(
      this,
      0,
      launchIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    val cancelIntent = Intent(this, ModelDownloadForegroundService::class.java).apply {
      action = ACTION_CANCEL_DOWNLOAD
    }
    val cancelPendingIntent = PendingIntent.getService(
      this,
      1,
      cancelIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    return NotificationCompat.Builder(this, CHANNEL_ID)
      .setSmallIcon(android.R.drawable.stat_sys_download)
      .setContentTitle(title)
      .setContentText(content)
      .setContentIntent(pendingIntent)
      .setOnlyAlertOnce(true)
      .setOngoing(progress != null)
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .addAction(
        NotificationCompat.Action.Builder(
          android.R.drawable.ic_menu_close_clear_cancel,
          "Cancel",
          cancelPendingIntent,
        ).build(),
      )
      .setProgress(
        100,
        progress?.times(100)?.toInt()?.coerceIn(0, 100) ?: 0,
        progress == null,
      )
      .build()
  }

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        CHANNEL_ID,
        CHANNEL_NAME,
        NotificationManager.IMPORTANCE_LOW,
      )
      channel.description = "Managed Liquid AI model downloads"
      notificationManager.createNotificationChannel(channel)
    }
  }
}
