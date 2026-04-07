package com.example.senscribe

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.widget.RemoteViews
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.time.Instant
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

internal data class CustomSoundProfileRecord(
  val id: String,
  var name: String,
  var enabled: Boolean,
  var status: String,
  var targetSamplePaths: List<String>,
  var backgroundSamplePaths: List<String>,
  val createdAt: String,
  var updatedAt: String,
  var lastError: String?,
  var targetEmbeddingBank: List<List<Float>>?,
  var backgroundEmbeddingBank: List<List<Float>>?,
  var detectionThreshold: Double?,
  var backgroundMargin: Double?,
) {
  val hasEnoughSamples: Boolean
    get() = targetSamplePaths.size >= AudioClassificationPlugin.REQUIRED_TARGET_SAMPLES &&
      backgroundSamplePaths.size >= AudioClassificationPlugin.REQUIRED_BACKGROUND_SAMPLES

  fun toMap(): Map<String, Any?> {
    return mapOf(
      "id" to id,
      "name" to name,
      "enabled" to enabled,
      "status" to status,
      "targetSamplePaths" to targetSamplePaths,
      "backgroundSamplePaths" to backgroundSamplePaths,
      "createdAt" to createdAt,
      "updatedAt" to updatedAt,
      "lastError" to lastError,
      "targetEmbeddingBank" to targetEmbeddingBank,
      "backgroundEmbeddingBank" to backgroundEmbeddingBank,
      "detectionThreshold" to detectionThreshold,
      "backgroundMargin" to backgroundMargin,
    )
  }

  fun toJson(): JSONObject {
    return JSONObject().apply {
      put("id", id)
      put("name", name)
      put("enabled", enabled)
      put("status", status)
      put("targetSamplePaths", JSONArray(targetSamplePaths))
      put("backgroundSamplePaths", JSONArray(backgroundSamplePaths))
      put("createdAt", createdAt)
      put("updatedAt", updatedAt)
      put("lastError", lastError)
      put("targetEmbeddingBank", targetEmbeddingBank?.let { embeddingBankToJsonArray(it) })
      put("backgroundEmbeddingBank", backgroundEmbeddingBank?.let { embeddingBankToJsonArray(it) })
      put("detectionThreshold", detectionThreshold)
      put("backgroundMargin", backgroundMargin)
    }
  }

  companion object {
    fun fromJson(json: JSONObject): CustomSoundProfileRecord {
      return CustomSoundProfileRecord(
        id = json.optString("id"),
        name = json.optString("name"),
        enabled = json.optBoolean("enabled", true),
        status = json.optString("status", "draft"),
        targetSamplePaths = json.optJSONArray("targetSamplePaths").toStringList(),
        backgroundSamplePaths = json.optJSONArray("backgroundSamplePaths").toStringList(),
        createdAt = json.optString("createdAt", Instant.now().toString()),
        updatedAt = json.optString("updatedAt", Instant.now().toString()),
        lastError = json.optStringOrNull("lastError"),
        targetEmbeddingBank = json.optJSONArray("targetEmbeddingBank").toEmbeddingBankOrNull(),
        backgroundEmbeddingBank = json.optJSONArray("backgroundEmbeddingBank").toEmbeddingBankOrNull(),
        detectionThreshold = json.optDoubleOrNull("detectionThreshold"),
        backgroundMargin = json.optDoubleOrNull("backgroundMargin"),
      ).normalizedForRequirements()
    }

    private fun embeddingBankToJsonArray(values: List<List<Float>>): JSONArray {
      val array = JSONArray()
      values.forEach { embedding ->
        val nested = JSONArray()
        embedding.forEach { nested.put(it.toDouble()) }
        array.put(nested)
      }
      return array
    }
  }
}

private data class CustomSoundMatcher(
  val profileId: String,
  val label: String,
  val targetBank: List<FloatArray>,
  val backgroundBank: List<FloatArray>,
  val detectionThreshold: Double,
  val backgroundMargin: Double,
)

private data class SignalLevels(
  val rms: Float,
  val peak: Float,
)

private data class MatchCandidate(
  val matcher: CustomSoundMatcher,
  val similarity: Double,
  val backgroundSimilarity: Double,
)

private data class TrainingFeatureWindow(
  val feature: FloatArray,
  val signalLevels: SignalLevels,
)

