# Liquid AI Leap SDK Implementation

## Overview

This document describes the current on-device summarization implementation using **Liquid AI Leap SDK** (`flutter_leap_sdk`) in Senscribe.

The app now uses a memory-safe long-text pipeline for mobile devices:

- Default model: **LFM2.5-1.2B-Instruct Q8_0**
- SDK model bundle id: `LFM2-1.2B-8da4w_output_8da8w-seq_4096.bundle`
- Chunked map-reduce summarization for transcripts up to and beyond ~5000 words
- On-demand model loading + auto-unload after inactivity

---

## Architecture

### 1) LeapService (`lib/services/leap_service.dart`)

Core wrapper for Leap SDK inference and model lifecycle.

### Responsibilities

- Resolve and validate model id
- Load model on demand
- Split transcript into fixed overlapping chunks
- Summarize each chunk in an isolated conversation
- Combine section summaries into final output
- Stream progress and final tokens
- Auto-unload model after 3 seconds idle
- Recover from transient Android stop interruptions

### Key public methods

```dart
Future<bool> isModelCached(String modelId)
Future<void> loadModel(String modelId)
Future<String> summarizeLargeText(String transcript, {String modelId})
Stream<String> summarizeLargeTextStream(String transcript, {String modelId})
Future<void> forceUnload()
Future<void> dispose()
```

### Runtime settings

- Chunk size: `1200` tokens
- Chunk overlap: `150` tokens
- Token approximation: `1 token ~= 0.75 words`
- Chunk summary generation: `temperature = 0.3`, `maxTokens = 150`
- Final summary generation: `temperature = 0.3`, `maxTokens = 300`

---

### 2) SummarizationService (`lib/services/summarization_service.dart`)

App-level orchestration and API facade.

### Responsibilities

- Model download progress handling
- Model selection persistence via `SharedPreferences`
- One-time preference cleanup/migration to valid model id
- User-facing synchronous and streaming summarization APIs

### Key methods

```dart
Future<String> getSelectedModelName()
Future<void> setSelectedModelName(String name)
Future<bool> isModelConfigured([LLMModel? model])
Future<void> downloadModelFiles(LLMModel model, ...)
Future<String> summarize(String transcript)
Stream<String> summarizeStream(String transcript)
Future<String> summarizeWithCallback(String transcript, ...)
```

---

### 3) LLMModel (`lib/models/llm_model.dart`)

Model catalog used by settings and summarization.

```dart
static const lfm25Instruct = LLMModel(
  name: 'LFM2-1.2B-8da4w_output_8da8w-seq_4096.bundle',
  description: 'LFM2.5-1.2B-Instruct Q8_0 (Liquid Managed)',
  estimatedSizeMB: 1250,
  requiredFiles: [],
);
```

---

## Summarization Pipeline

## Step 1: Model readiness

- Validate model exists: `checkModelExists(...)`
- Load model only when summarization starts

## Step 2: Chunking (map input)

Input transcript is split with word-based token approximation:

```dart
final words = text.trim().split(RegExp(r'\\s+'));
```

Chunking constants:

- `chunkTokens = 1200`
- `overlapTokens = 150`
- `chunkWords ~= 900`
- `overlapWords ~= 113`

## Step 3: Per-chunk summary (map)

For each chunk:

1. Create a **fresh** `Conversation`
2. Generate 50–100 word section summary
3. Dispose that conversation

No conversation history is shared between chunks.

## Step 4: Final summary (reduce)

- Create a fresh `Conversation`
- Merge section summaries into final ~200-word output
- Dispose that conversation

## Step 5: Model cleanup

- Cancel pending unload timers while work is active
- Auto-unload model after 3 seconds inactivity
- Manual lifecycle cleanup available via `forceUnload()`

---

## Streaming UX Behavior

Streaming emits progress markers before final tokens:

- `Processing section X of Y...`
- `Combining section summaries...`

Then final summary tokens are streamed to UI.

---

## Memory and Stability Strategy

- Keep service stateless regarding transcript history
- Isolated conversations prevent cross-request leakage
- On-demand load + idle unload frees ~1 GB class of memory footprint quickly
- Android interruption recovery:
  - Detect recoverable stop patterns (e.g., stop request / empty generation)
  - Force unload + reload model
  - Retry current chunk/final stage once

---

## Platform Notes

## Android

- Minimum SDK: `31`
- Model path format:
  - `/data/user/0/<package>/app_flutter/leap/<model-bundle>`

## iOS

- Supported with current app deployment setup
- Model stored in app support/documents space managed by SDK

---

## Error Handling

Typical user-facing errors:

- Model missing: prompt user to download in Settings
- Model load failure: return clear summarization failure message
- Generation interruption: auto recovery + single retry for stability

All errors are logged with `debugPrint` for diagnostics.

---

## Changelog

### 2026-02-15: Large-Text Refactor + LFM Migration

- Replaced Qwen default path with LFM2.5 1.2B Instruct bundle target
- Added map-reduce chunking (1200/150)
- Added sync + stream summarization APIs
- Added per-chunk fresh conversation lifecycle
- Added 3-second auto-unload and `forceUnload()`
- Added Android stop-interruption recovery and retry
- Added model preference cleanup for legacy/invalid stored values

### 2026-01-23: Initial Leap SDK Migration

- Replaced ONNX GenAI with `flutter_leap_sdk`
- Adopted managed model download + load flow

---

**Last Updated**: February 15, 2026  
**SDK Version**: `flutter_leap_sdk ^0.2.4`  
**Model**: `LFM2-1.2B-8da4w_output_8da8w-seq_4096.bundle` (LFM2.5-1.2B-Instruct Q8_0)
