# LEAP SDK Implementation (Current)

## Purpose

This document describes the **current, shipping** long-text summarization implementation in Senscribe using `flutter_leap_sdk`.

The implementation is optimized for:

- Large transcripts (e.g., 5,000+ words)
- Mobile memory safety (Android API 31+, iOS)
- Stable behavior across repeated summarization sessions
- No context leakage between independent transcripts

This document intentionally describes only the active architecture and runtime behavior.

---

## Model Configuration

### Active model

- Display name: `LFM2.5-1.2B-Instruct Q8_0`
- Bundle id used by SDK/runtime: `LFM2-1.2B-8da4w_output_8da8w-seq_4096.bundle`
- Approximate on-device model size: `~1.25 GB`

### Why this model setup

- Fits mobile constraints better than larger alternatives
- Works with on-device sequence capacity shown in runtime logs (`4096`)
- Provides adequate speed/quality tradeoff for transcript summarization

---

## Service Architecture

## 1) `LeapService` (`lib/services/leap_service.dart`)

`LeapService` is the core inference and lifecycle layer.

### Responsibilities

- Resolve model identifiers
- Ensure model loaded state
- Execute map-reduce summarization
- Manage conversation lifecycle per generation unit
- Handle retry/recovery on recoverable generation interruptions
- Manage model memory (explicit unload + idle auto-unload)

### Public API

```dart
Future<bool> isModelCached(String modelId)
Future<void> loadModel(String modelId)
Future<String> summarizeLargeText(String transcript, {String modelId})
Stream<String> summarizeLargeTextStream(String transcript, {String modelId})
Future<void> forceUnload()
Future<void> dispose()
```

### Key runtime constants

- Chunk size: `1200` tokens
- Chunk overlap: `150` tokens
- Token approximation: `1 token ≈ 0.75 words`
- Chunk generation: `temperature 0.3`, `maxTokens 150`
- Final generation: `temperature 0.3`, `maxTokens 300`
- Chunk timeout: `45s`
- Final timeout: `30s`
- Auto-unload delay: `3s`
- Conversation transition delay: `120ms`

---

## 2) `SummarizationService` (`lib/services/summarization_service.dart`)

`SummarizationService` is the app-facing orchestration layer.

### Responsibilities

- Persist selected model (`SharedPreferences`)
- Normalize/repair invalid or stale persisted model values
- Trigger model download via SDK
- Expose sync and streaming summarization interfaces for UI

### App-facing API

```dart
Future<String> summarize(String transcript)
Stream<String> summarizeStream(String transcript)
Future<String> summarizeWithCallback(String transcript, {required void Function(String token) onToken})
```

---

## 3) Model Catalog (`lib/models/llm_model.dart`)

The app model catalog currently contains one active production model entry:

```dart
LFM2-1.2B-8da4w_output_8da8w-seq_4096.bundle
```

Model selection logic falls back to this default if persisted value is empty/invalid.

---

## End-to-End Summarization Flow

## Phase A: Start + load

1. Validate transcript is non-empty
2. Resolve model id
3. Ensure model is loaded (`_ensureModelLoaded`)
4. Cancel pending auto-unload timers

## Phase B: Split input (Map setup)

Input text is normalized and split by whitespace:

```dart
split(RegExp(r'\\s+'))
```

Then chunked using:

- chunk words: `round(1200 * 0.75) ~= 900`
- overlap words: `round(150 * 0.75) ~= 113`
- sliding step: `chunkWords - overlapWords`

### Text normalization before chunking

A normalization pass reduces obvious STT word-fragment artifacts before chunking (for example, accidental single-letter split fragments inside words) while keeping conservative rules to avoid over-merging normal words.

## Phase C: Per-chunk summarization (Map)

For each chunk:

1. Create a **fresh** `Conversation`
2. Generate a 50–100 word chunk summary
3. Dispose that conversation
4. Insert a short transition delay (`120ms`) before next unit

This ensures no conversation history is shared between chunks.

## Phase D: Final combine (Reduce)

Before reduce stage:

1. `_prepareForFinalReduction(modelId)` is called
2. Model is force-unloaded
3. Model is reloaded cleanly

Then:

1. Create fresh reduce conversation
2. Generate final ~200-word summary from chunk summaries
3. Dispose conversation

### Why pre-final reduction reset exists

On Android, intermittent stop-state contamination can occur near stage transitions. A clean model reset before final reduce makes final combine more deterministic.

## Phase E: Finish + unload

- `summarize...` returns final result
- Auto-unload timer is scheduled (3s)
- If no further requests arrive, model is unloaded to free memory

---

## Streaming Behavior

`summarizeLargeTextStream` provides staged progress messages:

- `Processing section X of Y...`
- `Combining section summaries...`

After final text is produced, output is emitted as stream tokens for UI rendering.

UI additionally displays a QoL message during summarization indicating large transcripts may take longer.

---

## Context Isolation and Memory Guarantees

### Context isolation

- Each chunk uses a new conversation instance
- Final reduce uses a new conversation instance
- No chunk conversation history is reused for other chunks/transcripts

### Memory strategy

- Model loads on demand
- Model auto-unloads after inactivity
- Explicit `forceUnload()` is available for lifecycle cleanup
- In recoverable interruption paths, unload/reload is used to recover clean engine state

---

## Error Handling and Recovery

Recoverable interruption patterns include log/error signatures such as:

- `stop request`
- `generation stopped`
- `stopped unexpectedly`
- timeout-based incomplete generations

### Recovery behavior

For chunk/final failures (attempt 1):

1. Mark as recoverable when signature matches
2. Dispose current conversation first
3. Force unload model
4. Reload model
5. Retry once

For non-recoverable failures or second-attempt failures:

- Throw `LeapServiceException`
- Surface user-facing `SummarizationException`

---

## Platform Notes

## Android

- Minimum SDK target: `31`
- Typical bundle location:
  - `/data/user/0/<package>/app_flutter/leap/<bundle>`
- Runtime logs often show effective sequence capacity as `4096`

## iOS

- Uses same service-layer architecture
- Bundle storage and loading handled by LEAP SDK on iOS filesystem paths

---

## Operational Characteristics

For large transcript runs:

- Most time is spent in repeated chunk generation and final reduce
- Pauses can occur at stage boundaries when recovery/reload is triggered
- Recovery path trades a small latency hit for improved completion reliability

---

## Files and Responsibilities Map

- `lib/services/leap_service.dart`
  - Inference orchestration, chunking, retries, model lifecycle
- `lib/services/summarization_service.dart`
  - App-facing summarization interface, model preference persistence
- `lib/models/llm_model.dart`
  - Active model catalog and metadata
- `lib/screens/history_page.dart`
  - Summarization UI state and progress rendering

---

## Current Implementation Summary

The current implementation is a **single-model, mobile-safe, map-reduce summarization pipeline** with:

- fixed chunking (`1200` + `150 overlap`),
- strict context isolation (fresh conversation per unit),
- deterministic lifecycle controls (load on start, unload on idle),
- Android-focused recovery for stop-request interruptions,
- and progressive UX feedback for long-running operations.

---

**Last Updated**: February 15, 2026  
**SDK**: `flutter_leap_sdk ^0.2.4`  
**Active Bundle**: `LFM2-1.2B-8da4w_output_8da8w-seq_4096.bundle`
