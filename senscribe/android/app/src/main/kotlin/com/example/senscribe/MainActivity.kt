package com.example.senscribe

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
    }

    // Audio classification plugin
    private var audioClassificationPlugin: AudioClassificationPlugin? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register audio classification plugin
        audioClassificationPlugin = AudioClassificationPlugin.register(
            flutterEngine.dartExecutor.binaryMessenger,
            applicationContext,
            this,
        )
    }

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
        super.onDestroy()
    }
}