class AudioClassificationPlugin private constructor(
  private val context: Context,
  private var activity: Activity,
  messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

  companion object {
    private const val METHOD_CHANNEL = "senscribe/audio_classifier"
    private const val EVENT_CHANNEL = "senscribe/audio_classifier_events"
    private const val PERMISSION_REQUEST_CODE = 0xAC01
    private const val TAG = "AudioClassifierPlugin"

    private const val SAMPLE_RATE = 16000
    private const val CHANNEL_COUNT = 1
    private const val CLASSIFICATION_SAMPLE_COUNT = 15600
    private const val INFERENCE_HOP_SAMPLE_COUNT = 3200
    private const val EMBEDDING_STEP_SAMPLE_COUNT = CLASSIFICATION_SAMPLE_COUNT / 2
    private const val CAPTURE_DURATION_SECONDS = 5
    private const val CAPTURE_SAMPLE_COUNT = SAMPLE_RATE * CAPTURE_DURATION_SECONDS

    internal const val REQUIRED_TARGET_SAMPLES = 10
    internal const val REQUIRED_BACKGROUND_SAMPLES = 3

    private const val MODEL_ASSET_PATH = "yamnet/yamnet.tflite"

    private const val BUILT_IN_SCORE_THRESHOLD = 0.4f
    private const val BUILT_IN_MIN_SIGNAL_RMS = 0.006f
    private const val BUILT_IN_MIN_SIGNAL_PEAK = 0.018f
    private const val BUILT_IN_MIN_WIN_MARGIN = 0.06
    private const val BUILT_IN_REQUIRED_CONSECUTIVE_MATCHES = 2
    private const val BUILT_IN_THROTTLE_MS = 5_000L

    private const val CUSTOM_MIN_SIGNAL_RMS = 0.008f
    private const val CUSTOM_MIN_SIGNAL_PEAK = 0.024f
    private const val CUSTOM_MIN_WIN_MARGIN = 0.03
    private const val CUSTOM_MIN_BACKGROUND_SEPARATION = 0.045
    private const val CUSTOM_THROTTLE_MS = 5_000L
    private const val CUSTOM_REQUIRED_CONSECUTIVE_MATCHES = 2
    private const val TARGET_WINDOWS_PER_SAMPLE = 3
    private const val BACKGROUND_WINDOWS_PER_SAMPLE = 4

    // Notification constants
    const val NOTIFICATION_CHANNEL_ID = "senscribe_live_updates"
    const val NOTIFICATION_CHANNEL_NAME = "Live Audio Updates"
    const val NOTIFICATION_ID = 0xAC02
    private const val NOTIFICATION_UPDATE_THROTTLE_MS = 1000L

    @Volatile
    var isLiveUpdateMuted = false

    @Volatile
    private var sharedInstance: AudioClassificationPlugin? = null

    fun register(
      messenger: BinaryMessenger,
      context: Context,
      activity: Activity,
    ): AudioClassificationPlugin {
      sharedInstance?.let { plugin ->
        plugin.updateActivity(activity)
        return plugin
      }
      val plugin = AudioClassificationPlugin(context.applicationContext, activity, messenger)
      plugin.setup()
      sharedInstance = plugin
      return plugin
    }

    fun sharedInstance(): AudioClassificationPlugin? = sharedInstance

    fun buildNotification(context: Context, title: String, content: String): Notification {
      val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
      val pendingIntent = PendingIntent.getActivity(
        context,
        0,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      )

      val muteStateText = if (isLiveUpdateMuted) "Muted - no content updates" else "Tap Stop to end monitoring"
      val remoteViews = RemoteViews(context.packageName, R.layout.live_update_notification).apply {
        setTextViewText(R.id.notification_title, title)
        setTextViewText(R.id.notification_content, content)
        setTextViewText(R.id.notification_subtitle, muteStateText)
      }

      val stopIntent = Intent(context, LiveUpdateForegroundService::class.java).apply {
        action = LiveUpdateForegroundService.ACTION_STOP
      }
      val stopPendingIntent = PendingIntent.getService(
        context,
        0,
        stopIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      )

      val muteIntent = Intent(context, LiveUpdateForegroundService::class.java).apply {
        action = LiveUpdateForegroundService.ACTION_MUTE
      }
      val mutePendingIntent = PendingIntent.getService(
        context,
        1,
        muteIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      )

      val muteActionLabel = if (isLiveUpdateMuted) "Unmute" else "Mute"
      val muteIcon = if (isLiveUpdateMuted) android.R.drawable.ic_lock_silent_mode_off else android.R.drawable.ic_lock_silent_mode

      return NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
        .setSmallIcon(android.R.drawable.ic_btn_speak_now)
        .setCustomContentView(remoteViews)
        .setCustomBigContentView(remoteViews)
        .setStyle(NotificationCompat.DecoratedCustomViewStyle())
        .setOngoing(true)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setContentIntent(pendingIntent)
        .addAction(
          NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_view,
            "Open app",
            pendingIntent
          ).build()
        )
        .addAction(
          NotificationCompat.Action.Builder(
            muteIcon,
            muteActionLabel,
            mutePendingIntent
          ).build()
        )
        .addAction(
          NotificationCompat.Action.Builder(
            android.R.drawable.ic_media_pause,
            "Stop",
            stopPendingIntent
          ).build()
        )
        .setAutoCancel(false)
        .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        .setCategory(NotificationCompat.CATEGORY_SERVICE)
        .build()
    }
  }

  private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
  private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
  private val mainHandler = Handler(Looper.getMainLooper())

  private var eventSink: EventChannel.EventSink? = null

  private var pendingPermissionResult: MethodChannel.Result? = null
  private var pendingPermissionContinuation: (() -> Unit)? = null

  private var yamnetRunner: YamnetLiteRtRunner? = null
  private var audioRecord: AudioRecord? = null
  private var handlerThread: HandlerThread? = null
  private var workHandler: Handler? = null
  private var wakeLock: PowerManager.WakeLock? = null

  private val isRunning = AtomicBoolean(false)
  private val isCapturingSample = AtomicBoolean(false)
  private var resumeMonitoringAfterCapture = false

  private val classifierReadBuffer = ShortArray(INFERENCE_HOP_SAMPLE_COUNT)
  private val classifierReadFloatBuffer = FloatArray(INFERENCE_HOP_SAMPLE_COUNT)
  private val classifierRollingWindow = FloatArray(CLASSIFICATION_SAMPLE_COUNT)
  private var classifierWindowFillCount = 0

  private val lastEmittedAtByKey = mutableMapOf<String, Long>()
  private var lastBuiltInThrottleKey: String? = null
  private var lastCustomThrottleKey: String? = null
  private var lastBuiltInCandidateLabel: String? = null
  private var lastBuiltInCandidateCount = 0
  private var lastCustomCandidateId: String? = null
  private var lastCustomCandidateCount = 0
  private var activeCustomMatchers: List<CustomSoundMatcher> = emptyList()

  // Notification state
  private var isLiveUpdateEnabled = false
  private var lastNotificationUpdateMs = 0L
  private var currentNotificationContent = ""
  private var notificationManager: NotificationManagerCompat? = null

  private val customSoundsRootDir: File by lazy {
    File(context.filesDir, "custom_sounds").apply { mkdirs() }
  }

  private val profilesFile: File by lazy {
    File(customSoundsRootDir, "profiles.json")
  }

  private fun setup() {
    methodChannel.setMethodCallHandler(this)
    eventChannel.setStreamHandler(this)
    activeCustomMatchers = loadActiveCustomMatchers()
    notificationManager = NotificationManagerCompat.from(context)
    createNotificationChannel()
  }

  fun dispose() {
    stopClassification()
    hideLiveUpdateNotification()
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
  }

  fun updateActivity(activity: Activity) {
    this.activity = activity
  }

  fun stopMonitoringFromService() {
    internalStopClassification(shouldSendStatus = true)
    hideLiveUpdateNotification()
  }

  fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
    if (requestCode != PERMISSION_REQUEST_CODE) return

    val result = pendingPermissionResult
    val continuation = pendingPermissionContinuation
    pendingPermissionResult = null
    pendingPermissionContinuation = null

    if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
      try {
        continuation?.invoke()
      } catch (error: Exception) {
        result?.error("microphone_action_failed", error.message ?: "Unable to continue microphone action.", null)
      }
    } else {
      result?.error(
        "microphone_permission_denied",
        "Microphone permission is required to classify audio and capture custom sound samples.",
        null,
      )
    }
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "start" -> handleStart(result)
      "stop" -> {
        stopClassification()
        stopForegroundMonitoringService()
        result.success(null)
      }
      "startLiveUpdates" -> handleStartLiveUpdates(result)
      "stopLiveUpdates" -> handleStopLiveUpdates(result)
      "loadCustomSounds" -> result.success(loadProfiles().map { it.toMap() })
      "captureSample" -> captureSample(call, result)
      "trainOrRebuildCustomModel" -> trainOrRebuildCustomModel(result)
      "deleteCustomSound" -> deleteCustomSound(call, result)
      "setCustomSoundEnabled" -> setCustomSoundEnabled(call, result)
      else -> result.notImplemented()
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
    eventSink = events
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }

  private fun handleStart(result: MethodChannel.Result) {
    if (isRunning.get()) {
      ensureForegroundMonitoringService()
      result.success(null)
      return
    }

    runWithMicrophonePermission(result) {
      try {
        ensureForegroundMonitoringService()
        startClassification()
        currentNotificationContent = "Listening for sounds..."
        showLiveUpdateNotification()
        result.success(null)
      } catch (error: Exception) {
        stopForegroundMonitoringService()
        result.error(
          "start_failed",
          error.message ?: "Unable to start sound recognition.",
          null,
        )
      }
    }
  }

  private fun handleStartLiveUpdates(result: MethodChannel.Result) {
    if (isLiveUpdateEnabled) {
      result.success(null)
      return
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
        ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
      result.error("notification_permission_denied", "Notification permission is required for live updates.", null)
      return
    }

    isLiveUpdateEnabled = true
    currentNotificationContent = "Listening for sounds..."
    if (isRunning.get()) {
      ensureForegroundMonitoringService()
      showLiveUpdateNotification()
    }
    result.success(null)
  }

  private fun handleStopLiveUpdates(result: MethodChannel.Result) {
    if (!isLiveUpdateEnabled) {
      result.success(null)
      return
    }

    isLiveUpdateEnabled = false
    currentNotificationContent = "Listening for sounds..."
    if (isRunning.get()) {
      showLiveUpdateNotification()
    } else {
      hideLiveUpdateNotification()
    }
    result.success(null)
  }

  private fun runWithMicrophonePermission(
    result: MethodChannel.Result,
    onGranted: () -> Unit,
  ) {
    if (hasMicrophonePermission()) {
      onGranted()
      return
    }

    if (pendingPermissionResult != null) {
      result.error("permission_request_in_progress", "Another microphone permission request is already in progress.", null)
      return
    }

    pendingPermissionResult = result
    pendingPermissionContinuation = onGranted
    ActivityCompat.requestPermissions(
      activity,
      arrayOf(Manifest.permission.RECORD_AUDIO),
      PERMISSION_REQUEST_CODE,
    )
  }

  @Throws(Exception::class)
  private fun startClassification() {
    if (isRunning.get()) return

    activeCustomMatchers = loadActiveCustomMatchers()
    val runner = try {
      createYamnetRunner()
    } catch (error: Exception) {
      throw IllegalStateException(
        error.message ?: "Unable to initialize the YAMNet sound runner.",
        error,
      )
    }

    val minBufferSize =
      AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
    val bufferSizeInBytes = max(minBufferSize, CLASSIFICATION_SAMPLE_COUNT * 2)

    val recorder = AudioRecord(
      MediaRecorder.AudioSource.VOICE_RECOGNITION,
      SAMPLE_RATE,
      AudioFormat.CHANNEL_IN_MONO,
      AudioFormat.ENCODING_PCM_16BIT,
      bufferSizeInBytes,
    )

    if (recorder.state != AudioRecord.STATE_INITIALIZED) {
      runner.close()
      recorder.release()
      throw IllegalStateException("Unable to initialize microphone for audio classification.")
    }

    yamnetRunner = runner
    audioRecord = recorder

    classifierWindowFillCount = 0
    classifierRollingWindow.fill(0f)
    resetEmissionThrottleState()
    resetBuiltInCandidate()
    resetCustomCandidate()
    isRunning.set(true)

    acquireWakeLock()
    recorder.startRecording()

    handlerThread = HandlerThread("senscribe-audio-classifier").also { it.start() }
    workHandler = Handler(handlerThread!!.looper).also { handler ->
      handler.post(classificationRunnable)
    }

    sendStatus("started")
  }

  private val classificationRunnable = object : Runnable {
    override fun run() {
      if (!isRunning.get()) return

      val runner = yamnetRunner
      val recorder = audioRecord

      if (runner == null || recorder == null) {
        stopClassification()
        return
      }

      var totalRead = 0
      while (totalRead < INFERENCE_HOP_SAMPLE_COUNT && isRunning.get()) {
        val read = recorder.read(
          classifierReadBuffer,
          totalRead,
          INFERENCE_HOP_SAMPLE_COUNT - totalRead,
          AudioRecord.READ_BLOCKING,
        )
        if (read < 0) {
          postError("stream_failed", "Audio recorder read failure: $read")
          stopClassification()
          return
        }
        totalRead += read
      }

      if (!isRunning.get()) return

      for (i in 0 until totalRead) {
        classifierReadFloatBuffer[i] = classifierReadBuffer[i] / 32768f
      }

      classifierWindowFillCount = appendToRollingWindow(
        destination = classifierRollingWindow,
        currentFillCount = classifierWindowFillCount,
        source = classifierReadFloatBuffer,
        count = totalRead,
      )

      if (classifierWindowFillCount < CLASSIFICATION_SAMPLE_COUNT) {
        if (isRunning.get()) {
          workHandler?.post(this)
        }
        return
      }

      val recentSignalLevels = calculateSignalLevels(classifierReadFloatBuffer, totalRead)
      val inferenceResult = try {
        runner.analyze(classifierRollingWindow)
      } catch (error: Exception) {
        postError("analysis_failed", error.message ?: "Audio classification failed.")
        stopClassification()
        return
      }
      val builtInPayload = processBuiltInResult(inferenceResult, recentSignalLevels)

      var customPayload: Map<String, Any>? = null
      if (activeCustomMatchers.isNotEmpty()) {
        val featureVector = CustomAudioFeatureExtractor.extract(classifierRollingWindow)
        if (featureVector != null) {
          customPayload = processCustomEmbedding(
            featureVector,
            recentSignalLevels,
          )
        } else {
          resetCustomCandidate()
        }
      }

      customPayload?.let(::emitDetectionPayload)
      builtInPayload?.let(::emitDetectionPayload)

      if (isRunning.get()) {
        workHandler?.post(this)
      }
    }
  }

  private fun processBuiltInResult(
    result: YamnetInferenceResult,
    signalLevels: SignalLevels,
  ): Map<String, Any>? {
    if (signalLevels.rms < BUILT_IN_MIN_SIGNAL_RMS && signalLevels.peak < BUILT_IN_MIN_SIGNAL_PEAK) {
      resetBuiltInCandidate()
      return null
    }

    val audioResult = result.categories.firstOrNull() ?: return null
    val categories = result.categories
    val runnerUp = categories.getOrNull(1)

    if (audioResult.score < BUILT_IN_SCORE_THRESHOLD) {
      resetBuiltInCandidate()
      return null
    }
    if (runnerUp != null && audioResult.score < runnerUp.score + BUILT_IN_MIN_WIN_MARGIN) {
      resetBuiltInCandidate()
      return null
    }

    val label = audioResult.label
    val normalizedLabel = label.trim().lowercase()
    if (lastBuiltInCandidateLabel == normalizedLabel) {
      lastBuiltInCandidateCount += 1
    } else {
      lastBuiltInCandidateLabel = normalizedLabel
      lastBuiltInCandidateCount = 1
    }

    if (lastBuiltInCandidateCount < BUILT_IN_REQUIRED_CONSECUTIVE_MATCHES) {
      return null
    }

    val now = System.currentTimeMillis()
    if (
      !shouldEmit(
        key = "builtIn:$normalizedLabel",
        nowMs = now,
        throttleMs = BUILT_IN_THROTTLE_MS,
        source = "builtIn",
      )
    ) {
      return null
    }

    return mapOf(
      "type" to "result",
      "label" to label,
      "confidence" to audioResult.score,
      "source" to "builtIn",
      "timestampMs" to now,
    )
  }

  private fun appendToRollingWindow(
    destination: FloatArray,
    currentFillCount: Int,
    source: FloatArray,
    count: Int,
  ): Int {
    if (count <= 0) {
      return currentFillCount
    }

    if (count >= destination.size) {
      source.copyInto(
        destination,
        destinationOffset = 0,
        startIndex = count - destination.size,
        endIndex = count,
      )
      return destination.size
    }

    var fillCount = currentFillCount
    if (fillCount < destination.size) {
      val copyCount = min(count, destination.size - fillCount)
      source.copyInto(
        destination,
        destinationOffset = fillCount,
        startIndex = 0,
        endIndex = copyCount,
      )
      fillCount += copyCount
      if (copyCount == count) {
        return fillCount
      }

      val remaining = count - copyCount
      destination.copyInto(
        destination,
        destinationOffset = 0,
        startIndex = remaining,
        endIndex = destination.size,
      )
      source.copyInto(
        destination,
        destinationOffset = destination.size - remaining,
        startIndex = copyCount,
        endIndex = count,
      )
      return destination.size
    }

    destination.copyInto(
      destination,
      destinationOffset = 0,
      startIndex = count,
      endIndex = destination.size,
    )
    source.copyInto(
      destination,
      destinationOffset = destination.size - count,
      startIndex = 0,
      endIndex = count,
    )
    return destination.size
  }

  private fun processCustomEmbedding(
    embedding: FloatArray,
    signalLevels: SignalLevels,
  ): Map<String, Any>? {
    if (signalLevels.rms < CUSTOM_MIN_SIGNAL_RMS && signalLevels.peak < CUSTOM_MIN_SIGNAL_PEAK) {
      resetCustomCandidate()
      return null
    }

    val normalizedEmbedding = CustomSoundMatching.normalizeEmbedding(embedding)
    val candidates = activeCustomMatchers.mapNotNull { matcher ->
      val similarity = CustomSoundMatching.scoreAgainstBank(normalizedEmbedding, matcher.targetBank)
      val backgroundSimilarity = CustomSoundMatching.scoreAgainstBank(
        normalizedEmbedding,
        matcher.backgroundBank,
      )
      val requiredBackgroundGap = max(matcher.backgroundMargin, CUSTOM_MIN_BACKGROUND_SEPARATION)

      if (similarity < matcher.detectionThreshold) {
        return@mapNotNull null
      }
      if (similarity < backgroundSimilarity + requiredBackgroundGap) {
        return@mapNotNull null
      }

      MatchCandidate(
        matcher = matcher,
        similarity = similarity,
        backgroundSimilarity = backgroundSimilarity,
      )
    }.sortedByDescending { it.similarity }

    val best = candidates.firstOrNull()
    val runnerUp = candidates.getOrNull(1)
    if (best == null) {
      resetCustomCandidate()
      return null
    }

    if (runnerUp != null && best.similarity < runnerUp.similarity + CUSTOM_MIN_WIN_MARGIN) {
      resetCustomCandidate()
      return null
    }

    if (lastCustomCandidateId == best.matcher.profileId) {
      lastCustomCandidateCount += 1
    } else {
      lastCustomCandidateId = best.matcher.profileId
      lastCustomCandidateCount = 1
    }

    if (lastCustomCandidateCount < CUSTOM_REQUIRED_CONSECUTIVE_MATCHES) {
      return null
    }

    val now = System.currentTimeMillis()
    if (
      !shouldEmit(
        key = "custom:${best.matcher.profileId}",
        nowMs = now,
        throttleMs = CUSTOM_THROTTLE_MS,
        source = "custom",
      )
    ) {
      return null
    }

    return mapOf(
      "type" to "result",
      "label" to best.matcher.label,
      "confidence" to best.similarity,
      "source" to "custom",
      "timestampMs" to now,
      "customSoundId" to best.matcher.profileId,
    )
  }

  private fun stopClassification() {
    internalStopClassification(shouldSendStatus = true)
    stopForegroundMonitoringService()
  }

  private fun internalStopClassification(shouldSendStatus: Boolean) {
    if (!isRunning.getAndSet(false)) {
      return
    }

    workHandler?.removeCallbacksAndMessages(null)
    workHandler = null

    handlerThread?.quitSafely()
    handlerThread = null

    audioRecord?.let { recorder ->
      try {
        recorder.stop()
      } catch (_: IllegalStateException) {
        // Ignore stop failures when the recorder is already stopping.
      }
      recorder.release()
    }
    audioRecord = null

    yamnetRunner?.close()
    yamnetRunner = null
    releaseWakeLock()

    classifierWindowFillCount = 0
    classifierRollingWindow.fill(0f)
    resetEmissionThrottleState()
    resetBuiltInCandidate()
    resetCustomCandidate()

    if (shouldSendStatus) {
      sendStatus("stopped")
    }
  }

  private fun captureSample(call: MethodCall, result: MethodChannel.Result) {
    val args = call.arguments as? Map<*, *> ?: run {
      result.error("invalid_args", "Missing sample capture arguments.", null)
      return
    }

    val soundId = args["soundId"] as? String
    val name = args["name"] as? String
    val sampleKind = args["sampleKind"] as? String
    val sampleIndex = (args["sampleIndex"] as? Number)?.toInt() ?: 0

    if (soundId.isNullOrBlank() || name.isNullOrBlank() || sampleKind.isNullOrBlank()) {
      result.error("invalid_args", "Missing custom sound capture fields.", null)
      return
    }
    if (sampleKind != "target" && sampleKind != "background") {
      result.error("invalid_args", "Unknown sample kind: $sampleKind", null)
      return
    }
    if (isCapturingSample.get()) {
      result.error("capture_in_progress", "Another custom sound recording is already in progress.", null)
      return
    }

    runWithMicrophonePermission(result) {
      beginSampleCapture(
        soundId = soundId,
        name = name,
        sampleKind = sampleKind,
        sampleIndex = sampleIndex,
        result = result,
      )
    }
  }

  private fun beginSampleCapture(
    soundId: String,
    name: String,
    sampleKind: String,
    sampleIndex: Int,
    result: MethodChannel.Result,
  ) {
    if (!isCapturingSample.compareAndSet(false, true)) {
      result.error("capture_in_progress", "Another custom sound recording is already in progress.", null)
      return
    }

    resumeMonitoringAfterCapture = isRunning.get()
    if (resumeMonitoringAfterCapture) {
      internalStopClassification(shouldSendStatus = false)
    }

    var profiles = loadProfiles()
    val now = isoTimestamp()
    val existingProfile = profiles.firstOrNull { it.id == soundId }
    val profile = existingProfile?.copy(
      name = name.trim(),
      status = "recording",
      updatedAt = now,
      lastError = null,
      targetEmbeddingBank = null,
      backgroundEmbeddingBank = null,
      detectionThreshold = null,
      backgroundMargin = null,
    ) ?: CustomSoundProfileRecord(
      id = soundId,
      name = name.trim(),
      enabled = true,
      status = "recording",
      targetSamplePaths = emptyList(),
      backgroundSamplePaths = emptyList(),
      createdAt = now,
      updatedAt = now,
      lastError = null,
      targetEmbeddingBank = null,
      backgroundEmbeddingBank = null,
      detectionThreshold = null,
      backgroundMargin = null,
    )

    profiles = upsertProfile(profile, profiles)
    saveProfiles(profiles)

    val outputFile = outputFileFor(soundId, sampleKind, sampleIndex)
    Thread {
      try {
        outputFile.parentFile?.mkdirs()
        if (outputFile.exists()) {
          outputFile.delete()
        }
        recordFixedSample(outputFile)

        val refreshedProfiles = loadProfiles()
        val index = refreshedProfiles.indexOfFirst { it.id == soundId }
        if (index == -1) {
          throw IllegalStateException("Custom sound profile disappeared during capture.")
        }

        val updatedProfile = refreshedProfiles[index].copy(
          name = name.trim(),
          status = "draft",
          targetSamplePaths = samplePathsFor(soundId, "target"),
          backgroundSamplePaths = samplePathsFor(soundId, "background"),
          updatedAt = isoTimestamp(),
          lastError = null,
          targetEmbeddingBank = null,
          backgroundEmbeddingBank = null,
          detectionThreshold = null,
          backgroundMargin = null,
        )
        refreshedProfiles[index] = updatedProfile
        saveProfiles(refreshedProfiles)
        activeCustomMatchers = loadActiveCustomMatchers()

        mainHandler.post {
          result.success(updatedProfile.toMap())
          isCapturingSample.set(false)
          resumeMonitoringIfNecessary()
        }
      } catch (error: Exception) {
        val failureProfiles = loadProfiles()
        val failureIndex = failureProfiles.indexOfFirst { it.id == soundId }
        if (failureIndex != -1) {
          val failedProfile = failureProfiles[failureIndex].copy(
            status = "failed",
            updatedAt = isoTimestamp(),
            lastError = error.message ?: "Unable to capture custom sound sample.",
          )
          failureProfiles[failureIndex] = failedProfile
          saveProfiles(failureProfiles)
        }
        mainHandler.post {
          result.error("capture_failed", error.message ?: "Unable to capture custom sound sample.", null)
          isCapturingSample.set(false)
          resumeMonitoringIfNecessary()
        }
      }
    }.start()
  }

  private fun trainOrRebuildCustomModel(result: MethodChannel.Result) {
    if (isCapturingSample.get()) {
      result.error("capture_in_progress", "Wait for the current custom sound recording to finish before training.", null)
      return
    }

    Thread {
      try {
        val profiles = loadProfiles()
        val eligibleIds = profiles.filter {
          it.enabled && it.targetSamplePaths.size >= REQUIRED_TARGET_SAMPLES &&
            it.backgroundSamplePaths.size >= REQUIRED_BACKGROUND_SAMPLES
        }.map { it.id }.toSet()

        val trainingProfiles = profiles.map { profile ->
          when {
            eligibleIds.contains(profile.id) -> profile.copy(
              status = "training",
              updatedAt = isoTimestamp(),
              lastError = null,
            )
            profile.status == "training" -> profile.copy(
              status = "draft",
              updatedAt = isoTimestamp(),
            )
            else -> profile
          }
        }.toMutableList()
        saveProfiles(trainingProfiles)

        if (eligibleIds.isEmpty()) {
          activeCustomMatchers = loadActiveCustomMatchers()
          restartMonitoringIfNeeded()
          mainHandler.post {
            result.success(trainingProfiles.map { it.toMap() })
          }
          return@Thread
        }

        val rebuiltProfiles = trainingProfiles.map { profile ->
          if (!eligibleIds.contains(profile.id)) {
            return@map profile
          }

          try {
            trainProfile(profile)
          } catch (error: Exception) {
            profile.copy(
              status = "failed",
              updatedAt = isoTimestamp(),
              lastError = error.message ?: "Unable to train custom sound.",
              targetEmbeddingBank = null,
              backgroundEmbeddingBank = null,
              detectionThreshold = null,
              backgroundMargin = null,
            )
          }
        }.toMutableList()

        saveProfiles(rebuiltProfiles)
        activeCustomMatchers = loadActiveCustomMatchers()
        restartMonitoringIfNeeded()

        mainHandler.post {
          result.success(rebuiltProfiles.map { it.toMap() })
        }
      } catch (error: Exception) {
        mainHandler.post {
          result.error("training_failed", error.message ?: "Unable to train custom sounds.", null)
        }
      }
    }.start()
  }

  private fun trainProfile(
    profile: CustomSoundProfileRecord,
  ): CustomSoundProfileRecord {
    val targetFeatures = profile.targetSamplePaths.flatMap { path ->
      trainingFeaturesForFile(File(path), preferLoudWindows = true)
    }
    val backgroundFeatures = profile.backgroundSamplePaths.flatMap { path ->
      trainingFeaturesForFile(File(path), preferLoudWindows = false)
    }

    if (targetFeatures.isEmpty()) {
      throw IllegalStateException("No valid target features were generated for ${profile.name}.")
    }
    if (backgroundFeatures.isEmpty()) {
      throw IllegalStateException("No valid background features were generated for ${profile.name}.")
    }

    val calibratedBank = CustomSoundMatching.calibrate(
      targetEmbeddings = targetFeatures,
      backgroundEmbeddings = backgroundFeatures,
    )

    Log.d(
      TAG,
      "Trained custom sound '${profile.name}' " +
        "targetBank=${calibratedBank.targetEmbeddingBank.size} " +
        "backgroundBank=${calibratedBank.backgroundEmbeddingBank.size} " +
        "threshold=${calibratedBank.detectionThreshold} margin=${calibratedBank.backgroundMargin}",
    )

    return profile.copy(
      status = "ready",
      updatedAt = isoTimestamp(),
      lastError = null,
      targetSamplePaths = samplePathsFor(profile.id, "target"),
      backgroundSamplePaths = samplePathsFor(profile.id, "background"),
      targetEmbeddingBank = calibratedBank.targetEmbeddingBank,
      backgroundEmbeddingBank = calibratedBank.backgroundEmbeddingBank,
      detectionThreshold = calibratedBank.detectionThreshold,
      backgroundMargin = calibratedBank.backgroundMargin,
    )
  }

  private fun deleteCustomSound(call: MethodCall, result: MethodChannel.Result) {
    val args = call.arguments as? Map<*, *> ?: run {
      result.error("invalid_args", "Missing delete arguments.", null)
      return
    }
    val soundId = args["soundId"] as? String
    if (soundId.isNullOrBlank()) {
      result.error("invalid_args", "Missing sound id.", null)
      return
    }

    profileDirectory(soundId).deleteRecursively()
    val updatedProfiles = loadProfiles().filter { it.id != soundId }.toMutableList()
    saveProfiles(updatedProfiles)
    activeCustomMatchers = loadActiveCustomMatchers()
    restartMonitoringIfNeeded()
    result.success(null)
  }

  private fun setCustomSoundEnabled(call: MethodCall, result: MethodChannel.Result) {
    val args = call.arguments as? Map<*, *> ?: run {
      result.error("invalid_args", "Missing sound enable arguments.", null)
      return
    }
    val soundId = args["soundId"] as? String
    val enabled = args["enabled"] as? Boolean
    if (soundId.isNullOrBlank() || enabled == null) {
      result.error("invalid_args", "Missing sound enable arguments.", null)
      return
    }

    val profiles = loadProfiles()
    val index = profiles.indexOfFirst { it.id == soundId }
    if (index == -1) {
      result.error("missing_profile", "Custom sound profile not found.", null)
      return
    }

    val updatedProfile = profiles[index].copy(
      enabled = enabled,
      updatedAt = isoTimestamp(),
      lastError = if (enabled) profiles[index].lastError else null,
    )
    profiles[index] = updatedProfile
    saveProfiles(profiles)
    activeCustomMatchers = loadActiveCustomMatchers()
    restartMonitoringIfNeeded()
    result.success(updatedProfile.toMap())
  }

  private fun loadProfiles(): MutableList<CustomSoundProfileRecord> {
    if (!profilesFile.exists()) {
      return mutableListOf()
    }

    return try {
      val parsed = JSONArray(profilesFile.readText())
      MutableList(parsed.length()) { index ->
        syncProfileSamples(CustomSoundProfileRecord.fromJson(parsed.getJSONObject(index)))
      }.sortedByDescending { it.updatedAt }.toMutableList()
    } catch (_: Exception) {
      mutableListOf()
    }
  }

  private fun saveProfiles(profiles: List<CustomSoundProfileRecord>) {
    try {
      customSoundsRootDir.mkdirs()
      val array = JSONArray()
      profiles.sortedByDescending { it.updatedAt }.forEach { profile ->
        array.put(syncProfileSamples(profile).toJson())
      }
      profilesFile.writeText(array.toString())
    } catch (error: Exception) {
      postError("save_profiles_failed", error.message ?: "Unable to save custom sound profiles.")
    }
  }

  private fun syncProfileSamples(profile: CustomSoundProfileRecord): CustomSoundProfileRecord {
    return profile.copy(
      targetSamplePaths = samplePathsFor(profile.id, "target"),
      backgroundSamplePaths = samplePathsFor(profile.id, "background"),
    ).normalizedForRequirements()
  }

  private fun upsertProfile(
    profile: CustomSoundProfileRecord,
    profiles: MutableList<CustomSoundProfileRecord>,
  ): MutableList<CustomSoundProfileRecord> {
    val index = profiles.indexOfFirst { it.id == profile.id }
    if (index == -1) {
      profiles.add(profile)
    } else {
      profiles[index] = profile
    }
    return profiles
  }

  private fun profileDirectory(soundId: String): File {
    return File(customSoundsRootDir, soundId)
  }

  private fun sampleDirectory(soundId: String, sampleKind: String): File {
    return File(profileDirectory(soundId), sampleKind)
  }

  private fun outputFileFor(soundId: String, sampleKind: String, sampleIndex: Int): File {
    val fileName = if (sampleKind == "background") {
      "background_${sampleIndex + 1}.wav"
    } else {
      "target_${sampleIndex + 1}.wav"
    }
    return File(sampleDirectory(soundId, sampleKind), fileName)
  }

  private fun samplePathsFor(soundId: String, sampleKind: String): List<String> {
    val dir = sampleDirectory(soundId, sampleKind)
    if (!dir.exists()) {
      return emptyList()
    }
    return dir.listFiles()
      ?.filter { it.isFile }
      ?.sortedBy { it.name }
      ?.map { it.absolutePath }
      ?: emptyList()
  }

  @Throws(Exception::class)
  private fun recordFixedSample(outputFile: File) {
    val minBufferSize =
      AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
    val sampleBufferSize = max(minBufferSize / 2, 2048)
    val recorder = AudioRecord(
      MediaRecorder.AudioSource.VOICE_RECOGNITION,
      SAMPLE_RATE,
      AudioFormat.CHANNEL_IN_MONO,
      AudioFormat.ENCODING_PCM_16BIT,
      max(minBufferSize, sampleBufferSize * 2),
    )

    if (recorder.state != AudioRecord.STATE_INITIALIZED) {
      recorder.release()
      throw IllegalStateException("Unable to initialize microphone for sample capture.")
    }

    val shortBuffer = ShortArray(sampleBufferSize)
    var recordedSamples = 0

    try {
      BufferedOutputStream(FileOutputStream(outputFile)).use { stream ->
        writeWavHeader(stream, CAPTURE_SAMPLE_COUNT)
        recorder.startRecording()

        while (recordedSamples < CAPTURE_SAMPLE_COUNT) {
          val toRead = min(shortBuffer.size, CAPTURE_SAMPLE_COUNT - recordedSamples)
          val read = recorder.read(shortBuffer, 0, toRead, AudioRecord.READ_BLOCKING)
          if (read <= 0) {
            throw IllegalStateException("Audio recorder read failure: $read")
          }
          writePcm16LittleEndian(stream, shortBuffer, read)
          recordedSamples += read
        }
        stream.flush()
      }
    } finally {
      try {
        recorder.stop()
      } catch (_: IllegalStateException) {
        // Ignore stop failures while unwinding capture errors.
      }
      recorder.release()
    }
  }

  @Throws(Exception::class)
  private fun trainingFeaturesForFile(
    file: File,
    preferLoudWindows: Boolean,
  ): List<FloatArray> {
    val samples = readWavFile(file)
    if (samples.isEmpty()) {
      return emptyList()
    }

    val windows = mutableListOf<FloatArray>()
    if (samples.size <= CLASSIFICATION_SAMPLE_COUNT) {
      val padded = FloatArray(CLASSIFICATION_SAMPLE_COUNT)
      samples.copyInto(padded, endIndex = samples.size)
      windows.add(padded)
    } else {
      var start = 0
      while (start < samples.size) {
        val window = FloatArray(CLASSIFICATION_SAMPLE_COUNT)
        val count = min(CLASSIFICATION_SAMPLE_COUNT, samples.size - start)
        samples.copyInto(window, destinationOffset = 0, startIndex = start, endIndex = start + count)
        windows.add(window)
        if (start + CLASSIFICATION_SAMPLE_COUNT >= samples.size) {
          break
        }
        start += EMBEDDING_STEP_SAMPLE_COUNT
      }
    }

    val candidates = windows.mapNotNull { window ->
      val feature = CustomAudioFeatureExtractor.extract(window) ?: return@mapNotNull null
      TrainingFeatureWindow(
        feature = feature,
        signalLevels = calculateSignalLevels(window),
      )
    }

    if (candidates.isEmpty()) {
      return emptyList()
    }

    val selected =
      if (preferLoudWindows) {
        selectTargetTrainingWindows(candidates)
      } else {
        selectBackgroundTrainingWindows(candidates)
      }

    return selected.map { it.feature }
  }

  private fun selectTargetTrainingWindows(
    windows: List<TrainingFeatureWindow>,
  ): List<TrainingFeatureWindow> {
    val strongestRms = windows.maxOf { it.signalLevels.rms }
    val strongestPeak = windows.maxOf { it.signalLevels.peak }
    val minRms = max(CUSTOM_MIN_SIGNAL_RMS, strongestRms * 0.55f)
    val minPeak = max(CUSTOM_MIN_SIGNAL_PEAK, strongestPeak * 0.6f)

    val ranked = windows
      .filter { candidate ->
        candidate.signalLevels.rms >= minRms || candidate.signalLevels.peak >= minPeak
      }
      .ifEmpty { windows }
      .sortedByDescending { candidate ->
        (candidate.signalLevels.rms * 0.7f) + (candidate.signalLevels.peak * 0.3f)
      }

    return ranked.take(TARGET_WINDOWS_PER_SAMPLE)
  }

  private fun selectBackgroundTrainingWindows(
    windows: List<TrainingFeatureWindow>,
  ): List<TrainingFeatureWindow> {
    return windows
      .sortedByDescending { candidate ->
        (candidate.signalLevels.rms * 0.6f) + (candidate.signalLevels.peak * 0.4f)
      }
      .take(BACKGROUND_WINDOWS_PER_SAMPLE)
  }

  @Throws(Exception::class)
  private fun readWavFile(file: File): FloatArray {
    if (!file.exists()) {
      throw IllegalStateException("Missing sample file: ${file.name}")
    }

    BufferedInputStream(FileInputStream(file)).use { input ->
      val header = ByteArray(44)
      val headerRead = input.read(header)
      if (headerRead < header.size) {
        throw IllegalStateException("Invalid WAV file: ${file.name}")
      }

      val data = input.readBytes()
      val sampleCount = data.size / 2
      val samples = FloatArray(sampleCount)
      val buffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)
      for (i in 0 until sampleCount) {
        samples[i] = buffer.short / 32768f
      }
      return samples
    }
  }

  @Throws(Exception::class)
  private fun createYamnetRunner(): YamnetLiteRtRunner {
    return YamnetLiteRtRunner.create(
      context = context,
      modelAssetPath = MODEL_ASSET_PATH,
    )
  }

  private fun loadActiveCustomMatchers(): List<CustomSoundMatcher> {
    return loadProfiles().mapNotNull { profile ->
      if (!profile.enabled || profile.status != "ready") {
        return@mapNotNull null
      }
      if (!profile.hasEnoughSamples) {
        return@mapNotNull null
      }
      val targetBank = profile.targetEmbeddingBank?.map { it.toFloatArray() }
      val backgroundBank = profile.backgroundEmbeddingBank?.map { it.toFloatArray() }
      val threshold = profile.detectionThreshold
      val margin = profile.backgroundMargin ?: CustomSoundMatching.MIN_BACKGROUND_MARGIN
      if (targetBank.isNullOrEmpty() || backgroundBank.isNullOrEmpty() || threshold == null) {
        return@mapNotNull null
      }

      CustomSoundMatcher(
        profileId = profile.id,
        label = profile.name,
        targetBank = targetBank,
        backgroundBank = backgroundBank,
        detectionThreshold = threshold,
        backgroundMargin = margin,
      )
    }
  }

  private fun restartMonitoringIfNeeded() {
    if (!isRunning.get()) {
      return
    }

    mainHandler.post {
      try {
        internalStopClassification(shouldSendStatus = false)
        startClassification()
      } catch (error: Exception) {
        postError("restart_failed", error.message ?: "Unable to restart sound recognition.")
      }
    }
  }

  private fun resumeMonitoringIfNecessary() {
    if (!resumeMonitoringAfterCapture) {
      return
    }
    resumeMonitoringAfterCapture = false
    try {
      startClassification()
    } catch (error: Exception) {
      postError("resume_failed", error.message ?: "Unable to resume sound recognition.")
    }
  }

  private fun hasMicrophonePermission(): Boolean {
    return ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
  }

  private fun sendStatus(status: String) {
    mainHandler.post {
      eventSink?.success(mapOf("type" to "status", "status" to status))
    }
  }

  private fun postError(code: String, message: String) {
    mainHandler.post {
      eventSink?.error(code, message, null)
    }
  }

  private fun shouldEmit(
    key: String,
    nowMs: Long,
    throttleMs: Long,
    source: String,
  ): Boolean {
    val previousKey =
      when (source) {
        "custom" -> lastCustomThrottleKey
        else -> lastBuiltInThrottleKey
      }

    if (previousKey != null && previousKey != key) {
      lastEmittedAtByKey.remove(previousKey)
    }

    val lastEmittedAtMs = lastEmittedAtByKey[key]
    if (lastEmittedAtMs != null && nowMs - lastEmittedAtMs < throttleMs) {
      return false
    }
    lastEmittedAtByKey[key] = nowMs

    when (source) {
      "custom" -> lastCustomThrottleKey = key
      else -> lastBuiltInThrottleKey = key
    }
    return true
  }

  private fun emitDetectionPayload(payload: Map<String, Any>) {
    mainHandler.post { eventSink?.success(payload) }

    if (isLiveUpdateEnabled && !isLiveUpdateMuted) {
      val label = payload["label"] as? String ?: "Unknown"
      val confidence = ((payload["confidence"] as? Number)?.toDouble() ?: 0.0) * 100
      updateLiveUpdateNotification("Detected: $label (${confidence.toInt()}%)")
    }
  }

  private fun resetBuiltInCandidate() {
    lastBuiltInCandidateLabel = null
    lastBuiltInCandidateCount = 0
  }

  private fun resetCustomCandidate() {
    lastCustomCandidateId = null
    lastCustomCandidateCount = 0
  }

  private fun resetEmissionThrottleState() {
    lastEmittedAtByKey.clear()
    lastBuiltInThrottleKey = null
    lastCustomThrottleKey = null
  }

  private fun calculateSignalLevels(buffer: FloatArray): SignalLevels {
    return calculateSignalLevels(buffer, buffer.size)
  }

  private fun calculateSignalLevels(
    buffer: FloatArray,
    sampleCount: Int,
  ): SignalLevels {
    if (sampleCount <= 0) {
      return SignalLevels(rms = 0f, peak = 0f)
    }

    var sumSquares = 0.0
    var peak = 0f
    for (index in 0 until sampleCount) {
      val magnitude = abs(buffer[index])
      sumSquares += magnitude * magnitude
      if (magnitude > peak) {
        peak = magnitude
      }
    }
    val rms = sqrt(sumSquares / sampleCount).toFloat()
    return SignalLevels(rms = rms, peak = peak)
  }

  private fun writeWavHeader(
    output: BufferedOutputStream,
    totalSamples: Int,
  ) {
    val totalAudioLen = totalSamples * 2
    val totalDataLen = totalAudioLen + 36
    val byteRate = SAMPLE_RATE * CHANNEL_COUNT * 16 / 8

    val header = ByteArray(44)
    ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN).apply {
      put("RIFF".toByteArray())
      putInt(totalDataLen)
      put("WAVE".toByteArray())
      put("fmt ".toByteArray())
      putInt(16)
      putShort(1)
      putShort(CHANNEL_COUNT.toShort())
      putInt(SAMPLE_RATE)
      putInt(byteRate)
      putShort((CHANNEL_COUNT * 16 / 8).toShort())
      putShort(16)
      put("data".toByteArray())
      putInt(totalAudioLen)
    }
    output.write(header)
  }

  private fun writePcm16LittleEndian(
    output: BufferedOutputStream,
    samples: ShortArray,
    count: Int,
  ) {
    val bytes = ByteBuffer.allocate(count * 2).order(ByteOrder.LITTLE_ENDIAN)
    for (i in 0 until count) {
      bytes.putShort(samples[i])
    }
    output.write(bytes.array())
  }

  private fun isoTimestamp(): String = Instant.now().toString()

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        NOTIFICATION_CHANNEL_ID,
        NOTIFICATION_CHANNEL_NAME,
        NotificationManager.IMPORTANCE_LOW
      ).apply {
        description = "Live updates for detected sounds"
        setShowBadge(false)
        enableLights(false)
        enableVibration(false)
        lockscreenVisibility = Notification.VISIBILITY_PUBLIC
      }
      notificationManager?.createNotificationChannel(channel)
    }
  }

  private fun showLiveUpdateNotification() {
    if (currentNotificationContent.isBlank()) {
      currentNotificationContent = "Listening for sounds..."
    }
    val notification = createLiveUpdateNotification()
    notificationManager?.notify(NOTIFICATION_ID, notification)
  }

  private fun updateLiveUpdateNotification(content: String) {
    val now = System.currentTimeMillis()
    if (now - lastNotificationUpdateMs < NOTIFICATION_UPDATE_THROTTLE_MS) {
      return
    }
    lastNotificationUpdateMs = now
    currentNotificationContent = content
    val notification = createLiveUpdateNotification()
    notificationManager?.notify(NOTIFICATION_ID, notification)
  }

  private fun hideLiveUpdateNotification() {
    notificationManager?.cancel(NOTIFICATION_ID)
    currentNotificationContent = ""
  }

  private fun ensureForegroundMonitoringService() {
    val serviceIntent = Intent(context, LiveUpdateForegroundService::class.java).apply {
      action = LiveUpdateForegroundService.ACTION_START
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      context.startForegroundService(serviceIntent)
    } else {
      context.startService(serviceIntent)
    }
  }

  private fun stopForegroundMonitoringService() {
    val stopIntent = Intent(context, LiveUpdateForegroundService::class.java).apply {
      action = LiveUpdateForegroundService.ACTION_STOP
    }
    context.startService(stopIntent)
  }

  private fun acquireWakeLock() {
    if (wakeLock?.isHeld == true) return
    val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
    wakeLock = powerManager.newWakeLock(
      PowerManager.PARTIAL_WAKE_LOCK,
      "$TAG:MonitoringWakeLock",
    ).apply {
      setReferenceCounted(false)
      acquire()
    }
  }

  private fun releaseWakeLock() {
    val heldWakeLock = wakeLock
    wakeLock = null
    if (heldWakeLock?.isHeld == true) {
      heldWakeLock.release()
    }
  }

  private fun createLiveUpdateNotification(): Notification {
    return buildNotification(context, "SenScribe Live Updates", currentNotificationContent)
  }
}

