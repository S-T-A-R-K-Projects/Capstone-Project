package com.example.senscribe

import kotlin.math.sqrt

data class CalibratedEmbeddingBank(
  val targetEmbeddingBank: List<List<Float>>,
  val backgroundEmbeddingBank: List<List<Float>>,
  val detectionThreshold: Double,
  val backgroundMargin: Double,
)

object CustomSoundMatching {
  const val DEFAULT_TOP_K = 3
  const val MAX_TARGET_BANK_SIZE = 24
  const val MAX_BACKGROUND_BANK_SIZE = 18
  const val MIN_DETECTION_THRESHOLD = 0.64
  const val MAX_DETECTION_THRESHOLD = 0.94
  const val MIN_BACKGROUND_MARGIN = 0.005
  const val MAX_BACKGROUND_MARGIN = 0.03

  fun calibrate(
    targetEmbeddings: List<FloatArray>,
    backgroundEmbeddings: List<FloatArray>,
  ): CalibratedEmbeddingBank {
    require(targetEmbeddings.isNotEmpty()) { "Target embeddings cannot be empty." }
    require(backgroundEmbeddings.isNotEmpty()) { "Background embeddings cannot be empty." }

    val normalizedTargets = targetEmbeddings.map(::normalizeEmbedding)
    val normalizedBackground = backgroundEmbeddings.map(::normalizeEmbedding)

    val targetBank = selectRepresentativeEmbeddings(normalizedTargets, MAX_TARGET_BANK_SIZE)
    val backgroundBank = selectRepresentativeEmbeddings(normalizedBackground, MAX_BACKGROUND_BANK_SIZE)

    val positiveScores = targetBank.indices.map { index ->
      val probe = targetBank[index]
      val comparisonBank = targetBank.filterIndexed { comparisonIndex, _ ->
        comparisonIndex != index
      }.ifEmpty { listOf(probe) }
      scoreAgainstBank(probe, comparisonBank)
    }

    val negativeScores = normalizedBackground.map { background ->
      scoreAgainstBank(background, targetBank)
    }

    val positiveGaps = targetBank.indices.map { index ->
      val probe = targetBank[index]
      val comparisonBank = targetBank.filterIndexed { comparisonIndex, _ ->
        comparisonIndex != index
      }.ifEmpty { listOf(probe) }
      scoreAgainstBank(probe, comparisonBank) - scoreAgainstBank(probe, backgroundBank)
    }

    val negativeGaps = backgroundBank.indices.map { index ->
      val probe = backgroundBank[index]
      val comparisonBank = backgroundBank.filterIndexed { comparisonIndex, _ ->
        comparisonIndex != index
      }.ifEmpty { listOf(probe) }
      scoreAgainstBank(probe, targetBank) - scoreAgainstBank(probe, comparisonBank)
    }

    val positiveMean = positiveScores.average()
    val positiveP20 = percentile(positiveScores, 0.20)
    val negativeP90 = percentile(negativeScores, 0.90)

    var threshold = ((positiveMean * 0.55) + (negativeP90 * 0.45))
      .coerceIn(MIN_DETECTION_THRESHOLD, MAX_DETECTION_THRESHOLD)

    val positiveFloor = positiveP20 - 0.02
    if (threshold > positiveFloor) {
      threshold = positiveFloor
    }
    if (threshold < negativeP90 + MIN_BACKGROUND_MARGIN) {
      threshold = negativeP90 + MIN_BACKGROUND_MARGIN
    }
    if (threshold >= positiveMean) {
      threshold = positiveMean - 0.01
    }
    threshold = threshold.coerceIn(MIN_DETECTION_THRESHOLD, MAX_DETECTION_THRESHOLD)

    val positiveGapP25 = percentile(positiveGaps, 0.25)
    val negativeGapP90 = percentile(negativeGaps, 0.90)

    var margin = ((positiveGapP25 * 0.60) + (negativeGapP90 * 0.40))
      .coerceIn(MIN_BACKGROUND_MARGIN, MAX_BACKGROUND_MARGIN)

    val positiveGapFloor = positiveGaps.minOrNull()?.minus(0.0025) ?: MIN_BACKGROUND_MARGIN
    if (margin > positiveGapFloor) {
      margin = positiveGapFloor
    }
    if (margin < negativeGapP90 + 0.0025) {
      margin = negativeGapP90 + 0.0025
    }
    margin = margin.coerceIn(MIN_BACKGROUND_MARGIN, MAX_BACKGROUND_MARGIN)

    return CalibratedEmbeddingBank(
      targetEmbeddingBank = targetBank.map { it.toList() },
      backgroundEmbeddingBank = backgroundBank.map { it.toList() },
      detectionThreshold = threshold,
      backgroundMargin = margin,
    )
  }

