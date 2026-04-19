package com.opc.stella

import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "com.opc.stella/app_update"
    }

    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Setup MethodChannel for app update functionality
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownload" -> {
                    val downloadUrl = call.argument<String>("downloadUrl")
                    val fileName = call.argument<String>("fileName") ?: "update.apk"

                    if (downloadUrl != null) {
                        startDownloadService(downloadUrl, fileName)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Download URL is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Start the download service for APK update
     */
    private fun startDownloadService(downloadUrl: String, fileName: String) {
        android.util.Log.d(TAG, "Starting download service: $downloadUrl")

        val intent = Intent(this, DownloadService::class.java).apply {
            putExtra(DownloadService.EXTRA_DOWNLOAD_URL, downloadUrl)
            putExtra(DownloadService.EXTRA_FILE_NAME, fileName)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Keep splash screen visible longer on Android 12+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Set splash screen to stay on until Flutter tells it to close
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                // Remove splash screen immediately when Flutter is ready
                splashScreenView.remove()
            }
        }
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        // CRITICAL: Ensure AudioService is properly released when activity is destroyed
        // This prevents the service from running indefinitely after app exit
        try {
            methodChannel?.setMethodCallHandler(null)
            // AudioService will be cleaned up by Flutter's dispose method
            super.onDestroy()
        } catch (e: Exception) {
            // Log but don't crash
            android.util.Log.e("MainActivity", "Error in onDestroy", e)
            super.onDestroy()
        }
    }

    override fun onStop() {
        // Called when the activity is no longer visible to the user
        // This happens when app is minimized or another app is opened
        super.onStop()
    }
}
