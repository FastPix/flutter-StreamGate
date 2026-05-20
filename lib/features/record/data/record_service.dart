import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';

class RecordService {
  CameraController? controller;

 
  // CAMERA RECORDING
  

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

  
  // SCREEN RECORDING (FIXED)
  

  Future<void> startScreenRecording(String fileName) async {
    await FlutterScreenRecording.startRecordScreen(fileName);
  }

  Future<String?> stopScreenRecording() async {
    final path =
        await FlutterScreenRecording.stopRecordScreen; // ✅ IMPORTANT FIX
    debugPrint("📁 SCREEN RECORD PATH: $path");
    return path;
  }

  
  // CLEANUP
  

  void dispose() {
    controller?.dispose();
  }
}
