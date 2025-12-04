package com.example.senscribe

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.mediapipe.tasks.audio.audioclassifier.AudioClassifier
import com.google.mediapipe.tasks.audio.audioclassifier.AudioClassifier.AudioClassifierOptions
import com.google.mediapipe.tasks.audio.audioclassifier.AudioClassifierResult
import com.google.mediapipe.tasks.audio.core.RunningMode
import com.google.mediapipe.tasks.components.containers.AudioData
import com.google.mediapipe.tasks.core.BaseOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max

class AudioClassificationPlugin private constructor(
  private val context: Context,
  private val activity: Activity,
  messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

  companion object {
    private const val METHOD_CHANNEL = "senscribe/audio_classifier"
    private const val EVENT_CHANNEL = "senscribe/audio_classifier_events"
    private const val PERMISSION_REQUEST_CODE = 0xAC01

    private const val SAMPLE_RATE = 16000
    private const val CHANNEL_COUNT = 1
    private const val CLASSIFICATION_SAMPLE_COUNT = 15600 // Matches YAMNet receptive field (~0.975s).
    // MediaPipe requires asset path to have a directory component
    private const val MODEL_ASSET_PATH = "yamnet/yamnet.tflite"

    fun register(
      messenger: BinaryMessenger,
      context: Context,
      activity: Activity,
    ): AudioClassificationPlugin {
      val plugin = AudioClassificationPlugin(context, activity, messenger)
      plugin.setup()
      return plugin
    }
  }

  private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
  private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
  private val mainHandler = Handler(Looper.getMainLooper())

  private var eventSink: EventChannel.EventSink? = null
  private var pendingStartResult: MethodChannel.Result? = null

  private var audioClassifier: AudioClassifier? = null
  private var audioRecord: AudioRecord? = null
  private var handlerThread: HandlerThread? = null
  private var workHandler: Handler? = null

  private val isRunning = AtomicBoolean(false)
  private val scoreThreshold = 0.4f
  private val audioDataFormat = AudioData.AudioDataFormat.builder()
    .setNumOfChannels(CHANNEL_COUNT)
    .setSampleRate(SAMPLE_RATE.toFloat())
    .build()

  private var lastEmittedLabel: String? = null
  private var lastEmissionTimestampMs: Long = 0
  private val emissionThrottleMs = 700L

  private fun setup() {
    methodChannel.setMethodCallHandler(this)
    eventChannel.setStreamHandler(this)
  }

  fun dispose() {
    stopClassification()
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
  }

  fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
    if (requestCode != PERMISSION_REQUEST_CODE) return

    val result = pendingStartResult
    pendingStartResult = null

    if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
      try {
        startClassification()
        result?.success(null)
      } catch (error: Exception) {
        result?.error("start_failed", error.message ?: "Unable to start audio classification.", null)
      }
    } else {
      result?.error(
        "microphone_permission_denied",
        "Microphone permission is required to classify audio.",
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

    if (!hasMicrophonePermission()) {
      pendingStartResult = result
      ActivityCompat.requestPermissions(
        activity,
        arrayOf(Manifest.permission.RECORD_AUDIO),
        PERMISSION_REQUEST_CODE,
      )
      return
    }

    try {
      startClassification()
      result.success(null)
    } catch (error: Exception) {
      result.error("start_failed", error.message ?: "Unable to start audio classification.", null)
    }
  }

  @Throws(Exception::class)
  private fun startClassification() {
    if (isRunning.get()) return

    val options = AudioClassifierOptions.builder()
      .setBaseOptions(BaseOptions.builder().setModelAssetPath(MODEL_ASSET_PATH).build())
      .setRunningMode(RunningMode.AUDIO_CLIPS)
      .setMaxResults(3)
      .build()

    val classifier = AudioClassifier.createFromOptions(context, options)
    audioClassifier = classifier

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
      recorder.release()
      throw IllegalStateException("Unable to initialize microphone for audio classification.")
    }

    audioRecord = recorder
    recorder.startRecording()

    handlerThread = HandlerThread("senscribe-audio-classifier").also { it.start() }
    workHandler = Handler(handlerThread!!.looper).also { handler ->
      handler.post(classificationRunnable)
    }

    lastEmittedLabel = null
    lastEmissionTimestampMs = 0
    isRunning.set(true)
    sendStatus("started")
  }

  private val classificationRunnable = object : Runnable {
    private val shortBuffer = ShortArray(CLASSIFICATION_SAMPLE_COUNT)
    private val floatBuffer = FloatArray(CLASSIFICATION_SAMPLE_COUNT)

    override fun run() {
      if (!isRunning.get()) return

      val classifier = audioClassifier
      val recorder = audioRecord

      if (classifier == null || recorder == null) {
        stopClassification()
        return
      }

      var totalRead = 0
      while (totalRead < CLASSIFICATION_SAMPLE_COUNT && isRunning.get()) {
        val read = recorder.read(shortBuffer, totalRead, CLASSIFICATION_SAMPLE_COUNT - totalRead, AudioRecord.READ_BLOCKING)
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

      processResult(classificationResult)

      if (isRunning.get()) {
        workHandler?.post(this)
      }
    }
  }

  private fun processResult(result: AudioClassifierResult) {
    val audioResult = result.classificationResults()
      .firstOrNull()
      ?.classifications()
      ?.firstOrNull()
      ?.categories()
      ?.maxByOrNull { it.score() }
      ?: return

    if (audioResult.score() < scoreThreshold) {
      return
    }

    val label = audioResult.displayName().takeIf { it.isNotBlank() } ?: audioResult.categoryName()

    val now = System.currentTimeMillis()
    if (label == lastEmittedLabel && now - lastEmissionTimestampMs < emissionThrottleMs) {
      return
    }
    lastEmittedLabel = label
    lastEmissionTimestampMs = now

    val payload = mapOf(
      "type" to "result",
      "label" to label,
      "confidence" to audioResult.score().toDouble(),
      "timestampMs" to now,
    )

    mainHandler.post { eventSink?.success(payload) }
  }

  private fun stopClassification() {
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
        // Ignore stop failure if recorder already stopped.
      }
      recorder.release()
    }
    audioRecord = null

    audioClassifier?.close()
    audioClassifier = null

    sendStatus("stopped")
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
}