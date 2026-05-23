package com.example.streamgate_flutter

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.WindowInsets
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val ANDROID_SCREEN_CHANNEL = "streamgate/android_screen_record"
    private val RECORD_REQUEST_CODE = 1001
    private val AUDIO_PERMISSION_CODE = 1002

    private var mediaProjectionManager: MediaProjectionManager? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingFileName: String? = null

    private var screenWidth = 0
    private var screenHeight = 0
    private var screenDpi = 0

    // Service binding 
    private var recordService: ScreenRecordService? = null
    private var serviceBound = false

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            val lb = binder as? ScreenRecordService.LocalBinder ?: return
            recordService = lb.getService()
            serviceBound = true
            Log.d("StreamGate", "ScreenRecordService bound")
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            recordService = null
            serviceBound = false
        }
    }

    // Flutter engine
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaProjectionManager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager

        // FIX: Use WindowMetrics API (API 30+) for accurate screen size without nav bars
        // Fall back to DisplayMetrics for older APIs
        resolveScreenMetrics()

        // Bind the service (BIND_AUTO_CREATE starts it if not running)
        val serviceIntent = Intent(this, ScreenRecordService::class.java)
        bindService(serviceIntent, serviceConnection, Context.BIND_AUTO_CREATE)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ANDROID_SCREEN_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenRecording" -> {
                    val fileName = call.argument<String>("fileName")
                        ?: "screen_${System.currentTimeMillis()}"
                    startRecording(fileName, result)
                }
                "stopScreenRecording" -> stopRecording(result)
                else -> result.notImplemented()
            }
        }
    }

    // FIX: Accurate screen dimensions — excludes cutouts/nav bars on API 30+
    private fun resolveScreenMetrics() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // API 30+: WindowMetrics gives the real pixel bounds of the window
            val metrics = windowManager.currentWindowMetrics
            val bounds = metrics.bounds
            // Subtract insets so we only capture the visible content area
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout()
            )
            screenWidth = bounds.width() - insets.left - insets.right
            screenHeight = bounds.height() - insets.top - insets.bottom
        } else {
            @Suppress("DEPRECATION")
            val dm = android.util.DisplayMetrics()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getRealMetrics(dm)   // getRealMetrics = full panel
            screenWidth = dm.widthPixels
            screenHeight = dm.heightPixels
        }

        // DPI is fine from DisplayMetrics on all API levels
        val dm = resources.displayMetrics
        screenDpi = dm.densityDpi

        Log.d("StreamGate", " Screen: ${screenWidth}x${screenHeight} @ ${screenDpi}dpi")
    }

    // Start Recording 
    private fun startRecording(fileName: String, result: MethodChannel.Result) {
        pendingResult = result
        pendingFileName = fileName

        // Check microphone permission
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                AUDIO_PERMISSION_CODE
            )
            return
        }

        launchScreenCapture()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != AUDIO_PERMISSION_CODE) return

        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            launchScreenCapture()
        } else {
            pendingResult?.error("PERMISSION_DENIED", "Microphone permission required", null)
            pendingResult = null
            pendingFileName = null
        }
    }

    private fun launchScreenCapture() {
        startActivityForResult(
            mediaProjectionManager!!.createScreenCaptureIntent(),
            RECORD_REQUEST_CODE
        )
    }

    //  Activity result (MediaProjection grant) 
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != RECORD_REQUEST_CODE) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            pendingResult?.error("PERMISSION_DENIED", "Screen capture denied", null)
            pendingResult = null
            pendingFileName = null
            return
        }

        val service = recordService
        if (service == null) {
            pendingResult?.error("SERVICE_NOT_BOUND", "Recording service not ready", null)
            pendingResult = null
            pendingFileName = null
            return
        }

        // FIX: Start the service as a foreground-eligible started service BEFORE
        // passing the MediaProjection token. On API 29+ the system requires the
        // service to be a *started* (not just bound) foreground service to call
        // startForeground with FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION.
        val startIntent = Intent(this, ScreenRecordService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(startIntent)
        } else {
            startService(startIntent)
        }

        val fileName = pendingFileName ?: "screen_${System.currentTimeMillis()}"
        val capturedResult = pendingResult
        pendingResult = null
        pendingFileName = null

        // Re-read metrics right before starting — orientation may have changed
        resolveScreenMetrics()

        service.startRecording(
            resultCode = resultCode,
            data = data,
            fileName = fileName,
            screenWidth = screenWidth,
            screenHeight = screenHeight,
            screenDpi = screenDpi,
            onSuccess = { capturedResult?.success(null) },
            onError = { msg -> capturedResult?.error("START_FAILED", msg, null) }
        )
    }

    //  Stop Recording 
    private fun stopRecording(result: MethodChannel.Result) {
        val service = recordService
        if (service == null) {
            result.error("SERVICE_NOT_BOUND", "Recording service unavailable", null)
            return
        }
        service.stopRecording(
            onSuccess = { path -> result.success(path) },
            onError = { msg -> result.error("STOP_FAILED", msg, null) }
        )
    }

    //  Cleanup 
    override fun onDestroy() {
        if (serviceBound) {
            unbindService(serviceConnection)
            serviceBound = false
        }
        super.onDestroy()
    }
}