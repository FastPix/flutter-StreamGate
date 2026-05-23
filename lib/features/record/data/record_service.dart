import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// RecordService handles:
class RecordService {
  //  Camera 
  CameraController? controller;

  Future<void> init(CameraDescription camera) async {
    controller = CameraController(
      camera,
      ResolutionPreset.low,
    );
    await controller!.initialize();
  }

  Future<String?> startRecording() async {
    if (controller == null) return null;
    await controller!.startVideoRecording();
    return null;
  }

  Future<String?> stopRecording() async {
    if (controller == null) return null;
    final XFile file = await controller!.stopVideoRecording();
    return file.path;
  }

  // Android Screen Recording 
  static const _androidChannel =
      MethodChannel('streamgate/android_screen_record');

  /// Starts screen recording on Android.
  /// [fileName] is a base name (no extension); the native side appends .mp4.
  Future<void> startScreenRecording(String fileName) async {
    try {
      await _androidChannel.invokeMethod<void>(
        'startScreenRecording',
        {'fileName': fileName},
      );
    } catch (e) {
      debugPrint(' startScreenRecording error: $e');
    }
  }

  /// Stops screen recording and returns the absolute path to the saved MP4,
  /// or null on failure.
  Future<String?> stopScreenRecording() async {
    try {
      final path =
          await _androidChannel.invokeMethod<String>('stopScreenRecording');
      debugPrint('ANDROID SCREEN RECORD PATH: $path');
      return path;
    } catch (e) {
      debugPrint('stopScreenRecording error: $e');
      return null;
    }
  }

  // Cleanup 
  void dispose() {
    controller?.dispose();
  }
}