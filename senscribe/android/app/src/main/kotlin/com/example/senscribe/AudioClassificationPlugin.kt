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
import android.util.Log
import android.widget.RemoteViews
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.mediapipe.tasks.audio.audioclassifier.AudioClassifier
import com.google.mediapipe.tasks.audio.audioclassifier.AudioClassifier.AudioClassifierOptions
import com.google.mediapipe.tasks.audio.audioclassifier.AudioClassifierResult
import com.google.mediapipe.tasks.audio.audioembedder.AudioEmbedder
import com.google.mediapipe.tasks.audio.audioembedder.AudioEmbedder.AudioEmbedderOptions
import com.google.mediapipe.tasks.audio.audioembedder.AudioEmbedderResult
import com.google.mediapipe.tasks.audio.core.RunningMode
import com.google.mediapipe.tasks.components.containers.AudioData
import com.google.mediapipe.tasks.core.BaseOptions
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

private data class CustomSoundProfileRecord(
  val id: String,
  var name: String,
  var enabled: Boolean,
  var status: String,
  var targetSamplePaths: List<String>,
  var backgroundSamplePaths: List<String>,
  val createdAt: String,
  var updatedAt: String,
  var lastError: String?,
  var prototypeEmbedding: List<Float>?,
  var backgroundEmbedding: List<Float>?,
  var detectionThreshold: Double?,
  var backgroundMargin: Double?,
) {
  val hasEnoughSamples: Boolean
    get() = targetSamplePaths.size >= 5 && backgroundSamplePaths.isNotEmpty()

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
      "prototypeEmbedding" to prototypeEmbedding,
      "backgroundEmbedding" to backgroundEmbedding,
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
      put("prototypeEmbedding", prototypeEmbedding?.let { floatsToJsonArray(it) })
      put("backgroundEmbedding", backgroundEmbedding?.let { floatsToJsonArray(it) })
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
        prototypeEmbedding = json.optJSONArray("prototypeEmbedding").toFloatListOrNull(),
        backgroundEmbedding = json.optJSONArray("backgroundEmbedding").toFloatListOrNull(),
        detectionThreshold = json.optDoubleOrNull("detectionThreshold"),
        backgroundMargin = json.optDoubleOrNull("backgroundMargin"),
      )
    }

    private fun floatsToJsonArray(values: List<Float>): JSONArray {
      val array = JSONArray()
      values.forEach { array.put(it.toDouble()) }
      return array
    }
  }
}

