package com.example.senscribe

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ModelDownloadBridge private constructor(
  private val context: Context,
  messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
  ManagedModelDownloadManager.Listener {

  companion object {
    private const val METHOD_CHANNEL = "senscribe/model_downloads"
    private const val EVENT_CHANNEL = "senscribe/model_download_events"

    @Volatile
    private var instance: ModelDownloadBridge? = null

    fun register(
      messenger: BinaryMessenger,
      context: Context,
    ): ModelDownloadBridge {
      instance?.let { return it }
      return ModelDownloadBridge(context.applicationContext, messenger).also {
        it.setup()
        instance = it
      }
    }
  }

  private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
  private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
  private val mainHandler = Handler(Looper.getMainLooper())
  private var eventSink: EventChannel.EventSink? = null

  private fun setup() {
    ManagedModelDownloadManager.initialize(context)
    methodChannel.setMethodCallHandler(this)
    eventChannel.setStreamHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "startDownload" -> {
        val args = call.arguments as? Map<*, *>
        val modelId = args?.get("modelId") as? String
        val modelSlug = args?.get("modelSlug") as? String
        val quantizationSlug = args?.get("quantizationSlug") as? String
        val displayName = args?.get("displayName") as? String
        val estimatedSizeMB = (args?.get("estimatedSizeMB") as? Number)?.toInt()

        if (modelId.isNullOrBlank() ||
          modelSlug.isNullOrBlank() ||
          quantizationSlug.isNullOrBlank() ||
          displayName.isNullOrBlank()
        ) {
          result.error(
            "invalid_args",
            "Missing managed model download arguments.",
            null,
          )
          return
        }

        val intent = Intent(context, ModelDownloadForegroundService::class.java).apply {
          action = ModelDownloadForegroundService.ACTION_START_DOWNLOAD
          putExtra(ModelDownloadForegroundService.EXTRA_MODEL_ID, modelId)
          putExtra(ModelDownloadForegroundService.EXTRA_MODEL_SLUG, modelSlug)
          putExtra(
            ModelDownloadForegroundService.EXTRA_QUANTIZATION_SLUG,
            quantizationSlug,
          )
          putExtra(ModelDownloadForegroundService.EXTRA_DISPLAY_NAME, displayName)
          putExtra(ModelDownloadForegroundService.EXTRA_ESTIMATED_SIZE_MB, estimatedSizeMB ?: 0)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
          context.startForegroundService(intent)
        } else {
          context.startService(intent)
        }
        result.success(null)
      }
      "cancelDownload" -> {
        val intent = Intent(context, ModelDownloadForegroundService::class.java).apply {
          action = ModelDownloadForegroundService.ACTION_CANCEL_DOWNLOAD
        }
        context.startService(intent)
        result.success(null)
      }
      "getStatus" -> result.success(ManagedModelDownloadManager.currentSnapshotMap())
      else -> result.notImplemented()
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
    eventSink = events
    ManagedModelDownloadManager.addListener(this)
    events.success(ManagedModelDownloadManager.currentSnapshotMap())
  }

  override fun onCancel(arguments: Any?) {
    ManagedModelDownloadManager.removeListener(this)
    eventSink = null
  }

  override fun onSnapshotChanged(snapshot: ManagedModelDownloadSnapshot) {
    mainHandler.post {
      eventSink?.success(snapshot.toMap())
    }
  }
}
