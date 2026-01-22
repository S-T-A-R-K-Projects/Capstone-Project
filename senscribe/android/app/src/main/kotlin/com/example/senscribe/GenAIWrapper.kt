package com.example.senscribe

import ai.onnxruntime.genai.GenAIException
import ai.onnxruntime.genai.Generator
import ai.onnxruntime.genai.GeneratorParams
import ai.onnxruntime.genai.Model
import ai.onnxruntime.genai.Tokenizer
import ai.onnxruntime.genai.TokenizerStream
import android.util.Log
import kotlinx.coroutines.isActive
import kotlin.coroutines.coroutineContext

/**
 * Wrapper class for ONNX Runtime GenAI on Android.
 * Handles model loading, inference with streaming tokens, and cleanup.
 */
class GenAIWrapper {
    companion object {
        private const val TAG = "GenAIWrapper"
    }

    private var model: Model? = null
    private var tokenizer: Tokenizer? = null

    val isLoaded: Boolean
        get() = model != null && tokenizer != null

    /**
     * Load the model from the specified directory path.
     * @param modelPath Directory containing model files
     * @return true if successful, false otherwise
     */
    fun load(modelPath: String): Boolean {
        return try {
            Log.d(TAG, "Loading model from path: $modelPath")
            
            // Unload existing model first
            if (isLoaded) {
                unload()
            }
            
            model = Model(modelPath)
            tokenizer = Tokenizer(model)
            
            Log.d(TAG, "Model loaded successfully")
            true
        } catch (e: GenAIException) {
            Log.e(TAG, "Failed to load model: ${e.message}")
            model = null
            tokenizer = null
            false
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error loading model: ${e.message}")
            model = null
            tokenizer = null
            false
        }
    }

    /**
     * Run inference with the given prompt and stream tokens back via callback.
     * @param prompt The input prompt for the model
     * @param params Search parameters (temperature, max_length, etc.)
     * @param onTokenGenerated Callback invoked for each generated token
     * @return true if successful, false otherwise
     */
    suspend fun inference(
        prompt: String,
        params: Map<String, Double>,
        onTokenGenerated: (String) -> Unit
    ): Boolean {
        val currentModel = model
        val currentTokenizer = tokenizer
        
        if (currentModel == null || currentTokenizer == null) {
            Log.e(TAG, "Model not loaded")
            return false
        }

        var stream: TokenizerStream? = null
        var generatorParams: GeneratorParams? = null
        var generator: Generator? = null

        return try {
            Log.d(TAG, "Starting inference with prompt length: ${prompt.length}")
            
            // Create resources
            stream = currentTokenizer.createStream()
            generatorParams = GeneratorParams(currentModel)
            
            // Set default max_length for summarization (capped for mobile)
            generatorParams.setSearchOption("max_length", 300.0)
            
            // Apply custom parameters (only known-safe ones)
            params.forEach { (key, value) ->
                try {
                    // Only apply max_length - other params may cause issues
                    if (key == "max_length") {
                        Log.d(TAG, "Setting param $key = $value")
                        generatorParams.setSearchOption(key, value)
                    } else {
                        Log.d(TAG, "Skipping unsupported param: $key")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to set param $key: ${e.message}")
                }
            }
            
            Log.d(TAG, "Creating generator")
            generator = Generator(currentModel, generatorParams)
            
            // Encode and append prompt tokens
            Log.d(TAG, "Encoding prompt")
            val inputTokens = currentTokenizer.encode(prompt)
            Log.d(TAG, "Appending token sequences")
            generator.appendTokenSequences(inputTokens)
            
            var tokenCount = 0
            Log.d(TAG, "Starting token generation loop")
            
            // Generate tokens using the while loop pattern
            while (!generator.isDone && coroutineContext.isActive) {
                generator.generateNextToken()
                
                val tokenId = generator.getLastTokenInSequence(0)
                val token = stream.decode(tokenId)
                tokenCount++
                
                if (token.isNotEmpty()) {
                    // Call directly - EventChannel handles thread marshalling
                    onTokenGenerated(token)
                }
                
                // Safety limit
                if (tokenCount > 1000) {
                    Log.w(TAG, "Hit token limit, stopping generation")
                    break
                }
            }
            
            Log.d(TAG, "Inference complete, generated $tokenCount tokens")
            true
        } catch (e: GenAIException) {
            Log.e(TAG, "Inference failed (GenAI): ${e.message}", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error during inference: ${e.message}", e)
            false
        } finally {
            // Clean up resources in reverse order
            try {
                generator?.close()
            } catch (e: Exception) {
                Log.w(TAG, "Error closing generator: ${e.message}")
            }
            try {
                generatorParams?.close()
            } catch (e: Exception) {
                Log.w(TAG, "Error closing params: ${e.message}")
            }
            try {
                stream?.close()
            } catch (e: Exception) {
                Log.w(TAG, "Error closing stream: ${e.message}")
            }
        }
    }

    /**
     * Unload the model and free resources.
     */
    fun unload() {
        Log.d(TAG, "Unloading model")
        try {
            tokenizer?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing tokenizer: ${e.message}")
        }
        try {
            model?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing model: ${e.message}")
        }
        tokenizer = null
        model = null
    }
}