private fun JSONArray?.toStringList(): List<String> {
  if (this == null) return emptyList()
  return List(length()) { index -> optString(index) }.filter { it.isNotBlank() }
}

private fun JSONArray?.toEmbeddingBankOrNull(): List<List<Float>>? {
  if (this == null) return null
  return buildList {
    for (index in 0 until length()) {
      val embedding = optJSONArray(index)?.let { nested ->
        List(nested.length()) { nestedIndex -> nested.optDouble(nestedIndex).toFloat() }
      }
      if (!embedding.isNullOrEmpty()) {
        add(embedding)
      }
    }
  }.takeIf { it.isNotEmpty() }
}

private fun JSONObject.optStringOrNull(key: String): String? {
  return if (isNull(key)) null else optString(key).takeIf { it.isNotBlank() }
}

private fun JSONObject.optDoubleOrNull(key: String): Double? {
  return if (has(key) && !isNull(key)) optDouble(key) else null
}

internal fun CustomSoundProfileRecord.normalizedForRequirements(): CustomSoundProfileRecord {
  if (!hasEnoughSamples) {
    return copy(
      status = if (status == "ready" || status == "training") "draft" else status,
      targetEmbeddingBank = null,
      backgroundEmbeddingBank = null,
      detectionThreshold = null,
      backgroundMargin = null,
    )
  }

  if (status == "ready" &&
    (targetEmbeddingBank.isNullOrEmpty() || backgroundEmbeddingBank.isNullOrEmpty() || detectionThreshold == null)
  ) {
    return copy(
      status = "draft",
      targetEmbeddingBank = null,
      backgroundEmbeddingBank = null,
      detectionThreshold = null,
      backgroundMargin = null,
    )
  }

  return this
}
