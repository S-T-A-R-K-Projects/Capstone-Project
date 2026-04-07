package com.example.senscribe

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CustomSoundMatchingTest {
  @Test
  fun calibrateProducesStableThresholdsForSeparatedClusters() {
    val targetEmbeddings = List(18) { index ->
      vectorOf(1.0f, 0.10f + (index * 0.005f), 0.02f)
    }
    val backgroundEmbeddings = List(12) { index ->
      vectorOf(0.05f, 1.0f, 0.08f + (index * 0.004f))
    }

    val calibrated = CustomSoundMatching.calibrate(targetEmbeddings, backgroundEmbeddings)

    assertTrue(calibrated.targetEmbeddingBank.size <= CustomSoundMatching.MAX_TARGET_BANK_SIZE)
    assertTrue(
      calibrated.backgroundEmbeddingBank.size <= CustomSoundMatching.MAX_BACKGROUND_BANK_SIZE,
    )
    assertTrue(
      calibrated.detectionThreshold >= CustomSoundMatching.MIN_DETECTION_THRESHOLD,
    )
    assertTrue(
      calibrated.detectionThreshold <= CustomSoundMatching.MAX_DETECTION_THRESHOLD,
    )
    assertTrue(
      calibrated.backgroundMargin >= CustomSoundMatching.MIN_BACKGROUND_MARGIN,
    )

    val targetProbe = vectorOf(0.98f, 0.15f, 0.03f)
    val targetScore = CustomSoundMatching.scoreAgainstBank(
      targetProbe,
      calibrated.targetEmbeddingBank.map { it.toFloatArray() },
    )
    val backgroundScore = CustomSoundMatching.scoreAgainstBank(
      targetProbe,
      calibrated.backgroundEmbeddingBank.map { it.toFloatArray() },
    )

    assertTrue(targetScore >= calibrated.detectionThreshold)
    assertTrue(targetScore >= backgroundScore + calibrated.backgroundMargin)
  }

  @Test
  fun backgroundProbeDoesNotPassTargetMatcher() {
    val calibrated = CustomSoundMatching.calibrate(
      targetEmbeddings = List(14) { index ->
        vectorOf(1.0f, 0.08f + (index * 0.004f), 0.01f)
      },
      backgroundEmbeddings = List(10) { index ->
        vectorOf(0.02f, 1.0f, 0.12f + (index * 0.006f))
      },
    )

    val backgroundProbe = vectorOf(0.03f, 0.99f, 0.15f)
    val targetScore = CustomSoundMatching.scoreAgainstBank(
      backgroundProbe,
      calibrated.targetEmbeddingBank.map { it.toFloatArray() },
    )
    val backgroundScore = CustomSoundMatching.scoreAgainstBank(
      backgroundProbe,
      calibrated.backgroundEmbeddingBank.map { it.toFloatArray() },
    )

    assertTrue(targetScore < calibrated.detectionThreshold || targetScore < backgroundScore + calibrated.backgroundMargin)
  }

  @Test
  fun higherScoringBankWinsAcrossMultipleCustomSounds() {
    val doorbell = CustomSoundMatching.calibrate(
      targetEmbeddings = List(16) { index -> vectorOf(1.0f, 0.06f + (index * 0.003f), 0.01f) },
      backgroundEmbeddings = List(10) { index -> vectorOf(0.05f, 1.0f, 0.10f + (index * 0.004f)) },
    )
    val kettle = CustomSoundMatching.calibrate(
      targetEmbeddings = List(16) { index -> vectorOf(0.08f, 0.12f + (index * 0.003f), 1.0f) },
      backgroundEmbeddings = List(10) { index -> vectorOf(0.05f, 1.0f, 0.08f + (index * 0.004f)) },
    )

    val probe = vectorOf(0.97f, 0.11f, 0.02f)
    val doorbellScore = CustomSoundMatching.scoreAgainstBank(
      probe,
      doorbell.targetEmbeddingBank.map { it.toFloatArray() },
    )
    val kettleScore = CustomSoundMatching.scoreAgainstBank(
      probe,
      kettle.targetEmbeddingBank.map { it.toFloatArray() },
    )

    assertTrue(doorbellScore > kettleScore + 0.03)
  }

  @Test
  fun legacyReadyProfileWithoutBanksNormalizesToDraft() {
    val normalized = CustomSoundProfileRecord(
      id = "legacy",
      name = "Legacy",
      enabled = true,
      status = "ready",
      targetSamplePaths = List(5) { index -> "target_${index + 1}.wav" },
      backgroundSamplePaths = listOf("background_1.wav"),
      createdAt = "2026-04-01T00:00:00Z",
      updatedAt = "2026-04-01T00:00:00Z",
      lastError = null,
      targetEmbeddingBank = null,
      backgroundEmbeddingBank = null,
      detectionThreshold = 0.8,
      backgroundMargin = 0.01,
    ).normalizedForRequirements()

    assertEquals("draft", normalized.status)
    assertFalse(normalized.hasEnoughSamples)
    assertNull(normalized.targetEmbeddingBank)
    assertNull(normalized.backgroundEmbeddingBank)
  }

  @Test
  fun readyProfileWithBanksStaysReady() {
    val normalized = CustomSoundProfileRecord(
      id = "ready",
      name = "Ready",
      enabled = true,
      status = "ready",
      targetSamplePaths = List(10) { index -> "target_${index + 1}.wav" },
      backgroundSamplePaths = List(3) { index -> "background_${index + 1}.wav" },
      createdAt = "2026-04-01T00:00:00Z",
      updatedAt = "2026-04-01T00:00:00Z",
      lastError = null,
      targetEmbeddingBank = listOf(
        listOf(1.0f, 0.0f, 0.0f),
        listOf(0.95f, 0.1f, 0.0f),
      ),
      backgroundEmbeddingBank = listOf(
        listOf(0.0f, 1.0f, 0.0f),
        listOf(0.1f, 0.95f, 0.0f),
      ),
      detectionThreshold = 0.8,
      backgroundMargin = 0.01,
    ).normalizedForRequirements()

    assertEquals("ready", normalized.status)
    assertTrue(normalized.hasEnoughSamples)
    assertNotNull(normalized.targetEmbeddingBank)
    assertNotNull(normalized.backgroundEmbeddingBank)
  }

  private fun vectorOf(
    x: Float,
    y: Float,
    z: Float,
  ): FloatArray = floatArrayOf(x, y, z)
}
