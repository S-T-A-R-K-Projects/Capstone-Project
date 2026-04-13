package com.example.senscribe

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
    }

    // Audio classification plugin
    private var audioClassificationPlugin: AudioClassificationPlugin? = null
    private var androidOfflineSpeechPlugin: AndroidOfflineSpeechPlugin? = null
    private var modelDownloadBridge: ModelDownloadBridge? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Allow the activity to be visible when device is locked.
        // This is required for lock-screen “remote view” behavior.
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register audio classification plugin
        audioClassificationPlugin = AudioClassificationPlugin.register(
            flutterEngine.dartExecutor.binaryMessenger,
            applicationContext,
            this,
        )
        androidOfflineSpeechPlugin = AndroidOfflineSpeechPlugin.register(
            flutterEngine.dartExecutor.binaryMessenger,
            applicationContext,
        )
        modelDownloadBridge = ModelDownloadBridge.register(
            flutterEngine.dartExecutor.binaryMessenger,
            applicationContext,
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
        androidOfflineSpeechPlugin?.dispose()
        super.onDestroy()
    }

}