  fun scoreAgainstBank(
    embedding: FloatArray,
    bank: List<FloatArray>,
    topK: Int = DEFAULT_TOP_K,
  ): Double {
    if (bank.isEmpty()) {
      return -1.0
    }

    val normalizedProbe = normalizeEmbedding(embedding)
    val scores = bank.map { candidate ->
      cosineSimilarity(normalizedProbe, candidate)
    }.sortedDescending()

    val sampleCount = topK.coerceAtLeast(1).coerceAtMost(scores.size)
    return scores.take(sampleCount).average()
  }

  fun selectRepresentativeEmbeddings(
    embeddings: List<FloatArray>,
    maxSize: Int,
  ): List<FloatArray> {
    require(maxSize > 0) { "maxSize must be greater than zero." }

    val normalized = embeddings.map(::normalizeEmbedding)
    if (normalized.size <= maxSize) {
      return normalized.map { it.copyOf() }
    }

    val centroid = averageNormalizedEmbedding(normalized)
    val remaining = normalized.toMutableList()
    val selected = mutableListOf<FloatArray>()

    val first = remaining.maxByOrNull { candidate ->
      1.0 - cosineSimilarity(candidate, centroid)
    } ?: return emptyList()
    selected += first
    remaining.remove(first)

    while (selected.size < maxSize && remaining.isNotEmpty()) {
      val next = remaining.maxByOrNull { candidate ->
        selected.minOf { chosen -> 1.0 - cosineSimilarity(candidate, chosen) }
      } ?: break
      selected += next
      remaining.remove(next)
    }

    return selected.map { it.copyOf() }
  }

  fun normalizeEmbedding(embedding: FloatArray): FloatArray {
    val copy = embedding.copyOf()
    normalizeInPlace(copy)
    return copy
  }

  fun cosineSimilarity(
    left: FloatArray,
    right: FloatArray,
  ): Double {
    require(left.size == right.size) { "Embedding sizes do not match." }

    var dot = 0.0
    var leftNorm = 0.0
    var rightNorm = 0.0
    for (index in left.indices) {
      val leftValue = left[index].toDouble()
      val rightValue = right[index].toDouble()
      dot += leftValue * rightValue
      leftNorm += leftValue * leftValue
      rightNorm += rightValue * rightValue
    }

    if (leftNorm == 0.0 || rightNorm == 0.0) {
      return -1.0
    }

    return dot / (sqrt(leftNorm) * sqrt(rightNorm))
  }

  fun percentile(
    values: List<Double>,
    ratio: Double,
  ): Double {
    require(values.isNotEmpty()) { "Cannot compute a percentile for an empty list." }

    val sorted = values.sorted()
    val index = ((sorted.lastIndex) * ratio).toInt().coerceIn(0, sorted.lastIndex)
    return sorted[index]
  }

  private fun averageNormalizedEmbedding(embeddings: List<FloatArray>): FloatArray {
    val length = embeddings.firstOrNull()?.size
      ?: throw IllegalStateException("No embeddings were available to average.")
    val aggregate = FloatArray(length)
    embeddings.forEach { embedding ->
      require(embedding.size == length) { "Embedding dimensions do not match." }
      for (index in embedding.indices) {
        aggregate[index] += embedding[index]
      }
    }

    for (index in aggregate.indices) {
      aggregate[index] /= embeddings.size.toFloat()
    }
    normalizeInPlace(aggregate)
    return aggregate
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
    for (index in values.indices) {
      values[index] /= magnitude
    }
  }
}