private data class CustomSoundMatcher(
  val profileId: String,
  val label: String,
  val prototype: FloatArray,
  val backgroundPrototype: FloatArray?,
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

class AudioClassificationPlugin private constructor(
  private val context: Context,
  private val activity: Activity,
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
    private const val EMBEDDING_STEP_SAMPLE_COUNT = CLASSIFICATION_SAMPLE_COUNT / 2
    private const val CAPTURE_DURATION_SECONDS = 5
    private const val CAPTURE_SAMPLE_COUNT = SAMPLE_RATE * CAPTURE_DURATION_SECONDS

    private const val REQUIRED_TARGET_SAMPLES = 5
    private const val REQUIRED_BACKGROUND_SAMPLES = 1

    private const val MODEL_ASSET_PATH = "yamnet/yamnet.tflite"

    private const val BUILT_IN_SCORE_THRESHOLD = 0.4f
    private const val BUILT_IN_THROTTLE_MS = 700L

    private const val CUSTOM_MIN_SIGNAL_RMS = 0.008f
    private const val CUSTOM_MIN_SIGNAL_PEAK = 0.024f
    private const val CUSTOM_MIN_DETECTION_THRESHOLD = 0.64
    private const val CUSTOM_MAX_DETECTION_THRESHOLD = 0.94
    private const val CUSTOM_MIN_BACKGROUND_MARGIN = 0.005
    private const val CUSTOM_MIN_WIN_MARGIN = 0.03
    private const val CUSTOM_THROTTLE_MS = 1000L
    private const val CUSTOM_REQUIRED_CONSECUTIVE_MATCHES = 2

    // Notification constants
    const val NOTIFICATION_CHANNEL_ID = "senscribe_live_updates"
    const val NOTIFICATION_CHANNEL_NAME = "Live Audio Updates"
    const val NOTIFICATION_ID = 0xAC02
    private const val NOTIFICATION_UPDATE_THROTTLE_MS = 1000L

    @Volatile
    var isLiveUpdateMuted = false

    fun register(
      messenger: BinaryMessenger,
      context: Context,
      activity: Activity,
    ): AudioClassificationPlugin {
      val plugin = AudioClassificationPlugin(context, activity, messenger)
      plugin.setup()
      return plugin
    }

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

  private var audioClassifier: AudioClassifier? = null
  private var audioEmbedder: AudioEmbedder? = null
  private var audioRecord: AudioRecord? = null
  private var handlerThread: HandlerThread? = null
  private var workHandler: Handler? = null

  private val isRunning = AtomicBoolean(false)
  private val isCapturingSample = AtomicBoolean(false)
  private var resumeMonitoringAfterCapture = false

  private val audioDataFormat = AudioData.AudioDataFormat.builder()
    .setNumOfChannels(CHANNEL_COUNT)
    .setSampleRate(SAMPLE_RATE.toFloat())
    .build()

  private val lastEventTimestampsMs = mutableMapOf<String, Long>()
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
    stopClassification()
  }

  private fun handleStart(result: MethodChannel.Result) {
    if (isRunning.get()) {
      result.success(null)
      return
    }

    runWithMicrophonePermission(result) {
      startClassification()
      result.success(null)
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

    try {
      val serviceIntent = Intent(context, LiveUpdateForegroundService::class.java).apply {
        action = LiveUpdateForegroundService.ACTION_START
      }
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        context.startForegroundService(serviceIntent)
      } else {
        context.startService(serviceIntent)
      }
    } catch (e: Exception) {
      result.error("service_start_failed", "Unable to start live update foreground service: ${e.message}", null)
      return
    }

    isLiveUpdateEnabled = true
    currentNotificationContent = "Listening for sounds..."
    showLiveUpdateNotification()
    result.success(null)
  }

  private fun handleStopLiveUpdates(result: MethodChannel.Result) {
    if (!isLiveUpdateEnabled) {
      result.success(null)
      return
    }

    val stopIntent = Intent(context, LiveUpdateForegroundService::class.java).apply {
      action = LiveUpdateForegroundService.ACTION_STOP
    }
    context.startService(stopIntent)

    isLiveUpdateEnabled = false
    hideLiveUpdateNotification()
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

    val classifierOptions = AudioClassifierOptions.builder()
      .setBaseOptions(BaseOptions.builder().setModelAssetPath(MODEL_ASSET_PATH).build())
      .setRunningMode(RunningMode.AUDIO_CLIPS)
      .setMaxResults(3)
      .build()

    val classifier = AudioClassifier.createFromOptions(context, classifierOptions)
    val embedder = try {
      createLiveAudioEmbedderIfNeeded(activeCustomMatchers.isNotEmpty())
    } catch (_: Exception) {
      activeCustomMatchers = emptyList()
      null
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
      classifier.close()
      embedder?.close()
      recorder.release()
      throw IllegalStateException("Unable to initialize microphone for audio classification.")
    }

    audioClassifier = classifier
    audioEmbedder = embedder
    audioRecord = recorder

    lastEventTimestampsMs.clear()
    lastCustomCandidateId = null
    lastCustomCandidateCount = 0
    isRunning.set(true)

    recorder.startRecording()

    handlerThread = HandlerThread("senscribe-audio-classifier").also { it.start() }
    workHandler = Handler(handlerThread!!.looper).also { handler ->
      handler.post(classificationRunnable)
    }

    sendStatus("started")
  }

  private val classificationRunnable = object : Runnable {
    private val shortBuffer = ShortArray(CLASSIFICATION_SAMPLE_COUNT)
    private val floatBuffer = FloatArray(CLASSIFICATION_SAMPLE_COUNT)

    override fun run() {
      if (!isRunning.get()) return

      val classifier = audioClassifier
      val embedder = audioEmbedder
      val recorder = audioRecord

      if (classifier == null || recorder == null) {
        stopClassification()
        return
      }

      var totalRead = 0
      while (totalRead < CLASSIFICATION_SAMPLE_COUNT && isRunning.get()) {
        val read = recorder.read(
          shortBuffer,
          totalRead,
          CLASSIFICATION_SAMPLE_COUNT - totalRead,
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

      for (i in 0 until CLASSIFICATION_SAMPLE_COUNT) {
        floatBuffer[i] = shortBuffer[i] / 32768f
      }

      val audioData = AudioData.create(audioDataFormat, CLASSIFICATION_SAMPLE_COUNT)
      audioData.load(floatBuffer)

      val classificationResult = try {
        classifier.classify(audioData)
      } catch (error: Exception) {
        postError("analysis_failed", error.message ?: "Audio classification failed.")
        stopClassification()
        return
      }

      processBuiltInResult(classificationResult)

      if (embedder != null && activeCustomMatchers.isNotEmpty()) {
        val embedding = try {
          extractEmbedding(embedder.embed(audioData))
        } catch (error: Exception) {
          postError("custom_analysis_failed", error.message ?: "Custom sound matching failed.")
          stopClassification()
          return
        }

        if (embedding != null) {
          processCustomEmbedding(embedding, calculateSignalLevels(floatBuffer))
        } else {
          resetCustomCandidate()
        }
      }

      if (isRunning.get()) {
        workHandler?.post(this)
      }
    }
  }

  private fun processBuiltInResult(result: AudioClassifierResult) {
    val audioResult = result.classificationResults()
      .firstOrNull()
      ?.classifications()
      ?.firstOrNull()
      ?.categories()
      ?.maxByOrNull { it.score() }
      ?: return

    if (audioResult.score() < BUILT_IN_SCORE_THRESHOLD) {
      return
    }

    val label = audioResult.displayName().takeIf { it.isNotBlank() } ?: audioResult.categoryName()
    val now = System.currentTimeMillis()
    if (!shouldEmit("builtIn:$label", now, BUILT_IN_THROTTLE_MS)) {
      return
    }

    val payload = mapOf(
      "type" to "result",
      "label" to label,
      "confidence" to audioResult.score().toDouble(),
      "source" to "builtIn",
      "timestampMs" to now,
    )

    mainHandler.post { eventSink?.success(payload) }

    // Update live notification if enabled and not muted
    if (isLiveUpdateEnabled && !isLiveUpdateMuted) {
      val confidencePercent = (audioResult.score() * 100).toInt()
      updateLiveUpdateNotification("Detected: $label (${confidencePercent}%)")
    }
  }

  private fun processCustomEmbedding(
    embedding: FloatArray,
    signalLevels: SignalLevels,
  ) {
    if (signalLevels.rms < CUSTOM_MIN_SIGNAL_RMS && signalLevels.peak < CUSTOM_MIN_SIGNAL_PEAK) {
      resetCustomCandidate()
      return
    }

    val candidates = activeCustomMatchers.mapNotNull { matcher ->
      val similarity = cosineSimilarity(embedding, matcher.prototype)
      val backgroundSimilarity = matcher.backgroundPrototype?.let { cosineSimilarity(embedding, it) } ?: -1.0

      if (similarity < matcher.detectionThreshold) {
        return@mapNotNull null
      }
      if (matcher.backgroundPrototype != null &&
        similarity < backgroundSimilarity + matcher.backgroundMargin
      ) {
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
      return
    }

    if (runnerUp != null && best.similarity < runnerUp.similarity + CUSTOM_MIN_WIN_MARGIN) {
      resetCustomCandidate()
      return
    }

    if (lastCustomCandidateId == best.matcher.profileId) {
      lastCustomCandidateCount += 1
    } else {
      lastCustomCandidateId = best.matcher.profileId
      lastCustomCandidateCount = 1
    }

    if (lastCustomCandidateCount < CUSTOM_REQUIRED_CONSECUTIVE_MATCHES) {
      return
    }

    val now = System.currentTimeMillis()
    if (!shouldEmit("custom:${best.matcher.profileId}", now, CUSTOM_THROTTLE_MS)) {
      return
    }

    val payload = mapOf(
      "type" to "result",
      "label" to best.matcher.label,
      "confidence" to best.similarity,
      "source" to "custom",
      "timestampMs" to now,
      "customSoundId" to best.matcher.profileId,
    )

    mainHandler.post { eventSink?.success(payload) }

    // Update live notification if enabled and not muted
    if (isLiveUpdateEnabled && !isLiveUpdateMuted) {
      val confidencePercent = (best.similarity * 100).toInt()
      updateLiveUpdateNotification("Detected: ${best.matcher.label} (${confidencePercent}%)")
    }
  }

  private fun stopClassification() {
    internalStopClassification(shouldSendStatus = true)
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

    audioClassifier?.close()
    audioClassifier = null

    audioEmbedder?.close()
    audioEmbedder = null

    lastEventTimestampsMs.clear()
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
      prototypeEmbedding = null,
      backgroundEmbedding = null,
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
      prototypeEmbedding = null,
      backgroundEmbedding = null,
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
          prototypeEmbedding = null,
          backgroundEmbedding = null,
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

        val embedder = try {
          createTrainingAudioEmbedder()
        } catch (error: Exception) {
          val failedProfiles = trainingProfiles.map { profile ->
            if (!eligibleIds.contains(profile.id)) {
              return@map profile
            }
            profile.copy(
              status = "failed",
              updatedAt = isoTimestamp(),
              lastError = error.message ?: "Unable to load the custom sound embedder.",
            )
          }.toMutableList()
          saveProfiles(failedProfiles)
          mainHandler.post {
            result.success(failedProfiles.map { it.toMap() })
          }
          return@Thread
        }
        try {
          val rebuiltProfiles = trainingProfiles.map { profile ->
            if (!eligibleIds.contains(profile.id)) {
              return@map profile
            }

            try {
              trainProfile(profile, embedder)
            } catch (error: Exception) {
              profile.copy(
                status = "failed",
                updatedAt = isoTimestamp(),
                lastError = error.message ?: "Unable to train custom sound.",
                prototypeEmbedding = null,
                backgroundEmbedding = null,
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
        } finally {
          embedder.close()
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
    embedder: AudioEmbedder,
  ): CustomSoundProfileRecord {
    val targetEmbeddings = profile.targetSamplePaths.flatMap { path ->
      embeddingsForFile(File(path), embedder)
    }
    val backgroundEmbeddings = profile.backgroundSamplePaths.flatMap { path ->
      embeddingsForFile(File(path), embedder)
    }

    if (targetEmbeddings.isEmpty()) {
      throw IllegalStateException("No valid target embeddings were generated for ${profile.name}.")
    }
    if (backgroundEmbeddings.isEmpty()) {
      throw IllegalStateException("No valid background embeddings were generated for ${profile.name}.")
    }

    val prototype = averageNormalizedEmbedding(targetEmbeddings)
    val backgroundPrototype = averageNormalizedEmbedding(backgroundEmbeddings)

    val targetSimilarities = targetEmbeddings.map { cosineSimilarity(it, prototype) }
    val backgroundSimilarities = backgroundEmbeddings.map { cosineSimilarity(it, prototype) }

    val targetMeanSimilarity = targetSimilarities.average()
    val minTargetSimilarity = targetSimilarities.minOrNull()
      ?: throw IllegalStateException("Unable to determine target similarity for ${profile.name}.")
    val maxBackgroundSimilarity = backgroundSimilarities.maxOrNull()
      ?: throw IllegalStateException("Unable to determine background similarity for ${profile.name}.")
    val targetP20Similarity = percentile(targetSimilarities, 0.20)
    val backgroundP85Similarity = percentile(backgroundSimilarities, 0.85)

    var threshold = ((targetMeanSimilarity * 0.6) + (backgroundP85Similarity * 0.4))
      .coerceIn(CUSTOM_MIN_DETECTION_THRESHOLD, CUSTOM_MAX_DETECTION_THRESHOLD)

    val targetBiasedThreshold = minTargetSimilarity - 0.03
    if (threshold > targetBiasedThreshold) {
      threshold = targetBiasedThreshold
    }

    if (threshold < backgroundP85Similarity + CUSTOM_MIN_BACKGROUND_MARGIN) {
      threshold = backgroundP85Similarity + CUSTOM_MIN_BACKGROUND_MARGIN
    }

    if (threshold >= targetMeanSimilarity) {
      threshold = targetMeanSimilarity - 0.01
    }

    threshold = threshold.coerceIn(CUSTOM_MIN_DETECTION_THRESHOLD, CUSTOM_MAX_DETECTION_THRESHOLD)

    val backgroundMargin = (threshold - maxBackgroundSimilarity - 0.0025)
      .coerceIn(CUSTOM_MIN_BACKGROUND_MARGIN, 0.03)

    Log.d(
      TAG,
      "Trained custom sound '${profile.name}' " +
        "targetMean=$targetMeanSimilarity minTarget=$minTargetSimilarity " +
        "targetP20=$targetP20Similarity backgroundMax=$maxBackgroundSimilarity " +
        "backgroundP85=$backgroundP85Similarity threshold=$threshold margin=$backgroundMargin",
    )

    return profile.copy(
      status = "ready",
      updatedAt = isoTimestamp(),
      lastError = null,
      targetSamplePaths = samplePathsFor(profile.id, "target"),
      backgroundSamplePaths = samplePathsFor(profile.id, "background"),
      prototypeEmbedding = prototype.toList(),
      backgroundEmbedding = backgroundPrototype.toList(),
      detectionThreshold = threshold,
      backgroundMargin = backgroundMargin,
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
    )
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
      "background_1.wav"
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
  private fun embeddingsForFile(
    file: File,
    embedder: AudioEmbedder,
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

    return windows.mapNotNull { window ->
      val audioData = AudioData.create(audioDataFormat, CLASSIFICATION_SAMPLE_COUNT)
      audioData.load(window)
      extractEmbedding(embedder.embed(audioData))
    }
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
  private fun createLiveAudioEmbedderIfNeeded(enabled: Boolean): AudioEmbedder? {
    if (!enabled) {
      return null
    }
    return createTrainingAudioEmbedder()
  }

  @Throws(Exception::class)
  private fun createTrainingAudioEmbedder(): AudioEmbedder {
    val options = AudioEmbedderOptions.builder()
      .setBaseOptions(BaseOptions.builder().setModelAssetPath(MODEL_ASSET_PATH).build())
      .setRunningMode(RunningMode.AUDIO_CLIPS)
      .setL2Normalize(true)
      .setQuantize(false)
      .build()

    return AudioEmbedder.createFromOptions(context, options)
  }

  private fun loadActiveCustomMatchers(): List<CustomSoundMatcher> {
    return loadProfiles().mapNotNull { profile ->
      if (!profile.enabled || profile.status != "ready") {
        return@mapNotNull null
      }
      if (!profile.hasEnoughSamples) {
        return@mapNotNull null
      }
      val prototype = profile.prototypeEmbedding?.toFloatArray()
      val background = profile.backgroundEmbedding?.toFloatArray()
      val threshold = profile.detectionThreshold
      val margin = profile.backgroundMargin ?: CUSTOM_MIN_BACKGROUND_MARGIN
      if (prototype == null || threshold == null) {
        return@mapNotNull null
      }

      CustomSoundMatcher(
        profileId = profile.id,
        label = profile.name,
        prototype = prototype,
        backgroundPrototype = background,
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
  ): Boolean {
    val previous = lastEventTimestampsMs[key]
    if (previous != null && nowMs - previous < throttleMs) {
      return false
    }
    lastEventTimestampsMs[key] = nowMs
    return true
  }

  private fun resetCustomCandidate() {
    lastCustomCandidateId = null
    lastCustomCandidateCount = 0
  }

  private fun extractEmbedding(result: AudioEmbedderResult): FloatArray? {
    return result.embeddingResults()
      .firstOrNull()
      ?.embeddings()
      ?.firstOrNull()
      ?.floatEmbedding()
      ?.copyOf()
  }

  private fun calculateSignalLevels(buffer: FloatArray): SignalLevels {
    var sumSquares = 0.0
    var peak = 0f
    buffer.forEach { sample ->
      val magnitude = abs(sample)
      sumSquares += magnitude * magnitude
      if (magnitude > peak) {
        peak = magnitude
      }
    }
    val rms = sqrt(sumSquares / buffer.size).toFloat()
    return SignalLevels(rms = rms, peak = peak)
  }

  private fun averageNormalizedEmbedding(embeddings: List<FloatArray>): FloatArray {
    val length = embeddings.firstOrNull()?.size
      ?: throw IllegalStateException("No embeddings were available to average.")
    val aggregate = FloatArray(length)
    embeddings.forEach { embedding ->
      require(embedding.size == length) { "Embedding dimensions do not match." }
      for (i in embedding.indices) {
        aggregate[i] += embedding[i]
      }
    }

    for (i in aggregate.indices) {
      aggregate[i] /= embeddings.size.toFloat()
    }
    normalizeInPlace(aggregate)
    return aggregate
  }

  private fun cosineSimilarity(
    left: FloatArray,
    right: FloatArray,
  ): Double {
    if (left.size != right.size) {
      throw IllegalArgumentException("Embedding sizes do not match.")
    }
    var dot = 0.0
    var leftNorm = 0.0
    var rightNorm = 0.0
    for (i in left.indices) {
      val l = left[i].toDouble()
      val r = right[i].toDouble()
      dot += l * r
      leftNorm += l * l
      rightNorm += r * r
    }
    if (leftNorm == 0.0 || rightNorm == 0.0) {
      return -1.0
    }
    return dot / (sqrt(leftNorm) * sqrt(rightNorm))
  }

  private fun normalizeInPlace(values: FloatArray) {
    var sumSquares = 0.0
    values.forEach { value ->
      sumSquares += value * value
    }
    if (sumSquares <= 0.0) {
      return
    }
    val magnitude = sqrt(sumSquares).toFloat()
    for (i in values.indices) {
      values[i] /= magnitude
    }
  }

  private fun percentile(
    values: List<Double>,
    ratio: Double,
  ): Double {
    if (values.isEmpty()) {
      throw IllegalArgumentException("Cannot compute a percentile for an empty list.")
    }
    val sorted = values.sorted()
    val index = ((sorted.lastIndex) * ratio).toInt().coerceIn(0, sorted.lastIndex)
    return sorted[index]
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

  private fun createLiveUpdateNotification(): Notification {
    return buildNotification(context, "SenScribe Live Updates", currentNotificationContent)
  }
}

private fun JSONArray?.toStringList(): List<String> {
  if (this == null) return emptyList()
  return List(length()) { index -> optString(index) }.filter { it.isNotBlank() }
}

private fun JSONArray?.toFloatListOrNull(): List<Float>? {
  if (this == null) return null
  return List(length()) { index -> optDouble(index).toFloat() }
}

private fun JSONObject.optStringOrNull(key: String): String? {
  return if (isNull(key)) null else optString(key).takeIf { it.isNotBlank() }
}

private fun JSONObject.optDoubleOrNull(key: String): Double? {
  return if (has(key) && !isNull(key)) optDouble(key) else null
}
