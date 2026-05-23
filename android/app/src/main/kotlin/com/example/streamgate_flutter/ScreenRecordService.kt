package com.example.streamgate_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Binder
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ScreenRecordService : Service() {

    private val NOTIFICATION_CHANNEL_ID = "streamgate_recording"
    private val NOTIFICATION_ID = 1001
    private val TAG = "ScreenRecordService"

    private var mediaProjection: MediaProjection? = null
    private var mediaRecorder: MediaRecorder? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var outputFilePath: String? = null
    private var isRecording = false

    //  Binder 
    inner class LocalBinder : Binder() {
        fun getService(): ScreenRecordService = this@ScreenRecordService
    }
    private val binder = LocalBinder()

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    // Notification 
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Screen Recording",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Used while screen recording is active"
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Screen Recording")
            .setContentText("Recording your screen…")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setSilent(true)
            .build()

    //  Start Recording
    fun startRecording(
        resultCode: Int,
        data: Intent,
        fileName: String,
        screenWidth: Int,
        screenHeight: Int,
        screenDpi: Int,
        onSuccess: () -> Unit,
        onError: (String) -> Unit
    ) {
        createNotificationChannel()

        // FIX 1: Must call startForeground() before getMediaProjection() on API 29+
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // API 34+
                startForeground(
                    NOTIFICATION_ID,
                    buildNotification(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
            } else {
                startForeground(NOTIFICATION_ID, buildNotification())
            }
        } catch (e: Exception) {
            Log.e(TAG, " startForeground failed: ${e.message}")
            onError("Failed to start foreground service: ${e.message}")
            return
        }

        try {
            val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = mpm.getMediaProjection(resultCode, data)

            if (mediaProjection == null) {
                onError("Failed to obtain MediaProjection token")
                stopForegroundCompat()
                return
            }

            // FIX 2: Register MediaProjection.Callback BEFORE createVirtualDisplay (required API 31+)
            // Without this, the system kills the projection immediately on API 31+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                mediaProjection!!.registerCallback(object : MediaProjection.Callback() {
                    override fun onStop() {
                        Log.d(TAG, "MediaProjection stopped by system")
                        // Clean up if the system stops the projection externally
                        if (isRecording) {
                            try { mediaRecorder?.stop() } catch (_: Exception) {}
                            try { mediaRecorder?.release() } catch (_: Exception) {}
                            mediaRecorder = null
                            isRecording = false
                            virtualDisplay?.release()
                            virtualDisplay = null
                            stopForegroundCompat()
                        }
                    }
                }, Handler(Looper.getMainLooper()))
            }

            // FIX 3: Clamp screen dimensions to even numbers (MediaRecorder requirement)
            // Some devices report odd pixel counts which cause prepare() to fail
            val recWidth = if (screenWidth % 2 == 0) screenWidth else screenWidth - 1
            val recHeight = if (screenHeight % 2 == 0) screenHeight else screenHeight - 1

            // FIX 4: Cap resolution to avoid prepare() failure on low-end devices
            // Moto G71 5G = 1080p; cap at 1080 to be safe
            val (finalWidth, finalHeight) = scaleDown(recWidth, recHeight, maxDimension = 1280)

            // Prepare output file
            val dir = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                File(getExternalFilesDir(Environment.DIRECTORY_MOVIES), "StreamGate")
            } else {
                @Suppress("DEPRECATION")
                File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES),
                    "StreamGate"
                )
            }
            if (!dir.exists()) dir.mkdirs()

            val ts = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val outFile = File(dir, "${fileName}_${ts}.mp4")
            outputFilePath = outFile.absolutePath

            // FIX 5: Correct MediaRecorder setup order (Android docs mandate this exact order)
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            with(mediaRecorder!!) {
                // Step 1: Set sources FIRST — audio before video
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setVideoSource(MediaRecorder.VideoSource.SURFACE)

                // Step 2: Output format
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)

                // Step 3: Output file (must be after setOutputFormat)
                setOutputFile(outputFilePath)

                // Step 4: Encoders (must be after setOutputFormat)
                setVideoEncoder(MediaRecorder.VideoEncoder.H264)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)

                // Step 5: Encoding parameters
                setVideoSize(finalWidth, finalHeight)
                setVideoFrameRate(30)
                setVideoEncodingBitRate(4 * 1024 * 1024) // 4 Mbps — stable on mid-range devices
                setAudioEncodingBitRate(128_000)
                setAudioSamplingRate(44100)

                // Step 6: prepare() — this is where -2147483648 was thrown
                prepare()
            }

            // FIX 6: Create VirtualDisplay AFTER MediaRecorder is prepared (surface is now valid)
            virtualDisplay = mediaProjection!!.createVirtualDisplay(
                "StreamGateCapture",
                finalWidth, finalHeight, screenDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                mediaRecorder!!.surface,
                null, null
            )

            mediaRecorder!!.start()
            isRecording = true
            Log.d(TAG, " Screen recording started → $outputFilePath (${finalWidth}x${finalHeight})")
            onSuccess()

        } catch (e: Exception) {
            Log.e(TAG, " startRecording failed: ${e.message}")
            cleanupMediaRecorder()
            stopForegroundCompat()
            stopSelf()
            onError(e.message ?: "Unknown error")
        }
    }

    //  Stop Recording 
    fun stopRecording(
        onSuccess: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        try {
            if (isRecording) {
                mediaRecorder?.stop()
                isRecording = false
            }
            cleanupMediaRecorder()

            virtualDisplay?.release()
            virtualDisplay = null

            mediaProjection?.stop()
            mediaProjection = null

            stopForegroundCompat()
            stopSelf()

            val path = outputFilePath
            outputFilePath = null
            Log.d(TAG, "Screen recording stopped → $path")

            if (path != null && File(path).exists()) {
                onSuccess(path)
            } else {
                onError("Recording file not found at $path")
            }
        } catch (e: Exception) {
            Log.e(TAG, " stopRecording failed: ${e.message}")
            cleanupMediaRecorder()
            stopForegroundCompat()
            stopSelf()
            onError(e.message ?: "Unknown stop error")
        }
    }

    // Helpers 
    private fun cleanupMediaRecorder() {
        try { mediaRecorder?.reset() } catch (_: Exception) {}
        try { mediaRecorder?.release() } catch (_: Exception) {}
        mediaRecorder = null
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    /** Scale width/height down so neither exceeds [maxDimension], preserving even numbers. */
    private fun scaleDown(w: Int, h: Int, maxDimension: Int): Pair<Int, Int> {
        if (w <= maxDimension && h <= maxDimension) return Pair(w, h)
        val scale = maxDimension.toFloat() / maxOf(w, h)
        val sw = ((w * scale).toInt()).let { if (it % 2 == 0) it else it - 1 }
        val sh = ((h * scale).toInt()).let { if (it % 2 == 0) it else it - 1 }
        return Pair(sw, sh)
    }
}