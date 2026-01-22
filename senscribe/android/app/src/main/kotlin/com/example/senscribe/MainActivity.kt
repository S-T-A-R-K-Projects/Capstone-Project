package com.example.senscribe

import android.net.Uri
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        
        // LLM channel names - must match Flutter side
        private const val LLM_METHOD_CHANNEL = "com.example.senscribe/llm"
        private const val LLM_EVENT_CHANNEL = "com.example.senscribe/llm_tokens"
    }

    // Audio classification plugin
    private var audioClassificationPlugin: AudioClassificationPlugin? = null
    
    // LLM components
    private var llmEventSink: EventChannel.EventSink? = null
    private val genAIWrapper = GenAIWrapper()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register audio classification plugin
        audioClassificationPlugin = AudioClassificationPlugin.register(
            flutterEngine.dartExecutor.binaryMessenger,
            applicationContext,
            this,
        )
        
        // Setup LLM Method Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LLM_METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> handleLoadModel(call.arguments as String, result)
                "summarize" -> handleSummarize(call, result)
                "unloadModel" -> handleUnloadModel(result)
                "isModelLoaded" -> result.success(genAIWrapper.isLoaded)
                "copyModelFromUri" -> handleCopyModelFromUri(call, result)
                else -> result.notImplemented()
            }
        }
        
        // Setup LLM Event Channel for token streaming
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LLM_EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                Log.d(TAG, "LLM event stream started listening")
                llmEventSink = events
            }
            
            override fun onCancel(arguments: Any?) {
                Log.d(TAG, "LLM event stream cancelled")
                llmEventSink = null
            }
        })
    }

    // MARK: - LLM Method Handlers

    private fun handleLoadModel(path: String, result: MethodChannel.Result) {
        Log.d(TAG, "Loading model from path: $path")
        
        // Load on background thread to avoid ANR (model is ~1.8GB)
        CoroutineScope(Dispatchers.IO).launch {
            val isLoaded = genAIWrapper.load(path)
            
            withContext(Dispatchers.Main) {
                if (isLoaded) {
                    Log.d(TAG, "Model loaded successfully")
                    result.success("LOADED")
                } else {
                    Log.e(TAG, "Failed to load model")
                    result.error("LOAD_FAILED", "Failed to load model", null)
                }
            }
        }
    }

    private fun handleSummarize(call: MethodCall, result: MethodChannel.Result) {
        val prompt = call.argument<String>("prompt")
        if (prompt == null) {
            result.error("INVALID_ARGUMENTS", "Prompt is required", null)
            return
        }
        
        @Suppress("UNCHECKED_CAST")
        val params = call.argument<Map<String, Double>>("params") ?: mapOf()
        
        Log.d(TAG, "Starting summarization with prompt length: ${prompt.length}")
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val success = genAIWrapper.inference(prompt, params) { token ->
                    // EventSink.success must be called on main thread
                    CoroutineScope(Dispatchers.Main).launch {
                        llmEventSink?.success(token)
                    }
                }
                
                withContext(Dispatchers.Main) {
                    if (success) {
                        Log.d(TAG, "Summarization completed successfully")
                        result.success("DONE")
                    } else {
                        Log.e(TAG, "Summarization failed")
                        result.error("SUMMARIZATION_FAILED", "Text summarization failed", null)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Summarization error: ${e.message}")
                withContext(Dispatchers.Main) {
                    result.error("SUMMARIZATION_FAILED", e.message, null)
                }
            }
        }
    }

    private fun handleUnloadModel(result: MethodChannel.Result) {
        Log.d(TAG, "Unloading model")
        genAIWrapper.unload()
        result.success("UNLOADED")
    }

    /**
     * Copy model files from a content URI (SAF) to app's internal storage.
     * This is needed because ONNX Runtime requires direct file path access.
     */
    private fun handleCopyModelFromUri(call: MethodCall, result: MethodChannel.Result) {
        val folderUri = call.argument<String>("folderUri")
        val targetDir = call.argument<String>("targetDir")
        val files = call.argument<List<String>>("files")
        
        if (folderUri == null || targetDir == null || files == null) {
            result.error("INVALID_ARGS", "Missing folderUri, targetDir, or files", null)
            return
        }
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val uri = Uri.parse(folderUri)
                val tree = DocumentFile.fromTreeUri(this@MainActivity, uri)
                
                if (tree == null) {
                    withContext(Dispatchers.Main) {
                        result.error("COPY_FAILED", "Unable to access folder", null)
                    }
                    return@launch
                }
                
                val target = File(targetDir)
                if (!target.exists()) {
                    target.mkdirs()
                }
                
                val missing = mutableListOf<String>()
                
                for (fileName in files) {
                    val source = tree.findFile(fileName)
                    if (source == null) {
                        missing.add(fileName)
                        continue
                    }
                    
                    val outFile = File(target, fileName)
                    
                    // Skip if file already exists with content
                    if (outFile.exists() && outFile.length() > 0) {
                        Log.d(TAG, "File already exists: $fileName")
                        continue
                    }
                    
                    Log.d(TAG, "Copying file: $fileName")
                    contentResolver.openInputStream(source.uri)?.use { input ->
                        FileOutputStream(outFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                }
                
                withContext(Dispatchers.Main) {
                    if (missing.isNotEmpty()) {
                        result.error("COPY_FAILED", "Missing files: ${missing.joinToString(", ")}", null)
                    } else {
                        result.success("COPIED")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Copy failed: ${e.message}")
                withContext(Dispatchers.Main) {
                    result.error("COPY_FAILED", e.message, null)
                }
            }
        }
    }

    // MARK: - Lifecycle

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        audioClassificationPlugin?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        audioClassificationPlugin?.dispose()
        audioClassificationPlugin = null
        genAIWrapper.unload()
        super.onDestroy()
    }
}
