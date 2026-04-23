package com.example.senscribe

import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val ALERT_FEEDBACK_CHANNEL = "senscribe/alert_feedback"
        private const val PLAY_TRIGGER_ALERT_FEEDBACK_METHOD = "playTriggerAlertFeedback"
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ALERT_FEEDBACK_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                PLAY_TRIGGER_ALERT_FEEDBACK_METHOD -> {
                    playTriggerAlertFeedback()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
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

    private fun playTriggerAlertFeedback() {
        val timings = longArrayOf(0L, 90L, 60L, 90L, 70L, 190L)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val effect = VibrationEffect.createWaveform(timings, -1)
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            val vibrator = vibratorManager?.defaultVibrator
            if (vibrator?.hasVibrator() == true) {
                vibrator.cancel()
                vibrator.vibrate(effect)
            }
            return
        }

        @Suppress("DEPRECATION")
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        if (vibrator?.hasVibrator() != true) {
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = VibrationEffect.createWaveform(timings, -1)
            vibrator.cancel()
            vibrator.vibrate(effect)
            return
        }

        @Suppress("DEPRECATION")
        vibrator.cancel()
        @Suppress("DEPRECATION")
        vibrator.vibrate(timings, -1)
    }
}
