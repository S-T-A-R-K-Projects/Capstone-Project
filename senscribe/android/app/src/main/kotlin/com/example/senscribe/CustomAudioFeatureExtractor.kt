package com.example.senscribe

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sqrt

internal object CustomAudioFeatureExtractor {
  private const val SAMPLE_RATE = 16000.0
  private const val FRAME_SIZE = 512
  private const val HOP_SIZE = 256
  private const val BAND_COUNT = 18
  private const val ENVELOPE_BUCKETS = 8
  private const val MIN_FREQUENCY_HZ = 125.0
  private const val MAX_FREQUENCY_HZ = 7500.0

  private val window = FloatArray(FRAME_SIZE) { index ->
    (0.5 - (0.5 * cos((2.0 * PI * index) / (FRAME_SIZE - 1)))).toFloat()
  }

  private val analysisFrequencies = DoubleArray(BAND_COUNT) { index ->
    val ratio = if (BAND_COUNT == 1) 0.0 else index.toDouble() / (BAND_COUNT - 1).toDouble()
    MIN_FREQUENCY_HZ * (MAX_FREQUENCY_HZ / MIN_FREQUENCY_HZ).pow(ratio)
  }

  fun extract(samples: FloatArray): FloatArray? {
    if (samples.isEmpty()) return null

    val bandSums = DoubleArray(BAND_COUNT)
    val bandSquares = DoubleArray(BAND_COUNT)
    val frameBuffer = FloatArray(FRAME_SIZE)
    var frameCount = 0

    val lastStart = max(samples.size - FRAME_SIZE, 0)
    var start = 0
    while (true) {
      frameBuffer.fill(0f)
      val copyCount = min(FRAME_SIZE, samples.size - start)
      if (copyCount > 0) {
        for (index in 0 until copyCount) {
          frameBuffer[index] = samples[start + index] * window[index]
        }
      }

      for (bandIndex in analysisFrequencies.indices) {
        val energy = goertzelPower(frameBuffer, analysisFrequencies[bandIndex])
        val value = ln(1.0 + energy)
        bandSums[bandIndex] += value
        bandSquares[bandIndex] += value * value
      }

      frameCount += 1
      if (samples.size <= FRAME_SIZE || start >= lastStart) {
        break
      }
      start = min(start + HOP_SIZE, lastStart)
    }

    if (frameCount <= 0) return null

    val envelope = computeEnvelope(samples)
    val rms = computeRms(samples)
    val peak = samples.maxOfOrNull { kotlin.math.abs(it) } ?: 0f
    val zeroCrossingRate = computeZeroCrossingRate(samples)

    val featureVector =
      FloatArray((BAND_COUNT * 2) + ENVELOPE_BUCKETS + 3)

    var offset = 0
    for (bandIndex in 0 until BAND_COUNT) {
      featureVector[offset++] = (bandSums[bandIndex] / frameCount.toDouble()).toFloat()
    }
    for (bandIndex in 0 until BAND_COUNT) {
      val mean = bandSums[bandIndex] / frameCount.toDouble()
      val variance = max(0.0, (bandSquares[bandIndex] / frameCount.toDouble()) - (mean * mean))
      featureVector[offset++] = sqrt(variance).toFloat()
    }
    envelope.forEach { bucket ->
      featureVector[offset++] = bucket
    }
    featureVector[offset++] = rms
    featureVector[offset++] = peak
    featureVector[offset] = zeroCrossingRate

    return CustomSoundMatching.normalizeEmbedding(featureVector)
  }

  private fun computeEnvelope(samples: FloatArray): FloatArray {
    val bucketSize = max(samples.size / ENVELOPE_BUCKETS, 1)
    val envelope = FloatArray(ENVELOPE_BUCKETS)
    for (bucketIndex in 0 until ENVELOPE_BUCKETS) {
      val start = bucketIndex * bucketSize
      if (start >= samples.size) break
      val end = min(samples.size, start + bucketSize)
      var sumSquares = 0.0
      for (index in start until end) {
        val value = samples[index].toDouble()
        sumSquares += value * value
      }
      val count = max(end - start, 1)
      envelope[bucketIndex] = sqrt(sumSquares / count.toDouble()).toFloat()
    }
    return envelope
  }

  private fun computeRms(samples: FloatArray): Float {
    var sumSquares = 0.0
    samples.forEach { sample ->
      val value = sample.toDouble()
      sumSquares += value * value
    }
    return sqrt(sumSquares / max(samples.size, 1).toDouble()).toFloat()
  }

  private fun computeZeroCrossingRate(samples: FloatArray): Float {
    if (samples.size < 2) return 0f
    var crossings = 0
    for (index in 1 until samples.size) {
      val previous = samples[index - 1]
      val current = samples[index]
      if ((previous >= 0f && current < 0f) || (previous < 0f && current >= 0f)) {
        crossings += 1
      }
    }
    return crossings.toFloat() / (samples.size - 1).toFloat()
  }

  private fun goertzelPower(
    frame: FloatArray,
    targetFrequencyHz: Double,
  ): Double {
    val normalizedFrequency = (2.0 * PI * targetFrequencyHz) / SAMPLE_RATE
    val coefficient = 2.0 * cos(normalizedFrequency)
    var q0 = 0.0
    var q1 = 0.0
    var q2 = 0.0
    frame.forEach { sample ->
      q0 = sample + (coefficient * q1) - q2
      q2 = q1
      q1 = q0
    }
    val power = (q1 * q1) + (q2 * q2) - (coefficient * q1 * q2)
    return max(0.0, power / frame.size.toDouble())
  }
}
