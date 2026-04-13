package com.example.senscribe

import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.vosk.LogLevel
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.StorageService
import kotlin.math.min

internal class AndroidOfflineSpeechPlugin private constructor(
  private val context: Context,
  messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
  companion object {
    private const val METHOD_CHANNEL = "senscribe/android_speech"
    private const val EVENT_CHANNEL = "senscribe/android_speech_events"
    private const val TAG = "AndroidOfflineSpeech"
    private const val MODEL_ASSET_PATH = "vosk/vosk-model-small-en-us-0.15"
    private const val MODEL_CACHE_DIR = "vosk_models"
    private const val SAMPLE_RATE = 16000f
    private const val AUDIO_LISTENER_ID = "senscribe.android_offline_speech"
    private const val STAGING_BUFFER_SAMPLE_COUNT = 32000

    fun register(
      messenger: BinaryMessenger,
      context: Context,
    ): AndroidOfflineSpeechPlugin {
      return AndroidOfflineSpeechPlugin(context.applicationContext, messenger).also { it.setup() }
    }
  }

  private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
  private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
  private val mainHandler = Handler(Looper.getMainLooper())
  private val initLock = Any()
  private val stagingLock = Any()
  private val processingBuffer = ShortArray(SharedAudioInputFrameSize)
  private val stagingBuffer = ShortArray(STAGING_BUFFER_SAMPLE_COUNT)

  private var eventSink: EventChannel.EventSink? = null
  private var model: Model? = null
  private var initInFlight = false
  private val pendingInitializeResults = mutableListOf<MethodChannel.Result>()
  private var recognizer: Recognizer? = null
  private var recognitionThread: HandlerThread? = null
  private var recognitionHandler: Handler? = null
  private var speechProcessingScheduled = false
  private var stagingWriteOffset = 0
  private var stagingReadOffset = 0
  @Volatile
  private var isListening = false
  private var lastPartialText = ""

  private val audioListener =
    object : SharedAudioInputManager.Listener {
      override fun onAudioFrame(buffer: ShortArray, count: Int) {
        synchronized(stagingLock) {
          for (index in 0 until count) {
            val writeIndex = stagingWriteOffset % stagingBuffer.size
            stagingBuffer[writeIndex] = buffer[index]
            stagingWriteOffset++
          }
          val overflow = (stagingWriteOffset - stagingReadOffset) - stagingBuffer.size
          if (overflow > 0) {
            stagingReadOffset += overflow
          }
          if (speechProcessingScheduled) {
            return
          }
          speechProcessingScheduled = true
        }
        recognitionHandler?.post(processSpeechRunnable)
      }

      override fun onAudioError(code: String, message: String) {
        emitEvent(
          mapOf(
            "type" to "error",
            "code" to code,
            "message" to message,
          ),
        )
        stopListening(flushFinalResult = false, emitStatus = true)
      }
    }

  private val processSpeechRunnable =
    object : Runnable {
      override fun run() {
        while (true) {
          val sampleCount =
            synchronized(stagingLock) {
              val available = stagingWriteOffset - stagingReadOffset
              if (available <= 0) {
                speechProcessingScheduled = false
                return
              }
              val toConsume = min(available, processingBuffer.size)
              for (index in 0 until toConsume) {
                processingBuffer[index] = stagingBuffer[stagingReadOffset % stagingBuffer.size]
                stagingReadOffset++
              }
              if (stagingReadOffset >= stagingBuffer.size) {
                val shift = (stagingReadOffset / stagingBuffer.size) * stagingBuffer.size
                stagingWriteOffset -= shift
                stagingReadOffset -= shift
              }
              toConsume
            }

          val activeRecognizer = recognizer ?: return
          val isSegmentFinal = activeRecognizer.acceptWaveForm(processingBuffer, sampleCount)
          if (isSegmentFinal) {
            emitFinalFromJson(activeRecognizer.getResult())
          } else {
            emitPartialFromJson(activeRecognizer.getPartialResult())
          }
        }
      }
    }

  private fun setup() {
    methodChannel.setMethodCallHandler(this)
    eventChannel.setStreamHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "initialize" -> handleInitialize(result)
      "start" -> handleStart(result)
      "stop" -> handleStop(result)
      "cancel" -> handleCancel(result)
      "isListening" -> result.success(isListening)
      else -> result.notImplemented()
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
    eventSink = events
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }

  private fun handleInitialize(result: MethodChannel.Result) {
    synchronized(initLock) {
      if (model != null) {
        result.success(true)
        return
      }
      pendingInitializeResults.add(result)
      if (initInFlight) {
        return
      }
      initInFlight = true
    }

    Thread {
      try {
        org.vosk.LibVosk.setLogLevel(LogLevel.WARNINGS)
        val modelPath = StorageService.sync(context, MODEL_ASSET_PATH, MODEL_CACHE_DIR)
        val loadedModel = Model(modelPath)
        synchronized(initLock) {
          model = loadedModel
          initInFlight = false
        }
        mainHandler.post {
          finishInitialize(success = true)
          emitEvent(mapOf("type" to "status", "status" to "ready"))
        }
      } catch (error: Exception) {
        Log.e(TAG, "Failed to initialize offline speech model.", error)
        synchronized(initLock) {
          initInFlight = false
        }
        mainHandler.post {
          finishInitialize(
            success = false,
            errorCode = "model_init_failed",
            errorMessage = error.message ?: "Unable to initialize offline speech model.",
          )
        }
      }
    }.start()
  }

  private fun finishInitialize(
    success: Boolean,
    errorCode: String? = null,
    errorMessage: String? = null,
  ) {
    val pendingResults =
      synchronized(initLock) {
        pendingInitializeResults.toList().also { pendingInitializeResults.clear() }
      }
    pendingResults.forEach { pendingResult ->
      if (success) {
        pendingResult.success(true)
      } else {
        pendingResult.error(
          errorCode ?: "model_init_failed",
          errorMessage ?: "Unable to initialize offline speech model.",
          null,
        )
      }
    }
  }

  private fun handleStart(result: MethodChannel.Result) {
    val loadedModel = model
    if (loadedModel == null) {
      result.error("model_not_ready", "Offline speech model is not ready yet.", null)
      return
    }
    if (isListening) {
      result.success(null)
      return
    }

    try {
      ensureRecognitionThread()
      synchronized(stagingLock) {
        stagingWriteOffset = 0
        stagingReadOffset = 0
        speechProcessingScheduled = false
      }
      lastPartialText = ""
      recognizer =
        Recognizer(loadedModel, SAMPLE_RATE).apply {
          setPartialWords(false)
          setWords(false)
        }
      SharedAudioInputManager.addListener(context, AUDIO_LISTENER_ID, audioListener)
      isListening = true
      emitEvent(mapOf("type" to "status", "status" to "listening"))
      result.success(null)
    } catch (error: Exception) {
      recognizer?.close()
      recognizer = null
      result.error("start_failed", error.message ?: "Unable to start offline speech recognition.", null)
    }
  }

  private fun handleStop(result: MethodChannel.Result) {
    stopListening(flushFinalResult = true, emitStatus = true)
    result.success(null)
  }

  private fun handleCancel(result: MethodChannel.Result) {
    stopListening(flushFinalResult = false, emitStatus = true)
    result.success(null)
  }

  private fun stopListening(
    flushFinalResult: Boolean,
    emitStatus: Boolean,
  ) {
    if (!isListening && recognizer == null) {
      if (emitStatus) {
        emitEvent(mapOf("type" to "status", "status" to "stopped"))
      }
      return
    }

    SharedAudioInputManager.removeListener(AUDIO_LISTENER_ID)
    isListening = false

    synchronized(stagingLock) {
      stagingWriteOffset = 0
      stagingReadOffset = 0
      speechProcessingScheduled = false
    }

    recognitionHandler?.removeCallbacksAndMessages(null)
    val activeRecognizer = recognizer
    recognizer = null
    if (flushFinalResult && activeRecognizer != null) {
      emitFinalFromJson(activeRecognizer.getFinalResult())
    }
    activeRecognizer?.close()
    lastPartialText = ""

    if (emitStatus) {
      emitEvent(mapOf("type" to "status", "status" to "stopped"))
    }
  }

  fun dispose() {
    stopListening(flushFinalResult = false, emitStatus = false)
    recognitionHandler?.removeCallbacksAndMessages(null)
    recognitionHandler = null
    recognitionThread?.quitSafely()
    recognitionThread = null
    model?.close()
    model = null
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
  }

  private fun ensureRecognitionThread() {
    if (recognitionThread?.isAlive == true && recognitionHandler != null) {
      return
    }
    recognitionThread = HandlerThread("senscribe-offline-speech").also { it.start() }
    recognitionHandler = Handler(recognitionThread!!.looper)
  }

  private fun emitPartialFromJson(json: String) {
    val partialText = parseHypothesis(json, "partial")
    if (partialText.isEmpty() || partialText == lastPartialText) {
      return
    }
    lastPartialText = partialText
    emitEvent(
      mapOf(
        "type" to "partial",
        "text" to partialText,
      ),
    )
  }

  private fun emitFinalFromJson(json: String) {
    val finalText = parseHypothesis(json, "text")
    lastPartialText = ""
    if (finalText.isEmpty()) {
      return
    }
    emitEvent(
      mapOf(
        "type" to "final",
        "text" to finalText,
      ),
    )
  }

  private fun parseHypothesis(
    json: String,
    field: String,
  ): String {
    return runCatching {
      JSONObject(json).optString(field).trim()
    }.getOrDefault("")
  }

  private fun emitEvent(payload: Map<String, Any>) {
    mainHandler.post {
      eventSink?.success(payload)
    }
  }
}

private const val SharedAudioInputFrameSize = 4800
