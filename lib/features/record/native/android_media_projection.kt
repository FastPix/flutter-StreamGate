package com.example.streamgate_flutter

import android.app.Activity
import android.content.Intent
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Environment
import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

import java.io.File

class AndroidMediaProjection :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware {

    private lateinit var channel: MethodChannel

    private var activity: Activity? = null

    private var mediaProjectionManager:
        MediaProjectionManager? = null

    private var mediaProjection:
        MediaProjection? = null

    private var mediaRecorder:
        MediaRecorder? = null

    private var outputPath: String? = null

    companion object {

        private const val CHANNEL =
            "streamgate/screen_record"

        private const val REQUEST_CODE = 1001
    }

    
    // FLUTTER ENGINE
    override fun onAttachedToEngine(
        @NonNull binding:
        FlutterPlugin.FlutterPluginBinding
    ) {

        channel = MethodChannel(
            binding.binaryMessenger,
            CHANNEL
        )

        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(
        @NonNull binding:
        FlutterPlugin.FlutterPluginBinding
    ) {

        channel.setMethodCallHandler(null)
    }

    
    // METHOD CHANNEL

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result
    ) {

        when (call.method) {

            "startScreenRecording" -> {
                startRecording(result)
            }

            "stopScreenRecording" -> {
                stopRecording(result)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    
    // START RECORDING

    private fun startRecording(
        result: MethodChannel.Result
    ) {

        try {

            mediaProjectionManager =
                activity?.getSystemService(
                    Activity.MEDIA_PROJECTION_SERVICE
                ) as MediaProjectionManager

            val captureIntent =
                mediaProjectionManager
                    ?.createScreenCaptureIntent()

            activity?.startActivityForResult(
                captureIntent,
                REQUEST_CODE
            )

            setupRecorder()

            result.success(true)

        } catch (e: Exception) {

            result.error(
                "START_ERROR",
                e.message,
                null
            )
        }
    }

    
    // STOP RECORDING

    private fun stopRecording(
        result: MethodChannel.Result
    ) {

        try {

            mediaRecorder?.stop()
            mediaRecorder?.reset()

            mediaProjection?.stop()

            result.success(outputPath)

        } catch (e: Exception) {

            result.error(
                "STOP_ERROR",
                e.message,
                null
            )
        }
    }

  
    // RECORDER SETUP

    private fun setupRecorder() {

        val dir =
            activity?.getExternalFilesDir(null)

        outputPath =
            "${dir?.absolutePath}/screen_record.mp4"

        mediaRecorder = MediaRecorder()

        mediaRecorder?.apply {

            setAudioSource(
                MediaRecorder.AudioSource.MIC
            )

            setVideoSource(
                MediaRecorder.VideoSource.SURFACE
            )

            setOutputFormat(
                MediaRecorder.OutputFormat.MPEG_4
            )

            setOutputFile(outputPath)

            setVideoEncoder(
                MediaRecorder.VideoEncoder.H264
            )

            setAudioEncoder(
                MediaRecorder.AudioEncoder.AAC
            )

            setVideoFrameRate(30)

            setVideoSize(720, 1280)

            prepare()
        }
    }


    // ACTIVITY AWARE
   
    override fun onAttachedToActivity(
        binding: ActivityPluginBinding
    ) {

        activity = binding.activity
    }

    override fun onDetachedFromActivity() {

        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(
        binding: ActivityPluginBinding
    ) {

        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {

        activity = null
    }
}