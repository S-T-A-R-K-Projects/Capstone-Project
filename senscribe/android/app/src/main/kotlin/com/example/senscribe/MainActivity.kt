package com.example.senscribe

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  private var audioClassificationPlugin: AudioClassificationPlugin? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
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