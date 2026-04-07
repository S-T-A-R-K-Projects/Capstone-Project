package com.example.senscribe

import ai.liquid.leap.manifest.LeapDownloader
import ai.liquid.leap.manifest.LeapDownloaderConfig
import android.content.Context
import java.io.File
import java.util.concurrent.CopyOnWriteArraySet
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

data class ManagedModelDownloadSnapshot(
  val modelId: String = "",
  val isRunning: Boolean = false,
  val progress: Double = 0.0,
  val statusMessage: String = "",
  val platformCanContinueInBackground: Boolean = true,
  val lastError: String? = null,
  val updatedAtMs: Long = System.currentTimeMillis(),
) {
  fun toMap(): Map<String, Any?> {
    return mapOf(
      "modelId" to modelId,
      "isRunning" to isRunning,
      "progress" to progress,
      "statusMessage" to statusMessage,
      "platformCanContinueInBackground" to platformCanContinueInBackground,
      "lastError" to lastError,
      "updatedAtMs" to updatedAtMs,
    )
  }
}

object ManagedModelDownloadManager {
  interface Listener {
    fun onSnapshotChanged(snapshot: ManagedModelDownloadSnapshot)
  }

  private val listeners = CopyOnWriteArraySet<Listener>()
  private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

  @Volatile
  private var appContext: Context? = null
  @Volatile
  private var downloader: LeapDownloader? = null
  @Volatile
  private var activeJob: Job? = null
  @Volatile
  private var currentSnapshot = ManagedModelDownloadSnapshot()
  @Volatile
  private var lastDispatchAtMs: Long = 0L
  @Volatile
  private var lastDispatchedProgress: Double = 0.0

  fun initialize(context: Context) {
    if (appContext != null && downloader != null) return
    val applicationContext = context.applicationContext
    appContext = applicationContext
    downloader = LeapDownloader(
      LeapDownloaderConfig(saveDir = File(applicationContext.filesDir, "leap_models").absolutePath),
    )
  }

  fun addListener(listener: Listener) {
    listeners.add(listener)
  }

  fun removeListener(listener: Listener) {
    listeners.remove(listener)
  }

  fun currentSnapshotMap(): Map<String, Any?> = currentSnapshot.toMap()

  fun startDownload(
    context: Context,
    modelId: String,
    modelSlug: String,
    quantizationSlug: String,
  ) {
    initialize(context)
    if (activeJob?.isActive == true) {
      notifyListeners()
      return
    }

    updateSnapshot(
      currentSnapshot.copy(
        modelId = modelId,
        isRunning = true,
        progress = 0.0,
        statusMessage = "Starting download...",
        lastError = null,
        updatedAtMs = System.currentTimeMillis(),
      ),
    )

    activeJob = scope.launch {
      try {
        cleanupPartialDownload(modelSlug, quantizationSlug)
        downloader?.downloadModel(modelSlug, quantizationSlug) { progressData ->
          updateSnapshot(
            currentSnapshot.copy(
              modelId = modelId,
              isRunning = true,
              progress = progressData.progress.toDouble().coerceIn(0.0, 1.0),
              statusMessage = "Downloading... ${(progressData.progress * 100).toInt()}%",
              lastError = null,
              updatedAtMs = System.currentTimeMillis(),
            ),
          )
        }

        updateSnapshot(
          currentSnapshot.copy(
            modelId = modelId,
            isRunning = false,
            progress = 1.0,
            statusMessage = "Download complete.",
            lastError = null,
            updatedAtMs = System.currentTimeMillis(),
          ),
        )
      } catch (_: CancellationException) {
        clearDownloadArtifacts(modelSlug, quantizationSlug)
        updateSnapshot(
          ManagedModelDownloadSnapshot(
            modelId = modelId,
            updatedAtMs = System.currentTimeMillis(),
          ),
        )
      } catch (error: Exception) {
        updateSnapshot(
          currentSnapshot.copy(
            modelId = modelId,
            isRunning = false,
            statusMessage = "Download failed.",
            lastError = error.message ?: "Download failed.",
            updatedAtMs = System.currentTimeMillis(),
          ),
        )
      } finally {
        activeJob = null
      }
    }
  }

  fun cancelDownload() {
    activeJob?.cancel()
  }

  private fun cleanupPartialDownload(model: String, quantization: String) {
    val context = appContext ?: return
    val folderName = "$model-$quantization"
    val modelDir = File(File(context.filesDir, "leap_models"), folderName)
    val manifestFile = File(modelDir, "$folderName.json")
    if (manifestFile.exists()) {
      return
    }
    if (modelDir.exists()) {
      modelDir.deleteRecursively()
    }
  }

  private fun clearDownloadArtifacts(model: String, quantization: String) {
    val context = appContext ?: return
    val folderName = "$model-$quantization"
    val modelDir = File(File(context.filesDir, "leap_models"), folderName)
    if (modelDir.exists()) {
      modelDir.deleteRecursively()
    }
  }

  private fun updateSnapshot(snapshot: ManagedModelDownloadSnapshot) {
    currentSnapshot = snapshot
    notifyListeners()
  }

  private fun notifyListeners() {
    val snapshot = currentSnapshot
    val nowMs = System.currentTimeMillis()
    if (snapshot.isRunning &&
      snapshot.lastError == null &&
      nowMs - lastDispatchAtMs < 350 &&
      (snapshot.progress - lastDispatchedProgress) < 0.01
    ) {
      return
    }
    lastDispatchAtMs = nowMs
    lastDispatchedProgress = snapshot.progress
    listeners.forEach { listener ->
      listener.onSnapshotChanged(snapshot)
    }
  }

}
