package com.example.senscribe

import android.content.Context
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import android.util.Log
import kotlin.math.max

internal object SharedAudioInputManager {
  private const val TAG = "SharedAudioInput"
  private const val SAMPLE_RATE = 16000
  private const val FRAME_SAMPLE_COUNT = 4800

  internal interface Listener {
    fun onAudioFrame(buffer: ShortArray, count: Int)

    fun onAudioError(code: String, message: String)
  }

  private val listeners = linkedMapOf<String, Listener>()
  private val listenerLock = Any()
  private var audioRecord: AudioRecord? = null
  private var captureThread: Thread? = null
  private var shouldConfigureAudioEffects = true
  private var activeAudioSource = MediaRecorder.AudioSource.MIC
  @Volatile
  private var isRunning = false

  fun addListener(
    context: Context,
    listenerId: String,
    listener: Listener,
  ) {
    synchronized(listenerLock) {
      listeners[listenerId] = listener
      if (isRunning) {
        return
      }
    }

    try {
      startCapture(context.applicationContext)
    } catch (error: Exception) {
      synchronized(listenerLock) {
        listeners.remove(listenerId)
      }
      throw error
    }
  }

  fun removeListener(listenerId: String) {
    val shouldStop =
      synchronized(listenerLock) {
        listeners.remove(listenerId)
        listeners.isEmpty()
      }

    if (shouldStop) {
      stopCapture()
    }
  }

