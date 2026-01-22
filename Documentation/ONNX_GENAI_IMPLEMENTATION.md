# On-Device GenAI Implementation Overview (iOS & Android)

This document explains how Senscribe implements completely offline, on-device text summarization using Microsoft's [ONNX Runtime GenAI](https://github.com/microsoft/onnxruntime-genai). This feature allows users to summarize long speech transcripts without an internet connection, ensuring 100% data privacy.

We utilize the **Phi-3.5 Mini Instruct (INT4)** model, which offers a balance of performance and accuracy suitable for mobile devices.

## High-Level Architecture

The implementation follows a layered architecture to separate UI, Logic, and Native Inference.

**Flow:**
1.  **Flutter UI**: User requests a summary.
2.  **SummarizationService (Dart)**: Prepares the prompt and manages the request.
3.  **Native Bridge (MethodChannel)**: Passes the request to the platform-specific layer.
4.  **GenAIWrapper (Native)**: The C++ (iOS) or Kotlin (Android) wrapper receives the request.
5.  **ONNX Runtime GenAI**: The native engine runs inference using the local model files.
6.  **Streaming**: Tokens are generated one by one and streamed back up the chain to the UI via an EventChannel.

### Core Technologies
-   **Model**: Phi-3.5-Mini-Instruct (INT4 Quantized)
-   **Engine**: ONNX Runtime GenAI (C API)
-   **Wrapper**: Custom Native Wrappers (Objective-C++ for iOS, Kotlin for Android)
-   **Dart Bridge**: Flutter MethodChannel & EventChannel
-   **Reference**: Based on the [onnxruntime-genai](https://github.com/microsoft/onnxruntime-genai) library and adapted from [flutter_gen_ai_demo](https://github.com/psppspnaik209/flutter_gen_ai_demo).

---

## Flutter-Side Components (`lib/services/`)

### 1. `SummarizationService.dart`
This is the high-level orchestrator. It handles prompt engineering, input validation, and model lifecycle management.

*   **Prompt Engineering**: Uses the specific format required by Phi-3:
    ```text
    <|system|>
    You are a helpful assistant that creates medium-length summaries in 4-6 sentences...
    <|end|>
    <|user|>
    Summarize the following text...
    [Transcript]
    <|end|>
    <|assistant|>
    ```
*   **Memory Safety (Critical)**:
    *   **Truncation**: Inputs are strictly truncated to a safe character limit (currently ~800 characters) to prevent memory crashes on devices with limited RAM.
    *   **Lifecycle**: The model is loaded *just-in-time* for the summary and unloaded *immediately* after to free up significant RAM (~1.5GB).

### 2. `LLMService.dart`
Handles the raw communication with the native platform.
*   **MethodChannel** (`com.example.senscribe/llm`): Sends commands (`loadModel`, `summarize`, `unloadModel`).
*   **EventChannel** (`com.example.senscribe/llm_tokens`): Receives the generated text tokens in real-time.

---

## iOS Implementation (`ios/Runner/`)

The iOS implementation requires careful handling of C++ interop and memory management.

### 1. `GenAIWrapper.mm` (Objective-C++)
A direct wrapper around the `onnxruntime-genai` C API.
*   **Key APIs Used**:
    *   `OgaCreateModel`, `OgaCreateTokenizer`
    *   `OgaCreateGenerator`, `OgaGenerator_AppendTokenSequences`
    *   `OgaGenerator_GenerateNextToken`
*   **Memory Management**: Manually destroys all Oga objects (`OgaDestroyResult`, `OgaDestroyGenerator`, etc.) to prevent leaks.
*   **Configuration**:
    *   Implements safety limits on sequence length to prevent Out-Of-Memory (OOM) crashes.

### 2. `AppDelegate.swift`
Acts as the bridge between Flutter and the C++ wrapper.
*   **Threading**: Critical for stability.
    *   **Inference**: Runs on `DispatchQueue.global(qos: .userInitiated)`. **Never** run inference on the Main Thread, or the iOS Watchdog will kill the app (Error: `0x8badf00d`).
    *   **Callbacks**: Tokens are dispatched back to `DispatchQueue.main` before sending to Flutter.
*   **File Access**:
    *   Uses **Security Scoped Bookmarks** to maintain persistent access to the model folder selected by the user.

---

## Android Implementation (`android/.../GenAIWrapper.kt`)

Uses the Java/Kotlin bindings for ONNX Runtime GenAI.

*   **Language**: Kotlin
*   **Threading**: Uses Kotlin Coroutines (`suspend` functions) to handle background execution naturally.
*   **Streaming**: Implements a `TokenizerStream` to decode tokens on the fly and send them back via the MethodChannel callback.

---

## Challenges & Solutions

### 1. Memory Management (RAM Constraints)
*   **Problem**: Large LLMs (even quantized ones) require significant RAM for the model weights plus the KV Cache, which grows with input length. This can cause crashes on mobile devices.
*   **Solution**:
    1.  Implemented a strict "Load -> Summarize -> Unload" lifecycle to ensure RAM is only used during active generation.
    2.  Aggressively truncated input transcripts to a safe token count.
    3.  Restricted the maximum generation length to prevent the KV cache from growing too large.

### 2. UI Responsiveness (App Hangs)
*   **Problem**: Running heavy inference on the main thread blocks the UI, causing the app to freeze or be killed by the OS watchdog.
*   **Solution**: Moved the entire `inference` loop to a background thread (`DispatchQueue.global` on iOS, Coroutines on Android) while dispatching UI updates back to the main thread.

### 3. Token Generation Errors
*   **Problem**: Issues with token generation where the input length exceeded the model's configured total capacity.
*   **Solution**: Adjusted the `max_length` parameter logic. In ONNX GenAI, `max_length` refers to the **Total Sequence Length** (Input + Output), not just the generated output. The system now ensures `max_length` is sufficient to cover both the input prompt and the desired summary length.

---

## References
*   **Source Code Inspiration**: [flutter_gen_ai_demo](https://github.com/psppspnaik209/flutter_gen_ai_demo)
*   **Core Library**: [onnxruntime-genai](https://github.com/microsoft/onnxruntime-genai)
*   **Article**: "On-Device GenAI with Flutter" by HarshaNCK (Medium)
