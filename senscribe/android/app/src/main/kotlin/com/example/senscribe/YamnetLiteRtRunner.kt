package com.example.senscribe

import android.content.Context
import android.content.res.AssetManager
import android.util.Log
import org.tensorflow.lite.Interpreter
import java.io.Closeable
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import kotlin.math.min

internal data class YamnetCategory(
  val label: String,
  val score: Double,
)

internal data class YamnetInferenceResult(
  val categories: List<YamnetCategory>,
)

internal class YamnetLiteRtRunner private constructor(
  private val interpreter: Interpreter,
  private val labels: List<String>,
  private val inputSampleCount: Int,
  private val scoreOutputIndex: Int,
  private val scoreOutputBuffer: Any,
) : Closeable {
  private val inputBuffer =
    ByteBuffer.allocateDirect(inputSampleCount * Float.SIZE_BYTES).order(ByteOrder.nativeOrder())

  fun analyze(samples: FloatArray): YamnetInferenceResult {
    inputBuffer.clear()

    val sampleCount = min(samples.size, inputSampleCount)
    for (index in 0 until sampleCount) {
      inputBuffer.putFloat(samples[index])
    }
    for (index in sampleCount until inputSampleCount) {
      inputBuffer.putFloat(0f)
    }
    inputBuffer.rewind()

    val outputs = mutableMapOf<Int, Any>(scoreOutputIndex to scoreOutputBuffer)

    interpreter.runForMultipleInputsOutputs(
      arrayOf(inputBuffer),
      outputs,
    )

    return YamnetInferenceResult(
      categories = extractTopCategories(scoreOutputBuffer),
    )
  }

  override fun close() {
    interpreter.close()
  }

  private fun extractTopCategories(
    values: Any,
    topK: Int = 5,
  ): List<YamnetCategory> {
    val frames = flattenFrames(values)
    val classCount = frames.firstOrNull()?.size ?: return emptyList()
    if (classCount <= 0) return emptyList()
    val summedScores = DoubleArray(classCount)
    val observationCounts = IntArray(classCount)

    frames.forEach { frame ->
      if (frame.size < classCount) return@forEach
      for (classIndex in 0 until classCount) {
        val score = frame[classIndex].toDouble().coerceAtLeast(0.0)
        observationCounts[classIndex] += 1
        summedScores[classIndex] += score
      }
    }

    return summedScores
      .mapIndexed { index, score ->
        val averagedScore =
          if (observationCounts[index] > 0) {
            score / observationCounts[index].toDouble()
          } else {
            0.0
          }
        YamnetCategory(
          label = labels.getOrElse(index) { "Class $index" },
          score = averagedScore,
        )
      }
      .sortedByDescending { it.score }
      .take(topK)
  }

  private fun flattenFrames(value: Any?): List<FloatArray> {
    return when (value) {
      null -> emptyList()
      is FloatArray -> listOf(value)
      is Array<*> -> value.flatMap(::flattenFrames)
      else -> emptyList()
    }
  }

  companion object {
    private const val CLASS_MAP_ASSET_PATH = "yamnet/yamnet_class_map.csv"
    private const val TAG = "YamnetLiteRtRunner"

    fun create(
      context: Context,
      modelAssetPath: String,
      inputSampleCount: Int,
    ): YamnetLiteRtRunner {
      val labels = loadLabels(context.assets, CLASS_MAP_ASSET_PATH)
      check(labels.isNotEmpty()) { "YAMNet class map is empty." }

      val options = Interpreter.Options().apply {
        setNumThreads(2)
        setUseXNNPACK(true)
      }

      val interpreter = Interpreter(loadModel(context.assets, modelAssetPath), options)

      // The full YAMNet model has a dynamic input shape [-1].
      // We must resize it to our fixed window size before allocating.
      val inputTensor = interpreter.getInputTensor(0)
      val inputShape = inputTensor.shape()
      val needsResize = inputShape.size == 1 && inputShape[0] != inputSampleCount
      if (needsResize) {
        Log.d(TAG, "Resizing YAMNet input from ${inputShape.contentToString()} to [$inputSampleCount]")
        interpreter.resizeInput(0, intArrayOf(inputSampleCount))
      }
      interpreter.allocateTensors()

      val resizedInputTensor = interpreter.getInputTensor(0)
      val resolvedInputSampleCount = resizedInputTensor.numBytes() / Float.SIZE_BYTES
      check(resolvedInputSampleCount > 0) { "YAMNet input tensor has no float capacity after resize." }
      Log.d(TAG, "YAMNet input: shape=${resizedInputTensor.shape().contentToString()} samples=$resolvedInputSampleCount")

      var scoreOutputIndex = -1

      for (index in 0 until interpreter.outputTensorCount) {
        val tensor = interpreter.getOutputTensor(index)
        val shape = tensor.shape()
        Log.d(TAG, "YAMNet output[$index] name=${tensor.name()} shape=${shape.contentToString()}")
        val width = shape.lastOrNull() ?: 0
        if (width == labels.size) {
          scoreOutputIndex = index
        }
      }

      check(scoreOutputIndex >= 0) {
        "YAMNet score output was not found for ${labels.size} labels."
      }
      val scoreOutputBuffer = createTensorOutput(interpreter.getOutputTensor(scoreOutputIndex).shape())

      Log.d(TAG, "YAMNet ready: inputSamples=$inputSampleCount, scoreOutputIdx=$scoreOutputIndex")

      return YamnetLiteRtRunner(
        interpreter = interpreter,
        labels = labels,
        inputSampleCount = resolvedInputSampleCount,
        scoreOutputIndex = scoreOutputIndex,
        scoreOutputBuffer = scoreOutputBuffer,
      )
    }

    private fun loadLabels(
      assetManager: AssetManager,
      assetPath: String,
    ): List<String> {
      return assetManager.open(assetPath).bufferedReader().useLines { lines ->
        lines
          .drop(1)
          .mapNotNull { line ->
            if (line.isBlank()) return@mapNotNull null
            val firstComma = line.indexOf(',')
            val secondComma = line.indexOf(',', firstComma + 1)
            if (firstComma == -1 || secondComma == -1) return@mapNotNull null
            line.substring(secondComma + 1).trim().removeSurrounding("\"")
          }
          .toList()
      }
    }

    private fun loadModel(
      assetManager: AssetManager,
      modelAssetPath: String,
    ): ByteBuffer {
      val fileDescriptor = runCatching { assetManager.openFd(modelAssetPath) }.getOrNull()
      if (fileDescriptor != null) {
        fileDescriptor.use { descriptor ->
          FileInputStream(descriptor.fileDescriptor).channel.use { channel ->
            return channel.map(
              FileChannel.MapMode.READ_ONLY,
              descriptor.startOffset,
              descriptor.declaredLength,
            )
          }
        }
      }

      val bytes = assetManager.open(modelAssetPath).use { input -> input.readBytes() }
      return ByteBuffer.allocateDirect(bytes.size)
        .order(ByteOrder.nativeOrder())
        .apply {
          put(bytes)
          rewind()
        }
    }

    private fun createTensorOutput(shape: IntArray): Any {
      // Replace any dynamic (-1) dimensions with 1 for buffer allocation.
      val resolvedShape = IntArray(shape.size) { index ->
        val dim = shape[index]
        if (dim <= 0) 1 else dim
      }
      return java.lang.reflect.Array.newInstance(Float::class.javaPrimitiveType, *resolvedShape)
    }
  }
}