  private fun startCapture(context: Context) {
    synchronized(listenerLock) {
      if (isRunning) {
        return
      }

      val minBufferSize =
        AudioRecord.getMinBufferSize(
          SAMPLE_RATE,
          AudioFormat.CHANNEL_IN_MONO,
          AudioFormat.ENCODING_PCM_16BIT,
        )
      val bufferSizeInBytes = max(minBufferSize, FRAME_SAMPLE_COUNT * 4)
      val (recorder, audioSource) = createAudioRecord(context, bufferSizeInBytes)
      if (recorder.state != AudioRecord.STATE_INITIALIZED) {
        recorder.release()
        throw IllegalStateException("Unable to initialize shared microphone input.")
      }

      audioRecord = recorder
      activeAudioSource = audioSource
      isRunning = true
      recorder.startRecording()
      configureAudioEffects(recorder.audioSessionId)
      logAudioConfiguration(context, audioSource)
      logCaptureState(recorder)

      val drainBuffer = ShortArray(FRAME_SAMPLE_COUNT)
      recorder.read(drainBuffer, 0, drainBuffer.size, AudioRecord.READ_NON_BLOCKING)

      captureThread =
        Thread({
          android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_URGENT_AUDIO)
          captureLoop()
        }, "senscribe-shared-audio-capture").also { it.start() }
    }
  }

  private fun stopCapture() {
    val recorderToStop: AudioRecord?
    val threadToJoin: Thread?
    synchronized(listenerLock) {
      if (!isRunning) {
        return
      }
      isRunning = false
      recorderToStop = audioRecord
      audioRecord = null
      threadToJoin = captureThread
      captureThread = null
    }

    recorderToStop?.let { recorder ->
      try {
        recorder.stop()
      } catch (_: IllegalStateException) {
        // Ignore stop failures when the recorder is already stopping.
      }
      recorder.release()
    }

    if (threadToJoin != null && threadToJoin !== Thread.currentThread()) {
      try {
        threadToJoin.join(500)
      } catch (_: InterruptedException) {
        Thread.currentThread().interrupt()
      }
    }
  }

  private fun captureLoop() {
    val readBuffer = ShortArray(FRAME_SAMPLE_COUNT)
    while (isRunning) {
      val recorder = synchronized(listenerLock) { audioRecord } ?: break

      var totalRead = 0
      while (totalRead < FRAME_SAMPLE_COUNT && isRunning) {
        val read =
          recorder.read(
            readBuffer,
            totalRead,
            FRAME_SAMPLE_COUNT - totalRead,
            AudioRecord.READ_BLOCKING,
          )
        if (read < 0) {
          handleCaptureFailure("Shared audio recorder read failure: $read")
          return
        }
        totalRead += read
      }

      if (!isRunning || totalRead <= 0) {
        break
      }

      val snapshot =
        synchronized(listenerLock) {
          listeners.values.toList()
        }
      snapshot.forEach { listener ->
        runCatching {
          listener.onAudioFrame(readBuffer, totalRead)
        }.onFailure { error ->
          Log.w(TAG, "Shared audio listener failure.", error)
        }
      }
    }
  }

  private fun handleCaptureFailure(message: String) {
    val snapshot =
      synchronized(listenerLock) {
        listeners.values.toList()
      }
    snapshot.forEach { listener ->
      runCatching {
        listener.onAudioError("shared_audio_failed", message)
      }
    }
    stopCapture()
  }

  private fun createAudioRecord(
    context: Context,
    bufferSizeInBytes: Int,
  ): Pair<AudioRecord, Int> {
    val preferredSource = MediaRecorder.AudioSource.MIC
    val preferredRecorder = buildAudioRecord(preferredSource, bufferSizeInBytes)
    if (preferredRecorder.state == AudioRecord.STATE_INITIALIZED) {
      return preferredRecorder to preferredSource
    }

    preferredRecorder.release()
    val fallbackSource =
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        MediaRecorder.AudioSource.UNPROCESSED
      } else {
        MediaRecorder.AudioSource.MIC
      }
    val fallbackRecorder = buildAudioRecord(fallbackSource, bufferSizeInBytes)
    if (fallbackRecorder.state != AudioRecord.STATE_INITIALIZED) {
      fallbackRecorder.release()
      throw IllegalStateException("Unable to initialize shared microphone input.")
    }
    Log.d(
      TAG,
      "Shared audio fell back from ${audioSourceName(preferredSource)} to ${audioSourceName(fallbackSource)}",
    )
    return fallbackRecorder to fallbackSource
  }

  private fun buildAudioRecord(
    audioSource: Int,
    bufferSizeInBytes: Int,
  ): AudioRecord {
    val format =
      AudioFormat.Builder()
        .setSampleRate(SAMPLE_RATE)
        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
        .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
        .build()
    return AudioRecord.Builder()
      .setAudioSource(audioSource)
      .setAudioFormat(format)
      .setBufferSizeInBytes(bufferSizeInBytes)
      .apply {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
          setPrivacySensitive(false)
        }
      }
      .build()
  }

  private fun logAudioConfiguration(
    context: Context,
    audioSource: Int,
  ) {
    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
    val unprocessedSupport =
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        audioManager?.getProperty(AudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED)
      } else {
        null
      }
    Log.d(
      TAG,
      "Shared audio source=${audioSourceName(audioSource)} ($audioSource) " +
        "unprocessedSupport=${unprocessedSupport ?: "unknown"}",
    )
  }

  private fun logCaptureState(recorder: AudioRecord) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
      return
    }
    val config = runCatching { recorder.activeRecordingConfiguration }.getOrNull()
    Log.d(
      TAG,
      "Shared capture state silenced=${config?.isClientSilenced ?: "unknown"} " +
        "session=${recorder.audioSessionId} source=${audioSourceName(activeAudioSource)}",
    )
  }

  private fun configureAudioEffects(audioSessionId: Int) {
    if (audioSessionId <= 0 || !shouldConfigureAudioEffects) {
      return
    }
    runCatching {
      val agcState =
        if (AutomaticGainControl.isAvailable()) {
          AutomaticGainControl.create(audioSessionId)?.let { effect ->
            effect.enabled = false
            effect.enabled
          } ?: run {
            shouldConfigureAudioEffects = false
            false
          }
        } else {
          null
        }
      val noiseSuppressorState =
        if (NoiseSuppressor.isAvailable()) {
          NoiseSuppressor.create(audioSessionId)?.let { effect ->
            effect.enabled = false
            effect.enabled
          } ?: run {
            shouldConfigureAudioEffects = false
            false
          }
        } else {
          null
        }
      val echoCancelerState =
        if (AcousticEchoCanceler.isAvailable()) {
          AcousticEchoCanceler.create(audioSessionId)?.let { effect ->
            effect.enabled = false
            effect.enabled
          } ?: run {
            shouldConfigureAudioEffects = false
            false
          }
        } else {
          null
        }
      Log.d(
        TAG,
        "Shared audio effects session=$audioSessionId " +
          "agc=${audioEffectStateLabel(agcState)} " +
          "ns=${audioEffectStateLabel(noiseSuppressorState)} " +
          "aec=${audioEffectStateLabel(echoCancelerState)}",
      )
    }.onFailure { error ->
      shouldConfigureAudioEffects = false
      Log.w(TAG, "Unable to configure shared audio effects.", error)
    }
  }

  private fun audioSourceName(audioSource: Int): String {
    return when (audioSource) {
      MediaRecorder.AudioSource.DEFAULT -> "DEFAULT"
      MediaRecorder.AudioSource.MIC -> "MIC"
      MediaRecorder.AudioSource.CAMCORDER -> "CAMCORDER"
      MediaRecorder.AudioSource.VOICE_RECOGNITION -> "VOICE_RECOGNITION"
      MediaRecorder.AudioSource.UNPROCESSED -> "UNPROCESSED"
      else -> "UNKNOWN"
    }
  }

  private fun audioEffectStateLabel(enabled: Boolean?): String {
    return when (enabled) {
      null -> "unavailable"
      true -> "enabled"
      false -> "disabled"
    }
  }
}
